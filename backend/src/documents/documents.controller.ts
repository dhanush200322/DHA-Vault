import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  Req,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { StorageService } from '../storage/storage.service';
import { DocumentsService } from './documents.service';
import { CreateDocumentDto } from './dto/create-document.dto';
import { UpdateDocumentDto } from './dto/update-document.dto';
import { QueryDocumentDto } from './dto/query-document.dto';
import { CreateVersionDto } from './dto/create-version.dto';
import { AuditService, AuditAction } from '../audit/audit.service';

@Controller('documents')
export class DocumentsController {
  constructor(
    private readonly documentsService: DocumentsService,
    private readonly storageService: StorageService,
    private readonly auditService: AuditService,
  ) {}

  @Get('stats/overview')
  async getStats(@CurrentUser('userId') userId: string) {
    return this.documentsService.getStats(userId);
  }

  @Get('recent')
  async getRecent(
    @CurrentUser('userId') userId: string,
    @Query('limit') limit?: number,
  ) {
    return this.documentsService.getRecentlyViewed(userId, limit ? Number(limit) : 5);
  }

  @Get()
  async findAll(
    @CurrentUser('userId') userId: string,
    @Query() query: QueryDocumentDto,
  ) {
    return this.documentsService.findAll(userId, query);
  }

  @Post('upload')
  @HttpCode(HttpStatus.OK)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB max
    }),
  )
  async uploadFile(
    @CurrentUser('userId') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded or invalid form field name (expected "file")');
    }

    const docSubfolderId = uuidv4();
    const stored = await this.storageService.upload({
      buffer: file.buffer,
      originalFileName: file.originalname,
      mimeType: file.mimetype,
      subFolder: `users/${userId}/documents/${docSubfolderId}`,
    });

    return {
      storagePath: stored.storagePath,
      fileName: stored.fileName,
      originalFileName: stored.originalFileName,
      fileSize: stored.fileSize,
      mimeType: stored.mimeType,
      fileType: stored.mimeType.includes('pdf') ? 'PDF' : 'IMAGE',
      checksum: stored.checksum,
    };
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateDocumentDto,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.documentsService.create(userId, dto, ipAddress, userAgent);
  }

  @Get(':id')
  async findOne(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.documentsService.findOne(userId, id, ipAddress, userAgent);
  }

  @Get(':id/download')
  async download(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Res() res: Response,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    const document = await this.documentsService.findOne(userId, id, ipAddress, userAgent);

    const { stream, mimeType, fileSize } = await this.storageService.download(document.storagePath);

    await this.auditService.log({
      userId,
      action: AuditAction.DOCUMENT_DOWNLOAD,
      documentId: id,
      ipAddress,
      userAgent,
      metadata: { title: document.title },
    });

    res.set({
      'Content-Type': mimeType,
      'Content-Length': fileSize,
      'Content-Disposition': `inline; filename="${encodeURIComponent(document.title)}"`,
    });

    stream.pipe(res);
  }

  @Get(':id/preview')
  async preview(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Res() res: Response,
  ) {
    const document = await this.documentsService.findOne(userId, id);
    const targetPath = document.thumbnailPath || document.storagePath;

    const { stream, mimeType, fileSize } = await this.storageService.download(targetPath);

    res.set({
      'Content-Type': mimeType,
      'Content-Length': fileSize,
      'Cache-Control': 'public, max-age=3600',
    });

    stream.pipe(res);
  }

  @Patch(':id')
  async update(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateDocumentDto,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.documentsService.update(userId, id, dto, ipAddress, userAgent);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  async delete(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.documentsService.delete(userId, id, ipAddress, userAgent);
  }

  @Post(':id/favorite')
  @HttpCode(HttpStatus.OK)
  async toggleFavorite(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.documentsService.toggleFavorite(userId, id);
  }

  @Post(':id/archive')
  @HttpCode(HttpStatus.OK)
  async toggleArchive(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.documentsService.toggleArchive(userId, id);
  }

  @Post(':id/ocr')
  @HttpCode(HttpStatus.OK)
  async triggerOcr(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.documentsService.triggerOcr(userId, id);
  }

  @Patch(':id/intelligence')
  async confirmIntelligence(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body()
    dto: {
      documentType?: string;
      extractedFields?: Record<string, any>;
      expiryDate?: string;
      issueDate?: string;
      title?: string;
      categoryId?: string;
      tags?: string[];
    },
  ) {
    return this.documentsService.confirmIntelligence(userId, id, dto);
  }

  @Get(':id/versions')
  async getVersions(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.documentsService.getVersions(userId, id);
  }

  @Post(':id/versions')
  @HttpCode(HttpStatus.CREATED)
  async createVersion(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() dto: CreateVersionDto,
    @Req() req: Request,
  ) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.ip;
    const userAgent = req.headers['user-agent'];
    return this.documentsService.createVersion(userId, id, dto, ipAddress, userAgent);
  }

  @Get(':id/versions/:versionId/download')
  async downloadVersion(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Param('versionId') versionId: string,
    @Res() res: Response,
  ) {
    const file = await this.documentsService.downloadVersion(userId, id, versionId);
    res.setHeader('Content-Type', file.mimeType);
    res.setHeader('Content-Length', file.fileSize);
    file.stream.pipe(res);
  }
}
