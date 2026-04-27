import { Type } from 'class-transformer';
import { AvailabilityType } from '@prisma/client';
import {
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class UpsertAvailabilitySlotDto {
  @IsOptional()
  @IsEnum(AvailabilityType)
  availabilityType?: AvailabilityType;

  @IsOptional()
  @IsInt()
  @Min(1)
  weekday?: number;

  @IsOptional()
  @IsDateString()
  specificDate?: string;

  @IsString()
  @MaxLength(5)
  startTime!: string;

  @IsString()
  @MaxLength(5)
  endTime!: string;

  @IsOptional()
  @IsString()
  timezone?: string;
}

export class ReplaceAvailabilityDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => UpsertAvailabilitySlotDto)
  slots!: UpsertAvailabilitySlotDto[];
}
