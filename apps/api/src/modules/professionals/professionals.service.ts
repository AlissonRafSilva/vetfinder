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
      select: {
        id: true,
        email: true,
        role: true,
        veterinarianProfile: { select: { id: true } },
        profile: { select: { id: true, addressId: true, fullName: true } },
      },
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

    await this.upsertBaseProfileLocation({
      userId: currentUser.userId,
      email: user.email,
      existingProfile: user.profile,
      city: dto.city,
      state: dto.state,
      lat: dto.lat,
      lng: dto.lng,
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
      select: {
        id: true,
        email: true,
        role: true,
        internProfile: { select: { id: true } },
        profile: { select: { id: true, addressId: true, fullName: true } },
      },
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

    await this.upsertBaseProfileLocation({
      userId: currentUser.userId,
      email: user.email,
      existingProfile: user.profile,
      city: dto.city,
      state: dto.state,
      lat: dto.lat,
      lng: dto.lng,
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

  private async upsertBaseProfileLocation(input: {
    userId: string;
    email: string;
    existingProfile: { id: string; addressId: string | null; fullName: string } | null;
    city?: string;
    state?: string;
    lat?: number;
    lng?: number;
  }) {
    const hasLocationData =
      Boolean(input.city?.trim()) ||
      Boolean(input.state?.trim()) ||
      input.lat != null ||
      input.lng != null;

    if (!hasLocationData) {
      return;
    }

    const addressData = {
      city: input.city?.trim() || undefined,
      state: input.state?.trim().toUpperCase() || undefined,
      country: 'BR',
      lat: input.lat,
      lng: input.lng,
    };

    const address = input.existingProfile?.addressId
      ? await this.prisma.address.update({
          where: { id: input.existingProfile.addressId },
          data: addressData,
        })
      : await this.prisma.address.create({ data: addressData });

    await this.prisma.profile.upsert({
      where: { userId: input.userId },
      update: {
        city: input.city?.trim() || undefined,
        state: input.state?.trim().toUpperCase() || undefined,
        addressId: address.id,
      },
      create: {
        userId: input.userId,
        fullName: input.email.split('@')[0],
        city: input.city?.trim() || null,
        state: input.state?.trim().toUpperCase() || null,
        addressId: address.id,
      },
    });
  }
}
