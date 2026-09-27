# DHA Vault Architecture & Security Model

## Security Principles

1. **Zero-Trust Ownership**: No document or category operation is permitted without resolving authenticated user identity from cryptographic JWT tokens. Client-provided `userId` parameters are strictly rejected.
2. **Refresh Token Rotation**: Refresh tokens are cryptographically hashed and rotated on every exchange to mitigate replay attacks.
3. **Decoupled Binary Storage**: Metadata and audit trails reside in PostgreSQL; large document binaries and thumbnails reside in a segregated storage layer handled via an abstract `StorageService`.
4. **Fast View Engine**: List and detail views serve lightweight metadata and optimized thumbnails. Document downloads and decrypt-on-the-fly streams occur only on demand.
5. **Comprehensive Audit Trail**: Security actions, access patterns, and sharing activities are immutably logged. Sensitive credentials and file binaries are excluded from audit logs.
