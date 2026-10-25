import { IsUUID } from 'class-validator';

export class QuotePaymentDto {
  @IsUUID()
  engagementId!: string;
}
