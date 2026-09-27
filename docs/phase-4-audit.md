# DHA Vault — Phase 4 Audit Report
### Cloud Sync + Encrypted Backup + Multi-Device Architecture

**Date**: 2026-09-27  
**Scope**: Full-stack audit of Phase 1-3 foundations and architecture for Cloud Sync, Multi-Device, Application-Level Encryption, and Backup/Restore.

---

## 1. Executive Summary

Phases 1 through 3 established a hardened local vault foundation:
- Secure document storage with binary magic byte validation and isolated user subfolders.
- Fast View with in-memory caching and responsive streaming.
- Multi-factor local security (PIN with brute-force rate-limiting, pattern verification, biometrics, background auto-lock).
- AI/OCR local intelligence (document type classification, regex field extraction, proactive expiry reminders).

However, DHA Vault currently operates as a **single-device local vault**. If a user loses their phone or wants to access their documents across multiple devices (e.g. Android phone, tablet, desktop), their documents are trapped on the local filesystem.

Phase 4 introduces **Secure Multi-Device Synchronization and Encrypted Cloud Backup** while upholding the core privacy-first guarantee: **documents must never be uploaded as plaintext to public cloud storage, and storage credentials must never be exposed to clients.**

---

## 2. Current Architecture Audit

### 2.1 Storage Architecture
- **Current Backend Driver**: `LocalStorageService` (`backend/src/storage/local-storage.service.ts`) writes files directly to local disk under `./uploads/users/{userId}/documents/{uuid}`.
- **Provider Interface**: `IStorageService` defines `upload()`, `download()`, `delete()`, and `exists()`.
- **Gaps**:
  - Missing `getMetadata()` and `generateSecureUrl()`.
  - No S3-compatible cloud storage provider (`CloudStorageProvider`) supporting AWS S3, Cloudflare R2, MinIO, or Supabase Storage via `STORAGE_PROVIDER` configuration.
  - Direct local storage paths are tightly coupled to the active server instance.

### 2.2 Device Architecture
- **Prisma Model**: `Device` exists in `schema.prisma` with `userId`, `deviceId`, `deviceName`, `platform`, `pushToken`, `lastActiveAt`, and `isTrusted`.
- **Service & Controller**: `DevicesService` has `findAll()` and `revoke()`.
- **Gaps**:
  - Missing device registration endpoint (`POST /devices/register`), trust toggling (`PATCH /devices/:id/trust`), and remote lock (`POST /devices/:id/remote-lock`).
  - Missing sync tracking (`lastSyncedAt`, `syncStatus`, `isLocked`).
  - No mobile UI in Flutter for viewing trusted devices, revoking devices, or observing multi-device sync status.

### 2.3 Authentication & Session Management
- **Token Model**: JWT access token + refresh tokens hashed in `RefreshToken` table with device association (`deviceId`).
- **Security**: Device revocation correctly invalidates all refresh tokens for that `(userId, deviceId)`.
- **Gaps**:
  - If a device is marked `LOCKED` via remote lock, the JWT authentication middleware or guard does not yet check device lock status to immediately block requests.

### 2.4 Document Versioning & Metadata
- **Prisma Model**: `DocumentVersion` model exists with `id`, `documentId`, `versionNumber`, `fileSize`, `storagePath`, `changeNotes`, `createdById`, `createdAt`.
- **Document Metadata**: Has `title`, `description`, `documentType`, `fileType`, `fileSize`, `mimeType`, `storagePath`, `thumbnailPath`, `extractedText`, `ocrStatus`, `extractedFields`, `issueDate`, `expiryDate`, `isFavorite`, `isArchived`, `isEncrypted`.
- **Gaps**:
  - Missing cryptographic file integrity checksum (`checksum` SHA-256) on `Document` and `DocumentVersion`.
  - Missing `syncStatus` (`SYNCED`, `PENDING_UPLOAD`, `UPLOADING`, `PENDING_DOWNLOAD`, `DOWNLOADING`, `CONFLICT`, `FAILED`), `lastSyncedAt`, and `cloudObjectKey`.
  - Missing encryption metadata (`encryptionVersion` e.g. 1) to support key rotation without breaking existing archives.
  - Missing version history tracking when documents are updated with new binary payloads.

### 2.5 Security & Encryption Model
- **Mobile Hardware Security**: Flutter uses `FlutterSecureStorage` backed by Android Keystore (`encryptedSharedPreferences: true`) and iOS Keychain (`KeychainAccessibility.first_unlock`).
- **Application-Level Encryption Requirement**:
  - Documents must be encrypted before cloud backup using AES-256-GCM.
  - Master Vault Key derived using a standard KDF (PBKDF2 with salt) rather than raw SHA-256 passwords.
  - Privacy-first default: Vault starts in **Local-Only Mode**. Cloud backup requires explicit user opt-in (`Cloud Backup: ON/OFF`).

---

## 3. Phase 4 Architecture Blueprint

```text
                           DHA VAULT
                              │
             ┌────────────────┴────────────────┐
             ▼                                 ▼
      LOCAL VAULT (Fast View)           CLOUD VAULT (Encrypted)
      - Decrypted Local Cache           - AES-256-GCM Encrypted
      - Sub-20ms Rendering              - S3 / R2 / MinIO / Local
      - Offline-First Engine            - Private Bucket / Signed URLs
             │                                 │
             └────────────────┬────────────────┘
                              ▼
                        SYNC ENGINE
               - Sync Queue with Backoff
               - Checksum Hash Verification
               - Conflict Detection (3-way)
               - Versioning (DocumentVersion)
                              │
             ┌────────────────┼────────────────┐
             ▼                ▼                ▼
         PHONE 1           PHONE 2           TABLET
      (Primary Active)   (Multi-Device)    (Remote Lock)
```

---

## 4. Implementation Steps Plan

1. **Additive Prisma Schema Migration**:
   - Update `Document`: add `syncStatus`, `cloudObjectKey`, `checksum`, `lastSyncedAt`, `encryptionVersion`.
   - Update `DocumentVersion`: add `checksum`, `cloudObjectKey`, `encryptionVersion`, `deviceId`.
   - Update `Device`: add `isLocked`, `lastSyncedAt`, `syncStatus`, `appVersion`.
   - Add `SyncConflict` model: `id`, `documentId`, `userId`, `localVersionId`, `remoteVersionId`, `resolvedAt`, `resolution`.
   - Add `CloudBackup` model: `id`, `userId`, `backupStatus`, `totalDocuments`, `totalBytes`, `storageProvider`, `completedAt`.
   - Run safe `npx prisma migrate dev --name add_cloud_sync_backup_multidevice`.

2. **Storage Abstraction Expansion (`backend/src/storage/`)**:
   - Update `IStorageService` to include `upload`, `download`, `delete`, `exists`, `getMetadata`, `generateSecureUrl`.
   - Implement `CloudStorageProvider` supporting S3-compatible APIs (AWS, Cloudflare R2, MinIO, Supabase) and fallback `LocalStorageProvider`.
   - Enforce private object storage (no public bucket URLs).

3. **Encryption & Key Management Architecture (`backend/src/security/` & `mobile/lib/core/`)**:
   - `EncryptionService`: AES-256-GCM authenticated encryption/decryption, PBKDF2 master key derivation, key wrapping.
   - Versioned encryption tags (`v1`) to prepare for future key rotation.

4. **Sync Engine & Conflict Resolution (`backend/src/sync/`)**:
   - `SyncService`: Endpoints for `GET /sync/status`, `POST /sync/start`, `GET /sync/pending`, `POST /sync/resolve-conflict`.
   - 3 conflict resolution options: `KEEP_LOCAL`, `KEEP_REMOTE`, `CREATE_NEW_VERSION`.
   - SHA-256 checksum comparison to avoid redundant binary re-transfers.

5. **Backup & Restore Module (`backend/src/backup/`)**:
   - Endpoints: `GET /backup/status`, `POST /backup/start`, `POST /backup/pause`, `POST /backup/resume`, `GET /backup/storage`, `POST /backup/restore`.
   - Track storage metrics (document storage vs version storage vs backup archives).

6. **Device Management & Remote Lock (`backend/src/devices/`)**:
   - Endpoints: `GET /devices`, `POST /devices/register`, `PATCH /devices/:id/trust`, `POST /devices/:id/revoke`, `POST /devices/:id/remote-lock`.
   - Interceptor / Guard verification to immediately deny locked or revoked devices.

7. **Audit Logging**:
   - Record `DEVICE_REGISTERED`, `DEVICE_REVOKED`, `BACKUP_STARTED`, `BACKUP_COMPLETED`, `BACKUP_FAILED`, `DOCUMENT_SYNCED`, `SYNC_CONFLICT`, `REMOTE_LOCK`, `RESTORE_STARTED`, `RESTORE_COMPLETED`.

8. **Flutter Mobile Enhancements**:
   - `BackupSyncScreen`: Cloud backup toggle, Wi-Fi only, auto-backup, storage meter, restore trigger.
   - `DevicesScreen`: Trusted devices list, device platform icons, sync state pills, revoke and remote lock dialogs.
   - `HomeScreen`: Subtle sync status indicator (`✓ Synced`, `↻ Syncing`, `⚠ Needs attention`, `Offline`).
   - `DocumentDetailsScreen`: Version history list with download/view previous versions.
   - Offline-first cache retention for Fast View.
