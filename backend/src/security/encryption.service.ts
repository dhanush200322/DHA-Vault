import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import * as crypto from 'crypto';

export interface EncryptedDataPackage {
  version: number;
  iv: string; // Hex
  authTag: string; // Hex
  ciphertext: string; // Base64
}

export interface WrappedKeyPackage {
  wrappedKey: string; // Base64
  iv: string; // Hex
  authTag: string; // Hex
  version: number;
}

@Injectable()
export class EncryptionService {
  private readonly logger = new Logger(EncryptionService.name);
  private readonly CURRENT_ENCRYPTION_VERSION = 1;
  private readonly ALGORITHM = 'aes-256-gcm';
  private readonly IV_LENGTH_BYTES = 12; // Standard 96-bit nonce for GCM
  private readonly AUTH_TAG_LENGTH_BYTES = 16; // 128-bit authentication tag
  private readonly PBKDF2_ITERATIONS = 100000;

  /**
   * Generates a cryptographically strong 256-bit random key
   */
  generateKey(): Buffer {
    return crypto.randomBytes(32);
  }

  /**
   * Derives a 256-bit encryption key using PBKDF2-HMAC-SHA256 with user-specific salt
   */
  deriveKey(passphrase: string, salt: Buffer, iterations = this.PBKDF2_ITERATIONS): Buffer {
    if (!passphrase || passphrase.length < 8) {
      throw new BadRequestException('Passphrase must be at least 8 characters for key derivation');
    }
    return crypto.pbkdf2Sync(passphrase, salt, iterations, 32, 'sha256');
  }

  /**
   * Encrypts a buffer using AES-256-GCM authenticated encryption
   */
  encryptBuffer(plaintext: Buffer, key: Buffer, version = this.CURRENT_ENCRYPTION_VERSION): Buffer {
    if (key.length !== 32) {
      throw new BadRequestException('Key must be exactly 256 bits (32 bytes)');
    }

    const iv = crypto.randomBytes(this.IV_LENGTH_BYTES);
    const cipher = crypto.createCipheriv(this.ALGORITHM, key, iv);

    const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
    const authTag = cipher.getAuthTag();

    // Standard DHA Vault Encrypted Binary Envelope:
    // [1 byte version] + [12 bytes IV] + [16 bytes Auth Tag] + [Ciphertext]
    const versionHeader = Buffer.from([version]);
    return Buffer.concat([versionHeader, iv, authTag, ciphertext]);
  }

  /**
   * Decrypts a buffer encrypted with DHA Vault envelope
   */
  decryptBuffer(encryptedBuffer: Buffer, key: Buffer): { plaintext: Buffer; version: number } {
    if (key.length !== 32) {
      throw new BadRequestException('Key must be exactly 256 bits (32 bytes)');
    }

    if (encryptedBuffer.length < 1 + this.IV_LENGTH_BYTES + this.AUTH_TAG_LENGTH_BYTES) {
      throw new BadRequestException('Corrupted or truncated ciphertext envelope');
    }

    const version = encryptedBuffer[0];
    const iv = encryptedBuffer.subarray(1, 1 + this.IV_LENGTH_BYTES);
    const authTag = encryptedBuffer.subarray(
      1 + this.IV_LENGTH_BYTES,
      1 + this.IV_LENGTH_BYTES + this.AUTH_TAG_LENGTH_BYTES,
    );
    const ciphertext = encryptedBuffer.subarray(
      1 + this.IV_LENGTH_BYTES + this.AUTH_TAG_LENGTH_BYTES,
    );

    const decipher = crypto.createDecipheriv(this.ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);

    try {
      const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
      return { plaintext, version };
    } catch {
      throw new BadRequestException('Decryption failed: cryptographic integrity check or key mismatch');
    }
  }

  /**
   * Wraps a master vault key using a device-specific wrapping key
   */
  wrapKey(keyToWrap: Buffer, wrappingKey: Buffer): WrappedKeyPackage {
    const iv = crypto.randomBytes(this.IV_LENGTH_BYTES);
    const cipher = crypto.createCipheriv(this.ALGORITHM, wrappingKey, iv);
    const ciphertext = Buffer.concat([cipher.update(keyToWrap), cipher.final()]);
    const authTag = cipher.getAuthTag();

    return {
      wrappedKey: ciphertext.toString('base64'),
      iv: iv.toString('hex'),
      authTag: authTag.toString('hex'),
      version: this.CURRENT_ENCRYPTION_VERSION,
    };
  }

  /**
   * Unwraps a master vault key using a device-specific wrapping key
   */
  unwrapKey(wrappedPackage: WrappedKeyPackage, wrappingKey: Buffer): Buffer {
    const iv = Buffer.from(wrappedPackage.iv, 'hex');
    const authTag = Buffer.from(wrappedPackage.authTag, 'hex');
    const ciphertext = Buffer.from(wrappedPackage.wrappedKey, 'base64');

    const decipher = crypto.createDecipheriv(this.ALGORITHM, wrappingKey, iv);
    decipher.setAuthTag(authTag);

    try {
      return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
    } catch {
      throw new BadRequestException('Key unwrap failed: invalid wrapping key or corrupted key package');
    }
  }
}
