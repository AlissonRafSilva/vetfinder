import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
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
      select: { id: true, role: true, institution: { select: { id: true } } },
    });

    if (!user || (user.role !== UserRole.CLINIC && user.role !== UserRole.HOSPITAL)) {
      throw new NotFoundException('Usuario institucional nao encontrado.');
    }

    if (user.institution) {
      throw new ConflictException('Este usuario ja possui instituicao cadastrada.');
    }

    const institution = await this.prisma.institution.create({
      data: {
        userId: currentUser.userId,
        institutionType: dto.institutionType,
        legalName: dto.legalName,
        tradeName: dto.tradeName,
        cnpj: dto.cnpj,
        stateRegistration: dto.stateRegistration,
        description: dto.description,
        contactName: dto.contactName,
        contactPhone: dto.contactPhone,
        addressId: dto.addressId,
        verificationStatus: dto.verificationStatus ?? VerificationStatus.PENDING,
      },
    });

    return {
      message: 'Instituicao criada com sucesso.',
      institution,
    };
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
}
