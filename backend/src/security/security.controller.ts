import { Body, Controller, Get, Patch, Post, Req } from '@nestjs/common';
import { Request } from 'express';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { SecurityService } from './security.service';

@Controller('security')
export class SecurityController {
  constructor(private readonly securityService: SecurityService) {}

  @Get('settings')
  async getSettings(@CurrentUser('userId') userId: string) {
    return this.securityService.getSettings(userId);
  }

  @Patch('settings')
  async updateSettings(
    @CurrentUser('userId') userId: string,
    @Body()
    body: {
      pin?: string;
      isPinEnabled?: boolean;
      isBiometricEnabled?: boolean;
      autoLockSeconds?: number;
    },
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.securityService.updateSettings(userId, body, ipAddress, userAgent);
  }

  @Post('verify-pin')
  async verifyPin(
    @CurrentUser('userId') userId: string,
    @Body('pin') pin: string,
  ) {
    return this.securityService.verifyPin(userId, pin);
  }
}
