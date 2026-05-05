import { Transform } from 'class-transformer';
import { IsEnum, IsIn, IsNumber, IsOptional, IsUUID, Min } from 'class-validator';
import { OpportunityStatus, OpportunityType, UrgencyLevel } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination-query.dto';

export class ListOpportunitiesDto extends PaginationQueryDto {
  @IsOptional()
  @IsEnum(OpportunityStatus)
  status?: OpportunityStatus;

  @IsOptional()
  @IsEnum(OpportunityType)
  opportunityType?: OpportunityType;

  @IsOptional()
  @IsIn(['VETERINARIAN', 'INTERN'])
  audience?: 'VETERINARIAN' | 'INTERN';

  @IsOptional()
  @IsEnum(UrgencyLevel)
  urgencyLevel?: UrgencyLevel;

  @IsOptional()
  @IsUUID()
  specialtyId?: string;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsNumber()
  @Min(0)
  minAmount?: number;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsNumber()
  @Min(0)
  maxAmount?: number;
}
