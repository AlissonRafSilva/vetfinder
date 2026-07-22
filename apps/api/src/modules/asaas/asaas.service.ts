import {
  BadGatewayException,
  Injectable,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type CreateAsaasSubaccountInput = {
  name: string;
  email: string;
  cpfCnpj: string;
  birthDate?: string;
  companyType?: string;
  mobilePhone: string;
  incomeValue: number;
  address: string;
  addressNumber: string;
  complement?: string;
  province: string;
  postalCode: string;
};

type AsaasSubaccountResponse = {
  id: string;
  walletId: string;
  apiKey?: string;
};

type AsaasErrorResponse = {
  errors?: Array<{ code?: string; description?: string }>;
};

@Injectable()
export class AsaasService implements OnModuleInit {
  private readonly logger = new Logger(AsaasService.name);

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    if (!this.isEnabled()) {
      return;
    }

    const apiKey = this.configService.get<string>('ASAAS_API_KEY')?.trim();
    const apiUrl = this.getApiUrl();

    if (!apiKey) {
      throw new Error('ASAAS_API_KEY precisa estar configurada.');
    }

    if (!apiUrl.startsWith('https://')) {
      throw new Error('ASAAS_API_URL precisa usar HTTPS.');
    }

    this.logger.log(
      `Integracao Asaas habilitada no ambiente ${this.getEnvironment()}.`,
    );
  }

  async createSubaccount(
    input: CreateAsaasSubaccountInput,
  ): Promise<Pick<AsaasSubaccountResponse, 'id' | 'walletId'>> {
    const response = await fetch(`${this.getApiUrl()}/accounts`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(input),
      signal: AbortSignal.timeout(30_000),
    });
    const payload = (await response.json().catch(() => ({}))) as
      | AsaasSubaccountResponse
      | AsaasErrorResponse;

    if (!response.ok) {
      const errorPayload = payload as AsaasErrorResponse;
      this.logProviderError(
        'create_subaccount',
        response.status,
        errorPayload,
      );
      throw new BadGatewayException(
        this.getProviderErrorMessage(errorPayload) ??
          'Nao foi possivel criar a conta financeira no Asaas.',
      );
    }

    const account = payload as AsaasSubaccountResponse;
    if (!account.id || !account.walletId) {
      this.logger.error(
        `Resposta incompleta do Asaas ao criar subconta. status=${response.status}`,
      );
      throw new BadGatewayException(
        'O Asaas nao retornou os identificadores da conta financeira.',
      );
    }

    // A apiKey da subconta pode vir na resposta, mas nao deve ser persistida.
    return { id: account.id, walletId: account.walletId };
  }

  getEnvironment() {
    return (
      this.configService.get<string>('ASAAS_ENVIRONMENT') ?? 'sandbox'
    )
      .trim()
      .toLowerCase();
  }

  private isEnabled() {
    return (
      this.configService.get<string>('PAYMENT_PROVIDER')
        ?.trim()
        .toLowerCase() === 'asaas'
    );
  }

  private getApiUrl() {
    return (
      this.configService.get<string>('ASAAS_API_URL') ??
      'https://api-sandbox.asaas.com/v3'
    ).replace(/\/$/, '');
  }

  private getHeaders() {
    const apiKey = this.configService.get<string>('ASAAS_API_KEY')?.trim();
    if (!apiKey) {
      throw new Error('ASAAS_API_KEY nao configurada.');
    }

    return {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      access_token: apiKey,
      'User-Agent': 'VetFinder/0.1',
    };
  }

  private getProviderErrorMessage(payload: AsaasErrorResponse) {
    return payload.errors?.[0]?.description;
  }

  private logProviderError(
    operation: string,
    status: number,
    payload: AsaasErrorResponse,
  ) {
    this.logger.error(
      JSON.stringify({
        provider: 'asaas',
        operation,
        status,
        errorCodes: payload.errors?.map((error) => error.code).filter(Boolean),
      }),
    );
  }
}
