import { Module } from '@nestjs/common';
import { AsaasAccountsService } from './asaas-accounts.service';
import { AsaasController } from './asaas.controller';
import { AsaasService } from './asaas.service';

@Module({
  controllers: [AsaasController],
  providers: [AsaasService, AsaasAccountsService],
  exports: [AsaasService, AsaasAccountsService],
})
export class AsaasModule {}
