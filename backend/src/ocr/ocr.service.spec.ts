import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { OcrService } from './ocr.service';
import { LocalOcrProvider } from './local-ocr.provider';

describe('OcrService', () => {
  let service: OcrService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OcrService,
        LocalOcrProvider,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string, defaultValue?: any) => {
              if (key === 'OCR_PROVIDER') return 'local';
              return defaultValue;
            }),
          },
        },
      ],
    }).compile();

    service = module.get<OcrService>(OcrService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
    expect(service.getProviderName()).toBe('local');
  });

  it('should safely return empty result if file does not exist without crashing', async () => {
    const result = await service.processFile('non_existent_file.pdf', 'application/pdf');
    expect(result.text).toBe('');
    expect(result.confidence).toBe(0);
    expect(result.provider).toBe('local');
  });
});
