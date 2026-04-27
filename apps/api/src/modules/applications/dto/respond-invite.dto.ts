import { InteractionStatus } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class RespondInviteDto {
  @IsEnum(InteractionStatus)
  status!: InteractionStatus;
}
