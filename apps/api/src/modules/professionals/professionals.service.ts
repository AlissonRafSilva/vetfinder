import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRole, VerificationStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { CreateInternProfileDto } from './dto/create-intern-profile.dto';
import { CreateVeterinarianProfileDto } from './dto/create-veterinarian-profile.dto';

@Injectable()
export class ProfessionalsService {
  constructor(private readonly prisma: PrismaService) {}

  async createVeterinarianProfile(dto: CreateVeterinarianProfileDto, currentUser: AuthenticatedUser) {
    if (currentUser.role !== UserRole.VETERINARIAN) {
      throw new NotFoundException('Usuario autenticado nao pode criar perfil veterinario.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: currentUser.userId },
      select: { id: true, role: true, veterinarianProfile: { select: { id: true } } },
    });

    if (!user || user.role !== UserRole.VETERINARIAN) {
      throw new NotFoundException('Usuario veterinario nao encontrado.');
    }

    if (user.veterinarianProfile) {
      throw new ConflictException('Este usuario ja possui perfil veterinario.');
    }

    const profile = await this.prisma.veterinarianProfile.create({
      data: {
        userId: currentUser.userId,
        crmvNumber: dto.crmvNumber,
        crmvState: dto.crmvState.toUpperCase(),
        baseShiftRate: dto.baseShiftRate,
        yearsExperience: dto.yearsExperience,
        emergencyCare: dto.emergencyCare ?? false,
        canTravel: dto.canTravel ?? false,
        maxDistanceKm: dto.maxDistanceKm,
        verificationStatus: VerificationStatus.PENDING,
      },
    });

    return {
      message: 'Perfil veterinario criado com sucesso.',
      profile,
    };
  }

  async createInternProfile(dto: CreateInternProfileDto, currentUser: AuthenticatedUser) {
    if (currentUser.role !== UserRole.INTERN) {
      throw new NotFoundException('Usuario autenticado nao pode criar perfil de estagiario.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: currentUser.userId },
      select: { id: true, role: true, internProfile: { select: { id: true } } },
    });

    if (!user || user.role !== UserRole.INTERN) {
      throw new NotFoundException('Usuario estagiario nao encontrado.');
    }

    if (user.internProfile) {
      throw new ConflictException('Este usuario ja possui perfil de estagiario.');
    }

    const profile = await this.prisma.internProfile.create({
      data: {
        userId: currentUser.userId,
        universityName: dto.universityName,
        coursePeriod: dto.coursePeriod,
        expectedGraduationDate: dto.expectedGraduationDate
          ? new Date(dto.expectedGraduationDate)
          : undefined,
        verificationStatus: VerificationStatus.PENDING,
      },
    });

    return {
      message: 'Perfil de estagiario criado com sucesso.',
      profile,
    };
  }

  async findByUserId(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        profile: true,
        veterinarianProfile: true,
        internProfile: true,
        specialties: {
          include: {
            specialty: true,
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('Profissional nao encontrado.');
    }

    return user;
  }
}
