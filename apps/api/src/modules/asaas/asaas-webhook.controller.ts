import {
  Body,
  Controller,
  Headers,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, timingSafeEqual } from 'crypto';
import { AsaasWebhookService } from './asaas-webhook.service';

@Controller('payments/asaas/webhook')
export class AsaasWebhookController {
  constructor(
    private readonly configService: ConfigService,
    private readonly webhookService: AsaasWebhookService,
  ) {}

  @Post()
  receive(
    @Headers('asaas-access-token') receivedToken: string | undefined,
    @Body() payload: unknown,
  ) {
    this.assertValidToken(receivedToken);
    return this.webhookService.receive(payload);
  }

  private assertValidToken(receivedToken?: string) {
    const expectedToken = this.configService
      .get<string>('ASAAS_WEBHOOK_TOKEN')
      ?.trim();

    if (!expectedToken || !receivedToken) {
      throw new UnauthorizedException('Webhook nao autorizado.');
    }

    const expectedHash = createHash('sha256').update(expectedToken).digest();
    const receivedHash = createHash('sha256').update(receivedToken).digest();

    if (!timingSafeEqual(expectedHash, receivedHash)) {
      throw new UnauthorizedException('Webhook nao autorizado.');
    }
  }
}
