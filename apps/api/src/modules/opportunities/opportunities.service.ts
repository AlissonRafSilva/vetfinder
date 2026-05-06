import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { OpportunityStatus, OpportunityType, Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { CreateOpportunityDto } from './dto/create-opportunity.dto';
import { ListOpportunitiesDto } from './dto/list-opportunities.dto';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { UpdateOpportunityDto } from './dto/update-opportunity.dto';

@Injectable()
export class OpportunitiesService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(query: ListOpportunitiesDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    const where: Prisma.OpportunityWhereInput = {
      status: query.status ?? OpportunityStatus.OPEN,
      opportunityType: this.getOpportunityTypeFilter(query),
      urgencyLevel: query.urgencyLevel,
      specialtyId: query.specialtyId,
      grossAmount: {
        gte: query.minAmount,
        lte: query.maxAmount,
      },
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.opportunity.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: [{ startAt: 'asc' }, { createdAt: 'desc' }],
        include: {
          institution: {
            select: {
              id: true,
              tradeName: true,
              institutionType: true,
              verificationStatus: true,
              user: {
                select: {
                  reviewReceived: {
                    select: {
                      rating: true,
                    },
                  },
                },
              },
            },
          },
          specialty: {
            select: {
              id: true,
              name: true,
              slug: true,
            },
          },
          address: true,
        },
      }),
      this.prisma.opportunity.count({ where }),
    ]);

    return {
      items,
      page,
      limit,
      total,
    };
  }

  async findOne(id: string) {
    const opportunity = await this.prisma.opportunity.findUnique({
      where: { id },
      include: {
        institution: true,
        specialty: true,
        address: true,
        applications: {
          select: {
            id: true,
            professionalUserId: true,
            status: true,
            appliedAt: true,
          },
        },
        invites: {
          select: {
            id: true,
            professionalUserId: true,
            status: true,
            invitedAt: true,
          },
        },
      },
    });

    if (!opportunity) {
      throw new NotFoundException('Oportunidade nao encontrada.');
    }

    return opportunity;
  }

  async findMine(user: AuthenticatedUser) {
    if (user.role !== UserRole.CLINIC && user.role !== UserRole.HOSPITAL) {
      throw new ForbiddenException(
        'Apenas clinicas e hospitais podem visualizar suas proprias oportunidades.',
      );
    }

    const institution = await this.prisma.institution.findUnique({
      where: { userId: user.userId },
      select: { id: true },
    });

    if (!institution) {
      throw new NotFoundException('Instituicao do usuario autenticado nao encontrada.');
    }

    return this.prisma.opportunity.findMany({
      where: {
        institutionId: institution.id,
        status: {
          in: [
            OpportunityStatus.DRAFT,
            OpportunityStatus.OPEN,
            OpportunityStatus.IN_NEGOTIATION,
          ],
        },
      },
      orderBy: [{ startAt: 'asc' }, { createdAt: 'desc' }],
      select: {
        id: true,
        title: true,
        description: true,
        status: true,
        opportunityType: true,
        startAt: true,
        endAt: true,
        grossAmount: true,
        urgencyLevel: true,
        requiresVerifiedProfile: true,
        durationHours: true,
        specialty: {
          select: {
            id: true,
            name: true,
          },
        },
        customSpecialtyLabel: true,
      },
    });
  }

  async create(dto: CreateOpportunityDto, userId: string) {
    const institution = await this.prisma.institution.findUnique({
      where: { userId },
      select: {
        id: true,
        tradeName: true,
        institutionType: true,
        verificationStatus: true,
      },
    });

    if (!institution) {
      throw new NotFoundException('Instituicao do usuario autenticado nao encontrada.');
    }

    const opportunity = await this.prisma.opportunity.create({
      data: {
        institutionId: institution.id,
        title: dto.title,
        description: dto.description,
        opportunityType: dto.opportunityType,
        specialtyId: dto.specialtyId,
        customSpecialtyLabel: dto.customSpecialtyLabel,
        startAt: new Date(dto.startAt),
        endAt: new Date(dto.endAt),
        durationHours: dto.durationHours,
        grossAmount: dto.grossAmount,
        urgencyLevel: dto.urgencyLevel,
        addressId: dto.addressId,
        requiresVerifiedProfile: dto.requiresVerifiedProfile ?? true,
        status: OpportunityStatus.DRAFT,
      },
      include: {
        institution: {
          select: {
            id: true,
            tradeName: true,
            institutionType: true,
          },
        },
        specialty: true,
      },
    });

    return {
      message: 'Oportunidade criada com sucesso.',
      opportunity,
    };
  }

  async updateStatus(
    id: string,
    status: OpportunityStatus,
    user: AuthenticatedUser,
  ) {
    if (user.role !== UserRole.CLINIC && user.role !== UserRole.HOSPITAL) {
      throw new ForbiddenException(
        'Apenas clinicas e hospitais podem atualizar o status das oportunidades.',
      );
    }

    const institution = await this.prisma.institution.findUnique({
      where: { userId: user.userId },
      select: { id: true },
    });

    if (!institution) {
      throw new NotFoundException('Instituicao do usuario autenticado nao encontrada.');
    }

    const opportunity = await this.prisma.opportunity.findUnique({
      where: { id },
      select: {
        id: true,
        institutionId: true,
        status: true,
      },
    });

    if (!opportunity || opportunity.institutionId !== institution.id) {
      throw new NotFoundException('Oportunidade da instituicao nao encontrada.');
    }

    const allowedStatuses: OpportunityStatus[] = [
      OpportunityStatus.DRAFT,
      OpportunityStatus.OPEN,
      OpportunityStatus.CANCELLED,
    ];

    if (!allowedStatuses.includes(status)) {
      throw new ForbiddenException(
        'Somente os status rascunho, aberta e cancelada podem ser alterados nesta etapa.',
      );
    }

    const updatedOpportunity = await this.prisma.opportunity.update({
      where: { id },
      data: { status },
      select: {
        id: true,
        title: true,
        status: true,
        customSpecialtyLabel: true,
        startAt: true,
        endAt: true,
        grossAmount: true,
        specialty: {
          select: {
            name: true,
          },
        },
      },
    });

    return {
      message: 'Status da oportunidade atualizado com sucesso.',
      opportunity: updatedOpportunity,
    };
  }

  async update(
    id: string,
    dto: UpdateOpportunityDto,
    user: AuthenticatedUser,
  ) {
    if (user.role !== UserRole.CLINIC && user.role !== UserRole.HOSPITAL) {
      throw new ForbiddenException(
        'Apenas clinicas e hospitais podem editar oportunidades.',
      );
    }

    const institution = await this.prisma.institution.findUnique({
      where: { userId: user.userId },
      select: { id: true },
    });

    if (!institution) {
      throw new NotFoundException('Instituicao do usuario autenticado nao encontrada.');
    }

    const opportunity = await this.prisma.opportunity.findUnique({
      where: { id },
      select: {
        id: true,
        institutionId: true,
      },
    });

    if (!opportunity || opportunity.institutionId != institution.id) {
      throw new NotFoundException('Oportunidade da instituicao nao encontrada.');
    }

    const updatedOpportunity = await this.prisma.opportunity.update({
      where: { id },
      data: {
        title: dto.title,
        description: dto.description,
        opportunityType: dto.opportunityType,
        specialtyId: dto.specialtyId,
        customSpecialtyLabel: dto.customSpecialtyLabel,
        startAt: dto.startAt ? new Date(dto.startAt) : undefined,
        endAt: dto.endAt ? new Date(dto.endAt) : undefined,
        grossAmount: dto.grossAmount,
        durationHours: dto.durationHours,
        urgencyLevel: dto.urgencyLevel,
        addressId: dto.addressId,
        requiresVerifiedProfile: dto.requiresVerifiedProfile,
      },
      select: {
        id: true,
        title: true,
        description: true,
        status: true,
        opportunityType: true,
        startAt: true,
        endAt: true,
        grossAmount: true,
        urgencyLevel: true,
        requiresVerifiedProfile: true,
        durationHours: true,
        specialty: {
          select: {
            id: true,
            name: true,
          },
        },
        customSpecialtyLabel: true,
      },
    });

    return {
      message: 'Oportunidade atualizada com sucesso.',
      opportunity: updatedOpportunity,
    };
  }

  private getOpportunityTypeFilter(
    query: ListOpportunitiesDto,
  ): Prisma.OpportunityWhereInput['opportunityType'] {
    if (query.audience === 'INTERN') {
      return OpportunityType.INTERNSHIP;
    }

    if (query.audience === 'VETERINARIAN') {
      return {
        not: OpportunityType.INTERNSHIP,
      };
    }

    return query.opportunityType;
  }
}
