import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { AuditService, AuditAction } from '../audit/audit.service';
import { Readable } from 'stream';

@Injectable()
export class SharingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storageService: StorageService,
    private readonly auditService: AuditService,
  ) {}

  async createShareLink(
    userId: string,
    documentId: string,
    options?: {
      password?: string;
      expiresInHours?: number;
      maxUses?: number;
      allowDownload?: boolean;
    },
  ) {
    const document = await this.prisma.document.findUnique({
      where: { id: documentId },
    });

    if (!document || document.userId !== userId) {
      throw new NotFoundException('Document not found or unauthorized');
    }

    const token = crypto.randomBytes(24).toString('base64url');
    let passwordHash: string | null = null;
    if (options?.password && options.password.trim().length > 0) {
      passwordHash = await bcrypt.hash(options.password, 10);
    }

    let expiresAt: Date | null = null;
    if (options?.expiresInHours) {
      expiresAt = new Date(Date.now() + options.expiresInHours * 60 * 60 * 1000);
    }

    const share = await this.prisma.shareLink.create({
      data: {
        documentId,
        userId,
        token,
        passwordHash,
        expiresAt,
        maxUses: options?.maxUses || null,
        allowDownload: options?.allowDownload ?? true,
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.DOCUMENT_SHARE,
      documentId,
      metadata: { shareLinkId: share.id, expiresAt },
    });

    return {
      id: share.id,
      token: share.token,
      shareUrl: `/share/${share.token}`,
      expiresAt: share.expiresAt,
      maxUses: share.maxUses,
      allowDownload: share.allowDownload,
      hasPassword: !!share.passwordHash,
    };
  }

  async getMyShares(userId: string, documentId?: string) {
    const shares = await this.prisma.shareLink.findMany({
      where: {
        userId,
        ...(documentId && { documentId }),
      },
      include: {
        document: {
          select: { id: true, title: true, fileType: true, fileSize: true },
        },
        _count: {
          select: { accessLogs: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const now = new Date();
    return shares.map((s) => ({
      ...s,
      isExpired: s.expiresAt ? s.expiresAt < now : false,
      isExhausted: s.maxUses ? s.useCount >= s.maxUses : false,
      status: s.isRevoked
        ? 'REVOKED'
        : s.expiresAt && s.expiresAt < now
        ? 'EXPIRED'
        : s.maxUses && s.useCount >= s.maxUses
        ? 'EXHAUSTED'
        : 'ACTIVE',
    }));
  }

  async revokeShare(userId: string, id: string) {
    const share = await this.prisma.shareLink.findUnique({ where: { id } });
    if (!share || share.userId !== userId) {
      throw new NotFoundException('Share link not found or unauthorized');
    }

    await this.prisma.shareLink.update({
      where: { id },
      data: { isRevoked: true },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.SHARE_REVOKE,
      documentId: share.documentId,
      metadata: { shareLinkId: share.id },
    });

    return { success: true, message: 'Share link revoked' };
  }

  async accessSharedDocument(
    token: string,
    password?: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const share = await this.prisma.shareLink.findUnique({
      where: { token },
      include: {
        document: {
          select: {
            title: true,
            description: true,
            documentType: true,
            fileType: true,
            fileSize: true,
            mimeType: true,
            createdAt: true,
          },
        },
      },
    });

    if (!share || share.isRevoked) {
      throw new NotFoundException('Share link is invalid or has been revoked');
    }

    if (share.expiresAt && share.expiresAt < new Date()) {
      throw new ForbiddenException('This share link has expired');
    }

    if (share.maxUses && share.useCount >= share.maxUses) {
      throw new ForbiddenException('Maximum views for this share link exceeded');
    }

    if (share.passwordHash) {
      if (!password) {
        throw new UnauthorizedException('Password required to view this document');
      }
      const match = await bcrypt.compare(password, share.passwordHash);
      if (!match) {
        throw new UnauthorizedException('Invalid password for share link');
      }
    }

    await this.prisma.$transaction([
      this.prisma.shareLink.update({
        where: { id: share.id },
        data: { useCount: { increment: 1 } },
      }),
      this.prisma.shareAccessLog.create({
        data: {
          shareLinkId: share.id,
          ipAddress: ipAddress || null,
          userAgent: userAgent || null,
        },
      }),
    ]);

    await this.auditService.log({
      userId: share.userId,
      action: AuditAction.SHARE_ACCESS,
      documentId: share.documentId,
      ipAddress,
      userAgent,
      metadata: { shareLinkId: share.id },
    });

    // Strip internal database IDs and storage paths
    return {
      document: share.document,
      allowDownload: share.allowDownload,
      expiresAt: share.expiresAt,
      maxUses: share.maxUses,
      useCount: share.useCount + 1,
      downloadUrl: share.allowDownload ? `/sharing/public/${token}/download` : null,
    };
  }

  async downloadSharedFile(
    token: string,
    password?: string,
    ipAddress?: string,
    userAgent?: string,
  ): Promise<{ stream: Readable; mimeType: string; fileSize: number; title: string }> {
    const share = await this.prisma.shareLink.findUnique({
      where: { token },
      include: { document: true },
    });

    if (!share || share.isRevoked) {
      throw new NotFoundException('Share link is invalid or has been revoked');
    }

    if (!share.allowDownload) {
      throw new ForbiddenException('Download permission is disabled for this share link');
    }

    if (share.expiresAt && share.expiresAt < new Date()) {
      throw new ForbiddenException('This share link has expired');
    }

    if (share.maxUses && share.useCount >= share.maxUses) {
      throw new ForbiddenException('Maximum downloads for this share link exceeded');
    }

    if (share.passwordHash) {
      if (!password) {
        throw new UnauthorizedException('Password required to download this document');
      }
      const match = await bcrypt.compare(password, share.passwordHash);
      if (!match) {
        throw new UnauthorizedException('Invalid password for share link');
      }
    }

    const { stream, mimeType, fileSize } = await this.storageService.download(share.document.storagePath);

    await this.auditService.log({
      userId: share.userId,
      action: AuditAction.DOCUMENT_DOWNLOAD,
      documentId: share.documentId,
      ipAddress,
      userAgent,
      metadata: { viaShare: true, shareLinkId: share.id },
    });

    return {
      stream,
      mimeType,
      fileSize,
      title: share.document.title,
    };
  }
}
