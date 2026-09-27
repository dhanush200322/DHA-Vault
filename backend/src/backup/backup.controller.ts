import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { BackupService } from './backup.service';
import { RestoreBackupDto } from './dto/backup.dto';

@Controller('backup')
export class BackupController {
  constructor(private readonly backupService: BackupService) {}

  @Get('status')
  async getStatus(@CurrentUser('userId') userId: string) {
    return this.backupService.getStatus(userId);
  }

  @Post('start')
  @HttpCode(HttpStatus.OK)
  async startBackup(@CurrentUser('userId') userId: string, @Req() req: Request) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.backupService.startBackup(userId, ipAddress, userAgent);
  }

  @Post('pause')
  @HttpCode(HttpStatus.OK)
  async pauseBackup(@CurrentUser('userId') userId: string) {
    return this.backupService.pauseBackup(userId);
  }

  @Post('resume')
  @HttpCode(HttpStatus.OK)
  async resumeBackup(@CurrentUser('userId') userId: string, @Req() req: Request) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.backupService.resumeBackup(userId, ipAddress, userAgent);
  }

  @Get('storage')
  async getStorageBreakdown(@CurrentUser('userId') userId: string) {
    return this.backupService.getStorageBreakdown(userId);
  }

  @Post('restore')
  @HttpCode(HttpStatus.OK)
  async restoreVault(
    @CurrentUser('userId') userId: string,
    @Body() dto: RestoreBackupDto,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.backupService.restoreVault(userId, dto, ipAddress, userAgent);
  }
}
