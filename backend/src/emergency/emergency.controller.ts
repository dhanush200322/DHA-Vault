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
import { EmergencyService } from './emergency.service';
import { CreateEmergencyDto } from './dto/create-emergency.dto';

@Controller('emergency-access')
export class EmergencyController {
  constructor(private readonly emergencyService: EmergencyService) {}

  @Post()
  async create(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateEmergencyDto,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.emergencyService.create(userId, dto, ip, ua);
  }

  @Get()
  async findAll(@CurrentUser('userId') userId: string) {
    return this.emergencyService.findAll(userId);
  }

  @Get(':id')
  async findOne(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.emergencyService.findOne(userId, id);
  }

  @Post(':id/activate')
  @HttpCode(HttpStatus.OK)
  async activate(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.emergencyService.activate(userId, id, ip, ua);
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  async cancel(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.emergencyService.cancel(userId, id, ip, ua);
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
    return this.emergencyService.revoke(userId, id, ip, ua);
  }

  @Get(':id/documents')
  async getScopedDocuments(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.emergencyService.getScopedDocuments(userId, id);
  }
}
