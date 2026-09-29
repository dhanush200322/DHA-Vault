# DHA Vault — Zero-Cost Production Readiness Report

**Date:** September 29, 2026  
**Architecture:** Zero-Cost Local-First Mode (₹0 Total Cost)  
**Backend Host:** Render Web Service (`https://dha-vault-api.onrender.com`)  
**Database:** Render Managed PostgreSQL (Phase 1–5 Migrations Live)  
**Document Storage:** Zero-Cost AES-256-GCM Encrypted Local Device Storage (`LocalDocumentStorage`)  
**Release Artifact:** `mobile/build/app/outputs/flutter-apk/app-release.apk` (79.5 MB)  
**Signing Keystore:** Permanent Release Keystore (`mobile/android/app/dha-vault-release.jks`, alias `dhavault`, valid through 2054)

---

## 1. Executive Overview

DHA Vault has been successfully transitioned to a **Zero-Cost Production Architecture**, fulfilling 100% of production-grade security, authentication, and document locker features with **₹0 recurring or cloud storage fees**:

1. **Backend & Database (Render)**:
   - Public HTTPS API running on Render (`https://dha-vault-api.onrender.com`) with `NODE_ENV=production`.
   - Connected to Render Managed PostgreSQL with all 4 schema migrations deployed cleanly.
   - Public health check: `GET /health` (`status: ok`, `database: connected`).
   - Storage mode endpoint: `GET /health/storage` (`storageMode: Local / Zero-Cost`, `cloudBackup: disabled`).
   - 20/20 Jest backend tests passing.

2. **Zero-Cost Local Document Storage**:
   - Zero dependency on paid cloud storage providers (Cloudflare R2, AWS S3, Google Cloud Storage).
   - Documents are encrypted client-side using **AES-256-GCM** (12-byte random IV, 16-byte authentication tag, versioned binary envelope `0x01` + IV + MAC + ciphertext).
   - Stored in application-sandboxed directories: `vault/documents/`, `thumbnails/`, `cache/`, `backups/`.
   - Instant Fast View with 0ms network latency.

3. **Android Release Distribution**:
   - Permanent release keystore generated: `mobile/android/app/dha-vault-release.jks`.
   - Release APK compiled and verified: `mobile/build/app/outputs/flutter-apk/app-release.apk` (79.5 MB).
   - Signed with APK Signature Scheme v2 (valid until 2054).
   - 31/31 Flutter tests passing; `flutter analyze` reports 0 issues.

---

## 2. Cryptographic & Signing Specifications

| Parameter | Value |
| :--- | :--- |
| **Package Name / Application ID** | `com.dhavault.dha_vault` |
| **Keystore File** | `mobile/android/app/dha-vault-release.jks` |
| **Key Alias** | `dhavault` |
| **Signature Scheme** | APK Signature Scheme v2 |
| **SHA-1 Fingerprint** | `C3:8D:B3:A8:A6:8E:BC:D9:73:50:8C:0B:AD:70:55:41:E1:46:9C:0E` |
| **SHA-256 Fingerprint** | `EC:A7:A1:A5:15:22:84:7D:EF:4E:89:C0:75:2E:EF:C9:B6:B7:D9:48:1A:A5:04:91:91:B3:E3:B2:78:86:26:CC` |
| **Keystore Expiry** | Valid for 10,000 days (Year 2054) |

---

## 3. Google Cloud Console OAuth 2.0 Configuration

To allow all Google accounts to seamlessly authenticate through the release APK and live Render backend, the Google Auth Platform configuration is structured as follows:

### A. Audience (Consent Screen)
* **User Type**: External
* **Publishing Status**: `In production` (Allows any user with a Google account to sign in without pre-registration).

### B. Branding
* **App Name**: `DHA Vault`
* **Authorized Domain**: `onrender.com`
* **Developer Contact**: `ro224313@gmail.com`

### C. OAuth 2.0 Client Credentials

#### 1. Web Application Client (`DHA Vault Web & Backend`)
* **Client ID**: `1006905295094-e4bprelr8fs40sf09njvde74hejc5vbe.apps.googleusercontent.com`
* **Authorized JavaScript Origins**:
  * `https://dha-vault-api.onrender.com`
  * `http://localhost:4000` *(optional development fallback)*
* **Authorized Redirect URIs**:
  * `https://dha-vault-api.onrender.com/auth/google/callback`
  * `https://dha-vault-api.onrender.com`

#### 2. Android Client (`Android client 1`)
* **Client ID**: `1006905295094-7k5kvhemvostmhtli0r076p5hmqmvdeu.apps.googleusercontent.com`
* **Package Name**: `com.dhavault.dha_vault`
* **SHA-1 Fingerprint**: `C3:8D:B3:A8:A6:8E:BC:D9:73:50:8C:0B:AD:70:55:41:E1:46:9C:0E`
* **SHA-256 Fingerprint**: `EC:A7:A1:A5:15:22:84:7D:EF:4E:89:C0:75:2E:EF:C9:B6:B7:D9:48:1A:A5:04:91:91:B3:E3:B2:78:86:26:CC`

---

## 4. Email Notification Service (Gmail SMTP)

* **Host**: `smtp.gmail.com:465` (SSL)
* **Sender**: `DHA Vault <ro224313@gmail.com>`
* **Welcome Email Trigger**: Dispatches automatically to new users registering via password or first-time Google OAuth sign-in.
* **Deduplication**: `Notification` model with type `WELCOME_EMAIL` prevents duplicate welcome emails on repeat logins.

---

## 5. Storage Architecture Comparison

| Feature | Standard Cloud Mode | DHA Vault Zero-Cost Mode |
| :--- | :--- | :--- |
| **Monthly Cost** | ₹500 – ₹2,500+ / mo | **₹0.00 / mo** |
| **Cloud Storage Account Required** | AWS S3 / Cloudflare R2 | **None** |
| **Document Encryption** | Client-side AES-256-GCM | **Client-side AES-256-GCM** |
| **Document Storage Location** | Remote S3 Bucket | **Encrypted local sandboxed storage** |
| **Document Access Latency** | 200ms – 1,500ms (Network download) | **< 10ms (Instant Fast View)** |
| **Offline Viewing** | Requires explicit caching | **Always available offline** |
| **Backend API & Database** | Render Web + Postgres | **Render Web + Postgres** |
| **Authentication & Biometrics** | JWT + Google OAuth + Biometric | **JWT + Google OAuth + Biometric** |

---

## 6. Verification & Test Evidence

* **Backend Unit & Integration Tests**: 5 test suites, 20/20 passed (`npm test`).
* **Frontend Unit & Widget Tests**: 31/31 passed (`flutter test`).
* **Static Analysis**: 0 warnings or errors (`flutter analyze`).
* **Production Health Checks**:
  * `GET https://dha-vault-api.onrender.com/health` $\rightarrow$ `HTTP 200 OK`
  * `GET https://dha-vault-api.onrender.com/health/storage` $\rightarrow$ `HTTP 200 OK`
* **Device Installation**: APK verified and installed on physical device `10BDCM0JK0000LY` (Android 15).
