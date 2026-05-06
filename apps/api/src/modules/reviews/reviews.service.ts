import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { EngagementStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { CreateReviewDto } from './dto/create-review.dto';

@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(dto: CreateReviewDto, user: AuthenticatedUser) {
    const engagement = await this.prisma.engagement.findUnique({
      where: { id: dto.engagementId },
      include: {
        institution: {
          select: {
            userId: true,
          },
        },
      },
    });

    if (!engagement) {
      throw new NotFoundException('Fechamento nao encontrado.');
    }

    const revieweeUserId = this.getRevieweeUserId(engagement, user);
    this.ensureEngagementCanBeReviewed(engagement.status);

    const existingReview = await this.prisma.review.findFirst({
      where: {
        engagementId: dto.engagementId,
        reviewerUserId: user.userId,
        revieweeUserId,
      },
    });

    if (existingReview) {
      throw new ConflictException('Voce ja avaliou este fechamento.');
    }

    const review = await this.prisma.review.create({
      data: {
        engagementId: dto.engagementId,
        reviewerUserId: user.userId,
        revieweeUserId,
        rating: dto.rating,
        comment: dto.comment?.trim() || null,
      },
      include: this.reviewInclude(),
    });

    return {
      message: 'Avaliacao registrada com sucesso.',
      review,
    };
  }

  async findByEngagement(engagementId: string, user: AuthenticatedUser) {
    const engagement = await this.prisma.engagement.findUnique({
      where: { id: engagementId },
      include: {
        institution: {
          select: {
            userId: true,
          },
        },
      },
    });

    if (!engagement) {
      throw new NotFoundException('Fechamento nao encontrado.');
    }

    this.ensureUserParticipates(engagement, user);

    return this.prisma.review.findMany({
      where: {
        engagementId,
      },
      include: this.reviewInclude(),
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  private ensureEngagementCanBeReviewed(status: EngagementStatus) {
    const allowedStatuses: EngagementStatus[] = [
      EngagementStatus.CONFIRMED,
      EngagementStatus.IN_PROGRESS,
      EngagementStatus.COMPLETED,
    ];

    if (!allowedStatuses.includes(status)) {
      throw new ConflictException(
        'A avaliacao fica disponivel depois que o pagamento for confirmado.',
      );
    }
  }

  private getRevieweeUserId(
    engagement: {
      institution: { userId: string };
      professionalUserId: string;
    },
    user: AuthenticatedUser,
  ) {
    if (engagement.institution.userId === user.userId) {
      return engagement.professionalUserId;
    }

    if (engagement.professionalUserId === user.userId) {
      return engagement.institution.userId;
    }

    throw new ForbiddenException('Voce nao pode avaliar este fechamento.');
  }

  private ensureUserParticipates(
    engagement: {
      institution: { userId: string };
      professionalUserId: string;
    },
    user: AuthenticatedUser,
  ) {
    const canAccess =
      engagement.institution.userId === user.userId ||
      engagement.professionalUserId === user.userId;

    if (!canAccess) {
      throw new ForbiddenException('Voce nao pode visualizar estas avaliacoes.');
    }
  }

  private reviewInclude() {
    return {
      reviewer: {
        select: {
          id: true,
          email: true,
          role: true,
          profile: {
            select: {
              fullName: true,
            },
          },
          institution: {
            select: {
              legalName: true,
              tradeName: true,
            },
          },
        },
      },
      reviewee: {
        select: {
          id: true,
          email: true,
          role: true,
          profile: {
            select: {
              fullName: true,
            },
          },
          institution: {
            select: {
              legalName: true,
              tradeName: true,
            },
          },
        },
      },
    } as const;
  }
}
