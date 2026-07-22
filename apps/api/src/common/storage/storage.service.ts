import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { NodeHttpHandler } from '@smithy/node-http-handler';
import { randomUUID } from 'crypto';
import { mkdir, writeFile } from 'fs/promises';
import { Agent } from 'https';
import { basename, extname, join } from 'path';

const allowedExtensionsByMimeType: Record<string, string[]> = {
  'application/pdf': ['.pdf'],
  'image/jpg': ['.jpg', '.jpeg'],
  'image/jpeg': ['.jpg', '.jpeg'],
  'image/png': ['.png'],
};

@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private s3Client?: S3Client;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    if (this.getDriver() !== 's3') {
      return;
    }

    const requiredVariables = [
      'STORAGE_BUCKET',
      'S3_ENDPOINT',
      'S3_REGION',
      'S3_ACCESS_KEY_ID',
      'S3_SECRET_ACCESS_KEY',
    ];
    const missingVariables = requiredVariables.filter(
      (variable) => !this.configService.get<string>(variable)?.trim(),
    );

    if (missingVariables.length > 0) {
      throw new Error(
        `Storage S3 incompleto. Configure: ${missingVariables.join(', ')}.`,
      );
    }

    this.logger.log(
      `Storage S3 configurado: bucket=${this.getBucket()}, region=${this.getRegion()}, pathStyle=${this.usePathStyle()}.`,
    );
  }

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
    const mimeType = this.resolveMimeType(originalName, file.mimetype);
    const fileName = `${randomUUID()}-${safeBaseName || 'documento'}${extension}`;

    if (this.getDriver() === 's3') {
      const bucket = this.getBucket();
      const datePrefix = new Date().toISOString().slice(0, 7);
      const key = `documents/${datePrefix}/${fileName}`;

      try {
        await this.getS3Client().send(
          new PutObjectCommand({
            Bucket: bucket,
            Key: key,
            Body: file.buffer,
            ContentType: mimeType,
            ContentLength: file.buffer.length,
          }),
        );
      } catch (error) {
        this.logStorageError('upload', error);

        if (!this.allowLocalFallback()) {
          throw new Error(
            'Nao foi possivel armazenar o arquivo no storage permanente.',
          );
        }

        this.logger.warn(
          'Falha no storage S3. Usando storage local temporario para manter o fluxo de documentos disponivel.',
        );
        return this.saveLocalUploadedDocument(file, fileName, mimeType);
      }

      return {
        fileName,
        publicPath: `s3://${bucket}/${key}`,
        mimeType,
        size: file.buffer.length,
      };
    }

    return this.saveLocalUploadedDocument(file, fileName, mimeType);
  }

  private async saveLocalUploadedDocument(
    file: { buffer?: Buffer },
    fileName: string,
    mimeType: string,
  ) {
    if (!file.buffer) {
      throw new Error('Arquivo enviado sem conteudo.');
    }

    const uploadsDir = join(process.cwd(), 'uploads', 'documents');
    await mkdir(uploadsDir, { recursive: true });
    const absolutePath = join(uploadsDir, fileName);

    await writeFile(absolutePath, file.buffer);

    return {
      fileName,
      publicPath: `/uploads/documents/${fileName}`,
      mimeType,
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
    try {
      await client.send(
        new HeadObjectCommand({
          Bucket: location.bucket,
          Key: location.key,
        }),
      );
    } catch (error) {
      this.logStorageError('consulta', error);
      throw error;
    }

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
    const region = this.getRegion();
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
      maxAttempts: 1,
      requestChecksumCalculation: 'WHEN_REQUIRED',
      responseChecksumValidation: 'WHEN_REQUIRED',
      requestHandler: new NodeHttpHandler({
        connectionTimeout: 10_000,
        requestTimeout: 30_000,
        socketTimeout: 30_000,
        httpsAgent: new Agent({
          family: 4,
          keepAlive: false,
          minVersion: 'TLSv1.2',
        }),
      }),
      forcePathStyle: this.usePathStyle(),
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });

    return this.s3Client;
  }

  private getRegion() {
    return this.configService.get<string>('S3_REGION')?.trim() || 'auto';
  }

  private usePathStyle() {
    return (
      this.configService.get<string>('S3_FORCE_PATH_STYLE')
        ?.trim()
        .toLowerCase() === 'true'
    );
  }

  private allowLocalFallback() {
    const configuredValue = this.configService
      .get<string>('STORAGE_ALLOW_LOCAL_FALLBACK')
      ?.trim()
      .toLowerCase();

    if (configuredValue) {
      return configuredValue === 'true';
    }

    return this.configService.get<string>('NODE_ENV') !== 'production';
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

  private logStorageError(operation: string, error: unknown) {
    const storageError = error as {
      name?: string;
      message?: string;
      code?: string;
      $metadata?: { httpStatusCode?: number; requestId?: string };
    };

    this.logger.error(
      JSON.stringify({
        operation,
        name: storageError?.name ?? 'UnknownError',
        code: storageError?.code,
        status: storageError?.$metadata?.httpStatusCode,
        requestId: storageError?.$metadata?.requestId,
        message: storageError?.message ?? 'Falha desconhecida no storage.',
      }),
    );
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
      case 'image/jpg':
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      default:
        return '';
    }
  }

  private resolveMimeType(fileName: string, mimeType?: string) {
    if (
      mimeType &&
      mimeType !== 'application/octet-stream' &&
      mimeType !== 'image/jpg'
    ) {
      return mimeType;
    }

    switch (extname(fileName).toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      default:
        return mimeType ?? 'application/octet-stream';
    }
  }
}
