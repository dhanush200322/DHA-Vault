import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';

import { PrismaModule } from './prisma/prisma.module';
import { StorageModule } from './storage/storage.module';
import { AuditModule } from './audit/audit.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { CategoriesModule } from './categories/categories.module';
import { DocumentsModule } from './documents/documents.module';
import { TagsModule } from './tags/tags.module';
import { SharingModule } from './sharing/sharing.module';
import { SecurityModule } from './security/security.module';
import { DevicesModule } from './devices/devices.module';
import { NotificationsModule } from './notifications/notifications.module';
import { ScannerModule } from './scanner/scanner.module';
import { SearchModule } from './search/search.module';
import { OcrModule } from './ocr/ocr.module';
import { IntelligenceModule } from './intelligence/intelligence.module';
import { RemindersModule } from './reminders/reminders.module';
import { SyncModule } from './sync/sync.module';
import { BackupModule } from './backup/backup.module';
import { FamilyModule } from './family/family.module';
import { EmergencyModule } from './emergency/emergency.module';
import { RecoveryModule } from './recovery/recovery.module';
import { MailModule } from './mail/mail.module';

import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60000,
        limit: 120, // 120 requests per minute
      },
    ]),
    PrismaModule,
    StorageModule,
    AuditModule,
    HealthModule,
    AuthModule,
    UsersModule,
    CategoriesModule,
    DocumentsModule,
    TagsModule,
    SharingModule,
    SecurityModule,
    DevicesModule,
    NotificationsModule,
    ScannerModule,
    SearchModule,
    OcrModule,
    IntelligenceModule,
    RemindersModule,
    SyncModule,
    BackupModule,
    FamilyModule,
    EmergencyModule,
    RecoveryModule,
    MailModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
  ],
})
export class AppModule {}
