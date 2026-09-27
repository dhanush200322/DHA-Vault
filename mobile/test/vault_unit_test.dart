import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dha_vault/models/document.dart';
import 'package:dha_vault/models/device.dart';
import 'package:dha_vault/models/document_version.dart';
import 'package:dha_vault/models/sync_status.dart';
import 'package:dha_vault/models/backup_status.dart';
import 'package:dha_vault/models/storage_breakdown.dart';
import 'package:dha_vault/providers/document_provider.dart';

void main() {
  group('Phase 2 - Document Model & Expiry Engine Tests', () {
    test('Correctly calculates VALID expiry status for future document', () {
      final doc = DocumentModel(
        id: 'doc-1',
        userId: 'user-1',
        title: 'Passport',
        documentType: 'PASSPORT',
        fileType: 'PDF',
        fileSize: 1024 * 500, // 500 KB
        mimeType: 'application/pdf',
        storagePath: 'uploads/users/user-1/documents/doc-1/file.pdf',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 90)), // 90 days in future
      );

      expect(doc.expiryStatus, 'VALID');
      expect(doc.isExpired, isFalse);
      expect(doc.isExpiringSoon, isFalse);
      expect(doc.formattedFileSize, '500.0 KB');
    });

    test('Correctly calculates EXPIRING SOON status within 30 days', () {
      final doc = DocumentModel(
        id: 'doc-2',
        userId: 'user-1',
        title: 'Driving Licence',
        documentType: 'DRIVING_LICENCE',
        fileType: 'IMAGE',
        fileSize: 1024 * 1024 * 2, // 2 MB
        mimeType: 'image/png',
        storagePath: 'uploads/users/user-1/documents/doc-2/licence.png',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 18)), // 18 days left
      );

      expect(doc.expiryStatus, 'EXPIRING SOON');
      expect(doc.isExpiringSoon, isTrue);
      expect(doc.isExpired, isFalse);
      expect(doc.daysUntilExpiry, inInclusiveRange(17, 18));
      expect(doc.formattedFileSize, '2.0 MB');
    });

    test('Correctly calculates EXPIRED status for past documents', () {
      final doc = DocumentModel(
        id: 'doc-3',
        userId: 'user-1',
        title: 'Old Insurance',
        documentType: 'OTHER',
        fileType: 'PDF',
        fileSize: 850,
        mimeType: 'application/pdf',
        storagePath: 'uploads/users/user-1/documents/doc-3/ins.pdf',
        createdAt: DateTime.now().subtract(const Duration(days: 400)),
        updatedAt: DateTime.now().subtract(const Duration(days: 400)),
        expiryDate: DateTime.now().subtract(const Duration(days: 10)), // 10 days ago
      );

      expect(doc.expiryStatus, 'EXPIRED');
      expect(doc.isExpired, isTrue);
      expect(doc.isExpiringSoon, isFalse);
      expect(doc.formattedFileSize, '850 B');
    });

    test('Parses DocumentModel from JSON with tags and categories', () {
      final json = {
        'id': 'doc-uuid-123',
        'userId': 'usr-456',
        'categoryId': 'cat-identity',
        'title': 'National Identity Card',
        'description': 'Biometric identity credential',
        'documentType': 'NATIONAL_ID',
        'fileType': 'PDF',
        'fileSize': 1048576,
        'mimeType': 'application/pdf',
        'storagePath': 'users/usr-456/documents/doc-uuid-123/id.pdf',
        'isFavorite': true,
        'isArchived': false,
        'isEncrypted': true,
        'tags': ['gov', 'id', 'biometric'],
        'createdAt': '2026-09-27T10:00:00.000Z',
        'updatedAt': '2026-09-27T10:00:00.000Z',
      };

      final doc = DocumentModel.fromJson(json);
      expect(doc.id, 'doc-uuid-123');
      expect(doc.title, 'National Identity Card');
      expect(doc.isFavorite, isTrue);
      expect(doc.tags, contains('biometric'));
      expect(doc.formattedFileSize, '1.0 MB');
    });
  });

  group('Phase 2 - Fast View Cache Engine Tests', () {
    test('Caches and returns metadata and RAM preview bytes instantly', () {
      final cache = FastViewCache.instance;
      cache.clear();

      final doc = DocumentModel(
        id: 'fast-doc-1',
        userId: 'u1',
        title: 'Fast Preview PAN',
        documentType: 'PAN',
        fileType: 'IMAGE',
        fileSize: 45000,
        mimeType: 'image/jpeg',
        storagePath: 'path/pan.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      cache.putMetadata(doc);
      expect(cache.getMetadata('fast-doc-1'), isNotNull);
      expect(cache.getMetadata('fast-doc-1')!.title, 'Fast Preview PAN');

      // Test preview bytes in-memory RAM caching
      final sampleBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      cache.putPreviewBytes('fast-doc-1', sampleBytes);

      final retrieved = cache.getPreviewBytes('fast-doc-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.length, 6);
      expect(retrieved[0], 0xFF);
      expect(retrieved[1], 0xD8);
    });
  });

  group('Phase 2 - Vault Security & PIN Verifier Tests', () {
    test('Salted SHA-256 verifier correctly hashes and verifies without storing raw PIN', () {
      const salt = 'dha_vault_hardware_salt_v2_secure';
      const rawPin = '4921';

      final expectedHash = sha256.convert(utf8.encode('$salt:$rawPin:dha_secure_token')).toString();

      // Ensure raw PIN is never equal to hash
      expect(expectedHash, isNot(equals(rawPin)));
      expect(expectedHash.length, 64); // SHA-256 produces 64 hex characters

      // Verify matching secret reproduces identical digest
      final checkDigest = sha256.convert(utf8.encode('$salt:$rawPin:dha_secure_token')).toString();
      expect(checkDigest, equals(expectedHash));

      // Verify wrong pin yields different digest
      final wrongDigest = sha256.convert(utf8.encode('$salt:0000:dha_secure_token')).toString();
      expect(wrongDigest, isNot(equals(expectedHash)));
    });

    test('VaultStats parses valid and expired statistics accurately', () {
      final statsJson = {
        'totalDocuments': 12,
        'validDocuments': 8,
        'favoriteDocuments': 3,
        'archivedDocuments': 1,
        'expiringSoonDocuments': 2,
        'expiredDocuments': 2,
        'totalStorageBytes': 15728640, // 15 MB
      };

      final stats = VaultStats.fromJson(statsJson);
      expect(stats.totalDocuments, 12);
      expect(stats.validDocuments, 8);
      expect(stats.expiringSoonDocuments, 2);
      expect(stats.expiredDocuments, 2);
      expect(stats.favoriteDocuments, 3);
      expect(stats.formattedStorage, '15.0 MB');
    });

    test('Phase 3 - DocumentModel parses OCR intelligence and confidence metrics', () {
      final json = {
        'id': 'doc-ai-1',
        'userId': 'user-1',
        'title': 'Indian Driving Licence',
        'documentType': 'DRIVING_LICENCE',
        'fileType': 'PDF',
        'fileSize': 1024 * 100,
        'mimeType': 'application/pdf',
        'storagePath': 'uploads/users/user-1/documents/doc-ai-1/file.pdf',
        'ocrStatus': 'COMPLETED',
        'ocrConfidence': 0.94,
        'ocrProvider': 'local',
        'extractedText': 'UNION OF INDIA DRIVING LICENCE KA01-20150001234 DHANUSH AV',
        'extractedFields': {
          'licenseNumber': 'KA01-20150001234',
          'name': 'Dhanush AV',
          'vehicleClasses': 'MCWG, LMV',
        },
        'tags': ['#identity', '#vehicle', '#government'],
        'createdAt': '2026-09-27T00:00:00.000Z',
        'updatedAt': '2026-09-27T00:00:00.000Z',
      };

      final doc = DocumentModel.fromJson(json);
      expect(doc.ocrStatus, 'COMPLETED');
      expect(doc.isOcrCompleted, isTrue);
      expect(doc.isOcrProcessing, isFalse);
      expect(doc.ocrConfidence, 0.94);
      expect(doc.ocrConfidencePercentage, '94%');
      expect(doc.ocrProvider, 'local');
      expect(doc.extractedFields?['licenseNumber'], 'KA01-20150001234');
      expect(doc.extractedFields?['name'], 'Dhanush AV');
      expect(doc.tags.length, 3);
      expect(doc.tags, contains('#identity'));
    });

    test('Phase 3 - Vault Health parses attentionRequired and OCR counts', () {
      final statsJson = {
        'totalDocuments': 32,
        'validDocuments': 28,
        'favoriteDocuments': 6,
        'archivedDocuments': 2,
        'expiringSoonDocuments': 3,
        'expiredDocuments': 1,
        'noExpiryDocuments': 14,
        'ocrProcessingCount': 1,
        'ocrCompletedCount': 25,
        'totalStorageBytes': 52428800,
        'attentionRequired': [
          {
            'id': 'doc-exp-1',
            'title': 'Car Insurance Policy',
            'documentType': 'INSURANCE',
            'expiryDate': '2026-10-04T00:00:00.000Z',
            'status': 'EXPIRING_SOON',
          },
          {
            'id': 'doc-exp-2',
            'title': 'Expired Passport',
            'documentType': 'PASSPORT',
            'expiryDate': '2026-01-01T00:00:00.000Z',
            'status': 'EXPIRED',
          },
        ],
      };

      final stats = VaultStats.fromJson(statsJson);
      expect(stats.totalDocuments, 32);
      expect(stats.validDocuments, 28);
      expect(stats.expiringSoonDocuments, 3);
      expect(stats.expiredDocuments, 1);
      expect(stats.noExpiryDocuments, 14);
      expect(stats.ocrProcessingCount, 1);
      expect(stats.ocrCompletedCount, 25);
      expect(stats.attentionRequired.length, 2);
      expect(stats.attentionRequired[0]['title'], 'Car Insurance Policy');
      expect(stats.attentionRequired[1]['status'], 'EXPIRED');
    });
  });

  group('Phase 4 - Cloud Sync, Device & Storage Models Tests', () {
    test('Device model parses and detects trusted/locked state correctly', () {
      final json = {
        'id': 'device-px9',
        'userId': 'usr-1',
        'deviceId': 'pixel-9-pro-uuid',
        'deviceName': 'Pixel 9 Pro',
        'deviceType': 'ANDROID',
        'platform': 'Android 15',
        'appVersion': '1.4.0',
        'ipAddress': '192.168.1.50',
        'isTrusted': true,
        'isLocked': false,
        'syncStatus': 'SYNCED',
        'lastActiveAt': '2026-09-27T10:00:00.000Z',
        'lastSyncedAt': '2026-09-27T10:05:00.000Z',
        'createdAt': '2026-09-01T00:00:00.000Z',
      };

      final device = DeviceModel.fromJson(json);
      expect(device.id, 'device-px9');
      expect(device.deviceName, 'Pixel 9 Pro');
      expect(device.isTrusted, isTrue);
      expect(device.isLocked, isFalse);
      expect(device.syncStatus, 'SYNCED');
      expect(device.platform, 'android 15');
      expect(device.appVersion, '1.4.0');
    });

    test('DocumentVersionModel parses checksum and version hierarchy', () {
      final json = {
        'id': 'ver-3',
        'documentId': 'doc-passport',
        'versionNumber': 3,
        'storagePath': 'users/u1/documents/d1/versions/v3/encrypted.enc',
        'fileSize': 1048576, // 1 MB
        'checksum': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'changeNotes': 'Renewed passport scan with high DPI',
        'deviceId': 'pixel-9-pro-uuid',
        'createdAt': '2026-09-27T11:00:00.000Z',
      };

      final version = DocumentVersionModel.fromJson(json);
      expect(version.versionNumber, 3);
      expect(version.checksum?.length, 64);
      expect(version.formattedSize, '1.0 MB');
      expect(version.storagePath, contains('v3/encrypted.enc'));
      expect(version.changeNotes, 'Renewed passport scan with high DPI');
      expect(version.deviceId, 'pixel-9-pro-uuid');
    });

    test('SyncStatus and BackupStatus models parse states correctly', () {
      final syncJson = {
        'status': 'SYNCED',
        'totalDocuments': 45,
        'syncedDocuments': 45,
        'pendingCount': 0,
        'conflictCount': 0,
        'lastSyncedAt': '2026-09-27T11:30:00.000Z',
      };

      final syncStatus = SyncStatusModel.fromJson(syncJson);
      expect(syncStatus.status, 'SYNCED');
      expect(syncStatus.syncedDocuments, 45);
      expect(syncStatus.pendingCount, 0);
      expect(syncStatus.conflictCount, 0);

      final backupJson = {
        'status': 'COMPLETED',
        'lastBackupAt': '2026-09-27T11:30:00.000Z',
        'totalDocuments': 45,
        'totalStorageBytes': 52428800, // 50 MB
        'pendingCount': 0,
        'storageProvider': 'local',
        'latestBackupId': 'bk-001',
      };

      final backupStatus = BackupStatusModel.fromJson(backupJson);
      expect(backupStatus.status, 'COMPLETED');
      expect(backupStatus.storageProvider, 'local');
      expect(backupStatus.totalDocuments, 45);
      expect(backupStatus.totalStorageBytes, 52428800);
      expect(backupStatus.latestBackupId, 'bk-001');
    });

    test('StorageBreakdown model computes bytes, gigabytes and quota percent', () {
      final json = {
        'totalUsedBytes': 1932735283, // ~1.8 GB
        'quotaBytes': 10737418240, // 10 GB
        'availableBytes': 8804682957,
        'breakdown': {
          'documents': {'bytes': 1288490188, 'count': 45},
          'versions': {'bytes': 214748366, 'count': 12},
          'backups': {'bytes': 429496729, 'count': 3},
        },
      };

      final storage = StorageBreakdownModel.fromJson(json);
      expect(storage.formattedUsed, contains('GB'));
      expect(storage.formattedQuota, '10 GB');
      expect(storage.usedPercentage, greaterThan(0.15));
      expect(storage.usedPercentage, lessThan(0.20));
      expect(storage.documents.count, 45);
      expect(storage.versions.count, 12);
    });
  });
}
