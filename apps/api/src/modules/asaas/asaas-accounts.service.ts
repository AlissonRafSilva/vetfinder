import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AsaasAccountStatus,
  AsaasEnvironment,
  AsaasOnboardingStatus,
  Prisma,
  PaymentStatus,
  SplitStatus,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { AsaasService } from './asaas.service';
import {
  AsaasPaymentReconciliationService,
  asaasPaymentMetadata,
} from './asaas-payment-reconciliation.service';
import { CreateAsaasAccountDto } from './dto/create-asaas-account.dto';

@Injectable()
export class AsaasAccountsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly asaasService: AsaasService,
    private readonly reconciliation: AsaasPaymentReconciliationService,
  ) {}

  async create(
    dto: CreateAsaasAccountDto,
    authenticatedUser: AuthenticatedUser,
  ) {
    this.validateDocumentData(dto);
    const environment = this.getEnvironment();
    const user = await this.prisma.user.findUnique({
      where: { id: authenticatedUser.userId },
      include: { profile: true },
    });

    if (!user?.profile) {
      throw new NotFoundException('Perfil profissional nao encontrado.');
    }

    const existingAccount = await this.prisma.asaasAccount.findUnique({
      where: {
        userId_environment: { userId: user.id, environment },
      },
    });
    if (existingAccount) {
      throw new ConflictException(
        'Ja existe um cadastro financeiro para este ambiente.',
      );
    }

    let pendingAccount;
    try {
      pendingAccount = await this.prisma.asaasAccount.create({
        data: {
          userId: user.id,
          environment,
          onboardingStatus: AsaasOnboardingStatus.PENDING_DATA,
        },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException(
          'Ja existe um cadastro financeiro para este ambiente.',
        );
      }
      throw error;
    }

    let providerAccount: {
      id: string;
      walletId: string;
      generalStatus?: string;
    };
    try {
      providerAccount = await this.asaasService.createSubaccount({
        name: user.profile.fullName,
        email: user.email,
        ...dto,
      });
    } catch (error) {
      await this.prisma.asaasAccount.deleteMany({
        where: {
          id: pendingAccount.id,
          asaasAccountId: null,
        },
      });
      throw error;
    }

    return this.prisma.$transaction(async (tx) => {
      const approved = providerAccount.generalStatus === 'APPROVED';
      const account = await tx.asaasAccount.update({
        where: { id: pendingAccount.id },
        data: {
          asaasAccountId: providerAccount.id,
          asaasWalletId: providerAccount.walletId,
          accountStatus: approved
            ? AsaasAccountStatus.ACTIVE
            : AsaasAccountStatus.PENDING,
          onboardingStatus: approved
            ? AsaasOnboardingStatus.APPROVED
            : AsaasOnboardingStatus.UNDER_REVIEW,
          lastSynchronizedAt: new Date(),
        },
      });

      await tx.auditLog.create({
        data: {
          actorUserId: user.id,
          actorType: 'USER',
          action: 'ASAAS_ACCOUNT_CREATED',
          entityType: 'ASAAS_ACCOUNT',
          entityId: account.id,
          metadataJson: { environment },
        },
      });

      return account;
    });
  }

  async findMine(authenticatedUser: AuthenticatedUser) {
    const account = await this.prisma.asaasAccount.findUnique({
      where: {
        userId_environment: {
          userId: authenticatedUser.userId,
          environment: this.getEnvironment(),
        },
      },
    });

    if (!account) {
      throw new NotFoundException('Cadastro financeiro nao encontrado.');
    }

    return account;
  }

  async resetMine(authenticatedUser: AuthenticatedUser) {
    const environment = this.getEnvironment();
    if (environment !== AsaasEnvironment.SANDBOX) {
      throw new BadRequestException(
        'A reinicializacao da conta financeira so esta disponivel no Sandbox.',
      );
    }

    const account = await this.prisma.asaasAccount.findUnique({
      where: {
        userId_environment: {
          userId: authenticatedUser.userId,
          environment,
        },
      },
    });
    if (!account) {
      throw new NotFoundException('Cadastro financeiro nao encontrado.');
    }

    if (this.asaasService.isEnabled()) {
      const productionAccount = await this.prisma.asaasAccount.findFirst({
        where: {
          userId: authenticatedUser.userId,
          environment: AsaasEnvironment.PRODUCTION,
        },
        select: { id: true },
      });
      const failed = await this.prisma.payment.findMany({
        where: {
          provider: 'asaas',
          status: PaymentStatus.FAILED,
          providerStatus: 'CREATE_FAILED',
          providerPaymentId: null,
          engagement: { professionalUserId: authenticatedUser.userId },
        },
        select: { id: true, providerPayload: true },
      });
      for (const payment of failed) {
        const sourceEnvironment = asaasPaymentMetadata(
          payment.providerPayload,
        ).environment;
        if (
          sourceEnvironment === 'sandbox' ||
          (!sourceEnvironment && !productionAccount)
        ) {
          await this.reconciliation.refresh(payment.id);
        }
      }
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM public.asaas_accounts WHERE id = ${account.id}::uuid FOR UPDATE`;
      const current = await tx.asaasAccount.findUnique({
        where: { id: account.id },
      });
      if (!current)
        throw new NotFoundException('Cadastro financeiro nao encontrado.');
      const activePayments = await tx.payment.count({
        where: {
          provider: 'asaas',
          engagement: { professionalUserId: authenticatedUser.userId },
          OR: [
            {
              status: {
                in: [
                  PaymentStatus.PENDING,
                  PaymentStatus.AUTHORIZED,
                  PaymentStatus.PARTIALLY_REFUNDED,
                ],
              },
            },
            { status: PaymentStatus.FAILED, providerPaymentId: { not: null } },
          ],
        },
      });
      const pendingSplits = await tx.paymentSplit.count({
        where: {
          recipientId: authenticatedUser.userId,
          status: {
            in: [SplitStatus.PENDING, SplitStatus.SCHEDULED],
          },
        },
      });
      if (pendingSplits > 0 || activePayments > 0) {
        throw new ConflictException(
          'Existem pagamentos pendentes para esta carteira. O cadastro nao pode ser reiniciado.',
        );
      }

      await tx.auditLog.create({
        data: {
          actorUserId: authenticatedUser.userId,
          actorType: 'USER',
          action: 'ASAAS_SANDBOX_ACCOUNT_RESET',
          entityType: 'ASAAS_ACCOUNT',
          entityId: account.id,
          metadataJson: {
            environment,
            previousAccountStatus: current.accountStatus,
            previousOnboardingStatus: current.onboardingStatus,
          },
        },
      });
      await tx.asaasAccount.delete({
        where: { id: account.id },
      });
    });

    return {
      message: 'Cadastro financeiro Sandbox reiniciado com sucesso.',
    };
  }

  private getEnvironment() {
    return this.asaasService.getEnvironment() === 'production'
      ? AsaasEnvironment.PRODUCTION
      : AsaasEnvironment.SANDBOX;
  }

  private validateDocumentData(dto: CreateAsaasAccountDto) {
    if (dto.cpfCnpj.length === 11 && !dto.birthDate) {
      throw new BadRequestException(
        'Data de nascimento e obrigatoria para pessoa fisica.',
      );
    }

    if (dto.cpfCnpj.length === 14 && !dto.companyType) {
      throw new BadRequestException(
        'Tipo da empresa e obrigatorio para pessoa juridica.',
      );
    }
  }
}
