import { DocumentOwnerType, DocumentType } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class UploadDocumentDto {
  @IsEnum(DocumentOwnerType)
  ownerType!: DocumentOwnerType;

  @IsEnum(DocumentType)
  documentType!: DocumentType;
}
