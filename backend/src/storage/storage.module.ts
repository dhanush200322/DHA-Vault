import { Global, Module } from '@nestjs/common';
import { StorageService } from './storage.service';
import { LocalStorageService } from './local-storage.service';
import { CloudStorageService } from './cloud-storage.service';

@Global()
@Module({
  providers: [LocalStorageService, CloudStorageService, StorageService],
  exports: [StorageService, LocalStorageService, CloudStorageService],
})
export class StorageModule {}
