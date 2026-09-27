import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService, AuditAction } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StorageService } from '../storage/storage.service';
import { EncryptionService } from '../security/encryption.service';
import { CreateUserShareDto } from './dto/create-user-share.dto';
import { UpdateShareDto } from './dto/update-share.dto';

@Injectable()
export class SharesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly notificationsService: NotificationsService,
    private readonly storageService: StorageService,
    private readonly encryptionService: EncryptionService,
  ) {}

  async createUserShare(
    userId: string,
    dto: CreateUserShareDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const document = await this.prisma.document.findUnique({
      where: { id: dto.documentId },
    });

    if (!document) {
      throw new NotFoundException('Document not found');
    }

    if (document.userId !== userId) {
      throw new ForbiddenException('You can only share documents you own');
    }

    let recipientUserId = dto.recipientUserId;
    const recipientEmail = dto.recipientEmail?.trim().toLowerCase();

    if (recipientEmail) {
      const recipient = await this.prisma.user.findUnique({
        where: { email: recipientEmail },
      });
      if (recipient) {
        recipientUserId = recipient.id;
      }
    } else if (recipientUserId) {
      const recipient = await this.prisma.user.findUnique({
        where: { id: recipientUserId },
      });
      if (!recipient) {
        throw new NotFoundException('Recipient user not found');
      }
    }

    if (recipientUserId === userId) {
      throw new BadRequestException('You cannot share a document with yourself');
    }

    // Envelope encryption key delegation:
    // If client supplied wrapped key envelope, store it.
    // Otherwise, generate a delegated document key envelope.
    let keyEnvelope = dto.keyEnvelope;
    if (!keyEnvelope) {
      const docKey = this.encryptionService.generateKey();
      const wrappingKey = this.encryptionService.generateKey();
      keyEnvelope = this.encryptionService.wrapKey(docKey, wrappingKey);
    }

    const expiresAt = dto.expiresInHours
      ? new Date(Date.now() + dto.expiresInHours * 60 * 60 * 1000)
      : null;

    const permissions = dto.permissions && dto.permissions.length > 0
      ? dto.permissions
      : ['VIEW', 'DOWNLOAD'];

    const share = await this.prisma.documentShare.create({
      data: {
        documentId: dto.documentId,
        ownerId: userId,
        recipientUserId: recipientUserId || null,
        recipientEmail: recipientEmail || null,
        permissions,
        status: 'ACTIVE',
        keyEnvelope: keyEnvelope as any,
        allowDownload: dto.allowDownload ?? true,
        maxViews: dto.maxViews || null,
        watermarkText: dto.watermarkText || null,
        expiresAt,
      },
      include: {
        document: {
          select: {
            id: true,
            title: true,
            documentType: true,
            fileSize: true,
            mimeType: true,
          },
        },
        recipientUser: {
          select: { id: true, email: true, profile: true },
        },
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.DOCUMENT_SHARED,
      documentId: dto.documentId,
      ipAddress,
      userAgent,
      metadata: {
        shareId: share.id,
        recipientUserId,
        recipientEmail,
        permissions,
        expiresAt,
      },
    });

    if (recipientUserId) {
      await this.notificationsService.createNotification(
        recipientUserId,
        'Document Shared With You',
        `A document "${document.title}" has been shared with you.`,
        'DOCUMENT_SHARED',
        { shareId: share.id, documentId: document.id },
      );
    }

    return share;
  }

  async getOutgoingShares(userId: string) {
    const shares = await this.prisma.documentShare.findMany({
      where: { ownerId: userId },
      include: {
        document: {
          select: {
            id: true,
            title: true,
            documentType: true,
            fileSize: true,
            mimeType: true,
          },
        },
        recipientUser: {
          select: { id: true, email: true, profile: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return this.refreshShareStatuses(shares);
  }

  async getIncomingShares(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    const shares = await this.prisma.documentShare.findMany({
      where: {
        OR: [
          { recipientUserId: userId },
          ...(user?.email ? [{ recipientEmail: user.email.toLowerCase() }] : []),
        ],
      },
      include: {
        document: {
          select: {
            id: true,
            title: true,
            documentType: true,
            fileSize: true,
            mimeType: true,
          },
        },
        owner: {
          select: { id: true, email: true, profile: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return this.refreshShareStatuses(shares);
  }

  async getShare(userId: string, shareId: string) {
    const share = await this.prisma.documentShare.findUnique({
      where: { id: shareId },
      include: {
        document: true,
        owner: { select: { id: true, email: true, profile: true } },
        recipientUser: { select: { id: true, email: true, profile: true } },
      },
    });

    if (!share) {
      throw new NotFoundException('Share not found');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    const isOwner = share.ownerId === userId;
    const isRecipient =
      share.recipientUserId === userId ||
      (user?.email && share.recipientEmail?.toLowerCase() === user.email.toLowerCase());

    if (!isOwner && !isRecipient) {
      throw new ForbiddenException('You do not have access to this share');
    }

    return share;
  }

  async revokeShare(
    userId: string,
    shareId: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const share = await this.prisma.documentShare.findUnique({
      where: { id: shareId },
    });

    if (!share) {
      throw new NotFoundException('Share not found');
    }

    if (share.ownerId !== userId) {
      throw new ForbiddenException('Only the owner can revoke this share');
    }

    const updated = await this.prisma.documentShare.update({
      where: { id: shareId },
      data: { status: 'REVOKED' },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.SHARE_REVOKED,
      documentId: share.documentId,
      ipAddress,
      userAgent,
      metadata: { shareId },
    });

    if (share.recipientUserId) {
      await this.notificationsService.createNotification(
        share.recipientUserId,
        'Share Revoked',
        `Access to a shared document has been revoked by the owner.`,
        'SHARE_REVOKED',
        { shareId },
      );
    }

    return { success: true, message: 'Share successfully revoked', share: updated };
  }

  async updateShare(
    userId: string,
    shareId: string,
    dto: UpdateShareDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const share = await this.prisma.documentShare.findUnique({
      where: { id: shareId },
    });

    if (!share) {
      throw new NotFoundException('Share not found');
    }

    if (share.ownerId !== userId) {
      throw new ForbiddenException('Only the owner can update this share');
    }

    const newExpiresAt = dto.expiresInHours
      ? new Date(Date.now() + dto.expiresInHours * 60 * 60 * 1000)
      : undefined;

    const updated = await this.prisma.documentShare.update({
      where: { id: shareId },
      data: {
        ...(newExpiresAt !== undefined && { expiresAt: newExpiresAt }),
        ...(dto.maxViews !== undefined && { maxViews: dto.maxViews }),
        ...(dto.allowDownload !== undefined && { allowDownload: dto.allowDownload }),
        ...(dto.watermarkText !== undefined && { watermarkText: dto.watermarkText }),
      },
    });

    return updated;
  }

  async openShare(
    userId: string,
    shareId: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const share = await this.getShare(userId, shareId);

    const now = new Date();

    // Check expiration
    if (share.expiresAt && now > share.expiresAt) {
      if (share.status !== 'EXPIRED') {
        await this.prisma.documentShare.update({
          where: { id: shareId },
          data: { status: 'EXPIRED' },
        });
        await this.auditService.log({
          userId,
          action: AuditAction.SHARE_EXPIRED,
          documentId: share.documentId,
          metadata: { shareId },
        });
      }
      throw new ForbiddenException('This document share has expired');
    }

    // Check max views
    if (share.maxViews && share.viewCount >= share.maxViews) {
      if (share.status !== 'MAX_VIEWS_REACHED') {
        await this.prisma.documentShare.update({
          where: { id: shareId },
          data: { status: 'MAX_VIEWS_REACHED' },
        });
        await this.auditService.log({
          userId,
          action: AuditAction.SHARE_MAX_VIEWS_REACHED,
          documentId: share.documentId,
          metadata: { shareId },
        });
      }
      throw new ForbiddenException('Maximum view limit reached for this share');
    }

    if (share.status !== 'ACTIVE') {
      throw new ForbiddenException(`Share is not active (status: ${share.status})`);
    }

    // Increment view count
    const updated = await this.prisma.documentShare.update({
      where: { id: shareId },
      data: {
        viewCount: { increment: 1 },
        ...(share.maxViews && share.viewCount + 1 >= share.maxViews
          ? { status: 'MAX_VIEWS_REACHED' }
          : {}),
      },
      include: {
        document: true,
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.SHARE_OPENED,
      documentId: share.documentId,
      ipAddress,
      userAgent,
      metadata: { shareId, viewCount: updated.viewCount },
    });

    // Notify owner
    await this.notificationsService.createNotification(
      share.ownerId,
      'Shared Document Opened',
      `Your shared document "${share.document.title}" was opened.`,
      'SHARE_OPENED',
      { shareId, viewCount: updated.viewCount },
    );

    return {
      shareId: share.id,
      document: {
        id: share.document.id,
        title: share.document.title,
        documentType: share.document.documentType,
        mimeType: share.document.mimeType,
        fileSize: share.document.fileSize,
        storagePath: share.document.storagePath,
        extractedText: share.document.extractedText,
        extractedFields: share.document.extractedFields,
      },
      keyEnvelope: share.keyEnvelope,
      permissions: share.permissions,
      allowDownload: share.allowDownload,
      watermarkText: share.watermarkText,
      viewCount: updated.viewCount,
      maxViews: share.maxViews,
      expiresAt: share.expiresAt,
    };
  }

  async downloadShare(
    userId: string,
    shareId: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const share = await this.getShare(userId, shareId);

    if (share.status !== 'ACTIVE') {
      throw new ForbiddenException(`Share is not active (status: ${share.status})`);
    }

    if (share.expiresAt && new Date() > share.expiresAt) {
      throw new ForbiddenException('Share has expired');
    }

    if (!share.allowDownload) {
      throw new ForbiddenException('Download permission has not been granted for this share');
    }

    await this.auditService.log({
      userId,
      action: AuditAction.SHARE_DOWNLOADED,
      documentId: share.documentId,
      ipAddress,
      userAgent,
      metadata: { shareId },
    });

    const fileResult = await this.storageService.download(share.document.storagePath);
    return {
      stream: fileResult.stream,
      mimeType: share.document.mimeType || fileResult.mimeType,
      fileSize: share.document.fileSize || fileResult.fileSize,
      title: share.document.title,
    };
  }

  private async refreshShareStatuses(shares: any[]) {
    const now = new Date();
    return shares.map((share) => {
      let currentStatus = share.status;
      if (share.status === 'ACTIVE') {
        if (share.expiresAt && now > new Date(share.expiresAt)) {
          currentStatus = 'EXPIRED';
        } else if (share.maxViews && share.viewCount >= share.maxViews) {
          currentStatus = 'MAX_VIEWS_REACHED';
        }
      }
      return {
        ...share,
        status: currentStatus,
      };
    });
  }
}
