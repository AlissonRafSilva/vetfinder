import { DocumentOwnerType, DocumentType, VerificationStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsString, IsUUID, IsUrl } from 'class-validator';

export class CreateDocumentDto {
  @IsEnum(DocumentOwnerType)
  ownerType!: DocumentOwnerType;

  @IsOptional()
  @IsUUID()
  userId?: string;

  @IsOptional()
  @IsUUID()
  institutionId?: string;

  @IsEnum(DocumentType)
  documentType!: DocumentType;

  @IsUrl()
  fileUrl!: string;

  @IsOptional()
  @IsString()
  mimeType?: string;

  @IsOptional()
  @IsEnum(VerificationStatus)
  status?: VerificationStatus;
}
