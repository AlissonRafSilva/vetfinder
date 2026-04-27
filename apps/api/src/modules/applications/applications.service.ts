import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InteractionStatus, OpportunityStatus, UserRole } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { ApplyOpportunityDto } from './dto/apply-opportunity.dto';
import { InviteProfessionalDto } from './dto/invite-professional.dto';
import { RespondApplicationDto } from './dto/respond-application.dto';
import { RespondInviteDto } from './dto/respond-invite.dto';

@Injectable()
export class ApplicationsService {
  constructor(private readonly prisma: PrismaService) {}

  async apply(opportunityId: string, dto: ApplyOpportunityDto, user: AuthenticatedUser) {
    const opportunity = await this.prisma.opportunity.findUnique({
      where: { id: opportunityId },
      select: {
        id: true,
        status: true,
        opportunityType: true,
      },
    });

    if (!opportunity) {
      throw new NotFoundException('Oportunidade nao encontrada.');
    }

    if (opportunity.status !== OpportunityStatus.OPEN) {
      throw new ConflictException('Esta oportunidade nao esta aberta para candidaturas.');
    }

    if (user.role === UserRole.INTERN && opportunity.opportunityType !== 'INTERNSHIP') {
      throw new ForbiddenException('Estagiarios so podem se candidatar a vagas de estagio.');
    }

    const existing = await this.prisma.opportunityApplication.findUnique({
      where: {
        opportunityId_professionalUserId: {
          opportunityId,
          professionalUserId: user.userId,
        },
      },
      select: { id: true },
    });

    if (existing) {
      throw new ConflictException('Voce ja se candidatou a esta oportunidade.');
    }

    const application = await this.prisma.opportunityApplication.create({
      data: {
        opportunityId,
        professionalUserId: user.userId,
        message: dto.message,
        status: InteractionStatus.APPLIED,
      },
    });

    return {
      message: 'Candidatura realizada com sucesso.',
      application,
    };
  }

  async invite(opportunityId: string, dto: InviteProfessionalDto, user: AuthenticatedUser) {
    const opportunity = await this.prisma.opportunity.findUnique({
      where: { id: opportunityId },
      select: {
        id: true,
        institution: {
          select: {
            userId: true,
          },
        },
        status: true,
      },
    });

    if (!opportunity) {
      throw new NotFoundException('Oportunidade nao encontrada.');
    }

    if (opportunity.institution.userId !== user.userId) {
      throw new ForbiddenException('Voce nao pode convidar profissionais para esta oportunidade.');
    }

    if (opportunity.status !== OpportunityStatus.OPEN) {
      throw new ConflictException('Esta oportunidade nao esta aberta para convites.');
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
      throw new NotFoundException('Profissional nao encontrado.');
    }

    const existing = await this.prisma.opportunityInvite.findUnique({
      where: {
        opportunityId_professionalUserId: {
          opportunityId,
          professionalUserId: dto.professionalUserId,
        },
      },
      select: { id: true },
    });

    if (existing) {
      throw new ConflictException('Este profissional ja foi convidado para a oportunidade.');
    }

    const invite = await this.prisma.opportunityInvite.create({
      data: {
        opportunityId,
        professionalUserId: dto.professionalUserId,
        message: dto.message,
        status: InteractionStatus.SENT,
      },
    });

    return {
      message: 'Convite enviado com sucesso.',
      invite,
    };
  }

  async findForProfessional(userId: string) {
    return this.prisma.opportunityApplication.findMany({
      where: {
        professionalUserId: userId,
      },
      orderBy: {
        appliedAt: 'desc',
      },
      include: {
        opportunity: {
          include: {
            institution: true,
            specialty: true,
          },
        },
      },
    });
  }

  async findInvitesForProfessional(userId: string) {
    return this.prisma.opportunityInvite.findMany({
      where: {
        professionalUserId: userId,
      },
      orderBy: {
        invitedAt: 'desc',
      },
      include: {
        opportunity: {
          include: {
            institution: true,
            specialty: true,
          },
        },
      },
    });
  }

  async findByOpportunity(opportunityId: string, user: AuthenticatedUser) {
    const opportunity = await this.prisma.opportunity.findUnique({
      where: { id: opportunityId },
      select: {
        id: true,
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
      throw new ForbiddenException('Voce nao pode visualizar estas candidaturas.');
    }

    return this.prisma.opportunityApplication.findMany({
      where: {
        opportunityId,
      },
      orderBy: {
        appliedAt: 'asc',
      },
      include: {
        professional: {
          select: {
            id: true,
            email: true,
            role: true,
            profile: true,
            veterinarianProfile: true,
            internProfile: true,
          },
        },
      },
    });
  }

  async findInvitesByOpportunity(opportunityId: string, user: AuthenticatedUser) {
    const opportunity = await this.prisma.opportunity.findUnique({
      where: { id: opportunityId },
      select: {
        id: true,
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
      throw new ForbiddenException('Voce nao pode visualizar estes convites.');
    }

    return this.prisma.opportunityInvite.findMany({
      where: {
        opportunityId,
      },
      orderBy: {
        invitedAt: 'desc',
      },
      include: {
        professional: {
          select: {
            id: true,
            email: true,
            role: true,
            profile: true,
            veterinarianProfile: true,
            internProfile: true,
          },
        },
      },
    });
  }

  async respondApplication(
    applicationId: string,
    dto: RespondApplicationDto,
    user: AuthenticatedUser,
  ) {
    if (dto.status !== InteractionStatus.ACCEPTED && dto.status !== InteractionStatus.REJECTED) {
      throw new ConflictException('Status invalido para resposta da candidatura.');
    }

    const application = await this.prisma.opportunityApplication.findUnique({
      where: { id: applicationId },
      include: {
        opportunity: {
          include: {
            institution: {
              select: {
                userId: true,
              },
            },
          },
        },
      },
    });

    if (!application) {
      throw new NotFoundException('Candidatura nao encontrada.');
    }

    if (application.opportunity.institution.userId !== user.userId) {
      throw new ForbiddenException('Voce nao pode responder esta candidatura.');
    }

    const updated = await this.prisma.opportunityApplication.update({
      where: { id: applicationId },
      data: {
        status: dto.status,
        respondedAt: new Date(),
      },
    });

    return {
      message: 'Resposta da candidatura registrada com sucesso.',
      application: updated,
    };
  }

  async respondInvite(inviteId: string, dto: RespondInviteDto, user: AuthenticatedUser) {
    if (dto.status !== InteractionStatus.ACCEPTED && dto.status !== InteractionStatus.DECLINED) {
      throw new ConflictException('Status invalido para resposta do convite.');
    }

    const invite = await this.prisma.opportunityInvite.findUnique({
      where: { id: inviteId },
      select: {
        id: true,
        professionalUserId: true,
      },
    });

    if (!invite) {
      throw new NotFoundException('Convite nao encontrado.');
    }

    if (invite.professionalUserId !== user.userId) {
      throw new ForbiddenException('Voce nao pode responder este convite.');
    }

    const updated = await this.prisma.opportunityInvite.update({
      where: { id: inviteId },
      data: {
        status: dto.status,
        respondedAt: new Date(),
      },
    });

    return {
      message: 'Resposta do convite registrada com sucesso.',
      invite: updated,
    };
  }
}
