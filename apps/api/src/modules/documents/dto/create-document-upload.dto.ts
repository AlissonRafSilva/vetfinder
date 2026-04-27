import { DocumentOwnerType, DocumentType } from '@prisma/client';
import { IsEnum, IsOptional, IsString, IsUUID } from 'class-validator';

export class CreateDocumentUploadDto {
  @IsEnum(DocumentOwnerType)
  ownerType!: DocumentOwnerType;

  @IsOptional()
  @IsUUID()
  institutionId?: string;

  @IsEnum(DocumentType)
  documentType!: DocumentType;

  @IsString()
  fileName!: string;

  @IsOptional()
  @IsString()
  mimeType?: string;
}
