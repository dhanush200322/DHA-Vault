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
import { SyncService } from './sync.service';
import { ResolveConflictDto, StartSyncDto } from './dto/sync.dto';

@Controller('sync')
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Get('status')
  async getStatus(@CurrentUser('userId') userId: string) {
    return this.syncService.getStatus(userId);
  }

  @Get('pending')
  async getPending(@CurrentUser('userId') userId: string) {
    return this.syncService.getPending(userId);
  }

  @Get('conflicts')
  async getConflicts(@CurrentUser('userId') userId: string) {
    return this.syncService.getConflicts(userId);
  }

  @Post('start')
  @HttpCode(HttpStatus.OK)
  async startSync(
    @CurrentUser('userId') userId: string,
    @Body() dto: StartSyncDto,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.syncService.startSync(userId, dto, ipAddress, userAgent);
  }

  @Post('resolve-conflict')
  @HttpCode(HttpStatus.OK)
  async resolveConflict(
    @CurrentUser('userId') userId: string,
    @Body() dto: ResolveConflictDto,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.syncService.resolveConflict(userId, dto, ipAddress, userAgent);
  }
}
