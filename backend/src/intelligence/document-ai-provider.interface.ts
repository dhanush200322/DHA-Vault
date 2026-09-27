export interface ClassificationResult {
  documentType: string;
  confidence: number;
  suggestedCategory: string;
  suggestedTags: string[];
  summary: string;
}

export interface ExtractionResult {
  classification: ClassificationResult;
  fields: Record<string, any>;
  issueDate?: string | null;
  expiryDate?: string | null;
}

export interface DocumentAiProvider {
  readonly name: string;
  classifyDocument(text: string, fileName?: string): Promise<ClassificationResult>;
  extractFields(documentType: string, text: string): Promise<Record<string, any>>;
  summarizeDocument(documentType: string, fields: Record<string, any>): Promise<string>;
}
