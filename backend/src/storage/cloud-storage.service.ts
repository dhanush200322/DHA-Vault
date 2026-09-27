import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  HeadObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import * as crypto from 'crypto';
import { Readable } from 'stream';
import { v4 as uuidv4 } from 'uuid';
import {
  IStorageService,
  StorageMetadata,
  StoredFileResult,
  UploadFileOptions,
} from './storage.interface';

@Injectable()
export class CloudStorageService implements IStorageService {
  private readonly logger = new Logger(CloudStorageService.name);
  private readonly s3Client?: S3Client;
  private readonly bucketName: string;
  private readonly isConfigured: boolean;

  constructor(private readonly configService: ConfigService) {
    const endpoint = this.configService.get<string>('S3_ENDPOINT');
    const region = this.configService.get<string>('S3_REGION', 'us-east-1');
    const accessKeyId = this.configService.get<string>('S3_ACCESS_KEY');
    const secretAccessKey = this.configService.get<string>('S3_SECRET_KEY');
    this.bucketName = this.configService.get<string>('S3_BUCKET', 'dha-vault-private');

    if (accessKeyId && secretAccessKey) {
      this.s3Client = new S3Client({
        region,
        endpoint: endpoint || undefined,
        forcePathStyle: !!endpoint, // MinIO / local S3 compatibility
        credentials: {
          accessKeyId,
          secretAccessKey,
        },
      });
      this.isConfigured = true;
      this.logger.log(`Initialized S3-compatible cloud storage driver (bucket: ${this.bucketName})`);
    } else {
      this.isConfigured = false;
      this.logger.warn('Cloud storage credentials (S3_ACCESS_KEY / S3_SECRET_KEY) not provided. S3 driver dormant.');
    }
  }

  private checkConfigured() {
    if (!this.isConfigured || !this.s3Client) {
      throw new InternalServerErrorException(
        'Cloud storage (S3/R2/MinIO/Supabase) is not configured with access credentials',
      );
    }
  }

  async upload(options: UploadFileOptions): Promise<StoredFileResult> {
    this.checkConfigured();
    const { buffer, originalFileName, mimeType, subFolder, customKey } = options;

    if (!buffer || buffer.length === 0) {
      throw new BadRequestException('Buffer cannot be empty');
    }

    const checksum = crypto.createHash('sha256').update(buffer).digest('hex');
    const ext = originalFileName.includes('.')
      ? `.${originalFileName.split('.').pop()?.toLowerCase()}`
      : '.bin';

    const objectKey =
      customKey ||
      `${subFolder ? subFolder.replace(/^\/+|\/+$/g, '') + '/' : ''}${uuidv4()}${ext}`;

    try {
      await this.s3Client!.send(
        new PutObjectCommand({
          Bucket: this.bucketName,
          Key: objectKey,
          Body: buffer,
          ContentType: mimeType,
          Metadata: {
            'original-filename': encodeURIComponent(originalFileName),
            checksum,
          },
        }),
      );

      return {
        storagePath: objectKey,
        fileName: objectKey.split('/').pop() || objectKey,
        originalFileName: originalFileName.substring(0, 255),
        fileSize: buffer.length,
        mimeType,
        checksum,
      };
    } catch (err: any) {
      this.logger.error(`Cloud upload failed: ${err.message}`, err.stack);
      throw new InternalServerErrorException('Failed to upload encrypted object to cloud storage');
    }
  }

  async download(storagePath: string): Promise<{ stream: Readable; mimeType: string; fileSize: number }> {
    this.checkConfigured();

    try {
      const response = await this.s3Client!.send(
        new GetObjectCommand({
          Bucket: this.bucketName,
          Key: storagePath,
        }),
      );

      const stream = response.Body as Readable;
      const mimeType = response.ContentType || 'application/octet-stream';
      const fileSize = response.ContentLength || 0;

      return {
        stream,
        mimeType,
        fileSize,
      };
    } catch (err: any) {
      if (err.name === 'NoSuchKey') {
        throw new NotFoundException('Object not found in cloud storage');
      }
      this.logger.error(`Cloud download failed: ${err.message}`, err.stack);
      throw new InternalServerErrorException('Failed to retrieve object from cloud storage');
    }
  }

  async delete(storagePath: string): Promise<boolean> {
    this.checkConfigured();

    try {
      await this.s3Client!.send(
        new DeleteObjectCommand({
          Bucket: this.bucketName,
          Key: storagePath,
        }),
      );
      return true;
    } catch (err: any) {
      this.logger.warn(`Failed to delete cloud object ${storagePath}: ${err.message}`);
      return false;
    }
  }

  async exists(storagePath: string): Promise<boolean> {
    this.checkConfigured();

    try {
      await this.s3Client!.send(
        new HeadObjectCommand({
          Bucket: this.bucketName,
          Key: storagePath,
        }),
      );
      return true;
    } catch {
      return false;
    }
  }

  async getMetadata(storagePath: string): Promise<StorageMetadata> {
    this.checkConfigured();

    try {
      const response = await this.s3Client!.send(
        new HeadObjectCommand({
          Bucket: this.bucketName,
          Key: storagePath,
        }),
      );

      return {
        fileSize: response.ContentLength || 0,
        mimeType: response.ContentType || 'application/octet-stream',
        lastModified: response.LastModified,
        etag: response.ETag,
        checksum: response.Metadata?.checksum,
      };
    } catch (err: any) {
      throw new NotFoundException(`Object ${storagePath} not found in cloud storage`);
    }
  }

  async generateSecureUrl(storagePath: string, expiresInSeconds = 300): Promise<string> {
    this.checkConfigured();

    // Generates a short-lived presigned GET URL for private object access
    try {
      const command = new GetObjectCommand({
        Bucket: this.bucketName,
        Key: storagePath,
      });

      return await getSignedUrl(this.s3Client!, command, {
        expiresIn: expiresInSeconds,
      });
    } catch (err: any) {
      this.logger.error(`Failed to generate signed URL for ${storagePath}: ${err.message}`);
      throw new InternalServerErrorException('Failed to generate secure access URL');
    }
  }
}
