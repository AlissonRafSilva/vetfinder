import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

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
}
