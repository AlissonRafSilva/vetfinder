import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { UserRole, VerificationStatus } from '@prisma/client';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CreateDocumentDto } from './dto/create-document.dto';
import { CreateDocumentUploadDto } from './dto/create-document-upload.dto';
import { ReviewDocumentDto } from './dto/review-document.dto';
import { UploadDocumentDto } from './dto/upload-document.dto';
import { DocumentsService } from './documents.service';

@Controller('documents')
export class DocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(@Body() dto: CreateDocumentDto, @CurrentUser() user: AuthenticatedUser) {
    return this.documentsService.create(dto, user);
  }

  @UseGuards(JwtAuthGuard)
  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 8 * 1024 * 1024,
      },
      fileFilter: (_request: Request, file: any, callback) => {
        const allowedMimeTypes = new Set([
          'application/pdf',
          'image/jpeg',
          'image/png',
        ]);
        const originalName = file.originalname?.toLowerCase() ?? '';
        const hasAllowedExtension =
          originalName.endsWith('.pdf') ||
          originalName.endsWith('.jpg') ||
          originalName.endsWith('.jpeg') ||
          originalName.endsWith('.png');

        if (!allowedMimeTypes.has(file.mimetype) || !hasAllowedExtension) {
          callback(
            new BadRequestException('Formato invalido. Envie PDF, JPG ou PNG.'),
            false,
          );
          return;
        }

        callback(null, true);
      },
    }),
  )
  upload(
    @Body() dto: UploadDocumentDto,
    @UploadedFile() file: any,
    @CurrentUser() user: AuthenticatedUser,
    @Req() request: any,
  ) {
    if (!file) {
      throw new BadRequestException('Envie um arquivo para validacao.');
    }

    const baseUrl = `${request.protocol}://${request.get('host')}`;
    return this.documentsService.createFromUpload(dto, file, user, baseUrl);
  }

  @UseGuards(JwtAuthGuard)
  @Post('prepare-upload')
  prepareUpload(
    @Body() dto: CreateDocumentUploadDto,
    @CurrentUser() user: { userId: string },
  ) {
    return this.documentsService.prepareUpload(dto, user.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  findMine(@CurrentUser() user: AuthenticatedUser) {
    return this.documentsService.findMine(user);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @Get()
  findAll(@Query('status') status?: VerificationStatus) {
    return this.documentsService.findAll(status);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.documentsService.findOne(id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @Patch(':id/review')
  review(@Param('id') id: string, @Body() dto: ReviewDocumentDto) {
    return this.documentsService.review(id, dto);
  }
}
