import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { DevicesService } from './devices.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

@Controller('devices')
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  @Get()
  async findAll(@CurrentUser('userId') userId: string) {
    return this.devicesService.findAll(userId);
  }

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  async register(
    @CurrentUser('userId') userId: string,
    @Body() dto: RegisterDeviceDto,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.devicesService.register(userId, dto, ipAddress, userAgent);
  }

  @Patch(':deviceId/trust')
  async setTrust(
    @CurrentUser('userId') userId: string,
    @Param('deviceId') deviceId: string,
    @Body('isTrusted') isTrusted: boolean,
  ) {
    return this.devicesService.setTrust(userId, deviceId, isTrusted ?? true);
  }

  @Post(':deviceId/revoke')
  @HttpCode(HttpStatus.OK)
  async revokePost(
    @CurrentUser('userId') userId: string,
    @Param('deviceId') deviceId: string,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.devicesService.revoke(userId, deviceId, ipAddress, userAgent);
  }

  @Delete(':deviceId')
  async revoke(
    @CurrentUser('userId') userId: string,
    @Param('deviceId') deviceId: string,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.devicesService.revoke(userId, deviceId, ipAddress, userAgent);
  }

  @Post(':deviceId/remote-lock')
  @HttpCode(HttpStatus.OK)
  async remoteLock(
    @CurrentUser('userId') userId: string,
    @Param('deviceId') deviceId: string,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.devicesService.remoteLock(userId, deviceId, ipAddress, userAgent);
  }

  @Get(':deviceId/status')
  async getStatus(
    @CurrentUser('userId') userId: string,
    @Param('deviceId') deviceId: string,
  ) {
    return this.devicesService.checkDeviceStatus(userId, deviceId);
  }
}
