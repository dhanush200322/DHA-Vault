import { Injectable } from '@nestjs/common';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class ScannerService {
  constructor(private readonly storageService: StorageService) {}

  async processScanMetadata(
    userId: string,
    data: {
      scanType: 'DOCUMENT' | 'CARD' | 'PASSPORT';
      pagesCount: number;
      suggestedTitle?: string;
    },
  ) {
    return {
      sessionToken: `scan_${Date.now()}`,
      scanType: data.scanType,
      pagesCount: data.pagesCount,
      suggestedTitle: data.suggestedTitle || `Scanned_${data.scanType}_${new Date().toISOString().slice(0, 10)}`,
      timestamp: new Date().toISOString(),
    };
  }
}
