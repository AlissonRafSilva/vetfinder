import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DocumentOwnerType, VerificationStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { CreateDocumentDto } from './dto/create-document.dto';
import { CreateDocumentUploadDto } from './dto/create-document-upload.dto';
import { ReviewDocumentDto } from './dto/review-document.dto';

@Injectable()
export class DocumentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storageService: StorageService,
  ) {}

  async create(dto: CreateDocumentDto) {
    if (dto.ownerType === DocumentOwnerType.USER && !dto.userId) {
      throw new BadRequestException('userId e obrigatorio para documentos de usuario.');
    }

    if (dto.ownerType === DocumentOwnerType.INSTITUTION && !dto.institutionId) {
      throw new BadRequestException('institutionId e obrigatorio para documentos de instituicao.');
    }

    const document = await this.prisma.document.create({
      data: {
        ownerType: dto.ownerType,
        userId: dto.userId,
        institutionId: dto.institutionId,
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
