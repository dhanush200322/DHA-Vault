import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { SharesService } from './shares.service';
import { CreateUserShareDto } from './dto/create-user-share.dto';
import { UpdateShareDto } from './dto/update-share.dto';

@Controller('shares')
export class SharesController {
  constructor(private readonly sharesService: SharesService) {}

  @Post('user')
  async createUserShare(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateUserShareDto,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.sharesService.createUserShare(userId, dto, ip, ua);
  }

  @Get('outgoing')
  async getOutgoingShares(@CurrentUser('userId') userId: string) {
    return this.sharesService.getOutgoingShares(userId);
  }

  @Get('incoming')
  async getIncomingShares(@CurrentUser('userId') userId: string) {
    return this.sharesService.getIncomingShares(userId);
  }

  @Get(':shareId')
  async getShare(
    @CurrentUser('userId') userId: string,
    @Param('shareId') shareId: string,
  ) {
    return this.sharesService.getShare(userId, shareId);
  }

  @Post(':shareId/revoke')
  @HttpCode(HttpStatus.OK)
  async revokeShare(
    @CurrentUser('userId') userId: string,
    @Param('shareId') shareId: string,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.sharesService.revokeShare(userId, shareId, ip, ua);
  }

  @Patch(':shareId')
  async updateShare(
    @CurrentUser('userId') userId: string,
    @Param('shareId') shareId: string,
    @Body() dto: UpdateShareDto,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.sharesService.updateShare(userId, shareId, dto, ip, ua);
  }

  @Post(':shareId/open')
  @HttpCode(HttpStatus.OK)
  async openShare(
    @CurrentUser('userId') userId: string,
    @Param('shareId') shareId: string,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.sharesService.openShare(userId, shareId, ip, ua);
  }

  @Post(':shareId/download')
  @HttpCode(HttpStatus.OK)
  async downloadShare(
    @CurrentUser('userId') userId: string,
    @Param('shareId') shareId: string,
    @Res() res: Response,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    const { stream, mimeType, fileSize, title } = await this.sharesService.downloadShare(
      userId,
      shareId,
      ip,
      ua,
    );

    res.set({
      'Content-Type': mimeType,
      'Content-Length': fileSize,
      'Content-Disposition': `attachment; filename="${encodeURIComponent(title)}"`,
    });

    stream.pipe(res);
  }
}
