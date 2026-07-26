import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AsaasAccountStatus,
  AsaasEnvironment,
  EngagementStatus,
  PaymentStatus,
  Prisma,
  SplitRecipientType,
  SplitStatus,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AsaasService } from '../asaas/asaas.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { PlatformConfigService } from '../platform/platform-config.service';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { PaymentProvider } from './payment-provider';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly paymentProvider: PaymentProvider,
    private readonly asaasService: AsaasService,
    private readonly platformConfigService: PlatformConfigService,
  ) {}

  async create(dto: CreatePaymentDto, user: AuthenticatedUser) {
    const engagement = await this.prisma.engagement.findUnique({
      where: { id: dto.engagementId },
      include: {
        institution: {
          include: {
            user: {
              select: {
                email: true,
              },
            },
            address: true,
          },
        },
        payment: {
          include: {
            splits: true,
          },
        },
      },
    });

    if (!engagement) {
      throw new NotFoundException('Fechamento nao encontrado.');
    }

    if (engagement.institution.userId !== user.userId) {
      throw new ForbiddenException('Voce nao pode criar pagamento para este fechamento.');
    }

    if (
      engagement.payment &&
      !(
        this.asaasService.isEnabled() &&
        engagement.payment.provider === 'asaas' &&
        engagement.payment.status === PaymentStatus.FAILED &&
        !engagement.payment.providerPaymentId
      )
    ) {
      throw new ConflictException(
        'Ja existe pagamento registrado para este fechamento.',
      );
    }

    if (this.asaasService.isEnabled()) {
      return this.createAsaasPayment(engagement);
    }

    const paymentIntent = this.paymentProvider.createPaymentIntent({
      engagementId: dto.engagementId,
      grossAmount: engagement.grossAmount,
      platformFeeAmount: engagement.platformFeeAmount,
      netAmount: engagement.netAmount,
    });
    const provider = dto.provider ?? paymentIntent.provider;

    const payment = await this.prisma.$transaction(async (tx) => {
      const createdPayment = await tx.payment.create({
        data: {
          engagementId: dto.engagementId,
          provider,
          providerPaymentId: dto.providerPaymentId ?? paymentIntent.providerPaymentId,
          providerStatus: paymentIntent.providerStatus,
          checkoutUrl: paymentIntent.checkoutUrl,
          providerPayload: paymentIntent.providerPayload,
          status: PaymentStatus.PENDING,
          grossAmount: engagement.grossAmount,
          platformFeeAmount: engagement.platformFeeAmount,
          netAmount: engagement.netAmount,
        },
      });

      await tx.paymentSplit.createMany({
        data: [
          {
            paymentId: createdPayment.id,
            recipientType: SplitRecipientType.PLATFORM,
            amount: engagement.platformFeeAmount,
            status: SplitStatus.PENDING,
          },
          {
            paymentId: createdPayment.id,
            recipientType: SplitRecipientType.PROFESSIONAL,
            recipientId: engagement.professionalUserId,
            amount: engagement.netAmount,
            status: SplitStatus.PENDING,
          },
        ],
      });

      return tx.payment.findUnique({
        where: { id: createdPayment.id },
        include: {
          splits: true,
        },
      });
    });

    return {
      message: 'Checkout sandbox criado com sucesso.',
      payment,
    };
  }

  private async createAsaasPayment(engagement: {
    id: string;
    professionalUserId: string;
    grossAmount: Prisma.Decimal;
    platformFeeAmount: Prisma.Decimal;
    netAmount: Prisma.Decimal;
    institution: {
      id: string;
      legalName: string;
      tradeName: string;
      cnpj: string;
      contactPhone: string | null;
      userId: string;
      user: { email: string };
      address: {
        street: string | null;
        number: string | null;
        complement: string | null;
        district: string | null;
        zipCode: string | null;
      } | null;
    };
    payment: {
      id: string;
      providerPaymentId: string | null;
      status: PaymentStatus;
    } | null;
  }) {
    const environment =
      this.asaasService.getEnvironment() === 'production'
        ? AsaasEnvironment.PRODUCTION
        : AsaasEnvironment.SANDBOX;
    const professionalAccount = await this.prisma.asaasAccount.findUnique({
      where: {
        userId_environment: {
          userId: engagement.professionalUserId,
          environment,
        },
      },
    });

    if (
      !professionalAccount?.asaasWalletId ||
      professionalAccount.accountStatus !== AsaasAccountStatus.ACTIVE
    ) {
      throw new ConflictException(
        'O profissional precisa ter uma conta Asaas aprovada antes da cobranca.',
      );
    }

    const payment =
      engagement.payment ??
      (await this.prisma.$transaction(async (tx) => {
        const created = await tx.payment.create({
          data: {
            engagementId: engagement.id,
            provider: 'asaas',
            providerStatus: 'CREATING',
            status: PaymentStatus.PENDING,
            grossAmount: engagement.grossAmount,
            platformFeeAmount: engagement.platformFeeAmount,
            netAmount: engagement.netAmount,
          },
        });

        await tx.paymentSplit.createMany({
          data: [
            {
              paymentId: created.id,
              recipientType: SplitRecipientType.PLATFORM,
              amount: engagement.platformFeeAmount,
              status: SplitStatus.PENDING,
            },
            {
              paymentId: created.id,
              recipientType: SplitRecipientType.PROFESSIONAL,
              recipientId: engagement.professionalUserId,
              amount: engagement.netAmount,
              status: SplitStatus.PENDING,
            },
          ],
        });

        return created;
      }));

    try {
      const customer = await this.asaasService.ensureCustomer({
        externalReference: `vetfinder-institution-${engagement.institution.id}`,
        name:
          engagement.institution.tradeName || engagement.institution.legalName,
        cpfCnpj: engagement.institution.cnpj,
        email: engagement.institution.user.email,
        mobilePhone: engagement.institution.contactPhone ?? undefined,
        address: engagement.institution.address?.street ?? undefined,
        addressNumber: engagement.institution.address?.number ?? undefined,
        complement: engagement.institution.address?.complement ?? undefined,
        province: engagement.institution.address?.district ?? undefined,
        postalCode: engagement.institution.address?.zipCode ?? undefined,
      });
      const platformPercent =
        this.platformConfigService.getPlatformFeeRate() * 100;
      const professionalPercent =
        Math.round((100 - platformPercent) * 10_000) / 10_000;
      const charge = await this.asaasService.createPixCharge({
        customerId: customer.id,
        externalReference: payment.id,
        description: `Plantao VetFinder ${engagement.id}`,
        value: Number(engagement.grossAmount),
        dueDate: this.tomorrowDate(),
        professionalWalletId: professionalAccount.asaasWalletId,
        professionalPercent,
        splitExternalReference: `payment-split-${payment.id}`,
      });

      let pixQrCode:
        | { payload?: string; expirationDate?: string }
        | undefined;
      try {
        pixQrCode = await this.asaasService.getPixQrCode(charge.id);
      } catch {
        // A fatura continua valida mesmo quando o QR Code nao esta disponivel.
      }

      const updated = await this.prisma.payment.update({
        where: { id: payment.id },
        data: {
          providerPaymentId: charge.id,
          providerStatus: charge.status,
          checkoutUrl: charge.invoiceUrl,
          status: PaymentStatus.PENDING,
          providerPayload: {
            customerId: customer.id,
            billingType: 'PIX',
            pixCopyPaste: pixQrCode?.payload ?? null,
            pixExpirationDate: pixQrCode?.expirationDate ?? null,
            professionalPercent,
            splitCalculationBasis: 'ASAAS_NET_VALUE',
          },
        },
        include: { splits: true },
      });

      return {
        message: 'Cobranca Pix Asaas criada com sucesso.',
        payment: updated,
      };
    } catch (error) {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: PaymentStatus.FAILED,
          providerStatus: 'CREATE_FAILED',
        },
      });
      throw error;
    }
  }

  private tomorrowDate() {
    return new Date(Date.now() + 24 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);
  }

  async confirmSandboxPayment(paymentId: string, user: AuthenticatedUser) {
    if (this.asaasService.isEnabled()) {
      throw new ForbiddenException(
        'A confirmacao manual fica desabilitada quando o Asaas esta ativo.',
      );
    }

    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
      include: {
        engagement: {
          include: {
            institution: true,
          },
        },
      },
    });

    if (!payment) {
      throw new NotFoundException('Pagamento nao encontrado.');
    }

    if (payment.engagement.institution.userId !== user.userId) {
      throw new ForbiddenException('Voce nao pode confirmar este pagamento.');
    }

    if (payment.status === PaymentStatus.PAID) {
      throw new ConflictException('Este pagamento ja esta confirmado.');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.payment.update({
        where: { id: paymentId },
        data: {
          status: PaymentStatus.PAID,
          providerStatus: 'PAID_SANDBOX',
          paidAt: new Date(),
        },
      });

      await tx.paymentSplit.updateMany({
        where: { paymentId },
        data: {
          status: SplitStatus.SCHEDULED,
        },
      });

      await tx.engagement.update({
        where: { id: payment.engagementId },
        data: {
          status: EngagementStatus.CONFIRMED,
          confirmedAt: new Date(),
        },
      });

      return tx.payment.findUnique({
        where: { id: paymentId },
        include: { splits: true },
      });
    });

    return {
      message: 'Pagamento sandbox confirmado com sucesso.',
      payment: updated,
    };
  }

  async findOne(id: string, user: AuthenticatedUser) {
    const payment = await this.prisma.payment.findUnique({
      where: { id },
      include: {
        engagement: {
          include: {
            institution: true,
          },
        },
        splits: true,
      },
    });

    if (!payment) {
      throw new NotFoundException('Pagamento nao encontrado.');
    }

    const canAccess =
      payment.engagement.institution.userId === user.userId ||
      payment.engagement.professionalUserId === user.userId;

    if (!canAccess) {
      throw new ForbiddenException('Voce nao pode visualizar este pagamento.');
    }

    return payment;
  }

  async findByEngagement(engagementId: string, user: AuthenticatedUser) {
    const payment = await this.prisma.payment.findUnique({
      where: {
        engagementId,
      },
      include: {
        engagement: {
          include: {
            institution: true,
          },
        },
        splits: true,
      },
    });

    if (!payment) {
      throw new NotFoundException('Pagamento nao encontrado para este fechamento.');
    }

    const canAccess =
      payment.engagement.institution.userId === user.userId ||
      payment.engagement.professionalUserId === user.userId;

    if (!canAccess) {
      throw new ForbiddenException('Voce nao pode visualizar este pagamento.');
    }

    return payment;
  }
}
