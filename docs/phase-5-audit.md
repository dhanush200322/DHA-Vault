# DHA Vault — Phase 5 Pre-Implementation Security & Architecture Audit

## 1. Executive Summary
Phase 5 implements **Advanced Secure Sharing + Family Vault + Emergency Access + Recovery Delegation** as an additive extension to the existing DHA Vault platform (Phases 1–4).

This document audits the existing cryptographic, database, authorization, and device trust foundations, and details the non-breaking architecture for Phase 5.

---

## 2. Existing Foundation Analysis (Phases 1–4)

### 2.1 Cryptographic Primitives (`EncryptionService`)
- **Symmetric Cipher:** AES-256-GCM authenticated encryption.
- **Envelope Standard:** `[1 byte version] + [12 bytes IV] + [16 bytes Auth Tag] + [Ciphertext]`.
- **Key Wrapping:** `wrapKey(keyToWrap, wrappingKey)` / `unwrapKey(wrappedPackage, wrappingKey)` using AES-256-GCM.
- **Key Derivation:** PBKDF2-HMAC-SHA256 with 100,000 iterations.
- **Rule for Phase 5:**
  - Never generate or store raw AES keys in plain database columns.
  - Never transmit master vault keys over API responses.
  - In user-to-user sharing, delegate access using per-document encryption keys wrapped in recipient-specific envelopes.
  - The sender's master vault key is never exposed. The recipient unwraps only the delegated document key envelope.

### 2.2 Storage & File Paths
- Uploads and files are stored in `backend/uploads/users/:userId/documents/:documentId/`.
- File streaming and mime type handling are abstracted via `StorageService`.

### 2.3 Existing Sharing Model (`ShareLink`)
- Used for public link-based sharing with token, password hash, max uses, expiry, and access logging.
- **Decision:** Keep `ShareLink` and `/sharing/*` 100% intact to guarantee backward compatibility with Phase 2 test suites.
- Introduce `/shares/*` for authenticated DHA Vault User-to-User sharing and envelope key distribution.

### 2.4 Device Security & Multi-Device Trust (`DevicesService`)
- Phase 4 introduced `Device` model with `isTrusted`, `isLocked`, and remote locking.
- Sensitive sharing operations (revocation, family deletion, master key envelope generation) must verify device trust if a `x-device-id` header is present.

---

## 3. Phase 5 Architecture Design

### 3.1 Family Vault System
```text
Dhanush's Personal Vault (Owner)
        │
        ├── Family Vault ("AV Family")
        │       ├── Members:
        │       │     ├── Owner (Full Admin, Emergency Access, Settings)
        │       │     ├── Member (View/Download/Share permitted docs)
        │       │     └── Viewer (Read-only view of shared docs)
        │       ├── Invitations (SHA-256 token hash, single-use, expiry)
        │       └── Family Document Access (Explicit document sharing)
```

- **FamilyVault:** `id`, `name`, `ownerId`, `status` (`ACTIVE`, `SUSPENDED`, `ARCHIVED`), `settings`, `createdAt`, `updatedAt`.
- **FamilyMembership:** `familyVaultId`, `userId`, `role` (`OWNER`, `MEMBER`, `VIEWER`), `status` (`INVITED`, `ACTIVE`, `SUSPENDED`, `REMOVED`), `joinedAt`.
- **FamilyInvitation:** `familyVaultId`, `email`, `tokenHash` (SHA-256), `role`, `status` (`PENDING`, `ACCEPTED`, `EXPIRED`, `REVOKED`), `expiresAt`, `invitedById`.
- **FamilyDocumentAccess:** `familyVaultId`, `documentId`, `sharedById`, `targetUserId` (null for entire family), `permissions` (JSON `["VIEW", "DOWNLOAD"]`).

### 3.2 Advanced Secure Sharing & User-to-User E2EE
```text
User A (Sender)
   │
   ├── Select Document
   ├── Wrap Document Key with Recipient Envelope (AES-256-GCM)
   └── POST /shares/user ────────► DocumentShare Record Created
                                          │
                                          ▼
                                   User B (Recipient)
                                   ├── Notification received
                                   ├── GET /shares/incoming
                                   ├── POST /shares/:id/open
                                   └── Unwrap key envelope locally to decrypt
```
- Sender vault master key is **NEVER** transmitted or exposed.
- Cloud backend stores only the wrapped key envelope.
- Access can be revoked anytime by the owner (`status = REVOKED`).
- Enforces view limits (`maxViews`) and automatic expiration (`expiresAt`).

### 3.3 Emergency Access & Recovery Delegation
```text
Owner registers Delegate (e.g. spouse/sibling)
   │
   ├── EmergencyAccess record created with Activation Delay (e.g. 48h)
   ├── Delegate accepts
   ├── Dormant status: ACTIVE
   │
   └── In Emergency:
         Delegate calls POST /emergency-access/:id/activate
               │
               ▼
         Status: TRIGGERED
         Waiting Period Countdown starts (e.g., 48 hours)
         Owner receives high-priority notification!
               │
         ├── If Owner cancels (POST /emergency-access/:id/cancel):
         │     Access CANCELLED. Delegate gets nothing.
         │
         └── If countdown completes without cancellation:
               Status becomes COMPLETED.
               Delegate can view ONLY scoped documents (Selected IDs or Categories).
```
- Zero unconstrained account takeover.
- Scoped strictly to explicitly permitted document IDs or categories.
- Immediate owner notification with safety waiting window.

---

## 4. Multi-Tenant Isolation & Zero Trust Guarantees
1. All queries verify authenticated user identity (`@CurrentUser('userId')`).
2. Client-provided `userId`, `ownerId`, or `familyId` in request bodies are NEVER trusted for authorization.
3. Access to family records requires verified active membership in that family.
4. Access to shared documents requires either document ownership or an active, unexpired, non-revoked `DocumentShare` or `FamilyDocumentAccess` grant.
5. Device revocation/locking blocks sensitive vault operations.
