# DHA Vault — Phase 2 Audit Report

**Date**: 2026-09-27  
**Scope**: Full stack audit of backend API and Flutter mobile client for Phase 2 hardening.

---

## 1. Executive Summary

Phase 1 established a working backend modular monolith on NestJS, PostgreSQL schema via Prisma, and an initial Flutter foundation. However, several components rely on placeholder workflows, incomplete validation, or unlinked screens that must be upgraded for a production-grade digital vault.

---

## 2. Backend Audit Findings

### 2.1 Storage & Document Upload (`backend/src/storage`, `backend/src/documents`)
- **File Signature / Magic Bytes**: Current `LocalStorageService` validates MIME types and file extensions, but does not verify binary magic bytes (e.g., `%PDF-`, PNG header, JPEG markers, WebP RIFF), leaving room for extension spoofing.
- **Directory Hierarchy**: The upload directory uses `uploads/users/{userId}/...` rather than the segregated hierarchy required by Phase 2: `uploads/users/{userId}/documents/{documentId}/`.
- **Thumbnail Generation**: Thumbnails are stored as null unless manually supplied; need a lightweight preview generator or SVG/image thumbnail extractor.
- **Recent Documents**: No dedicated `GET /documents/recent` endpoint exists to query the `DocumentAccessLog` table for recently accessed documents.
- **Stats Breakdown**: `GET /documents/stats/overview` returns total, expiring soon, and storage, but lacks `valid` and `expired` counts.
- **Expiry Filtering**: `QueryDocumentDto` only supports a fixed 30-day window (`isExpiringSoon`), lacking custom day ranges (7, 15, 30 days) and explicit `isExpired` queries.

### 2.2 Sharing Engine (`backend/src/sharing`)
- **Watermark & QR Configuration**: `ShareLink` supports password and expiration, but lacks watermark tracking and explicit view limitation enforcement on raw file streams.
- **Share Public View**: `POST /sharing/public/:token` exists, but public streaming of the file itself must enforce one-time/max-uses decrement and access controls.

### 2.3 Search Engine (`backend/src/search`)
- Basic text matching exists, but does not search tags properly or support compound token matching.

---

## 3. Flutter Mobile Audit Findings

### 3.1 Document Upload Flow (`mobile/lib/features/scanner`, `mobile/lib/features/documents`)
- **Placeholder Upload**: `ScannerScreen` writes a mock `uploads/sample_scan.pdf` path rather than executing a real multipart upload with progress indicator.
- **Missing File Source Bottom Sheet**: `+ Add Document` does not provide the 5 options (Scan Document, Upload PDF, Upload Image, Choose from Files, Choose from Gallery).
- **No Upload Progress**: UI lacks progress percentage during document encryption and upload.

### 3.2 Fast View Engine (`mobile/lib/features/documents`)
- Document cards download no thumbnails; previews rely on icons.
- No in-memory / local disk caching of document previews to eliminate network lag on tap.
- Document viewer for PDFs shows static placeholder rather than multi-page interactive rendering.

### 3.3 Security & Vault Lock (`mobile/lib/features/security`, `mobile/lib/core/storage`)
- **Brute Force Defense**: `VaultUnlockScreen` has no lockout cooldown or exponential backoff after multiple failed attempts.
- **Lifecycle Auto-Lock**: App does not listen to `AppLifecycleState.paused` / `resumed` to enforce 30s, 1m, 5m, 15m auto-lock timeouts.
- **Pattern Lock**: Architecture lacks pattern lock gesture widget and pattern hash verifier.

### 3.4 Search & Debounce (`mobile/lib/features/home`, `mobile/lib/features/documents`)
- Search input triggers immediately on every keystroke without 300ms debounce.

### 3.5 Secure Sharing & QR (`mobile/lib/features/sharing`)
- No modal to configure share parameters (View Only vs View + Download, Password, Expiration, Max views, Watermark).
- No QR code generation for share links.

---

## 4. Phase 2 Action Plan

1. **Backend**:
   - Add magic bytes signature validation in `LocalStorageService`.
   - Update storage path hierarchy to `uploads/users/{userId}/documents/{documentId}/`.
   - Implement `GET /documents/recent` powered by `DocumentAccessLog`.
   - Enhance `GET /documents/stats/overview` with Valid & Expired counts.
   - Add flexible expiry filtering (7, 15, 30 days, expired) to `GET /documents`.
   - Add watermark support to `SharingService`.

2. **Mobile (Flutter)**:
   - Add `file_picker` and `qr_flutter` dependencies.
   - Implement upload options modal with real file selection and progress tracking.
   - Implement Fast View memory cache for instant card & thumbnail display.
   - Implement rate-limiting and lockout delay on PIN entry.
   - Implement AppLifecycle auto-lock observer.
   - Implement Pattern lock option.
   - Implement Secure Share creation dialog with QR code generation.
   - Implement Expiring Documents dedicated view.
   - Debounce search queries.
