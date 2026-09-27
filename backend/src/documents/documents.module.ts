import { Module } from '@nestjs/common';
import { DocumentsController } from './documents.controller';
import { DocumentsService } from './documents.service';
import { OcrModule } from '../ocr/ocr.module';
import { IntelligenceModule } from '../intelligence/intelligence.module';
import { RemindersModule } from '../reminders/reminders.module';

@Module({
  imports: [OcrModule, IntelligenceModule, RemindersModule],
  controllers: [DocumentsController],
  providers: [DocumentsService],
  exports: [DocumentsService],
})
export class DocumentsModule {}
