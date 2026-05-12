import { Injectable, NotFoundException } from '@nestjs/common';
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

    const data = {
        userId: currentUser.userId,
        crmvNumber: dto.crmvNumber,
        crmvState: dto.crmvState.toUpperCase(),
        baseShiftRate: dto.baseShiftRate,
        yearsExperience: dto.yearsExperience,
        emergencyCare: dto.emergencyCare ?? false,
        canTravel: dto.canTravel ?? false,
        maxDistanceKm: dto.maxDistanceKm,
        verificationStatus: VerificationStatus.PENDING,
      };

    const profile = user.veterinarianProfile
      ? await this.prisma.veterinarianProfile.update({
          where: { userId: currentUser.userId },
          data,
        })
      : await this.prisma.veterinarianProfile.create({
          data,
        });

    return {
      message: user.veterinarianProfile
        ? 'Perfil veterinario atualizado com sucesso.'
        : 'Perfil veterinario criado com sucesso.',
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

    const data = {
        userId: currentUser.userId,
        universityName: dto.universityName,
        coursePeriod: dto.coursePeriod,
        expectedGraduationDate: dto.expectedGraduationDate
          ? new Date(dto.expectedGraduationDate)
          : undefined,
        verificationStatus: VerificationStatus.PENDING,
      };

    const profile = user.internProfile
      ? await this.prisma.internProfile.update({
          where: { userId: currentUser.userId },
          data,
        })
      : await this.prisma.internProfile.create({
          data,
        });

    return {
      message: user.internProfile
        ? 'Perfil de estagiario atualizado com sucesso.'
        : 'Perfil de estagiario criado com sucesso.',
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
