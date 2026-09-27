import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LocalOcrProvider } from './local-ocr.provider';
import { OcrProvider, OcrResult } from './ocr-provider.interface';

@Injectable()
export class OcrService {
  private readonly logger = new Logger(OcrService.name);
  private provider: OcrProvider;

  constructor(
    private readonly configService: ConfigService,
    private readonly localOcrProvider: LocalOcrProvider,
  ) {
    const providerName = this.configService.get<string>('OCR_PROVIDER', 'local');
    // Default to privacy-preserving local provider
    this.provider = this.localOcrProvider;
    this.logger.log(`Initialized OCR Service with provider: ${this.provider.name}`);
  }

  setProvider(provider: OcrProvider) {
    this.provider = provider;
    this.logger.log(`OCR Provider switched to: ${provider.name}`);
  }

  getProviderName(): string {
    return this.provider.name;
  }

  async processFile(filePath: string, mimeType: string): Promise<OcrResult> {
    try {
      this.logger.log(`Starting OCR processing for file: ${filePath}`);
      const result = await this.provider.extractText(filePath, mimeType);
      this.logger.log(
        `OCR completed via ${result.provider}. Confidence: ${(result.confidence * 100).toFixed(1)}%`,
      );
      return result;
    } catch (error: any) {
      this.logger.error(`OCR processing failed: ${error.message}`);
      return {
        text: '',
        confidence: 0,
        provider: this.provider.name,
      };
    }
  }
}
