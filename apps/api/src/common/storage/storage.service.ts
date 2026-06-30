import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';
import { mkdir, writeFile } from 'fs/promises';
import { basename, extname, join } from 'path';

const allowedExtensionsByMimeType: Record<string, string[]> = {
  'application/pdf': ['.pdf'],
  'image/jpeg': ['.jpg', '.jpeg'],
  'image/png': ['.png'],
};

@Injectable()
export class StorageService {
  private s3Client?: S3Client;

  constructor(private readonly configService: ConfigService) {}

  createUploadPlaceholder(input: { folder: string; fileName: string }) {
    const driver = this.configService.get<string>('STORAGE_DRIVER') ?? 'local';
    const bucket = this.configService.get<string>('STORAGE_BUCKET') ?? 'vetfinder-documents';
    const safeFileName = input.fileName.replace(/\s+/g, '-').toLowerCase();
    const key = `${input.folder}/${Date.now()}-${safeFileName}`;

    return {
      driver,
      bucket,
      key,
      uploadUrl: `pending://${bucket}/${key}`,
      publicUrl: `pending://${bucket}/${key}`,
    };
  }

  async saveUploadedDocument(file: {
    originalname?: string;
    mimetype?: string;
    buffer?: Buffer;
  }) {
    if (!file.buffer) {
      throw new Error('Arquivo enviado sem conteudo.');
    }

    const originalName = file.originalname ?? 'documento';
    const safeBaseName = originalName
      .replace(extname(originalName), '')
      .replace(/[^a-zA-Z0-9-_]/g, '-')
      .replace(/-+/g, '-')
      .toLowerCase();
    const extension = this.resolveExtension(originalName, file.mimetype);
    const fileName = `${randomUUID()}-${safeBaseName || 'documento'}${extension}`;

    if (this.getDriver() === 's3') {
      const bucket = this.getBucket();
      const datePrefix = new Date().toISOString().slice(0, 7);
      const key = `documents/${datePrefix}/${fileName}`;

      await this.getS3Client().send(
        new PutObjectCommand({
          Bucket: bucket,
          Key: key,
          Body: file.buffer,
          ContentType: file.mimetype ?? 'application/octet-stream',
          ContentLength: file.buffer.length,
        }),
      );

      return {
        fileName,
        publicPath: `s3://${bucket}/${key}`,
        mimeType: file.mimetype,
        size: file.buffer.length,
      };
    }

    const uploadsDir = join(process.cwd(), 'uploads', 'documents');
    await mkdir(uploadsDir, { recursive: true });
    const absolutePath = join(uploadsDir, fileName);

    await writeFile(absolutePath, file.buffer);

    return {
      fileName,
      publicPath: `/uploads/documents/${fileName}`,
      mimeType: file.mimetype,
      size: file.buffer.length,
    };
  }

  resolveLocalDocumentPath(fileUrl: string) {
    const rawPath = this.extractPathFromUrl(fileUrl);
    const fileName = basename(rawPath);

    return join(process.cwd(), 'uploads', 'documents', fileName);
  }

  async createTemporaryDownloadUrl(
    fileUrl: string,
    expiresInSeconds = 120,
  ) {
    const location = this.parseS3Location(fileUrl);
    if (!location) {
      return null;
    }

    const client = this.getS3Client();
    await client.send(
      new HeadObjectCommand({
        Bucket: location.bucket,
        Key: location.key,
      }),
    );

    return getSignedUrl(
      client,
      new GetObjectCommand({
        Bucket: location.bucket,
        Key: location.key,
      }),
      { expiresIn: expiresInSeconds },
    );
  }

  private extractPathFromUrl(fileUrl: string) {
    try {
      return new URL(fileUrl).pathname;
    } catch {
      return fileUrl;
    }
  }

  private getDriver() {
    return (this.configService.get<string>('STORAGE_DRIVER') ?? 'local')
      .trim()
      .toLowerCase();
  }

  private getBucket() {
    return (
      this.configService.get<string>('STORAGE_BUCKET') ?? 'vetfinder-documents'
    );
  }

  private getS3Client() {
    if (this.s3Client) {
      return this.s3Client;
    }

    const endpoint = this.configService.get<string>('S3_ENDPOINT')?.trim();
    const region = this.configService.get<string>('S3_REGION')?.trim() || 'auto';
    const accessKeyId = this.configService
      .get<string>('S3_ACCESS_KEY_ID')
      ?.trim();
    const secretAccessKey = this.configService
      .get<string>('S3_SECRET_ACCESS_KEY')
      ?.trim();

    if (!accessKeyId || !secretAccessKey) {
      throw new Error('Credenciais S3 nao configuradas.');
    }

    this.s3Client = new S3Client({
      endpoint: endpoint || undefined,
      region,
      requestChecksumCalculation: 'WHEN_REQUIRED',
      responseChecksumValidation: 'WHEN_REQUIRED',
      forcePathStyle:
        this.configService.get<string>('S3_FORCE_PATH_STYLE') === 'true',
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });

    return this.s3Client;
  }

  private parseS3Location(fileUrl: string) {
    if (!fileUrl.startsWith('s3://')) {
      return null;
    }

    const location = new URL(fileUrl);
    const key = decodeURIComponent(location.pathname.replace(/^\//, ''));

    if (!location.hostname || !key) {
      throw new Error('Localizacao S3 invalida.');
    }

    return {
      bucket: location.hostname,
      key,
    };
  }

  private resolveExtension(fileName: string, mimeType?: string) {
    const currentExtension = extname(fileName).toLowerCase();
    const allowedExtensions = mimeType
      ? allowedExtensionsByMimeType[mimeType]
      : undefined;

    if (
      currentExtension &&
      (!allowedExtensions || allowedExtensions.includes(currentExtension))
    ) {
      return currentExtension;
    }

    switch (mimeType) {
      case 'application/pdf':
        return '.pdf';
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      default:
        return '';
    }
  }
}
