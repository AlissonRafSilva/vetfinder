import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DocumentOwnerType, UserRole, VerificationStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { CreateDocumentDto } from './dto/create-document.dto';
import { CreateDocumentUploadDto } from './dto/create-document-upload.dto';
import { ReviewDocumentDto } from './dto/review-document.dto';

@Injectable()
export class DocumentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storageService: StorageService,
  ) {}

  async create(dto: CreateDocumentDto, user: AuthenticatedUser) {
    const owner = await this.resolveDocumentOwner(dto.ownerType, user);

    const document = await this.prisma.document.create({
      data: {
        ownerType: dto.ownerType,
        userId: owner.userId,
        institutionId: owner.institutionId,
        documentType: dto.documentType,
        fileUrl: dto.fileUrl,
        mimeType: dto.mimeType,
        status: dto.status ?? VerificationStatus.PENDING,
      },
    });

    return {
      message: 'Documento registrado com sucesso.',
      document,
    };
  }

  async findMine(user: AuthenticatedUser) {
    const institution =
      user.role === UserRole.CLINIC || user.role === UserRole.HOSPITAL
        ? await this.prisma.institution.findUnique({
            where: { userId: user.userId },
            select: { id: true },
          })
        : null;

    return this.prisma.document.findMany({
      where: {
        OR: [
          { ownerType: DocumentOwnerType.USER, userId: user.userId },
          ...(institution
            ? [
                {
                  ownerType: DocumentOwnerType.INSTITUTION,
                  institutionId: institution.id,
                },
              ]
            : []),
        ],
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async findAll(status?: VerificationStatus) {
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
          },
        },
        institution: {
          select: {
            id: true,
            tradeName: true,
            institutionType: true,
          },
        },
      },
    });
  }

  async prepareUpload(dto: CreateDocumentUploadDto, authenticatedUserId: string) {
    if (dto.ownerType === DocumentOwnerType.USER) {
      return this.storageService.createUploadPlaceholder({
        folder: `users/${authenticatedUserId}/documents/${dto.documentType.toLowerCase()}`,
        fileName: dto.fileName,
      });
    }

    if (!dto.institutionId) {
      throw new BadRequestException('institutionId e obrigatorio para upload institucional.');
    }

    return this.storageService.createUploadPlaceholder({
      folder: `institutions/${dto.institutionId}/documents/${dto.documentType.toLowerCase()}`,
      fileName: dto.fileName,
    });
  }

  private async resolveDocumentOwner(
    ownerType: DocumentOwnerType,
    user: AuthenticatedUser,
  ) {
    if (ownerType === DocumentOwnerType.USER) {
      return {
        userId: user.userId,
        institutionId: null,
      };
    }

    if (user.role !== UserRole.CLINIC && user.role !== UserRole.HOSPITAL) {
      throw new BadRequestException(
        'Apenas clinicas e hospitais podem enviar documentos institucionais.',
      );
    }

    const institution = await this.prisma.institution.findUnique({
      where: { userId: user.userId },
      select: { id: true },
    });

    if (!institution) {
      throw new BadRequestException(
        'Cadastre a instituicao antes de enviar documentos institucionais.',
      );
    }

    return {
      userId: null,
      institutionId: institution.id,
    };
  }

  async findOne(id: string) {
    const document = await this.prisma.document.findUnique({
      where: { id },
      include: {
        user: true,
        institution: true,
      },
    });

    if (!document) {
      throw new NotFoundException('Documento nao encontrado.');
    }

    return document;
  }

  async review(id: string, dto: ReviewDocumentDto) {
    const existing = await this.prisma.document.findUnique({
      where: { id },
      select: { id: true },
    });

    if (!existing) {
      throw new NotFoundException('Documento nao encontrado.');
    }

    const document = await this.prisma.document.update({
      where: { id },
      data: {
        status: dto.status,
        rejectionReason: dto.rejectionReason,
        reviewedBy: dto.reviewedBy,
        reviewedAt: new Date(),
      },
    });

    return {
      message: 'Revisao de documento registrada com sucesso.',
      document,
    };
  }
}
