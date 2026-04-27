import { OpportunityStatus } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class UpdateOpportunityStatusDto {
  @IsEnum(OpportunityStatus)
  status!: OpportunityStatus;
}
