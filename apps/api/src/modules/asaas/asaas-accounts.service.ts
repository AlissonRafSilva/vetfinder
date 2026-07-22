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
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { AsaasService } from './asaas.service';
import { CreateAsaasAccountDto } from './dto/create-asaas-account.dto';

@Injectable()
export class AsaasAccountsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly asaasService: AsaasService,
  ) {}

  async create(dto: CreateAsaasAccountDto, authenticatedUser: AuthenticatedUser) {
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

    let providerAccount: { id: string; walletId: string };
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
      const account = await tx.asaasAccount.update({
        where: { id: pendingAccount.id },
        data: {
          asaasAccountId: providerAccount.id,
          asaasWalletId: providerAccount.walletId,
          accountStatus: AsaasAccountStatus.PENDING,
          onboardingStatus: AsaasOnboardingStatus.UNDER_REVIEW,
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
