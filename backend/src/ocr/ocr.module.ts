import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { OcrService } from './ocr.service';
import { LocalOcrProvider } from './local-ocr.provider';

@Module({
  imports: [ConfigModule],
  providers: [OcrService, LocalOcrProvider],
  exports: [OcrService, LocalOcrProvider],
})
export class OcrModule {}
