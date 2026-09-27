import { Global, Module } from '@nestjs/common';
import { SecurityController } from './security.controller';
import { SecurityService } from './security.service';
import { EncryptionService } from './encryption.service';

@Global()
@Module({
  controllers: [SecurityController],
  providers: [SecurityService, EncryptionService],
  exports: [SecurityService, EncryptionService],
})
export class SecurityModule {}
