import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class InviteProfessionalDto {
  @IsUUID()
  professionalUserId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;
}
