export interface OcrResult {
  text: string;
  confidence: number;
  provider: string;
  rawMetadata?: Record<string, any>;
}

export interface OcrProvider {
  readonly name: string;
  extractText(filePath: string, mimeType: string): Promise<OcrResult>;
  extractTextFromImage(filePath: string): Promise<OcrResult>;
  extractTextFromPdf(filePath: string): Promise<OcrResult>;
}
