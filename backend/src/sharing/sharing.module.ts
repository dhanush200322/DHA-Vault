import { Module } from '@nestjs/common';
import { SharingController } from './sharing.controller';
import { SharingService } from './sharing.service';
import { SharesController } from './shares.controller';
import { SharesService } from './shares.service';
import { StorageModule } from '../storage/storage.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AuditModule } from '../audit/audit.module';
import { SecurityModule } from '../security/security.module';

@Module({
  imports: [StorageModule, NotificationsModule, AuditModule, SecurityModule],
  controllers: [SharingController, SharesController],
  providers: [SharingService, SharesService],
  exports: [SharingService, SharesService],
})
export class SharingModule {}
