import { IsOptional, IsString, MaxLength } from 'class-validator';

export class ApplyOpportunityDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;
}
