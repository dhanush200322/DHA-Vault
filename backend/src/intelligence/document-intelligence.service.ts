import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  ClassificationResult,
  DocumentAiProvider,
  ExtractionResult,
} from './document-ai-provider.interface';
import { LocalRuleBasedProvider } from './local-rule-based.provider';
import { GeminiAiProvider } from './gemini-ai.provider';

@Injectable()
export class DocumentIntelligenceService {
  private readonly logger = new Logger(DocumentIntelligenceService.name);
  private provider: DocumentAiProvider;

  constructor(
    private readonly configService: ConfigService,
    private readonly localRuleBasedProvider: LocalRuleBasedProvider,
    private readonly geminiAiProvider: GeminiAiProvider,
  ) {
    const aiProvider = this.configService.get<string>('AI_PROVIDER', 'local');
    if (aiProvider === 'gemini') {
      this.provider = this.geminiAiProvider;
    } else {
      this.provider = this.localRuleBasedProvider;
    }
    this.logger.log(`Initialized Document Intelligence with provider: ${this.provider.name}`);
  }

  setProvider(provider: DocumentAiProvider) {
    this.provider = provider;
    this.logger.log(`Switched Document Intelligence provider to: ${provider.name}`);
  }

  async analyzeDocument(text: string, fileName?: string): Promise<ExtractionResult> {
    try {
      this.logger.log(`Analyzing document intelligence (file: ${fileName || 'unnamed'})`);
      
      // 1. Classification
      const classification = await this.provider.classifyDocument(text, fileName);
      
      // 2. Field extraction
      const fields = await this.provider.extractFields(classification.documentType, text);
      
      // 3. Summarization
      const summary = await this.provider.summarizeDocument(classification.documentType, fields);
      classification.summary = summary;

      // 4. Extract standardized dates
      const { issueDate, expiryDate } = this.parseStandardDates(fields);

      return {
        classification,
        fields,
        issueDate,
        expiryDate,
      };
    } catch (error: any) {
      this.logger.error(`Document intelligence analysis failed: ${error.message}`);
      return {
        classification: {
          documentType: 'OTHER',
          confidence: 0.3,
          suggestedCategory: 'General',
          suggestedTags: ['#vault'],
          summary: 'Vault Document',
        },
        fields: {},
      };
    }
  }

  private parseStandardDates(fields: Record<string, any>): {
    issueDate?: string | null;
    expiryDate?: string | null;
  } {
    let issueDate: string | null = null;
    let expiryDate: string | null = null;

    if (fields.issueDate) {
      issueDate = this.normalizeDateToIso(fields.issueDate);
    }
    if (fields.expiryDate) {
      expiryDate = this.normalizeDateToIso(fields.expiryDate);
    }

    return { issueDate, expiryDate };
  }

  private normalizeDateToIso(dateStr: string): string | null {
    try {
      // Handles DD/MM/YYYY or DD-MM-YYYY
      const parts = dateStr.split(/[./-]/);
      if (parts.length === 3) {
        if (parts[2].length === 4) {
          const day = parseInt(parts[0], 10);
          const month = parseInt(parts[1], 10) - 1;
          const year = parseInt(parts[2], 10);
          const d = new Date(Date.UTC(year, month, day));
          if (!isNaN(d.getTime())) return d.toISOString();
        } else if (parts[0].length === 4) {
          const year = parseInt(parts[0], 10);
          const month = parseInt(parts[1], 10) - 1;
          const day = parseInt(parts[2], 10);
          const d = new Date(Date.UTC(year, month, day));
          if (!isNaN(d.getTime())) return d.toISOString();
        }
      }
      const parsed = new Date(dateStr);
      if (!isNaN(parsed.getTime())) return parsed.toISOString();
    } catch {
      // Ignore format errors
    }
    return null;
  }
}
