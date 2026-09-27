import { Body, Controller, Post } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ScannerService } from './scanner.service';

@Controller('scanner')
export class ScannerController {
  constructor(private readonly scannerService: ScannerService) {}

  @Post('session')
  async startScanSession(
    @CurrentUser('userId') userId: string,
    @Body()
    body: {
      scanType: 'DOCUMENT' | 'CARD' | 'PASSPORT';
      pagesCount: number;
      suggestedTitle?: string;
    },
  ) {
    return this.scannerService.processScanMetadata(userId, body);
  }
}
