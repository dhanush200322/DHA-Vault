import { Test, TestingModule } from '@nestjs/testing';
import { EncryptionService } from './encryption.service';
import * as crypto from 'crypto';

describe('EncryptionService', () => {
  let service: EncryptionService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [EncryptionService],
    }).compile();

    service = module.get<EncryptionService>(EncryptionService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should generate a 256-bit (32 bytes) key', () => {
    const key = service.generateKey();
    expect(key).toBeInstanceOf(Buffer);
    expect(key.length).toBe(32);
  });

  it('should derive consistent 256-bit key using PBKDF2 with salt', () => {
    const salt = Buffer.from('dha_test_salt_123456');
    const key1 = service.deriveKey('master_passphrase_secure', salt, 1000);
    const key2 = service.deriveKey('master_passphrase_secure', salt, 1000);
    expect(key1.length).toBe(32);
    expect(key1.equals(key2)).toBe(true);

    const key3 = service.deriveKey('different_passphrase_abc', salt, 1000);
    expect(key1.equals(key3)).toBe(false);
  });

  it('should perform AES-256-GCM encryption and decryption roundtrip', () => {
    const key = service.generateKey();
    const originalText = 'DHA Vault Sensitive Identity Document Payload 2026';
    const originalBuffer = Buffer.from(originalText, 'utf-8');

    const encrypted = service.encryptBuffer(originalBuffer, key, 1);
    expect(encrypted.length).toBeGreaterThan(originalBuffer.length);

    const decrypted = service.decryptBuffer(encrypted, key);
    expect(decrypted.version).toBe(1);
    expect(decrypted.plaintext.toString('utf-8')).toBe(originalText);
  });

  it('should fail decryption when ciphertext is tampered with (Auth Tag verification)', () => {
    const key = service.generateKey();
    const originalBuffer = Buffer.from('Integrity Test Payload', 'utf-8');
    const encrypted = service.encryptBuffer(originalBuffer, key, 1);

    // Tamper with the last byte
    encrypted[encrypted.length - 1] ^= 0xff;

    expect(() => service.decryptBuffer(encrypted, key)).toThrow();
  });

  it('should wrap and unwrap a master key using a device wrapping key', () => {
    const masterKey = service.generateKey();
    const wrappingKey = service.generateKey();

    const wrappedPackage = service.wrapKey(masterKey, wrappingKey);
    expect(wrappedPackage.wrappedKey).toBeDefined();
    expect(wrappedPackage.iv).toBeDefined();
    expect(wrappedPackage.authTag).toBeDefined();

    const unwrapped = service.unwrapKey(wrappedPackage, wrappingKey);
    expect(unwrapped.equals(masterKey)).toBe(true);
  });
});
