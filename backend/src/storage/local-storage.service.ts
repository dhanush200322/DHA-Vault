import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { Readable } from 'stream';
import { v4 as uuidv4 } from 'uuid';
import { IStorageService, StoredFileResult, UploadFileOptions } from './storage.interface';

const ALLOWED_MIME_TYPES = new Map<string, string>([
  ['application/pdf', '.pdf'],
  ['image/jpeg', '.jpg'],
  ['image/jpg', '.jpg'],
  ['image/png', '.png'],
  ['image/webp', '.webp'],
  ['application/octet-stream', '.enc'],
]);

const MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024; // 25 MB

@Injectable()
export class LocalStorageService implements IStorageService {
  private readonly logger = new Logger(LocalStorageService.name);
  private readonly basePath: string;

  constructor(private readonly configService: ConfigService) {
    const configuredPath = this.configService.get<string>('STORAGE_PATH', './uploads');
    this.basePath = path.resolve(process.cwd(), configuredPath);

    if (!fs.existsSync(this.basePath)) {
      fs.mkdirSync(this.basePath, { recursive: true });
    }
  }

  /**
   * Validates file buffer against known binary magic numbers
   */
  private validateMagicBytes(buffer: Buffer, mimeType: string): void {
    if (buffer.length < 4) {
      throw new BadRequestException('File is corrupted or too small to verify signature');
    }

    const isPdf =
      buffer[0] === 0x25 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x44 &&
      buffer[3] === 0x46; // %PDF

    const isJpeg =
      buffer[0] === 0xff &&
      buffer[1] === 0xd8 &&
      buffer[2] === 0xff; // \xFF\xD8\xFF

    const isPng =
      buffer.length >= 8 &&
      buffer[0] === 0x89 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x4e &&
      buffer[3] === 0x47 &&
      buffer[4] === 0x0d &&
      buffer[5] === 0x0a &&
      buffer[6] === 0x1a &&
      buffer[7] === 0x0a; // \x89PNG\r\n\x1a\n

    const isWebp =
      buffer.length >= 12 &&
      buffer[0] === 0x52 &&
      buffer[1] === 0x49 &&
      buffer[2] === 0x46 &&
      buffer[3] === 0x46 && // RIFF
      buffer[8] === 0x57 &&
      buffer[9] === 0x45 &&
      buffer[10] === 0x42 &&
      buffer[11] === 0x50; // WEBP

    if (mimeType.includes('octet-stream')) {
      return; // Encrypted envelopes have pseudorandom bytes by design
    }

    if (mimeType.includes('pdf') && !isPdf) {
      throw new BadRequestException('Invalid PDF file signature (magic bytes mismatch)');
    }
    if ((mimeType.includes('jpeg') || mimeType.includes('jpg')) && !isJpeg) {
      throw new BadRequestException('Invalid JPEG file signature (magic bytes mismatch)');
    }
    if (mimeType.includes('png') && !isPng) {
      throw new BadRequestException('Invalid PNG file signature (magic bytes mismatch)');
    }
    if (mimeType.includes('webp') && !isWebp) {
      throw new BadRequestException('Invalid WEBP file signature (magic bytes mismatch)');
    }
  }

  async upload(options: UploadFileOptions): Promise<StoredFileResult> {
    const { buffer, originalFileName, mimeType, subFolder } = options;

    if (!buffer || buffer.length === 0) {
      throw new BadRequestException('File buffer cannot be empty');
    }

    if (buffer.length > MAX_FILE_SIZE_BYTES) {
      throw new BadRequestException(`File size exceeds 25MB limit (${buffer.length} bytes)`);
    }

    const normalizedMime = mimeType.toLowerCase().trim();
    const expectedExtension = ALLOWED_MIME_TYPES.get(normalizedMime);
    if (!expectedExtension) {
      throw new BadRequestException(
        `Unsupported MIME type "${normalizedMime}". Only PDF, JPEG, PNG, WEBP, and encrypted backups are allowed.`,
      );
    }

    // Sanitize extension from original filename
    const originalExt = path.extname(originalFileName).toLowerCase();
    const allowedExts = ['.pdf', '.jpg', '.jpeg', '.png', '.webp', '.enc', '.bin'];
    if (originalExt && !allowedExts.includes(originalExt)) {
      throw new BadRequestException(`Prohibited file extension "${originalExt}"`);
    }

    // Validate binary signature (magic bytes) to defeat spoofing
    this.validateMagicBytes(buffer, normalizedMime);

    // Target folder structure: uploads/{subFolder or 'documents'}
    const sanitizedSubfolder = subFolder
      ? path.normalize(subFolder).replace(/^(\.\.[\/\\])+/, '')
      : 'documents';
    const targetDir = path.join(this.basePath, sanitizedSubfolder);

    if (!targetDir.startsWith(this.basePath)) {
      throw new BadRequestException('Invalid target folder path');
    }

    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }

    // Secure server-side randomized filename
    const generatedFileName = `${uuidv4()}${expectedExtension}`;
    const destinationPath = path.join(targetDir, generatedFileName);

    try {
      await fs.promises.writeFile(destinationPath, buffer);
      const relativeStoragePath = path
        .relative(process.cwd(), destinationPath)
        .replace(/\\/g, '/');

      // Calculate cryptographic SHA-256 checksum
      const checksum = crypto.createHash('sha256').update(buffer).digest('hex');

      return {
        storagePath: relativeStoragePath,
        fileName: generatedFileName,
        originalFileName: path.basename(originalFileName).substring(0, 255),
        fileSize: buffer.length,
        mimeType: normalizedMime,
        checksum,
      };
    } catch (err: any) {
      this.logger.error(`Failed to write file to local disk: ${err.message}`, err.stack);
      throw new InternalServerErrorException('Failed to securely store document file');
    }
  }

  async download(storagePath: string): Promise<{ stream: Readable; mimeType: string; fileSize: number }> {
    const resolvedPath = path.resolve(process.cwd(), storagePath);

    // Prevent directory traversal
    if (!resolvedPath.startsWith(this.basePath)) {
      throw new BadRequestException('Security violation: invalid storage path access');
    }

    if (!fs.existsSync(resolvedPath)) {
      throw new NotFoundException('Requested file not found on storage server');
    }

    const stat = await fs.promises.stat(resolvedPath);
    const ext = path.extname(resolvedPath).toLowerCase();
    let mimeType = 'application/octet-stream';

    for (const [mime, allowedExt] of ALLOWED_MIME_TYPES.entries()) {
      if (allowedExt === ext || (ext === '.jpeg' && allowedExt === '.jpg')) {
        mimeType = mime;
        break;
      }
    }

    const stream = fs.createReadStream(resolvedPath);
    return {
      stream,
      mimeType,
      fileSize: stat.size,
    };
  }

  async delete(storagePath: string): Promise<boolean> {
    const resolvedPath = path.resolve(process.cwd(), storagePath);
    if (!resolvedPath.startsWith(this.basePath)) {
      return false;
    }

    if (fs.existsSync(resolvedPath)) {
      await fs.promises.unlink(resolvedPath);
      return true;
    }
    return false;
  }

  async exists(storagePath: string): Promise<boolean> {
    const resolvedPath = path.resolve(process.cwd(), storagePath);
    if (!resolvedPath.startsWith(this.basePath)) {
      return false;
    }
    return fs.existsSync(resolvedPath);
  }

  async getMetadata(storagePath: string) {
    const resolvedPath = path.resolve(process.cwd(), storagePath);
    if (!resolvedPath.startsWith(this.basePath) || !fs.existsSync(resolvedPath)) {
      throw new NotFoundException('File not found');
    }
    const stat = await fs.promises.stat(resolvedPath);
    const buffer = await fs.promises.readFile(resolvedPath);
    const checksum = crypto.createHash('sha256').update(buffer).digest('hex');
    const ext = path.extname(resolvedPath).toLowerCase();
    let mimeType = 'application/octet-stream';
    for (const [mime, allowedExt] of ALLOWED_MIME_TYPES.entries()) {
      if (allowedExt === ext || (ext === '.jpeg' && allowedExt === '.jpg')) {
        mimeType = mime;
        break;
      }
    }
    return {
      fileSize: stat.size,
      mimeType,
      lastModified: stat.mtime,
      checksum,
    };
  }

  async generateSecureUrl(storagePath: string, expiresInSeconds = 300): Promise<string> {
    // For local storage, returns an internal tokenized endpoint with expiry timestamp and signature
    const expiresAt = Math.floor(Date.now() / 1000) + expiresInSeconds;
    const secret = this.configService.get<string>('JWT_ACCESS_SECRET') || 'dha_vault_secret';
    const signature = crypto
      .createHmac('sha256', secret)
      .update(`${storagePath}:${expiresAt}`)
      .digest('hex')
      .substring(0, 32);
    return `/storage/secure-view?path=${encodeURIComponent(storagePath)}&exp=${expiresAt}&sig=${signature}`;
  }

  getFilePath(storagePath: string): string {
    return path.resolve(process.cwd(), storagePath);
  }
}
