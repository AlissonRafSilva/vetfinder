import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  EngagementSourceType,
  EngagementStatus,
  InteractionStatus,
  OpportunityStatus,
  OpportunityType,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { CreateEngagementDto } from './dto/create-engagement.dto';

@Injectable()
export class EngagementsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
  ) {}

  async create(dto: CreateEngagementDto, user: AuthenticatedUser) {
    const opportunity = await this.prisma.opportunity.findUnique({
      where: { id: dto.opportunityId },
      select: {
        id: true,
        status: true,
        institutionId: true,
        opportunityType: true,
        institution: {
          select: {
            userId: true,
          },
        },
      },
    });

    if (!opportunity) {
      throw new NotFoundException('Oportunidade nao encontrada.');
    }

    if (opportunity.institution.userId !== user.userId) {
      throw new ForbiddenException('Voce nao pode fechar esta oportunidade.');
    }

    if (opportunity.status !== OpportunityStatus.OPEN) {
      throw new ConflictException('A oportunidade precisa estar aberta para ser fechada.');
    }

    const existingEngagement = await this.prisma.engagement.findFirst({
      where: {
        opportunityId: dto.opportunityId,
      },
      select: { id: true },
    });

    if (existingEngagement) {
      throw new ConflictException('Esta oportunidade ja possui um fechamento registrado.');
    }

    if (dto.sourceType === EngagementSourceType.APPLICATION) {
      const application = await this.prisma.opportunityApplication.findUnique({
        where: { id: dto.sourceId },
        select: {
          id: true,
          opportunityId: true,
          professionalUserId: true,
          status: true,
        },
      });

      if (
        !application ||
        application.opportunityId !== dto.opportunityId ||
        application.professionalUserId !== dto.professionalUserId
      ) {
        throw new NotFoundException('Candidatura origem nao encontrada para este fechamento.');
      }

      if (application.status !== InteractionStatus.ACCEPTED) {
        throw new ConflictException(
          'A candidatura precisa estar aceita antes de fechar o plantao.',
        );
      }
    }

    if (dto.sourceType === EngagementSourceType.INVITE) {
      const invite = await this.prisma.opportunityInvite.findUnique({
        where: { id: dto.sourceId },
        select: {
          id: true,
          opportunityId: true,
          professionalUserId: true,
          status: true,
        },
      });

      if (
        !invite ||
        invite.opportunityId !== dto.opportunityId ||
        invite.professionalUserId !== dto.professionalUserId
      ) {
        throw new NotFoundException('Convite origem nao encontrado para este fechamento.');
      }

      if (invite.status !== InteractionStatus.ACCEPTED) {
        throw new ConflictException(
          'O convite precisa estar aceito antes de fechar o plantao.',
        );
      }
    }

    const professional = await this.prisma.user.findUnique({
      where: { id: dto.professionalUserId },
      select: {
        id: true,
        role: true,
      },
    });

    if (
      !professional ||
      (professional.role !== UserRole.VETERINARIAN && professional.role !== UserRole.INTERN)
    ) {
      throw new NotFoundException('Profissional nao encontrado para este fechamento.');
    }

    if (
      professional.role === UserRole.INTERN &&
      opportunity.opportunityType !== OpportunityType.INTERNSHIP
    ) {
      throw new ForbiddenException('Estagiarios so podem fechar vagas de estagio.');
    }

    if (
      professional.role === UserRole.VETERINARIAN &&
      opportunity.opportunityType === OpportunityType.INTERNSHIP
    ) {
      throw new ForbiddenException('Veterinarios volantes nao podem fechar vagas de estagio.');
    }

    const platformFeeAmount = this.calculatePlatformFee(dto.grossAmount);
    const netAmount = this.roundMoney(dto.grossAmount - platformFeeAmount);

    const engagement = await this.prisma.$transaction(async (tx) => {
      const created = await tx.engagement.create({
        data: {
          opportunityId: dto.opportunityId,
          institutionId: opportunity.institutionId,
          professionalUserId: dto.professionalUserId,
          sourceType: dto.sourceType,
          sourceId: dto.sourceId,
          grossAmount: dto.grossAmount,
          platformFeeAmount,
          netAmount,
          status: EngagementStatus.PENDING_PAYMENT,
        },
      });

      await tx.opportunity.update({
        where: { id: dto.opportunityId },
        data: {
          status: OpportunityStatus.FILLED,
        },
      });

      if (dto.sourceType === EngagementSourceType.APPLICATION) {
        await tx.opportunityApplication.update({
          where: { id: dto.sourceId },
          data: {
            status: InteractionStatus.ACCEPTED,
            respondedAt: new Date(),
          },
        });
      }

      if (dto.sourceType === EngagementSourceType.INVITE) {
        await tx.opportunityInvite.update({
          where: { id: dto.sourceId },
          data: {
            status: InteractionStatus.ACCEPTED,
            respondedAt: new Date(),
          },
        });
      }

      return created;
    });

    return {
      message: 'Plantao fechado com sucesso.',
      engagement,
    };
  }

  async findForInstitution(user: AuthenticatedUser) {
    const institution = await this.prisma.institution.findUnique({
      where: { userId: user.userId },
      select: { id: true },
    });

    if (!institution) {
      throw new NotFoundException('Instituicao do usuario autenticado nao encontrada.');
    }

    return this.prisma.engagement.findMany({
      where: {
        institutionId: institution.id,
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        opportunity: {
          select: {
            id: true,
            title: true,
            customSpecialtyLabel: true,
            specialty: {
              select: {
                name: true,
              },
            },
            startAt: true,
            endAt: true,
          },
        },
        professional: {
          select: {
            id: true,
            email: true,
            role: true,
            profile: {
              select: {
                fullName: true,
              },
            },
          },
        },
      },
    });
  }

  async findForProfessional(user: AuthenticatedUser) {
    return this.prisma.engagement.findMany({
      where: {
        professionalUserId: user.userId,
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        opportunity: {
          select: {
            id: true,
            title: true,
            customSpecialtyLabel: true,
            specialty: {
              select: {
                name: true,
              },
            },
            startAt: true,
            endAt: true,
          },
        },
        institution: {
          select: {
            id: true,
            tradeName: true,
            legalName: true,
            institutionType: true,
          },
        },
        professional: {
          select: {
            id: true,
            email: true,
            role: true,
            profile: {
              select: {
                fullName: true,
              },
            },
          },
        },
      },
    });
  }

  async findOne(id: string, user: AuthenticatedUser) {
    const engagement = await this.prisma.engagement.findUnique({
      where: { id },
      include: {
        opportunity: true,
        institution: true,
        professional: {
          include: {
            profile: true,
            veterinarianProfile: true,
            internProfile: true,
          },
        },
      },
    });

    if (!engagement) {
      throw new NotFoundException('Fechamento nao encontrado.');
    }

    const canAccess =
      engagement.institution.userId === user.userId || engagement.professionalUserId === user.userId;

    if (!canAccess) {
      throw new ForbiddenException('Voce nao pode visualizar este fechamento.');
    }

    return engagement;
  }

  private calculatePlatformFee(grossAmount: number) {
    return this.roundMoney(grossAmount * this.getPlatformFeeRate());
  }

  private getPlatformFeeRate() {
    const rawRate = this.configService.get<string>('PLATFORM_FEE_RATE');
    const parsedRate = Number(rawRate ?? '0.03');

    if (!Number.isFinite(parsedRate) || parsedRate < 0 || parsedRate > 1) {
      return 0.03;
    }

    return parsedRate;
  }

  private roundMoney(value: number) {
    return Math.round(value * 100) / 100;
  }
}
