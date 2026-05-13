import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { UserRole, VerificationStatus } from '@prisma/client';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CreateDocumentDto } from './dto/create-document.dto';
import { CreateDocumentUploadDto } from './dto/create-document-upload.dto';
import { ReviewDocumentDto } from './dto/review-document.dto';
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
