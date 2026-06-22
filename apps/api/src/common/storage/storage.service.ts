import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { mkdir, writeFile } from 'fs/promises';
import { extname, join } from 'path';

const allowedExtensionsByMimeType: Record<string, string[]> = {
  'application/pdf': ['.pdf'],
  'image/jpeg': ['.jpg', '.jpeg'],
  'image/png': ['.png'],
};

@Injectable()
export class StorageService {
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

    const uploadsDir = join(process.cwd(), 'uploads', 'documents');
    await mkdir(uploadsDir, { recursive: true });

    const originalName = file.originalname ?? 'documento';
    const safeBaseName = originalName
      .replace(extname(originalName), '')
      .replace(/[^a-zA-Z0-9-_]/g, '-')
      .replace(/-+/g, '-')
      .toLowerCase();
    const extension = this.resolveExtension(originalName, file.mimetype);
    const fileName = `${randomUUID()}-${safeBaseName || 'documento'}${extension}`;
    const absolutePath = join(uploadsDir, fileName);

    await writeFile(absolutePath, file.buffer);

    return {
      fileName,
      publicPath: `/uploads/documents/${fileName}`,
      mimeType: file.mimetype,
      size: file.buffer.length,
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
