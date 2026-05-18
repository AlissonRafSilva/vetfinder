import { Module } from '@nestjs/common';
import { PaymentProvider } from './payment-provider';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

@Module({
  controllers: [PaymentsController],
  providers: [PaymentsService, PaymentProvider],
})
export class PaymentsModule {}
