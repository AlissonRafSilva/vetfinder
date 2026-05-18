import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { EngagementStatus, PaymentStatus, SplitRecipientType, SplitStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { PaymentProvider } from './payment-provider';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly paymentProvider: PaymentProvider,
  ) {}

  async create(dto: CreatePaymentDto, user: AuthenticatedUser) {
    const engagement = await this.prisma.engagement.findUnique({
      where: { id: dto.engagementId },
      include: {
        institution: {
          select: {
            userId: true,
          },
        },
        payment: true,
      },
    });

    if (!engagement) {
      throw new NotFoundException('Fechamento nao encontrado.');
    }

    if (engagement.institution.userId !== user.userId) {
      throw new ForbiddenException('Voce nao pode criar pagamento para este fechamento.');
    }

    if (engagement.payment) {
      throw new ConflictException('Ja existe pagamento registrado para este fechamento.');
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

  async confirmSandboxPayment(paymentId: string, user: AuthenticatedUser) {
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
