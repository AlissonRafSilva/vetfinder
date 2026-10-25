import { IsNumber, IsOptional, Max, Min } from 'class-validator';
import { QuotePaymentDto } from './quote-payment.dto';

export class CreatePaymentDto extends QuotePaymentDto {
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(99999999.99)
  expectedChargeAmount?: number;
}
