import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { stat } from 'fs/promises';
import {
  AccountStatus,
  DocumentOwnerType,
  DocumentType,
  Prisma,
  UserRole,
  VerificationStatus,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { CreateDocumentDto } from './dto/create-document.dto';
import { CreateDocumentUploadDto } from './dto/create-document-upload.dto';
import { ReviewDocumentDto } from './dto/review-document.dto';
import { UploadDocumentDto } from './dto/upload-document.dto';

type DocumentFileAccess = {
  documentId: string;
  absolutePath: string;
  mimeType: string | null;
  expiresAt: number;
};

const fileAccessTokens = new Map<string, DocumentFileAccess>();
const fileAccessTtlMs = 2 * 60 * 1000;

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

  async createFromUpload(
    dto: UploadDocumentDto,
    file: { originalname?: string; mimetype?: string; buffer?: Buffer },
    user: AuthenticatedUser,
    baseUrl: string,
  ) {
    this.validateUploadedDocument(file);

    const owner = await this.resolveDocumentOwner(dto.ownerType, user);
    const storedFile = await this.storageService.saveUploadedDocument(file);
    const document = await this.prisma.document.create({
      data: {
        ownerType: dto.ownerType,
        userId: owner.userId,
        institutionId: owner.institutionId,
        documentType: dto.documentType,
        fileUrl: `${baseUrl}${storedFile.publicPath}`,
        mimeType: storedFile.mimeType,
        status: VerificationStatus.PENDING,
      },
    });

    return {
      message: 'Documento enviado com sucesso.',
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

  private validateUploadedDocument(file: {
    originalname?: string;
    mimetype?: string;
    buffer?: Buffer;
  }) {
    if (!file.buffer || file.buffer.length === 0) {
      throw new BadRequestException('Arquivo enviado sem conteudo.');
    }

    const allowedMimeTypes = new Set(['application/pdf', 'image/jpeg', 'image/png']);
    const fileName = file.originalname?.toLowerCase() ?? '';
    const hasAllowedExtension =
      fileName.endsWith('.pdf') ||
      fileName.endsWith('.jpg') ||
      fileName.endsWith('.jpeg') ||
      fileName.endsWith('.png');

    if (
      (!file.mimetype || !allowedMimeTypes.has(file.mimetype)) &&
      !hasAllowedExtension
    ) {
      throw new BadRequestException(
        'Formato invalido. Envie PDF, JPG ou PNG.',
      );
    }
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

  async createFileAccess(id: string, user: AuthenticatedUser, baseUrl: string) {
    const document = await this.prisma.document.findUnique({
      where: { id },
      select: {
        id: true,
        ownerType: true,
        userId: true,
        institutionId: true,
        fileUrl: true,
        mimeType: true,
        institution: {
          select: {
            userId: true,
          },
        },
      },
    });

    if (!document) {
      throw new NotFoundException('Documento nao encontrado.');
    }

    const canAccess =
      user.role === UserRole.ADMIN ||
      (document.ownerType === DocumentOwnerType.USER &&
        document.userId === user.userId) ||
      (document.ownerType === DocumentOwnerType.INSTITUTION &&
        document.institution?.userId === user.userId);

    if (!canAccess) {
      throw new ForbiddenException('Usuario sem permissao para acessar este documento.');
    }

    const absolutePath = this.storageService.resolveLocalDocumentPath(
      document.fileUrl,
    );

    try {
      await stat(absolutePath);
    } catch {
      throw new NotFoundException('Arquivo do documento nao encontrado.');
    }

    this.cleanupExpiredFileAccessTokens();

    const token = randomUUID();
    const expiresAt = Date.now() + fileAccessTtlMs;

    fileAccessTokens.set(token, {
      documentId: document.id,
      absolutePath,
      mimeType: document.mimeType,
      expiresAt,
    });

    return {
      url: `${baseUrl}/v1/documents/file-access/${token}`,
      expiresAt: new Date(expiresAt).toISOString(),
    };
  }

  resolveFileAccessToken(token: string) {
    this.cleanupExpiredFileAccessTokens();

    const access = fileAccessTokens.get(token);
    if (!access) {
      throw new NotFoundException('Acesso temporario expirado ou invalido.');
    }

    return access;
  }

  async review(id: string, dto: ReviewDocumentDto) {
    const existing = await this.prisma.document.findUnique({
      where: { id },
      select: {
        id: true,
        ownerType: true,
        userId: true,
        institutionId: true,
        documentType: true,
      },
    });

    if (!existing) {
      throw new NotFoundException('Documento nao encontrado.');
    }

    const document = await this.prisma.$transaction(async (tx) => {
      const reviewedDocument = await tx.document.update({
        where: { id },
        data: {
          status: dto.status,
          rejectionReason:
            dto.status === VerificationStatus.REJECTED
              ? dto.rejectionReason
              : null,
          reviewedBy: dto.reviewedBy,
          reviewedAt: new Date(),
        },
      });

      await this.applyReviewEffects(existing, tx);

      return reviewedDocument;
    });

    return {
      message: 'Revisao de documento registrada com sucesso.',
      document,
    };
  }

  private cleanupExpiredFileAccessTokens() {
    const now = Date.now();

    for (const [token, access] of fileAccessTokens.entries()) {
      if (access.expiresAt <= now) {
        fileAccessTokens.delete(token);
      }
    }
  }

  private async applyReviewEffects(
    document: {
      ownerType: DocumentOwnerType;
      userId: string | null;
      institutionId: string | null;
      documentType: DocumentType;
    },
    tx: Prisma.TransactionClient,
  ) {
    if (document.ownerType === DocumentOwnerType.INSTITUTION) {
      if (!document.institutionId) {
        return;
      }

      await this.applyInstitutionVerification(document.institutionId, tx);
      return;
    }

    if (!document.userId) {
      return;
    }

    await this.applyProfessionalVerification(document.userId, tx);
  }

  private async applyInstitutionVerification(
    institutionId: string,
    tx: Prisma.TransactionClient,
  ) {
    const institution = await tx.institution.findUnique({
      where: { id: institutionId },
      select: { userId: true },
    });

    if (!institution) {
      return;
    }

    const hasApprovedCnpj = await this.hasApprovedDocument(tx, {
      ownerType: DocumentOwnerType.INSTITUTION,
      institutionId,
      documentType: DocumentType.CNPJ_PROOF,
    });

    const nextStatus = hasApprovedCnpj
      ? VerificationStatus.APPROVED
      : VerificationStatus.PENDING;
    const nextAccountStatus = hasApprovedCnpj
      ? AccountStatus.ACTIVE
      : AccountStatus.PENDING_VERIFICATION;

    await tx.institution.update({
      where: { id: institutionId },
      data: { verificationStatus: nextStatus },
    });
    await tx.user.update({
      where: { id: institution.userId },
      data: { status: nextAccountStatus },
    });
  }

  private async applyProfessionalVerification(
    userId: string,
    tx: Prisma.TransactionClient,
  ) {
    const user = await tx.user.findUnique({
      where: { id: userId },
      select: { role: true },
    });

    if (!user) {
      return;
    }

    const hasApprovedPhoto = await this.hasApprovedDocument(tx, {
      ownerType: DocumentOwnerType.USER,
      userId,
      documentType: DocumentType.PROFILE_PHOTO,
    });

    if (user.role === UserRole.VETERINARIAN) {
      const hasApprovedCrmv = await this.hasApprovedDocument(tx, {
        ownerType: DocumentOwnerType.USER,
        userId,
        documentType: DocumentType.CRMV_PROOF,
      });

      const isApproved = hasApprovedPhoto && hasApprovedCrmv;
      await tx.veterinarianProfile.updateMany({
        where: { userId },
        data: {
          verificationStatus: isApproved
            ? VerificationStatus.APPROVED
            : VerificationStatus.PENDING,
        },
      });
      await this.updateUserVerificationStatus(userId, isApproved, tx);
      return;
    }

    if (user.role === UserRole.INTERN) {
      const hasApprovedEnrollment = await this.hasApprovedDocument(tx, {
        ownerType: DocumentOwnerType.USER,
        userId,
        documentType: DocumentType.ENROLLMENT_STATEMENT,
      });

      const isApproved = hasApprovedPhoto && hasApprovedEnrollment;
      await tx.internProfile.updateMany({
        where: { userId },
        data: {
          verificationStatus: isApproved
            ? VerificationStatus.APPROVED
            : VerificationStatus.PENDING,
        },
      });
      await this.updateUserVerificationStatus(userId, isApproved, tx);
    }
  }

  private async updateUserVerificationStatus(
    userId: string,
    isApproved: boolean,
    tx: Prisma.TransactionClient,
  ) {
    await tx.user.update({
      where: { id: userId },
      data: {
        status: isApproved
          ? AccountStatus.ACTIVE
          : AccountStatus.PENDING_VERIFICATION,
      },
    });
  }

  private async hasApprovedDocument(
    tx: Prisma.TransactionClient,
    where: {
      ownerType: DocumentOwnerType;
      documentType: DocumentType;
      userId?: string;
      institutionId?: string;
    },
  ) {
    const document = await tx.document.findFirst({
      where: {
        ownerType: where.ownerType,
        documentType: where.documentType,
        userId: where.userId,
        institutionId: where.institutionId,
        status: VerificationStatus.APPROVED,
      },
      select: { id: true },
    });

    return Boolean(document);
  }
}
