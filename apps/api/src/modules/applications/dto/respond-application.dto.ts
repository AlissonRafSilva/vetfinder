import { InteractionStatus } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class RespondApplicationDto {
  @IsEnum(InteractionStatus)
  status!: InteractionStatus;
}
