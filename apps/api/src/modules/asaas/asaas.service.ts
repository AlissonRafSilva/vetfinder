import {
  BadGatewayException,
  Injectable,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';

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

export type EnsureAsaasCustomerInput = {
  externalReference: string;
  name: string;
  cpfCnpj: string;
  email: string;
  mobilePhone?: string;
  address?: string;
  addressNumber?: string;
  complement?: string;
  province?: string;
  postalCode?: string;
};

export type CreateAsaasPixChargeInput = {
  customerId: string;
  externalReference: string;
  description: string;
  value: number;
  dueDate: string;
  professionalWalletId: string;
  professionalAmount: number;
  splitExternalReference: string;
};

type AsaasSubaccountResponse = {
  id: string;
  walletId: string;
  apiKey?: string;
};

type AsaasAccountStatusResponse = {
  general?: string;
};

type AsaasCustomerResponse = {
  id: string;
};

type AsaasCustomerListResponse = {
  data?: AsaasCustomerResponse[];
};

export type AsaasChargeSplit = {
  id?: string;
  walletId?: string;
  status?: string;
  fixedValue?: number;
  percentualValue?: number;
  totalValue?: number;
  externalReference?: string;
};

export type AsaasChargeResponse = {
  id: string;
  status: string;
  invoiceUrl?: string;
  value?: number;
  netValue?: number;
  externalReference?: string;
  customer?: string;
  billingType?: string;
  paymentDate?: string;
  confirmedDate?: string;
  split?: AsaasChargeSplit[];
};

type AsaasChargeListResponse = {
  data?: AsaasChargeResponse[];
};

type AsaasPixQrCodeResponse = {
  encodedImage?: string;
  payload?: string;
  expirationDate?: string;
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
    const webhookToken = this.configService
      .get<string>('ASAAS_WEBHOOK_TOKEN')
      ?.trim();
    const webhookUrl = this.configService
      .get<string>('ASAAS_WEBHOOK_URL')
      ?.trim();
    const webhookEmail = this.configService
      .get<string>('ASAAS_WEBHOOK_EMAIL')
      ?.trim();
    const apiUrl = this.getApiUrl();
    const environment = this.getEnvironment();
    const expectedApiUrl = environment === 'production'
      ? 'https://api.asaas.com/v3' : 'https://api-sandbox.asaas.com/v3';

    if (!['sandbox', 'production'].includes(environment) || apiUrl !== expectedApiUrl) {
      throw new Error('ASAAS_ENVIRONMENT e ASAAS_API_URL precisam apontar para o mesmo ambiente oficial.');
    }

    if (!apiKey) {
      throw new Error('ASAAS_API_KEY precisa estar configurada.');
    }

    if (!webhookToken || webhookToken.length < 32) {
      throw new Error(
        'ASAAS_WEBHOOK_TOKEN precisa ter pelo menos 32 caracteres.',
      );
    }

    if (!webhookUrl || !webhookUrl.startsWith('https://')) {
      throw new Error('ASAAS_WEBHOOK_URL precisa usar HTTPS.');
    }

    if (!webhookEmail || !webhookEmail.includes('@')) {
      throw new Error('ASAAS_WEBHOOK_EMAIL precisa ser um e-mail valido.');
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
  ): Promise<
    Pick<AsaasSubaccountResponse, 'id' | 'walletId'> & {
      generalStatus?: string;
    }
  > {
    const response = await fetch(`${this.getApiUrl()}/accounts`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({
        ...input,
        webhooks: [this.getSubaccountWebhook()],
      }),
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

    // A apiKey e usada apenas em memoria para a consulta inicial e nunca e persistida.
    const initialStatus = account.apiKey
      ? await this.getInitialAccountStatus(account.apiKey)
      : undefined;
    return {
      id: account.id,
      walletId: account.walletId,
      generalStatus: initialStatus?.general,
    };
  }

  async ensureCustomer(
    input: EnsureAsaasCustomerInput,
  ): Promise<AsaasCustomerResponse> {
    const query = new URLSearchParams({
      externalReference: input.externalReference,
      cpfCnpj: input.cpfCnpj,
      limit: '1',
    });
    const existing = await this.request<AsaasCustomerListResponse>(
      `/customers?${query.toString()}`,
      { method: 'GET' },
      'find_customer',
    );
    const existingCustomer = existing.data?.[0];
    if (existingCustomer?.id) {
      return existingCustomer;
    }

    return this.request<AsaasCustomerResponse>(
      '/customers',
      {
        method: 'POST',
        body: JSON.stringify({
          ...input,
          notificationDisabled: true,
        }),
      },
      'create_customer',
    );
  }

  async createPixCharge(
    input: CreateAsaasPixChargeInput,
  ): Promise<AsaasChargeResponse> {
    const existing = await this.findChargeByExternalReference(
      input.externalReference,
    );
    if (existing) {
      this.assertExpectedCharge(existing, input);
      return existing;
    }

    try {
      const created = await this.request<AsaasChargeResponse>(
        '/payments',
        {
          method: 'POST',
          body: JSON.stringify({
            customer: input.customerId,
            billingType: 'PIX',
            value: input.value,
            dueDate: input.dueDate,
            description: input.description,
            externalReference: input.externalReference,
            split: [
              {
                walletId: input.professionalWalletId,
                fixedValue: input.professionalAmount,
                externalReference: input.splitExternalReference,
                description: 'Repasse do profissional VetFinder',
              },
            ],
          }),
        },
        'create_pix_charge',
      );
      this.assertExpectedCharge(created, input);
      return created;
    } catch (error) {
      const recovered = await this.findChargeByExternalReference(
        input.externalReference,
      ).catch(() => undefined);
      if (recovered) {
        this.assertExpectedCharge(recovered, input);
        return recovered;
      }
      throw error;
    }
  }

  async getPixQrCode(paymentId: string): Promise<AsaasPixQrCodeResponse> {
    return this.request<AsaasPixQrCodeResponse>(
      `/payments/${encodeURIComponent(paymentId)}/pixQrCode`,
      { method: 'GET' },
      'get_pix_qr_code',
    );
  }

  async getCharge(paymentId: string): Promise<AsaasChargeResponse> {
    return this.request<AsaasChargeResponse>(
      `/payments/${encodeURIComponent(paymentId)}`,
      { method: 'GET' },
      'get_payment',
    );
  }

  async quotePixCharge(serviceAmount: number) {
    const serviceValue = new Prisma.Decimal(serviceAmount);
    if (!serviceValue.isFinite() || serviceValue.lte(0)) {
      throw new BadGatewayException('O valor do plantao precisa ser positivo.');
    }

    let chargeValue = serviceValue.toDecimalPlaces(2);
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const simulation = await this.request<{ pix?: { netValue?: number } }>(
        '/payments/simulate',
        {
          method: 'POST',
          body: JSON.stringify({
            value: chargeValue.toNumber(),
            billingTypes: ['PIX'],
          }),
        },
        'quote_pix_charge',
      );
      const net = simulation.pix?.netValue;
      if (typeof net !== 'number' || !Number.isFinite(net)) {
        throw new BadGatewayException('O Asaas nao retornou a tarifa do Pix.');
      }
      const netValue = new Prisma.Decimal(net).toDecimalPlaces(2);
      const missing = serviceValue.minus(netValue);
      if (missing.isZero()) {
        return {
          serviceAmount: serviceValue.toNumber(),
          chargeAmount: chargeValue.toNumber(),
          gatewayFeeAmount: chargeValue.minus(serviceValue).toNumber(),
        };
      }
      chargeValue = chargeValue.plus(missing).toDecimalPlaces(2);
      if (chargeValue.lt(serviceValue) || chargeValue.gt('99999999.99')) {
        break;
      }
    }

    throw new BadGatewayException(
      'Nao foi possivel confirmar a tarifa do Pix. Tente atualizar a simulacao.',
    );
  }

  async findChargeByExternalReference(
    externalReference: string,
  ): Promise<AsaasChargeResponse | undefined> {
    const query = new URLSearchParams({
      externalReference,
      limit: '2',
    });
    const result = await this.request<AsaasChargeListResponse>(
      `/payments?${query.toString()}`,
      { method: 'GET' },
      'find_pix_charge',
    );
    if ((result.data?.length ?? 0) > 1) {
      throw new BadGatewayException(
        'Existe mais de uma cobranca para este pagamento. Solicite conciliacao.',
      );
    }
    return result.data?.[0];
  }

  private assertExpectedCharge(
    charge: AsaasChargeResponse,
    input: CreateAsaasPixChargeInput,
  ) {
    const split = (Array.isArray(charge.split) ? charge.split : []).find(
      (item) => item.externalReference === input.splitExternalReference,
    );
    if (
      !charge.id || !charge.status ||
      charge.externalReference !== input.externalReference ||
      charge.customer !== input.customerId ||
      charge.value !== input.value ||
      charge.billingType !== 'PIX' ||
      charge.split?.length !== 1 ||
      split?.walletId !== input.professionalWalletId ||
      split.fixedValue !== input.professionalAmount ||
      (split.percentualValue ?? 0) !== 0
    ) {
      throw new BadGatewayException(
        'A cobranca existente diverge dos valores ou da carteira do contrato.',
      );
    }
  }

  getEnvironment() {
    return (
      this.configService.get<string>('ASAAS_ENVIRONMENT') ?? 'sandbox'
    )
      .trim()
      .toLowerCase();
  }

  isEnabled() {
    return (
      this.configService.get<string>('PAYMENT_PROVIDER')
        ?.trim()
        .toLowerCase() === 'asaas'
    );
  }

  private getApiUrl() {
    return (
      this.configService.get<string>('ASAAS_API_URL') ??
      (this.getEnvironment() === 'production'
        ? 'https://api.asaas.com/v3' : 'https://api-sandbox.asaas.com/v3')
    ).trim().replace(/\/+$/, '');
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

  private getSubaccountWebhook() {
    const url = this.configService.get<string>('ASAAS_WEBHOOK_URL')?.trim();
    const email = this.configService
      .get<string>('ASAAS_WEBHOOK_EMAIL')
      ?.trim();
    const authToken = this.configService
      .get<string>('ASAAS_WEBHOOK_TOKEN')
      ?.trim();
    if (!url || !email || !authToken) {
      throw new Error('Configuracao do webhook Asaas incompleta.');
    }

    return {
      name: 'VetFinder - conta e pagamentos',
      url,
      email,
      sendType: 'SEQUENTIALLY',
      interrupted: false,
      enabled: true,
      apiVersion: 3,
      authToken,
      events: [
        'ACCOUNT_STATUS_BANK_ACCOUNT_INFO_APPROVED',
        'ACCOUNT_STATUS_BANK_ACCOUNT_INFO_AWAITING_APPROVAL',
        'ACCOUNT_STATUS_BANK_ACCOUNT_INFO_PENDING',
        'ACCOUNT_STATUS_BANK_ACCOUNT_INFO_REJECTED',
        'ACCOUNT_STATUS_COMMERCIAL_INFO_APPROVED',
        'ACCOUNT_STATUS_COMMERCIAL_INFO_AWAITING_APPROVAL',
        'ACCOUNT_STATUS_COMMERCIAL_INFO_PENDING',
        'ACCOUNT_STATUS_COMMERCIAL_INFO_REJECTED',
        'ACCOUNT_STATUS_DOCUMENT_APPROVED',
        'ACCOUNT_STATUS_DOCUMENT_AWAITING_APPROVAL',
        'ACCOUNT_STATUS_DOCUMENT_PENDING',
        'ACCOUNT_STATUS_DOCUMENT_REJECTED',
        'ACCOUNT_STATUS_GENERAL_APPROVAL_APPROVED',
        'ACCOUNT_STATUS_GENERAL_APPROVAL_AWAITING_APPROVAL',
        'ACCOUNT_STATUS_GENERAL_APPROVAL_PENDING',
        'ACCOUNT_STATUS_GENERAL_APPROVAL_REJECTED',
        'PAYMENT_CREATED',
        'PAYMENT_UPDATED',
        'PAYMENT_CONFIRMED',
        'PAYMENT_RECEIVED',
        'PAYMENT_OVERDUE',
        'PAYMENT_DELETED',
        'PAYMENT_REFUNDED',
        'PAYMENT_PARTIALLY_REFUNDED',
        'PAYMENT_SPLIT_CANCELLED',
        'PAYMENT_SPLIT_DONE',
        'PAYMENT_SPLIT_DIVERGENCE_BLOCK',
        'PAYMENT_SPLIT_DIVERGENCE_BLOCK_FINISHED',
      ],
    };
  }

  private async getInitialAccountStatus(apiKey: string) {
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      if (attempt > 1) {
        await new Promise((resolve) => setTimeout(resolve, 2_000));
      }

      try {
        const response = await fetch(`${this.getApiUrl()}/myAccount/status/`, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
            access_token: apiKey,
            'User-Agent': 'VetFinder/0.1',
          },
          signal: AbortSignal.timeout(15_000),
        });
        if (!response.ok) {
          continue;
        }

        const status =
          (await response.json()) as AsaasAccountStatusResponse;
        if (status.general) {
          return status;
        }
      } catch {
        // O webhook permanece como fonte de atualizacoes caso a consulta falhe.
      }
    }

    return undefined;
  }

  private async request<T>(
    path: string,
    init: RequestInit,
    operation: string,
  ): Promise<T> {
    let response: Response;
    try {
      response = await fetch(`${this.getApiUrl()}${path}`, {
        ...init,
        headers: {
          ...this.getHeaders(),
          ...(init.headers ?? {}),
        },
        signal: AbortSignal.timeout(30_000),
      });
    } catch {
      this.logger.error(
        JSON.stringify({ provider: 'asaas', operation, transportError: true }),
      );
      throw new BadGatewayException(
        'O Asaas demorou para responder. Tente novamente.',
      );
    }

    const payload = (await response.json().catch(() => ({}))) as
      | T
      | AsaasErrorResponse;
    if (!response.ok) {
      const errorPayload = payload as AsaasErrorResponse;
      this.logProviderError(operation, response.status, errorPayload);
      throw new BadGatewayException(
        this.getProviderErrorMessage(errorPayload) ??
          'Nao foi possivel concluir a operacao no Asaas.',
      );
    }

    return payload as T;
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
