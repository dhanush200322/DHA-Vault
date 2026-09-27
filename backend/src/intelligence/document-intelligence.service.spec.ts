import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { DocumentIntelligenceService } from './document-intelligence.service';
import { LocalRuleBasedProvider } from './local-rule-based.provider';
import { GeminiAiProvider } from './gemini-ai.provider';

describe('DocumentIntelligenceService', () => {
  let service: DocumentIntelligenceService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DocumentIntelligenceService,
        LocalRuleBasedProvider,
        GeminiAiProvider,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string, defaultValue?: any) => {
              if (key === 'AI_PROVIDER') return 'local';
              return defaultValue;
            }),
          },
        },
      ],
    }).compile();

    service = module.get<DocumentIntelligenceService>(DocumentIntelligenceService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should accurately classify an Indian Driving Licence and extract fields', async () => {
    const text = `
      UNION OF INDIA DRIVING LICENCE
      TRANSPORT DEPARTMENT KARNATAKA
      DL NO: KA01-20150001234
      NAME: DHANUSH AV
      DOB: 15/08/1995
      VALIDITY NON-TRANSPORT: 18/11/2036
      AUTHORISATION TO DRIVE: MCWG, LMV
    `;

    const result = await service.analyzeDocument(text, 'Driving_Licence.pdf');
    expect(result.classification.documentType).toBe('DRIVING_LICENCE');
    expect(result.classification.confidence).toBeGreaterThanOrEqual(0.85);
    expect(result.classification.suggestedCategory).toBe('Vehicle');
    expect(result.classification.suggestedTags).toContain('#identity');
    expect(result.fields.licenseNumber).toBe('KA01-20150001234');
    expect(result.fields.vehicleClasses).toContain('MCWG');
  });

  it('should classify PAN card accurately using regex and keywords', async () => {
    const text = `
      INCOME TAX DEPARTMENT
      GOVT OF INDIA
      PERMANENT ACCOUNT NUMBER
      ABCDE1234F
      NAME: DHANUSH AV
      FATHER NAME: VENKATESH
      DOB: 15/08/1995
    `;

    const result = await service.analyzeDocument(text, 'pancard.pdf');
    expect(result.classification.documentType).toBe('PAN');
    expect(result.classification.confidence).toBeGreaterThanOrEqual(0.85);
    expect(result.fields.panNumber).toBe('ABCDE1234F');
  });

  it('should classify Passport accurately and extract expiry', async () => {
    const text = `
      PASSPORT
      REPUBLIC OF INDIA
      TYPE P
      PASSPORT NO: Z1234567
      GIVEN NAME: DHANUSH
      SURNAME: AV
      NATIONALITY: INDIAN
      DATE OF ISSUE: 10/05/2017
      DATE OF EXPIRY: 09/05/2027
    `;

    const result = await service.analyzeDocument(text, 'passport_travel.pdf');
    expect(result.classification.documentType).toBe('PASSPORT');
    expect(result.classification.confidence).toBeGreaterThanOrEqual(0.85);
    expect(result.fields.passportNumber).toBe('Z1234567');
  });

  it('should classify Vehicle Insurance policy', async () => {
    const text = `
      CERTIFICATE OF INSURANCE
      POLICY NUMBER: POL-88990011
      INSURED: DHANUSH AV
      PERIOD OF INSURANCE: 12/01/2026 TO 11/01/2027
      SUM INSURED: 500000
    `;

    const result = await service.analyzeDocument(text, 'Car_Insurance.pdf');
    expect(result.classification.documentType).toBe('INSURANCE');
    expect(result.fields.policyNumber).toBe('POL-88990011');
  });
});
