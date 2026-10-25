import { Module } from '@nestjs/common';
import { AsaasAccountsService } from './asaas-accounts.service';
import { AsaasController } from './asaas.controller';
import { AsaasService } from './asaas.service';
import { AsaasWebhookController } from './asaas-webhook.controller';
import { AsaasWebhookService } from './asaas-webhook.service';
import { AsaasPaymentReconciliationService } from './asaas-payment-reconciliation.service';

@Module({
  controllers: [AsaasController, AsaasWebhookController],
  providers: [AsaasService, AsaasAccountsService, AsaasWebhookService, AsaasPaymentReconciliationService],
  exports: [AsaasService, AsaasAccountsService, AsaasPaymentReconciliationService],
})
export class AsaasModule {}
