import { Injectable, NotFoundException } from '@nestjs/common';
import {
  AccountStatus,
  DocumentOwnerType,
  DocumentType,
  Prisma,
  VerificationStatus,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { ReviewDocumentDto } from '../documents/dto/review-document.dto';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async summary() {
    const [
      pendingDocuments,
      inReviewDocuments,
      approvedDocuments,
      rejectedDocuments,
      pendingUsers,
      activeUsers,
    ] = await this.prisma.$transaction([
      this.prisma.document.count({ where: { status: VerificationStatus.PENDING } }),
      this.prisma.document.count({ where: { status: VerificationStatus.IN_REVIEW } }),
      this.prisma.document.count({ where: { status: VerificationStatus.APPROVED } }),
      this.prisma.document.count({ where: { status: VerificationStatus.REJECTED } }),
      this.prisma.user.count({ where: { status: AccountStatus.PENDING_VERIFICATION } }),
      this.prisma.user.count({ where: { status: AccountStatus.ACTIVE } }),
    ]);

    return {
      documents: {
        pending: pendingDocuments,
        inReview: inReviewDocuments,
        approved: approvedDocuments,
        rejected: rejectedDocuments,
      },
      users: {
        pendingVerification: pendingUsers,
        active: activeUsers,
      },
    };
  }

  listDocuments(status?: VerificationStatus) {
    return this.prisma.document.findMany({
      where: {
        status,
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            role: true,
            status: true,
            profile: {
              select: {
                fullName: true,
              },
            },
          },
        },
        institution: {
          select: {
            id: true,
            tradeName: true,
            legalName: true,
            institutionType: true,
            verificationStatus: true,
            user: {
              select: {
                id: true,
                email: true,
                status: true,
              },
            },
          },
        },
      },
    });
  }

  async reviewDocument(id: string, dto: ReviewDocumentDto, user: AuthenticatedUser) {
    const existing = await this.prisma.document.findUnique({
      where: { id },
      include: {
        user: {
          select: {
            id: true,
            role: true,
          },
        },
        institution: {
          select: {
            id: true,
            userId: true,
          },
        },
      },
    });

    if (!existing) {
      throw new NotFoundException('Documento nao encontrado.');
    }

    const document = await this.prisma.$transaction(async (tx) => {
      const reviewed = await tx.document.update({
        where: { id },
        data: {
          status: dto.status,
          rejectionReason: dto.rejectionReason,
          reviewedBy: user.userId,
          reviewedAt: new Date(),
        },
      });

      if (
        dto.status === VerificationStatus.APPROVED ||
        dto.status === VerificationStatus.REJECTED
      ) {
        await this.applyOwnerVerificationStatus(tx, {
          ownerType: existing.ownerType,
          documentType: existing.documentType,
          userId: existing.userId,
          institutionId: existing.institutionId,
          institutionUserId: existing.institution?.userId,
          status: dto.status,
        });
      }

      return reviewed;
    });

    return {
      message: 'Revisao administrativa registrada com sucesso.',
      document,
    };
  }

  private async applyOwnerVerificationStatus(
    tx: Prisma.TransactionClient,
    input: {
      ownerType: DocumentOwnerType;
      documentType: DocumentType;
      userId: string | null;
      institutionId: string | null;
      institutionUserId?: string;
      status: VerificationStatus;
    },
  ) {
    const accountStatus =
      input.status === VerificationStatus.APPROVED
        ? AccountStatus.ACTIVE
        : AccountStatus.REJECTED;

    if (input.ownerType === DocumentOwnerType.USER && input.userId) {
      if (input.documentType === DocumentType.CRMV_PROOF) {
        await tx.veterinarianProfile.updateMany({
          where: { userId: input.userId },
          data: { verificationStatus: input.status },
        });
      }

      if (input.documentType === DocumentType.ENROLLMENT_STATEMENT) {
        await tx.internProfile.updateMany({
          where: { userId: input.userId },
          data: { verificationStatus: input.status },
        });
      }

      await tx.user.update({
        where: { id: input.userId },
        data: { status: accountStatus },
      });
    }

    if (input.ownerType === DocumentOwnerType.INSTITUTION && input.institutionId) {
      await tx.institution.update({
        where: { id: input.institutionId },
        data: { verificationStatus: input.status },
      });

      if (input.institutionUserId) {
        await tx.user.update({
          where: { id: input.institutionUserId },
          data: { status: accountStatus },
        });
      }
    }
  }
}
