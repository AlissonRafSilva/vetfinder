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

@Injectable()
export class PaymentsService {
  constructor(private readonly prisma: PrismaService) {}

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

    const provider = dto.provider ?? 'manual-mvp';

    const payment = await this.prisma.$transaction(async (tx) => {
      const createdPayment = await tx.payment.create({
        data: {
          engagementId: dto.engagementId,
          provider,
          providerPaymentId: dto.providerPaymentId,
          status: PaymentStatus.PAID,
          grossAmount: engagement.grossAmount,
          platformFeeAmount: engagement.platformFeeAmount,
          netAmount: engagement.netAmount,
          paidAt: new Date(),
        },
      });

      await tx.paymentSplit.createMany({
        data: [
          {
            paymentId: createdPayment.id,
            recipientType: SplitRecipientType.PLATFORM,
            amount: engagement.platformFeeAmount,
            status: SplitStatus.SCHEDULED,
          },
          {
            paymentId: createdPayment.id,
            recipientType: SplitRecipientType.PROFESSIONAL,
            recipientId: engagement.professionalUserId,
            amount: engagement.netAmount,
            status: SplitStatus.SCHEDULED,
          },
        ],
      });

      await tx.engagement.update({
        where: { id: dto.engagementId },
        data: {
          status: EngagementStatus.CONFIRMED,
          confirmedAt: new Date(),
        },
      });

      return tx.payment.findUnique({
        where: { id: createdPayment.id },
        include: {
          splits: true,
        },
      });
    });

    return {
      message: 'Pagamento registrado com sucesso.',
      payment,
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
