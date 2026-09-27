import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  ClassificationResult,
  DocumentAiProvider,
} from './document-ai-provider.interface';
import { LocalRuleBasedProvider } from './local-rule-based.provider';

@Injectable()
export class GeminiAiProvider implements DocumentAiProvider {
  readonly name = 'gemini';
  private readonly logger = new Logger(GeminiAiProvider.name);
  private readonly isConfigured: boolean;

  constructor(
    private readonly configService: ConfigService,
    private readonly localFallback: LocalRuleBasedProvider,
  ) {
    const apiKey = this.configService.get<string>('GEMINI_API_KEY');
    this.isConfigured = Boolean(apiKey && apiKey.length > 5);
  }

  async classifyDocument(text: string, fileName?: string): Promise<ClassificationResult> {
    if (!this.isConfigured) {
      // Privacy-first fallback to local rule-based
      return this.localFallback.classifyDocument(text, fileName);
    }
    // Future expansion hook for cloud AI with user consent
    return this.localFallback.classifyDocument(text, fileName);
  }

  async extractFields(documentType: string, text: string): Promise<Record<string, any>> {
    if (!this.isConfigured) {
      return this.localFallback.extractFields(documentType, text);
    }
    return this.localFallback.extractFields(documentType, text);
  }

  async summarizeDocument(documentType: string, fields: Record<string, any>): Promise<string> {
    return this.localFallback.summarizeDocument(documentType, fields);
  }
}
