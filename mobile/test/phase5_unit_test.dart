import 'package:flutter_test/flutter_test.dart';
import 'package:dha_vault/models/family_vault.dart';
import 'package:dha_vault/models/document_share.dart';
import 'package:dha_vault/models/emergency_access.dart';

void main() {
  group('Phase 5 - Family Vault Models & RBAC Tests', () {
    test('FamilyVaultModel correctly identifies OWNER capabilities', () {
      final json = {
        'id': 'fam-1',
        'name': 'Dhanush Family Vault',
        'ownerId': 'user-1',
        'myRole': 'OWNER',
        'createdAt': '2026-09-27T10:00:00.000Z',
        'updatedAt': '2026-09-27T10:00:00.000Z',
        '_count': {'members': 4, 'documents': 12},
      };

      final family = FamilyVaultModel.fromJson(json);
      expect(family.name, 'Dhanush Family Vault');
      expect(family.isOwner, isTrue);
      expect(family.canManageMembers, isTrue);
      expect(family.canShare, isTrue);
      expect(family.memberCount, 4);
      expect(family.documentCount, 12);
    });

    test('FamilyVaultModel correctly restricts VIEWER capabilities', () {
      final json = {
        'id': 'fam-2',
        'name': 'Extended Family',
        'ownerId': 'user-owner',
        'myRole': 'VIEWER',
        'createdAt': '2026-09-27T10:00:00.000Z',
        'updatedAt': '2026-09-27T10:00:00.000Z',
        '_count': {'members': 2, 'documents': 5},
      };

      final family = FamilyVaultModel.fromJson(json);
      expect(family.isOwner, isFalse);
      expect(family.canManageMembers, isFalse);
      expect(family.canShare, isFalse);
    });

    test('FamilyVaultModel allows MEMBER to share but not manage members', () {
      final json = {
        'id': 'fam-3',
        'name': 'Core Family',
        'ownerId': 'user-owner',
        'myRole': 'MEMBER',
        'createdAt': '2026-09-27T10:00:00.000Z',
        'updatedAt': '2026-09-27T10:00:00.000Z',
      };

      final family = FamilyVaultModel.fromJson(json);
      expect(family.isOwner, isFalse);
      expect(family.canManageMembers, isFalse);
      expect(family.canShare, isTrue);
    });

    test('FamilyMemberModel parses user details and role cleanly', () {
      final json = {
        'id': 'mem-1',
        'userId': 'user-42',
        'role': 'MEMBER',
        'status': 'ACTIVE',
        'joinedAt': '2026-09-27T10:30:00.000Z',
        'user': {
          'email': 'spouse@example.com',
          'profile': {'fullName': 'Spouse Name'},
        },
      };

      final member = FamilyMemberModel.fromJson(json);
      expect(member.userId, 'user-42');
      expect(member.role, 'MEMBER');
      expect(member.status, 'ACTIVE');
      expect(member.email, 'spouse@example.com');
      expect(member.fullName, 'Spouse Name');
    });

    test('FamilyDocumentAccessModel parses permissions and document info', () {
      final json = {
        'id': 'acc-1',
        'documentId': 'doc-101',
        'sharedByUserId': 'user-1',
        'permissions': ['VIEW', 'DOWNLOAD'],
        'sharedAt': '2026-09-27T11:00:00.000Z',
        'sharedBy': {'email': 'owner@example.com'},
        'document': {
          'id': 'doc-101',
          'userId': 'user-1',
          'title': 'Property Deed',
          'documentType': 'PROPERTY',
          'fileType': 'PDF',
          'fileSize': 1048576,
          'mimeType': 'application/pdf',
          'storagePath': 'uploads/doc-101.pdf',
          'createdAt': '2026-09-27T10:00:00.000Z',
          'updatedAt': '2026-09-27T10:00:00.000Z',
        },
      };

      final access = FamilyDocumentAccessModel.fromJson(json);
      expect(access.documentId, 'doc-101');
      expect(access.permissions, containsAll(['VIEW', 'DOWNLOAD']));
      expect(access.sharedByEmail, 'owner@example.com');
      expect(access.document?.title, 'Property Deed');
    });
  });

  group('Phase 5 - Advanced Secure Sharing & E2EE Key Envelope Tests', () {
    test('DocumentShareModel correctly calculates active status and permissions', () {
      final json = {
        'id': 'share-1',
        'documentId': 'doc-202',
        'ownerId': 'user-sender',
        'recipientEmail': 'recipient@example.com',
        'permissions': ['VIEW', 'DOWNLOAD'],
        'status': 'ACTIVE',
        'allowDownload': true,
        'maxViews': 3,
        'viewCount': 1,
        'watermarkText': 'CONFIDENTIAL',
        'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'createdAt': '2026-09-27T12:00:00.000Z',
        'updatedAt': '2026-09-27T12:00:00.000Z',
        'keyEnvelope': {
          'encryptedKey': 'encKeyBytesBase64...',
          'keyIv': 'ivBase64...',
          'keyTag': 'tagBase64...',
        },
        'document': {
          'id': 'doc-202',
          'userId': 'user-sender',
          'title': 'Confidential Tax Return',
          'documentType': 'FINANCIAL',
          'fileType': 'PDF',
          'fileSize': 524288,
          'mimeType': 'application/pdf',
          'storagePath': 'uploads/doc-202.pdf',
          'createdAt': '2026-09-27T10:00:00.000Z',
          'updatedAt': '2026-09-27T10:00:00.000Z',
        },
      };

      final share = DocumentShareModel.fromJson(json);
      expect(share.isActive, isTrue);
      expect(share.isExpired, isFalse);
      expect(share.isRevoked, isFalse);
      expect(share.isMaxViewsReached, isFalse);
      expect(share.documentTitle, 'Confidential Tax Return');
      expect(share.keyEnvelope?['encryptedKey'], 'encKeyBytesBase64...');
      expect(share.watermarkText, 'CONFIDENTIAL');
    });

    test('DocumentShareModel identifies MAX_VIEWS_REACHED condition', () {
      final json = {
        'id': 'share-2',
        'documentId': 'doc-203',
        'ownerId': 'user-sender',
        'recipientEmail': 'recipient@example.com',
        'permissions': ['VIEW'],
        'status': 'MAX_VIEWS_REACHED',
        'maxViews': 2,
        'viewCount': 2,
        'createdAt': '2026-09-27T12:00:00.000Z',
        'updatedAt': '2026-09-27T12:00:00.000Z',
      };

      final share = DocumentShareModel.fromJson(json);
      expect(share.isMaxViewsReached, isTrue);
      expect(share.isActive, isFalse);
    });

    test('DocumentShareModel identifies EXPIRED condition', () {
      final json = {
        'id': 'share-3',
        'documentId': 'doc-204',
        'ownerId': 'user-sender',
        'recipientEmail': 'recipient@example.com',
        'permissions': ['VIEW'],
        'status': 'ACTIVE',
        'expiresAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'createdAt': '2026-09-27T10:00:00.000Z',
        'updatedAt': '2026-09-27T10:00:00.000Z',
      };

      final share = DocumentShareModel.fromJson(json);
      expect(share.isExpired, isTrue);
    });
  });

  group('Phase 5 - Emergency Access & Recovery Delegation Tests', () {
    test('EmergencyAccessModel parses delayed activation and status', () {
      final json = {
        'id': 'emg-1',
        'ownerId': 'user-owner',
        'delegateEmail': 'trusted.friend@example.com',
        'status': 'TRIGGERED',
        'activationDelayHours': 48,
        'triggerRequestedAt': '2026-09-27T12:00:00.000Z',
        'scope': 'EMERGENCY_ONLY',
        'remainingSeconds': 172800,
        'isFullyActivated': false,
        'createdAt': '2026-09-27T10:00:00.000Z',
        'updatedAt': '2026-09-27T12:00:00.000Z',
      };

      final emg = EmergencyAccessModel.fromJson(json);
      expect(emg.delegateEmail, 'trusted.friend@example.com');
      expect(emg.isTriggered, isTrue);
      expect(emg.isCompleted, isFalse);
      expect(emg.activationDelayHours, 48);
      expect(emg.scope, 'EMERGENCY_ONLY');
      expect(emg.remainingSeconds, 172800);
      expect(emg.triggeredAt, isNotNull);
    });

    test('RecoveryDelegationModel parses guardian status and expiration', () {
      final json = {
        'id': 'rec-1',
        'ownerId': 'user-owner',
        'delegateEmail': 'guardian@example.com',
        'status': 'ACCEPTED',
        'expiresAt': '2026-10-27T10:00:00.000Z',
        'createdAt': '2026-09-27T10:00:00.000Z',
        'updatedAt': '2026-09-27T10:30:00.000Z',
      };

      final rec = RecoveryDelegationModel.fromJson(json);
      expect(rec.delegateEmail, 'guardian@example.com');
      expect(rec.status, 'ACCEPTED');
      expect(rec.isAccepted, isTrue);
      expect(rec.isRevoked, isFalse);
      expect(rec.expiresAt, isNotNull);
    });
  });
}
