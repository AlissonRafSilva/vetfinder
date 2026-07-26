import { Module } from '@nestjs/common';
import { AsaasModule } from '../asaas/asaas.module';
import { PlatformConfigModule } from '../platform/platform-config.module';
import { PaymentProvider } from './payment-provider';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

@Module({
  imports: [AsaasModule, PlatformConfigModule],
  controllers: [PaymentsController],
  providers: [PaymentsService, PaymentProvider],
})
export class PaymentsModule {}
