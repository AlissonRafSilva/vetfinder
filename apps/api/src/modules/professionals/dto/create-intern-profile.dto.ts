import { Transform } from 'class-transformer';
import { IsDateString, IsNumber, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateInternProfileDto {
  @IsString()
  @MaxLength(150)
  universityName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  coursePeriod?: string;

  @IsOptional()
  @IsDateString()
  expectedGraduationDate?: string;

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
}
