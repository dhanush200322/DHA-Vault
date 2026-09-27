import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
  Res,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { SharingService } from './sharing.service';

@Controller('sharing')
export class SharingController {
  constructor(private readonly sharingService: SharingService) {}

  @Post('create')
  async createShare(
    @CurrentUser('userId') userId: string,
    @Body('documentId') documentId: string,
    @Body('password') password?: string,
    @Body('expiresInHours') expiresInHours?: number,
    @Body('maxUses') maxUses?: number,
    @Body('allowDownload') allowDownload?: boolean,
  ) {
    return this.sharingService.createShareLink(userId, documentId, {
      password,
      expiresInHours,
      maxUses,
      allowDownload,
    });
  }

  @Get('my-shares')
  async getMyShares(
    @CurrentUser('userId') userId: string,
    @Query('documentId') documentId?: string,
  ) {
    return this.sharingService.getMyShares(userId, documentId);
  }

  @Post(':id/revoke')
  @HttpCode(HttpStatus.OK)
  async revokeShare(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.sharingService.revokeShare(userId, id);
  }

  @Public()
  @Post('public/:token')
  @HttpCode(HttpStatus.OK)
  async accessPublicShare(
    @Param('token') token: string,
    @Body('password') password?: string,
    @Req() req?: Request,
  ) {
    const ipAddress = req ? ((req.headers['x-forwarded-for'] as string) || req.ip) : undefined;
    const userAgent = req ? req.headers['user-agent'] : undefined;
    return this.sharingService.accessSharedDocument(token, password, ipAddress, userAgent);
  }

  @Public()
  @Get('public/:token/download')
  async downloadPublicShare(
    @Param('token') token: string,
    @Query('password') password: string,
    @Res() res: Response,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    const { stream, mimeType, fileSize, title } = await this.sharingService.downloadSharedFile(
      token,
      password,
      ipAddress,
      userAgent,
    );

    res.set({
      'Content-Type': mimeType,
      'Content-Length': fileSize,
      'Content-Disposition': `attachment; filename="${encodeURIComponent(title)}"`,
    });

    stream.pipe(res);
  }
}
