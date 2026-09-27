import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { DocumentIntelligenceService } from './document-intelligence.service';
import { LocalRuleBasedProvider } from './local-rule-based.provider';
import { GeminiAiProvider } from './gemini-ai.provider';

@Module({
  imports: [ConfigModule],
  providers: [
    DocumentIntelligenceService,
    LocalRuleBasedProvider,
    GeminiAiProvider,
  ],
  exports: [DocumentIntelligenceService],
})
export class IntelligenceModule {}
