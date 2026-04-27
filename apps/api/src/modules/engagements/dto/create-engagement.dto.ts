import { EngagementSourceType } from '@prisma/client';
import { IsEnum, IsNumber, IsOptional, IsUUID, Min } from 'class-validator';
import { Transform } from 'class-transformer';

export class CreateEngagementDto {
  @IsUUID()
  opportunityId!: string;

  @IsUUID()
  professionalUserId!: string;

  @IsEnum(EngagementSourceType)
  sourceType!: EngagementSourceType;

  @IsUUID()
  sourceId!: string;

  @Transform(({ value }) => Number(value))
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  grossAmount!: number;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  platformFeeAmount?: number;
}
