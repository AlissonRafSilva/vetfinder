import { InstitutionType, VerificationStatus } from '@prisma/client';
import { Transform } from 'class-transformer';
import { IsEnum, IsNumber, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

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
  @IsString()
  @MaxLength(100)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2)
  state?: string;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsNumber()
  lat?: number;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsNumber()
  lng?: number;

  @IsOptional()
  @IsEnum(VerificationStatus)
  verificationStatus?: VerificationStatus;
}
