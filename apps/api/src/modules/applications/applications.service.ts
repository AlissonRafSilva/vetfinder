import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  InteractionStatus,
  OpportunityStatus,
  OpportunityType,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { NotificationsService } from '../notifications/notifications.service';
import { ApplyOpportunityDto } from './dto/apply-opportunity.dto';
import { InviteProfessionalDto } from './dto/invite-professional.dto';
import { RespondApplicationDto } from './dto/respond-application.dto';
import { RespondInviteDto } from './dto/respond-invite.dto';

@Injectable()
export class ApplicationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async apply(opportunityId: string, dto: ApplyOpportunityDto, user: AuthenticatedUser) {
    const opportunity = await this.prisma.opportunity.findUnique({
      where: { id: opportunityId },
      select: {
        id: true,
        title: true,
        status: true,
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

    if (opportunity.status !== OpportunityStatus.OPEN) {
      throw new ConflictException('Esta oportunidade nao esta aberta para candidaturas.');
    }

    if (user.role === UserRole.INTERN && opportunity.opportunityType !== OpportunityType.INTERNSHIP) {
      throw new ForbiddenException('Estagiarios so podem se candidatar a vagas de estagio.');
    }

    if (
      user.role === UserRole.VETERINARIAN &&
      opportunity.opportunityType === OpportunityType.INTERNSHIP
    ) {
      throw new ForbiddenException('Veterinarios volantes nao podem se candidatar a vagas de estagio.');
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

    await this.safeNotify({
      userId: opportunity.institution.userId,
      type: 'APPLICATION_RECEIVED',
      title: 'Nova candidatura recebida',
      body: `Um profissional se candidatou para "${opportunity.title}".`,
      dataJson: {
        opportunityId,
        applicationId: application.id,
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
        title: true,
        institution: {
          select: {
            userId: true,
          },
        },
        status: true,
        opportunityType: true,
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

    if (
      professional.role === UserRole.INTERN &&
      opportunity.opportunityType !== OpportunityType.INTERNSHIP
    ) {
      throw new ForbiddenException('Estagiarios so podem ser convidados para vagas de estagio.');
    }

    if (
      professional.role === UserRole.VETERINARIAN &&
      opportunity.opportunityType === OpportunityType.INTERNSHIP
    ) {
      throw new ForbiddenException(
        'Veterinarios volantes nao podem ser convidados para vagas de estagio.',
      );
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

    await this.safeNotify({
      userId: dto.professionalUserId,
      type: 'INVITE_RECEIVED',
      title: 'Novo convite de vaga',
      body: `Voce recebeu um convite para "${opportunity.title}".`,
      dataJson: {
        opportunityId,
        inviteId: invite.id,
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
          select: {
            id: true,
            title: true,
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

    await this.safeNotify({
      userId: application.professionalUserId,
      type:
        dto.status === InteractionStatus.ACCEPTED
          ? 'APPLICATION_ACCEPTED'
          : 'APPLICATION_REJECTED',
      title:
        dto.status === InteractionStatus.ACCEPTED
          ? 'Candidatura aceita'
          : 'Candidatura recusada',
      body: `Sua candidatura para "${application.opportunity.title}" foi ${
        dto.status === InteractionStatus.ACCEPTED ? 'aceita' : 'recusada'
      }.`,
      dataJson: {
        opportunityId: application.opportunityId,
        applicationId,
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
        opportunityId: true,
        opportunity: {
          select: {
            title: true,
            institution: {
              select: {
                userId: true,
              },
            },
          },
        },
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

    await this.safeNotify({
      userId: invite.opportunity.institution.userId,
      type:
        dto.status === InteractionStatus.ACCEPTED
          ? 'INVITE_ACCEPTED'
          : 'INVITE_DECLINED',
      title:
        dto.status === InteractionStatus.ACCEPTED
          ? 'Convite aceito'
          : 'Convite recusado',
      body: `Um profissional ${
        dto.status === InteractionStatus.ACCEPTED ? 'aceitou' : 'recusou'
      } o convite para "${invite.opportunity.title}".`,
      dataJson: {
        opportunityId: invite.opportunityId,
        inviteId,
      },
    });

    return {
      message: 'Resposta do convite registrada com sucesso.',
      invite: updated,
    };
  }

  private async safeNotify(input: Parameters<NotificationsService['create']>[0]) {
    try {
      await this.notificationsService.create(input);
    } catch {
      // Notificacoes nao devem bloquear candidatura, convite ou resposta.
    }
  }

}
