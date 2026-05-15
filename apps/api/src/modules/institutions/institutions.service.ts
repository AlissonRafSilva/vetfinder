import { Injectable, NotFoundException } from '@nestjs/common';
import { UserRole, VerificationStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { CreateInstitutionDto } from './dto/create-institution.dto';

@Injectable()
export class InstitutionsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(dto: CreateInstitutionDto, currentUser: AuthenticatedUser) {
    if (currentUser.role !== UserRole.CLINIC && currentUser.role !== UserRole.HOSPITAL) {
      throw new NotFoundException('Usuario autenticado nao pode criar instituicao.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: currentUser.userId },
      select: {
        id: true,
        role: true,
        institution: { select: { id: true, addressId: true } },
      },
    });

    if (!user || (user.role !== UserRole.CLINIC && user.role !== UserRole.HOSPITAL)) {
      throw new NotFoundException('Usuario institucional nao encontrado.');
    }

    const addressId = await this.resolveInstitutionAddressId(dto, user.institution?.addressId);

    const data = {
        userId: currentUser.userId,
        institutionType: dto.institutionType,
        legalName: dto.legalName,
        tradeName: dto.tradeName,
        cnpj: dto.cnpj,
        stateRegistration: dto.stateRegistration,
        description: dto.description,
        contactName: dto.contactName,
        contactPhone: dto.contactPhone,
        addressId: addressId ?? dto.addressId,
        verificationStatus: dto.verificationStatus ?? VerificationStatus.PENDING,
      };

    const institution = user.institution
      ? await this.prisma.institution.update({
          where: { userId: currentUser.userId },
          data,
        })
      : await this.prisma.institution.create({
          data,
        });

    return {
      message: user.institution
        ? 'Instituicao atualizada com sucesso.'
        : 'Instituicao criada com sucesso.',
      institution,
    };
  }

  async findMine(currentUser: AuthenticatedUser) {
    if (currentUser.role !== UserRole.CLINIC && currentUser.role !== UserRole.HOSPITAL) {
      throw new NotFoundException('Usuario autenticado nao possui perfil institucional.');
    }

    const institution = await this.prisma.institution.findUnique({
      where: { userId: currentUser.userId },
      include: {
        address: true,
        documents: true,
        opportunities: {
          orderBy: { createdAt: 'desc' },
          take: 10,
        },
      },
    });

    if (!institution) {
      throw new NotFoundException('Instituicao nao encontrada para este usuario.');
    }

    return institution;
  }

  async findById(id: string) {
    const institution = await this.prisma.institution.findUnique({
      where: { id },
      include: {
        address: true,
        documents: true,
        opportunities: {
          orderBy: { createdAt: 'desc' },
          take: 10,
        },
      },
    });

    if (!institution) {
      throw new NotFoundException('Instituicao nao encontrada.');
    }

    return institution;
  }

  private async resolveInstitutionAddressId(
    dto: CreateInstitutionDto,
    currentAddressId?: string | null,
  ) {
    const hasLocationData =
      Boolean(dto.city?.trim()) ||
      Boolean(dto.state?.trim()) ||
      dto.lat != null ||
      dto.lng != null;

    if (!hasLocationData) {
      return undefined;
    }

    const data = {
      city: dto.city?.trim() || undefined,
      state: dto.state?.trim().toUpperCase() || undefined,
      country: 'BR',
      lat: dto.lat,
      lng: dto.lng,
    };

    if (currentAddressId) {
      const address = await this.prisma.address.update({
        where: { id: currentAddressId },
        data,
      });

      return address.id;
    }

    const address = await this.prisma.address.create({ data });
    return address.id;
  }
}
