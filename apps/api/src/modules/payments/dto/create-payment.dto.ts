import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class CreatePaymentDto {
  @IsUUID()
  engagementId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  provider?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  providerPaymentId?: string;
}
