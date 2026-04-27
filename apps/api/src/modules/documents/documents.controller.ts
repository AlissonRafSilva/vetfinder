import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { DocumentOwnerType, VerificationStatus } from '@prisma/client';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateDocumentDto } from './dto/create-document.dto';
import { CreateDocumentUploadDto } from './dto/create-document-upload.dto';
import { ReviewDocumentDto } from './dto/review-document.dto';
import { DocumentsService } from './documents.service';

@Controller('documents')
export class DocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  @Post()
  create(@Body() dto: CreateDocumentDto) {
    return this.documentsService.create(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('prepare-upload')
  prepareUpload(
    @Body() dto: CreateDocumentUploadDto,
    @CurrentUser() user: { userId: string },
  ) {
    return this.documentsService.prepareUpload(dto, user.userId);
  }

  @Get()
  findAll(@Query('status') status?: VerificationStatus) {
    return this.documentsService.findAll(status);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.documentsService.findOne(id);
  }

  @Patch(':id/review')
  review(@Param('id') id: string, @Body() dto: ReviewDocumentDto) {
    return this.documentsService.review(id, dto);
  }
}
