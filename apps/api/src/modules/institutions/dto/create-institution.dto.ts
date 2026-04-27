import { InstitutionType, VerificationStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class CreateInstitutionDto {
  @IsEnum(InstitutionType)
  institutionType!: InstitutionType;

  @IsString()
  @MaxLength(150)
  legalName!: string;

  @IsString()
  @MaxLength(150)
  tradeName!: string;

  @IsString()
  @MaxLength(20)
  cnpj!: string;

  @IsOptional()
  @IsString()
  stateRegistration?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  contactName?: string;

  @IsOptional()
  @IsString()
  contactPhone?: string;

  @IsOptional()
  @IsUUID()
  addressId?: string;

  @IsOptional()
  @IsEnum(VerificationStatus)
  verificationStatus?: VerificationStatus;
}
