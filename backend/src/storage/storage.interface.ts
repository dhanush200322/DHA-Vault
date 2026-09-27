import { Readable } from 'stream';

export interface UploadFileOptions {
  buffer: Buffer;
  originalFileName: string;
  mimeType: string;
  subFolder?: string;
  customKey?: string;
}

export interface StoredFileResult {
  storagePath: string;
  fileName: string;
  originalFileName: string;
  fileSize: number;
  mimeType: string;
  checksum: string; // SHA-256 cryptographic integrity hash
}

export interface StorageMetadata {
  fileSize: number;
  mimeType: string;
  lastModified?: Date;
  etag?: string;
  checksum?: string;
}

export interface IStorageService {
  upload(options: UploadFileOptions): Promise<StoredFileResult>;
  download(storagePath: string): Promise<{ stream: Readable; mimeType: string; fileSize: number }>;
  delete(storagePath: string): Promise<boolean>;
  exists(storagePath: string): Promise<boolean>;
  getMetadata(storagePath: string): Promise<StorageMetadata>;
  generateSecureUrl(storagePath: string, expiresInSeconds?: number): Promise<string>;
}
