import { BadRequestException, Injectable } from '@nestjs/common';
import { AvailabilityType, UserRole, VerificationStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { ReplaceAvailabilityDto } from './dto/upsert-availability-slot.dto';
import { SearchAvailableProfessionalsDto } from './dto/search-available-professionals.dto';

@Injectable()
export class AvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  async findMyAvailability(user: AuthenticatedUser) {
    return this.prisma.availabilitySlot.findMany({
      where: {
        userId: user.userId,
      },
      orderBy: [
        { weekday: 'asc' },
        { specificDate: 'asc' },
        { startTime: 'asc' },
      ],
    });
  }

  async replaceMyAvailability(dto: ReplaceAvailabilityDto, user: AuthenticatedUser) {
    if (user.role !== UserRole.VETERINARIAN && user.role !== UserRole.INTERN) {
      throw new BadRequestException(
        'Apenas veterinarios e estagiarios podem configurar disponibilidade.',
      );
    }

    for (const slot of dto.slots) {
      const availabilityType = slot.availabilityType ?? AvailabilityType.RECURRING;

      if (availabilityType === AvailabilityType.RECURRING && !slot.weekday) {
        throw new BadRequestException(
          'Slots recorrentes precisam informar o dia da semana.',
        );
      }

      if (availabilityType === AvailabilityType.SPECIFIC_DATE && !slot.specificDate) {
        throw new BadRequestException(
          'Slots por data especifica precisam informar a data.',
        );
      }

      if (slot.startTime >= slot.endTime) {
        throw new BadRequestException(
          'O horario inicial precisa ser menor que o horario final.',
        );
      }
    }

    await this.prisma.$transaction([
      this.prisma.availabilitySlot.deleteMany({
        where: { userId: user.userId },
      }),
      this.prisma.availabilitySlot.createMany({
        data: dto.slots.map((slot) => ({
          userId: user.userId,
          availabilityType: slot.availabilityType ?? AvailabilityType.RECURRING,
          weekday: slot.weekday,
          specificDate: slot.specificDate ? new Date(slot.specificDate) : null,
          startTime: slot.startTime,
          endTime: slot.endTime,
          timezone: slot.timezone ?? 'America/Sao_Paulo',
        })),
      }),
    ]);

    const slots = await this.findMyAvailability(user);

    return {
      message: 'Disponibilidade atualizada com sucesso.',
      slots,
    };
  }

  async searchAvailableProfessionals(query: SearchAvailableProfessionalsDto) {
    const professionals = await this.prisma.user.findMany({
      where: {
        role: {
          in: [UserRole.VETERINARIAN, UserRole.INTERN],
        },
        availabilitySlots: {
          some: {
            availabilityType: AvailabilityType.RECURRING,
            weekday: query.weekday,
            startTime: query.startTime
              ? {
                  lte: query.startTime,
                }
              : undefined,
            endTime: query.endTime
              ? {
                  gte: query.endTime,
                }
              : undefined,
          },
        },
      },
      select: {
        id: true,
        email: true,
        role: true,
        profile: true,
        veterinarianProfile: true,
        internProfile: true,
        availabilitySlots: {
          where: {
            availabilityType: AvailabilityType.RECURRING,
            weekday: query.weekday,
          },
          orderBy: {
            startTime: 'asc',
          },
        },
        reviewReceived: {
          select: {
            rating: true,
          },
        },
      },
      take: 50,
    });

    return professionals.sort((left, right) => {
      return this.professionalSearchScore(right) - this.professionalSearchScore(left);
    });
  }

  private professionalSearchScore(professional: {
    role: UserRole;
    profile: {
      fullName?: string | null;
      photoUrl?: string | null;
      city?: string | null;
      state?: string | null;
      bio?: string | null;
    } | null;
    veterinarianProfile: {
      verificationStatus: VerificationStatus;
      crmvNumber?: string | null;
      baseShiftRate?: unknown;
      yearsExperience?: number | null;
    } | null;
    internProfile: {
      verificationStatus: VerificationStatus;
      universityName?: string | null;
      coursePeriod?: string | null;
    } | null;
    reviewReceived: Array<{ rating: number }>;
  }) {
    const verificationStatus =
      professional.role === UserRole.INTERN
        ? professional.internProfile?.verificationStatus
        : professional.veterinarianProfile?.verificationStatus;
    const ratings = professional.reviewReceived.map((review) => review.rating);
    const averageRating =
      ratings.length > 0
        ? ratings.reduce((sum, rating) => sum + rating, 0) / ratings.length
        : 0;

    let score = 0;
    if (verificationStatus === VerificationStatus.APPROVED) {
      score += 1000;
    }

    score += averageRating * 100;
    score += ratings.length * 10;

    if (professional.profile?.fullName) score += 20;
    if (professional.profile?.photoUrl) score += 20;
    if (professional.profile?.city || professional.profile?.state) score += 15;
    if (professional.profile?.bio) score += 10;

    if (professional.role === UserRole.VETERINARIAN) {
      if (professional.veterinarianProfile?.crmvNumber) score += 30;
      if (professional.veterinarianProfile?.baseShiftRate) score += 15;
      if (professional.veterinarianProfile?.yearsExperience) score += 10;
    }

    if (professional.role === UserRole.INTERN) {
      if (professional.internProfile?.universityName) score += 30;
      if (professional.internProfile?.coursePeriod) score += 10;
    }

    return score;
  }
}
