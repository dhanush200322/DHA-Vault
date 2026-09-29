import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LocalStorageService } from './local-storage.service';
import { CloudStorageService } from './cloud-storage.service';
import {
  IStorageService,
  StorageMetadata,
  StoredFileResult,
  UploadFileOptions,
} from './storage.interface';
import { Readable } from 'stream';

@Injectable()
export class StorageService implements IStorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly activeDriver: IStorageService;
  private readonly providerName: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly localDriver: LocalStorageService,
    private readonly cloudDriver: CloudStorageService,
  ) {
    const rawMode = (
      this.configService.get<string>('STORAGE_MODE') ||
      this.configService.get<string>('STORAGE_PROVIDER') ||
      this.configService.get<string>('STORAGE_DRIVER', 'local')
    ).toLowerCase();

    if (rawMode === 'local_only' || rawMode === 'local' || rawMode === 'zero_cost') {
      this.providerName = 'local';
      this.activeDriver = this.localDriver;
      this.logger.log('Active storage provider: LocalStorageService (Zero-Cost Local-First Mode)');
    } else if (rawMode === 's3' || rawMode === 'r2') {
      this.providerName = rawMode;
      this.activeDriver = this.cloudDriver;
      this.logger.log('Active storage provider: CloudStorageService (S3/Cloudflare R2)');
    } else {
      this.providerName = 'local';
      this.activeDriver = this.localDriver;
      this.logger.log('Active storage provider: LocalStorageService (Local Private Default)');
    }
  }

  getProviderName(): string {
    return this.providerName;
  }

  getStorageMode(): string {
    return this.providerName === 'local' ? 'Local / Zero-Cost' : 'Cloud';
  }

  getStorageStatus(): { mode: string; provider: string; encrypted: boolean } {
    return {
      mode: this.getStorageMode(),
      provider: this.providerName,
      encrypted: true,
    };
  }

  async upload(options: UploadFileOptions): Promise<StoredFileResult> {
    return this.activeDriver.upload(options);
  }

  async download(storagePath: string): Promise<{ stream: Readable; mimeType: string; fileSize: number }> {
    return this.activeDriver.download(storagePath);
  }

  async delete(storagePath: string): Promise<boolean> {
    return this.activeDriver.delete(storagePath);
  }

  async exists(storagePath: string): Promise<boolean> {
    return this.activeDriver.exists(storagePath);
  }

  async getMetadata(storagePath: string): Promise<StorageMetadata> {
    return this.activeDriver.getMetadata(storagePath);
  }

  async generateSecureUrl(storagePath: string, expiresInSeconds?: number): Promise<string> {
    return this.activeDriver.generateSecureUrl(storagePath, expiresInSeconds);
  }

  getFilePath(storagePath: string): string {
    // For local operations, returns local disk path
    return this.localDriver.getFilePath(storagePath);
  }
}
