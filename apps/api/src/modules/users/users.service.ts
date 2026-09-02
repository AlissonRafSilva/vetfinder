import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AccountStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findById(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        email: true,
        phone: true,
        role: true,
        status: true,
        profile: {
          select: {
            fullName: true,
            photoUrl: true,
            city: true,
            state: true,
            bio: true,
            isVisible: true,
          },
        },
        veterinarianProfile: true,
        internProfile: true,
        institution: true,
      },
    });

    if (!user) {
      throw new NotFoundException('Usuario nao encontrado.');
    }

    return user;
  }

  async exportMyData(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        phone: true,
        role: true,
        status: true,
        createdAt: true,
        profile: true,
        veterinarianProfile: true,
        internProfile: true,
        institution: true,
        documents: {
          select: {
            documentType: true,
            fileUrl: true,
            status: true,
            createdAt: true,
          },
        },
        availabilitySlots: true,
        notifications: true,
        asaasAccounts: {
          select: {
            environment: true,
            accountStatus: true,
            onboardingStatus: true,
            createdAt: true,
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('Usuario nao encontrado.');
    }

    return {
      exportedAt: new Date().toISOString(),
      format: 'vetfinder-account-export-v1',
      data: user,
    };
  }

  async deactivateMyAccount(userId: string, confirmation: string) {
    if (confirmation !== 'ENCERRAR MINHA CONTA') {
      throw new BadRequestException('Confirmacao invalida.');
    }

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { status: AccountStatus.SUSPENDED },
      }),
      this.prisma.auditLog.create({
        data: {
          actorUserId: userId,
          actorType: 'USER',
          action: 'ACCOUNT_DEACTIVATED_BY_OWNER',
          entityType: 'USER',
          entityId: userId,
        },
      }),
    ]);

    return {
      message:
        'Conta desativada. Registros financeiros e de auditoria sao preservados conforme obrigacoes legais.',
    };
  }
}
