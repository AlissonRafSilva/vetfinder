import { Module } from '@nestjs/common';
import { AsaasAccountsService } from './asaas-accounts.service';
import { AsaasController } from './asaas.controller';
import { AsaasService } from './asaas.service';
import { AsaasWebhookController } from './asaas-webhook.controller';
import { AsaasWebhookService } from './asaas-webhook.service';

@Module({
  controllers: [AsaasController, AsaasWebhookController],
  providers: [AsaasService, AsaasAccountsService, AsaasWebhookService],
  exports: [AsaasService, AsaasAccountsService],
})
export class AsaasModule {}
