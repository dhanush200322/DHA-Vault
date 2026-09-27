import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { RecoveryService } from './recovery.service';
import { CreateRecoveryDto } from './dto/create-recovery.dto';

@Controller('recovery-delegations')
export class RecoveryController {
  constructor(private readonly recoveryService: RecoveryService) {}

  @Post()
  async create(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateRecoveryDto,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.recoveryService.create(userId, dto, ip, ua);
  }

  @Get()
  async findAll(@CurrentUser('userId') userId: string) {
    return this.recoveryService.findAll(userId);
  }

  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  async accept(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.recoveryService.accept(userId, id, ip, ua);
  }

  @Post(':id/revoke')
  @HttpCode(HttpStatus.OK)
  async revoke(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.recoveryService.revoke(userId, id, ip, ua);
  }
}
