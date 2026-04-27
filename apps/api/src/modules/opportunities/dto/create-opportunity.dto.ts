import { Transform } from 'class-transformer';
import { OpportunityType, UrgencyLevel } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class CreateOpportunityDto {
  @IsString()
  title!: string;

  @IsString()
  description!: string;

  @IsEnum(OpportunityType)
  opportunityType!: OpportunityType;

  @IsOptional()
  @IsUUID()
  specialtyId?: string;

  @IsOptional()
  @IsString()
  customSpecialtyLabel?: string;

  @IsDateString()
  startAt!: string;

  @IsDateString()
  endAt!: string;

  @Transform(({ value }) => Number(value))
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  grossAmount!: number;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  durationHours?: number;

  @IsOptional()
  @IsEnum(UrgencyLevel)
  urgencyLevel?: UrgencyLevel;

  @IsOptional()
  @IsUUID()
  addressId?: string;

  @IsOptional()
  @IsBoolean()
  requiresVerifiedProfile?: boolean;
}
