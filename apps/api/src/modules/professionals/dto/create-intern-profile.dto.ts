import { IsDateString, IsOptional, IsString, MaxLength } from 'class-validator';

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
}
