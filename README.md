# DHA Vault — Secure Digital Document Locker

> **Your Documents. Secured. Organized. Instantly Accessible.**

DHA Vault is a production-quality, secure digital document locker engineered with a dark-first, banking-grade aesthetic and high-security document management capabilities.

## Architecture Overview

- **Backend**: NestJS (TypeScript, Modular Monolith, JWT + Refresh rotation, Helmet, Rate Limiting, Class-Validator)
- **Database & ORM**: PostgreSQL with Prisma ORM (`dha_vault`)
- **Storage Layer**: Abstract `StorageService` with local encrypted/safe file storage (extensible to S3/MinIO)
- **Mobile**: Flutter (Dart, Riverpod, GoRouter, Biometrics, Secure Storage, Fast Document Viewer)
- **API Testing**: Integrated Postman MCP verification

## Project Structure

```
dha-vault/
├── backend/           # NestJS Modular Monolith API
│   ├── prisma/        # Database schema & migrations
│   ├── src/           # Modules (auth, users, documents, categories, storage, etc.)
│   └── uploads/       # Secure local document storage
├── mobile/            # Flutter cross-platform mobile application
│   └── lib/           # Riverpod state, GoRouter, features & banking UI
├── docs/              # Architecture and API documentation
├── .gitignore
└── README.md
```

## Quick Start

### 1. Backend Setup
```bash
cd backend
npm install
npx prisma generate
npx prisma migrate dev --name init
npm run start:dev
```

### 2. Mobile App Setup
```bash
cd mobile
flutter pub get
flutter run
```
