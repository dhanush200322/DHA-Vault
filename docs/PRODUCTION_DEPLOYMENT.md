# DHA Vault — Production Deployment & Distribution Guide

This document outlines the complete procedure to deploy DHA Vault to live production infrastructure and build the standalone Android Release APK for direct user distribution (no Google Play Store publishing required).

---

## Architecture Overview

```
                      +-----------------------------+
                      |   Android Release APK       |
                      |   (Distributed to users)    |
                      +--------------+--------------+
                                     |
                                     | HTTPS (TLS)
                                     v
                      +-----------------------------+
                      |   Render Web Service        |
                      |   (NestJS API @ 0.0.0.0)    |
                      +-------+-------------+-------+
                              |             |
                 Internal SQL |             | S3 API (Signed URLs)
                              v             v
       +-------------------------+       +-------------------------+
       |   Render PostgreSQL     |       |   Cloudflare R2 Bucket  |
       |   (Managed Database)    |       |   (Private Encrypted)   |
       +-------------------------+       +-------------------------+
                              |
                              +---------> Gmail SMTP (Port 465 SSL)
                              |
                              +---------> Google OAuth Token Verification
```

---

## 1. Render PostgreSQL Setup

### Provisioned Instance Details
- **Service Name:** `dha-vault-postgres`
- **Database Name:** `dha_vault_postgres`
- **Database User:** `dha_vault_postgres_user`
- **Region:** `Oregon (US West)`
- **Render Dashboard:** [dha-vault-postgres Dashboard](https://dashboard.render.com/d/dpg-dathn6m0tbcc73ch2t0g-a)

### Connecting to the Database
In Render, the database provides two connection strings in its Dashboard:
1. **Internal Database URL:** Used by services running inside the same Render account/region (Faster, free internal bandwidth).
   ```text
   postgresql://dha_vault_postgres_user:<PASSWORD>@dpg-dathn6m0tbcc73ch2t0g-a/dha_vault_postgres
   ```
2. **External Database URL:** Used when migrating or running commands from external machines or local terminals:
   ```text
   postgresql://dha_vault_postgres_user:<PASSWORD>@dpg-dathn6m0tbcc73ch2t0g-a-a.oregon-postgres.render.com/dha_vault_postgres?sslmode=require
   ```

### Running Migrations in Production
To apply migrations without resetting or dropping data:
```bash
npx prisma migrate deploy
```
*Note: This command runs automatically on every Render deployment as part of the Service Start Command.*

---

## 2. Render Web Service Setup

### Web Service Configuration
- **Name:** `dha-vault-api`
- **Repository:** `https://github.com/dhanush200322/DHA-Vault.git`
- **Branch:** `main`
- **Runtime:** `Node`
- **Region:** `Oregon` (must match the database region)
- **Plan:** `Free` (or Starter for 24/7 background uptime)
- **Root Directory:** *(leave blank or set to repository root)*
- **Build Command:**
  ```bash
  cd backend && npm install --include=dev && npx prisma generate && npm run build
  ```
- **Start Command:**
  ```bash
  cd backend && npx prisma migrate deploy && node dist/main.js
  ```
- **Health Check Path:** `/health`
- **Auto-Deploy:** `Yes`

---

## 3. Required Environment Variables

Configure the following environment variables in the Render Dashboard (**Web Service -> Environment**):

| Variable | Description | Recommended Production Value |
|---|---|---|
| `NODE_ENV` | Runtime environment | `production` |
| `PORT` | Listening port (Render provides automatically) | `10000` |
| `DATABASE_URL` | Render Internal Database connection string | `<RENDER_DATABASE_URL>` |
| `JWT_SECRET` | Secret key for signing access JWTs (64+ chars) | `<JWT_SECRET>` |
| `JWT_REFRESH_SECRET` | Secret key for signing refresh JWTs (64+ chars) | `<JWT_REFRESH_SECRET>` |
| `JWT_EXPIRATION` | Access token lifespan | `15m` |
| `JWT_REFRESH_EXPIRATION` | Refresh token lifespan | `7d` |
| `STORAGE_DRIVER` | Active storage provider | `s3` |
| `R2_ENDPOINT` | Cloudflare R2 S3 API endpoint URL | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` |
| `R2_ACCESS_KEY_ID` | Cloudflare R2 Access Key ID | `<R2_ACCESS_KEY>` |
| `R2_SECRET_ACCESS_KEY` | Cloudflare R2 Secret Access Key | `<R2_SECRET_KEY>` |
| `R2_BUCKET_NAME` | Name of your private Cloudflare R2 bucket | `dha-vault-production` |
| `R2_REGION` | Cloudflare R2 region | `auto` |
| `SMTP_HOST` | Gmail SMTP server | `smtp.gmail.com` |
| `SMTP_PORT` | Gmail SMTP secure port | `465` |
| `SMTP_SECURE` | Enable SSL/TLS encryption | `true` |
| `SMTP_USER` | Gmail sender address | `your-email@gmail.com` |
| `SMTP_APP_PASSWORD` | 16-character Google App Password | `<SMTP_APP_PASSWORD>` |
| `SMTP_FROM_NAME` | Display name for outbound emails | `DHA Vault` |
| `SMTP_FROM_EMAIL` | Outbound sender email address | `your-email@gmail.com` |
| `GOOGLE_CLIENT_ID` | Production Google Web/Android Client ID | `<GOOGLE_CLIENT_ID>` |
| `APP_URL` | Public frontend/client identifier | `https://dha-vault-api.onrender.com` |

---

## 4. Cloudflare R2 Document Storage Setup

1. Sign in to the [Cloudflare Dashboard](https://dash.cloudflare.com/) and navigate to **R2**.
2. Click **Create bucket**.
   - Bucket name: `dha-vault-production`
   - Location: `Automatic`
3. **Keep Public Access Disabled.** (Do NOT enable custom domains or R2 public dev URL). Documents are securely served only through signed URLs and AES-256 server-side encryption.
4. Go to **Manage R2 API Tokens** -> **Create API Token**.
   - Permissions: **Object Read & Write**
   - Bucket restriction: `dha-vault-production`
5. Copy:
   - Account ID (used to construct `R2_ENDPOINT: https://<ACCOUNT_ID>.r2.cloudflarestorage.com`)
   - Access Key ID -> `R2_ACCESS_KEY_ID`
   - Secret Access Key -> `R2_SECRET_ACCESS_KEY`
6. Add these credentials into your Render Web Service environment variables.

---

## 5. Gmail SMTP Setup

1. Go to your [Google Account Security](https://myaccount.google.com/security).
2. Ensure **2-Step Verification** is turned **ON**.
3. Search for or navigate to **App passwords** (`https://myaccount.google.com/apppasswords`).
4. Create a new App password:
   - Name: `DHA Vault Production`
5. Google will generate a 16-character password (e.g., `xxxx xxxx xxxx xxxx`).
6. Remove any spaces and paste into `SMTP_APP_PASSWORD` on Render.
7. Set `SMTP_USER` and `SMTP_FROM_EMAIL` to your Gmail address.

### Email Lifecycle Validation
- **New Registration:** Sends the DHA Vault Welcome Email upon initial account creation.
- **Existing User Login:** Does NOT send duplicate welcome emails.
- **Security:** SMTP credentials remain exclusively on the server and are never exposed to mobile clients.

---

## 6. Google OAuth Production Setup

1. Open the [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
2. Create or select your DHA Vault project.
3. Under **Credentials**, configure:
   - **Android Client ID:**
     - Package name: `com.dhavault.dha_vault`
     - SHA-1 Fingerprint of your Release Keystore (and debug keystore for development).
   - **Web Client ID:** (Used for server token verification).
     - Save the Web Client ID into `GOOGLE_CLIENT_ID` on Render.
4. **Production Token Verification Flow:**
   - The Flutter mobile client obtains a Google ID Token upon Google Sign-In.
   - The ID token is transmitted securely via HTTPS to `POST /auth/google`.
   - The NestJS backend verifies the token directly against Google's token endpoint (`https://oauth2.googleapis.com/tokeninfo`).
   - The backend validates `aud`, extracts the verified email, and establishes the user session. Unverified client emails are strictly rejected in production.

---

## 7. Android Release Keystore & Signing

### Generating a Production Keystore
Run the following command in PowerShell/Terminal to generate your private signing key:
```bash
keytool -genkey -v -keystore mobile/android/app/dha-vault-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias dhavault
```

### Configuring `key.properties`
Create the file `mobile/android/key.properties` (this file is excluded from Git):
```properties
storePassword=<YOUR_STORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=dhavault
storeFile=dha-vault-release.jks
```

*Note: If `key.properties` is absent, the Gradle build will automatically fall back to the debug keystore, ensuring local builds do not break.*

---

## 8. Building the Android Release APK

Run the release build command pointing to your Render production URL:

```bash
cd mobile

# Standard release build (uses AppConfig.defaultProductionUrl):
flutter build apk --release

# Or explicitly define the production API URL at build time:
flutter build apk --release --dart-define=API_URL=https://dha-vault-api.onrender.com
```

The resulting standalone release APK will be located at:
```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

You can distribute this APK file directly via WhatsApp, Telegram, Google Drive, or your website.

---

## 9. Physical Device Testing Checklist

Before sharing the APK with real users, test the release APK on a physical Android device disconnected from your local Wi-Fi (using 4G/5G mobile data):

- [ ] **Health Endpoint:** Open `https://<YOUR_RENDER_URL>/health` in a mobile browser. Confirm `{ "status": "ok", "service": "DHA Vault API", "database": "connected" }`.
- [ ] **New User Email Registration:** Register a new user with a valid email. Verify the welcome email arrives in inbox.
- [ ] **Existing User Email Login:** Log in with the registered user. Confirm no duplicate welcome email is sent.
- [ ] **Google Sign-In:** Tap "Continue with Google". Confirm account creation, token verification, and welcome email.
- [ ] **Document Upload:** Add a PDF, JPG, and PNG document. Confirm AES-256 encryption and upload to Cloudflare R2.
- [ ] **Fast View & Download:** Open the uploaded documents in Fast View. Confirm fast decryption and viewing.
- [ ] **OCR & Smart Extraction:** Verify text extraction and classification on an uploaded bill or ID.
- [ ] **Native Android Share Sheet:** Share a document via the system share sheet.
- [ ] **Family Vault & Emergency Access:** Create a family group, invite a member, and verify permission controls.
- [ ] **Biometric Unlock:** Lock and unlock the vault using Android Fingerprint/Biometrics.

---

## 10. Rollback & Disaster Recovery Procedure

### Rollback Procedure
If a production issue occurs after deploying new code:
1. In the **Render Dashboard -> dha-vault-api -> Deploys**, find the last known stable deployment.
2. Click the three dots `...` and select **Rollback to this deploy**.
3. Render will immediately restore the previous container build within ~60 seconds.

### Database Backup & Recovery
Render automatically performs daily backups of managed PostgreSQL databases:
1. Navigate to **Render Dashboard -> dha-vault-postgres -> Backups**.
2. To download a snapshot: Click **Download Backup** (`.pgdump`).
3. To restore locally or into a new database:
   ```bash
   pg_restore -d "<DATABASE_URL>" backup.pgdump
   ```

### Storage Resilience
Cloudflare R2 provides 99.999999999% (11 9's) durability. Since documents in DHA Vault are encrypted before transmission using client/server keys, data at rest remains strictly confidential even in worst-case disaster recovery scenarios.
