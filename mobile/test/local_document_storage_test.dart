import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dha_vault/core/storage/local_document_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDocumentStorage & AES-256-GCM Tests', () {
    late Directory tempDir;
    late LocalDocumentStorage storage;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dha_vault_test_');
      FlutterSecureStorage.setMockInitialValues({});
      storage = LocalDocumentStorage(vaultRootDir: tempDir);
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('calculateChecksum produces standard 64-character SHA-256 hex string', () {
      final sample = Uint8List.fromList('DHA Vault Zero-Cost Security'.codeUnits);
      final checksum = storage.calculateChecksum(sample);
      expect(checksum.length, equals(64));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum), isTrue);
    });

    test('getStoragePath returns virtual path without exposing absolute system path', () async {
      final path = await storage.getStoragePath('doc-uuid-1234');
      expect(path, equals('vault/documents/doc-uuid-1234.enc'));
      expect(path.contains('C:'), isFalse);
      expect(path.contains('/'), isTrue);
    });

    test('saveDocument encrypts with AES-256-GCM and readDocument decrypts exact plaintext', () async {
      const originalText = 'DHA-Vault-Confidential-Medical-Record-Content-2026';
      final plaintext = Uint8List.fromList(originalText.codeUnits);
      const docId = 'test-doc-001';

      // 1. Save document (AES-256-GCM encrypted envelope)
      final relativePath = await storage.saveDocument(
        documentId: docId,
        plaintextBytes: plaintext,
      );
      expect(relativePath, equals('vault/documents/test-doc-001.enc'));

      // 2. Verify file on disk exists and contains versioned envelope
      final fileOnDisk = File('${tempDir.path}/documents/$docId.enc');
      expect(await fileOnDisk.exists(), isTrue);

      final envelopeBytes = await fileOnDisk.readAsBytes();
      // Envelope must have: [1 byte version] + [12 bytes IV] + [16 bytes Tag] + [Ciphertext]
      expect(envelopeBytes.length, greaterThanOrEqualTo(1 + 12 + 16 + plaintext.length));
      expect(envelopeBytes[0], equals(1)); // Version 1

      // Ensure raw disk file does NOT contain plaintext string (military grade encryption verified)
      final rawDiskString = String.fromCharCodes(envelopeBytes);
      expect(rawDiskString.contains(originalText), isFalse);

      // 3. Verify documentExists
      expect(await storage.documentExists(docId), isTrue);

      // 4. Decrypt via readDocument in memory
      final decrypted = await storage.readDocument(docId);
      final decryptedString = String.fromCharCodes(decrypted);
      expect(decryptedString, equals(originalText));

      // 5. Metadata verification
      final meta = await storage.getDocumentMetadata(docId);
      expect(meta['documentId'], equals('test-doc-001'));
      expect(meta['isEncrypted'], equals(true));
      expect(meta['encryptionAlgorithm'], equals('AES-256-GCM'));

      // 6. Delete document
      final deleted = await storage.deleteDocument(docId);
      expect(deleted, isTrue);
      expect(await storage.documentExists(docId), isFalse);
    });
  });
}
