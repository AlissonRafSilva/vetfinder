import { Transform } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CreateVeterinarianProfileDto {
  @IsString()
  @MaxLength(50)
  crmvNumber!: string;

  @IsString()
  @MaxLength(2)
  crmvState!: string;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @Min(0)
  baseShiftRate?: number;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(0)
  yearsExperience?: number;

  @IsOptional()
  @IsBoolean()
  emergencyCare?: boolean;

  @IsOptional()
  @IsBoolean()
  canTravel?: boolean;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(0)
  maxDistanceKm?: number;
}
