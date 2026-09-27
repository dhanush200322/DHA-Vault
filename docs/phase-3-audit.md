# DHA Vault — Phase 3 Audit Report
### Document Intelligence, OCR, Smart Search, Classification & Reminders

**Date**: 2026-09-27  
**Scope**: Full stack assessment of Phase 2 foundation and roadmap for Phase 3 Intelligence implementation.

---

## 1. Executive Summary

Phase 2 successfully delivered real document upload, binary magic byte verification, user storage isolation, RAM-decrypted Fast View caching, multi-factor vault security (PIN with rate limiting, Biometrics, Auto-lock), and Secure Share link/QR controls.

However, the current vault is strictly a **passive locker**: documents are stored as opaque binary blobs. It does not inspect the contents of documents, detect document types automatically, extract core identification metadata, run smart queries against OCR contents, or dispatch intelligent expiry reminders.

---

## 2. Detailed Audit Findings

### 2.1 OCR & Extraction Infrastructure
- **Backend Model**: `Document.extractedText` exists in `schema.prisma` as an optional string, but no OCR pipeline populates it.
- **Missing OCR Metadata**: The schema lacks status tracking (`ocrStatus`: `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`), provider tracking (`ocrProvider`), confidence scoring (`ocrConfidence`), processed timestamp (`ocrProcessedAt`), and structured key-value extraction (`extractedFields` Json).
- **Scanner Output**: `ScannerScreen` currently generates a valid PDF document with clean metadata, but does not execute client-side or server-side text recognition before saving.
- **Provider Decoupling**: No OCR module or service abstraction exists in `backend/src/`. A modular `OcrModule` with a swappable `OcrProvider` interface is required.

### 2.2 Document Intelligence & Auto-Classification
- **Classification**: Documents are categorized solely by user selection (defaulting to `OTHER` or manual category pick).
- **No Field Extraction**: Key identity attributes (e.g., Aadhaar 12-digit UID, PAN 10-char alphanumeric, Passport MRZ/Number, Driving Licence DL number, Expiry Date, Date of Birth, Holder Name) are not parsed or extracted.
- **No Confirmation Flow**: There is no "Document Intelligence / Detected Information" intermediate screen where users can review, edit, and confirm AI-suggested fields before committing.

### 2.3 Search Capabilities
- **Current Implementation**: `SearchService.globalSearch` queries `title`, `description`, `extractedText`, and `documentType` with basic case-insensitive substring matching.
- **Gaps**: Does not search inside structured extracted fields (e.g. searching a specific PAN or DL number), does not search document tags, and does not support compound structured search filters (e.g., "All passports expiring in 2027", "Expiring vehicle insurance").

### 2.4 Notifications & Expiry Reminders
- **Existing Models**: `Notification` and `DocumentReminder` models exist in Prisma with indices on `[userId, reminderDate]`.
- **Existing Endpoints**: `GET /notifications`, `PATCH /notifications/:id/read`, `POST /notifications/read-all` exist, but no automated reminder dispatch engine schedules or generates reminders at the 90, 30, 15, 7, and 1-day milestones.
- **Mobile Client**: Flutter currently lacks a dedicated Notification Center screen and an unread notification badge indicator in the app bar.

### 2.5 Privacy & Security Safeguards
- **Zero Third-Party Cloud Leaks by Default**: Documents must not be transmitted to external cloud APIs without explicit user consent.
- **Asynchronous Execution**: OCR and intelligence extraction must run asynchronously so Fast View and document uploads remain instantaneous.

---

## 3. Phase 3 Architecture Blueprint

```text
               UPLOAD / SCAN
                     │ (Immediate 201 Response & Fast View Ready)
                     ▼
             BACKGROUND WORKER / ASYNC
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
    OCR SERVICE          REMINDER ENGINE
   (Local Engine)        (90, 30, 15, 7, 1d)
         │                       │
         ▼                       ▼
   TEXT EXTRACTED         NOTIFICATIONS
         │
         ▼
  INTELLIGENCE ENGINE
  (Layered Classifier:
   Keywords + Regex +
   Pattern Matchers)
         │
         ▼
  EXTRACTED FIELDS
  (Name, Number, Dates)
         │
         ▼
  UPDATE METADATA
  (ocrStatus: COMPLETED)
         │
         ▼
  SMART SEARCH & CONFIRMATION
```

---

## 4. Implementation Steps Plan

1. **Prisma Schema Update**:
   - Add `ocrStatus`, `ocrProvider`, `ocrConfidence`, `ocrProcessedAt`, `extractedFields` to `Document`.
   - Run safe `prisma migrate dev --name add_ocr_intelligence_fields` without data loss.
2. **Backend OCR Module (`src/ocr/`)**:
   - `OcrModule`, `OcrService`, and pluggable `OcrProvider` interface with `LocalRuleBasedOcrProvider` (and mock/extensible Tesseract hooks).
3. **Backend Document Intelligence Module (`src/intelligence/`)**:
   - `DocumentIntelligenceService` with layered classification (AADHAAR, PAN, PASSPORT, DRIVING_LICENCE, VEHICLE, INSURANCE, etc.).
   - Regex & structural field extraction (name, documentNumber, issueDate, expiryDate, dob, address, policyNumber).
   - Smart tag generator and short safe document summaries.
4. **Backend Smart Reminder Service (`src/reminders/`)**:
   - `ReminderService` computing 90, 30, 15, 7, and 1-day expiry notices. Idempotent creation to prevent duplicate alerts.
5. **Backend Smart Search Enhancement (`src/search/`)**:
   - Multi-field compound filters (category, documentType, expiry window, tags, extracted text, and structured fields).
6. **Flutter Mobile Intelligence UI**:
   - `DocumentIntelligenceScreen`: displays preview, detected type, confidence badge, editable extracted fields, suggested category and tags.
   - `NotificationCenterScreen`: Today vs Earlier grouped list with status icons, unread badges, and read toggles.
   - Upgrade `HomeScreen`: Vault Health overview, Attention Required expiring list, Notification Bell with live unread badge.
   - Upgrade `ScannerScreen`: multi-step scan with auto-OCR and routing to intelligence confirmation.
7. **Testing & Postman Verification**:
   - Comprehensive test suite covering OCR status, classification, extraction, search, reminder creation, notification read states, and ownership security.
