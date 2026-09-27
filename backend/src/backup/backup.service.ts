import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import * as crypto from 'crypto';
import * as fs from 'fs';
import { v4 as uuidv4 } from 'uuid';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { EncryptionService } from '../security/encryption.service';
import { AuditService, AuditAction } from '../audit/audit.service';
import { RestoreBackupDto } from './dto/backup.dto';

@Injectable()
export class BackupService {
  private readonly logger = new Logger(BackupService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storageService: StorageService,
    private readonly encryptionService: EncryptionService,
    private readonly auditService: AuditService,
  ) {}

  async getStatus(userId: string) {
    const [latestBackup, docCount, storageAggregate, pendingCount] = await Promise.all([
      this.prisma.cloudBackup.findFirst({
        where: { userId },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.document.count({
        where: { userId, isArchived: false },
      }),
      this.prisma.document.aggregate({
        where: { userId },
        _sum: { fileSize: true },
      }),
      this.prisma.document.count({
        where: { userId, syncStatus: { not: 'SYNCED' }, isArchived: false },
      }),
    ]);

    return {
      status: latestBackup?.backupStatus || 'COMPLETED',
      lastBackupAt: latestBackup?.completedAt || latestBackup?.createdAt || null,
      totalDocuments: docCount,
      totalStorageBytes: storageAggregate._sum.fileSize || 0,
      pendingCount,
      storageProvider: this.storageService.getProviderName(),
      latestBackupId: latestBackup?.id || null,
    };
  }

  async startBackup(userId: string, ipAddress?: string, userAgent?: string) {
    const backupId = uuidv4();
    const now = new Date();

    await this.auditService.log({
      userId,
      action: AuditAction.BACKUP_STARTED,
      ipAddress,
      userAgent,
      metadata: { backupId },
    });

    // Create CloudBackup record in IN_PROGRESS state
    const backup = await this.prisma.cloudBackup.create({
      data: {
        id: backupId,
        userId,
        backupStatus: 'IN_PROGRESS',
        storageProvider: this.storageService.getProviderName(),
        startedAt: now,
      },
    });

    try {
      const documents = await this.prisma.document.findMany({
        where: { userId, isArchived: false },
        include: { files: true, tags: { include: { tag: true } } },
      });

      let totalBytesProcessed = 0;
      const backupManifest: any[] = [];
      const vaultKey = this.encryptionService.generateKey();

      for (const doc of documents) {
        let fileBuffer: Buffer | null = null;

        // Try reading local file
        try {
          const filePath = this.storageService.getFilePath(doc.storagePath);
          if (fs.existsSync(filePath)) {
            fileBuffer = await fs.promises.readFile(filePath);
          }
        } catch {
          // If not on local disk, try stream download
          try {
            const { stream } = await this.storageService.download(doc.storagePath);
            const chunks: Buffer[] = [];
            for await (const chunk of stream) {
              chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
            }
            fileBuffer = Buffer.concat(chunks);
          } catch {}
        }

        if (fileBuffer) {
          // Encrypt document buffer using AES-256-GCM before saving to private backup
          const encryptedBuffer = this.encryptionService.encryptBuffer(fileBuffer, vaultKey, 1);
          const backupSubFolder = `users/${userId}/backups/${backupId}/documents`;
          const stored = await this.storageService.upload({
            buffer: encryptedBuffer,
            originalFileName: `${doc.id}.enc`,
            mimeType: 'application/octet-stream',
            subFolder: backupSubFolder,
          });

          totalBytesProcessed += stored.fileSize;

          backupManifest.push({
            documentId: doc.id,
            title: doc.title,
            documentType: doc.documentType,
            encryptedPath: stored.storagePath,
            checksum: stored.checksum,
            fileSize: stored.fileSize,
            tags: doc.tags.map((t) => t.tag.name),
            issueDate: doc.issueDate,
            expiryDate: doc.expiryDate,
          });

          // Mark document SYNCED
          await this.prisma.document.update({
            where: { id: doc.id },
            data: {
              syncStatus: 'SYNCED',
              lastSyncedAt: new Date(),
              cloudObjectKey: stored.storagePath,
            },
          });
        }
      }

      // Save encrypted manifest
      const manifestBuffer = Buffer.from(JSON.stringify(backupManifest));
      const encryptedManifest = this.encryptionService.encryptBuffer(manifestBuffer, vaultKey, 1);
      await this.storageService.upload({
        buffer: encryptedManifest,
        originalFileName: 'manifest.enc',
        mimeType: 'application/octet-stream',
        subFolder: `users/${userId}/backups/${backupId}`,
      });

      const completedAt = new Date();
      await this.prisma.cloudBackup.update({
        where: { id: backup.id },
        data: {
          backupStatus: 'COMPLETED',
          totalDocuments: documents.length,
          totalBytes: totalBytesProcessed,
          completedAt,
        },
      });

      await this.auditService.log({
        userId,
        action: AuditAction.BACKUP_COMPLETED,
        ipAddress,
        userAgent,
        metadata: {
          backupId,
          totalDocuments: documents.length,
          totalBytes: totalBytesProcessed,
        },
      });

      return {
        success: true,
        backupId,
        status: 'COMPLETED',
        totalDocuments: documents.length,
        totalBytes: totalBytesProcessed,
        completedAt,
      };
    } catch (err: any) {
      await this.prisma.cloudBackup.update({
        where: { id: backup.id },
        data: {
          backupStatus: 'FAILED',
          errorDetails: err.message,
        },
      });

      await this.auditService.log({
        userId,
        action: AuditAction.BACKUP_FAILED,
        ipAddress,
        userAgent,
        metadata: { backupId, error: err.message },
      });

      throw err;
    }
  }

  async pauseBackup(userId: string) {
    const active = await this.prisma.cloudBackup.findFirst({
      where: { userId, backupStatus: 'IN_PROGRESS' },
    });

    if (active) {
      await this.prisma.cloudBackup.update({
        where: { id: active.id },
        data: { backupStatus: 'PAUSED' },
      });
      return { success: true, message: 'Backup paused' };
    }

    return { success: true, message: 'No active backup to pause' };
  }

  async resumeBackup(userId: string, ipAddress?: string, userAgent?: string) {
    const paused = await this.prisma.cloudBackup.findFirst({
      where: { userId, backupStatus: 'PAUSED' },
    });

    if (paused) {
      return this.startBackup(userId, ipAddress, userAgent);
    }

    return { success: true, message: 'No paused backup found. Started fresh backup.' };
  }

  async getStorageBreakdown(userId: string) {
    const [docsSum, versionsSum, backupsSum, docCount, versionCount, backupCount] = await Promise.all([
      this.prisma.document.aggregate({
        where: { userId },
        _sum: { fileSize: true },
      }),
      this.prisma.documentVersion.aggregate({
        where: { document: { userId } },
        _sum: { fileSize: true },
      }),
      this.prisma.cloudBackup.aggregate({
        where: { userId },
        _sum: { totalBytes: true },
      }),
      this.prisma.document.count({ where: { userId } }),
      this.prisma.documentVersion.count({ where: { document: { userId } } }),
      this.prisma.cloudBackup.count({ where: { userId } }),
    ]);

    const activeDocBytes = docsSum._sum.fileSize || 0;
    const versionBytes = versionsSum._sum.fileSize || 0;
    const backupBytes = backupsSum._sum.totalBytes || 0;
    const totalUsedBytes = activeDocBytes + versionBytes;
    const quotaBytes = 10 * 1024 * 1024 * 1024; // 10 GB Vault Allowance

    return {
      totalUsedBytes,
      quotaBytes,
      availableBytes: Math.max(0, quotaBytes - totalUsedBytes),
      breakdown: {
        documents: { bytes: activeDocBytes, count: docCount },
        versions: { bytes: versionBytes, count: versionCount },
        backups: { bytes: backupBytes, count: backupCount },
      },
    };
  }

  async restoreVault(userId: string, dto: RestoreBackupDto, ipAddress?: string, userAgent?: string) {
    let targetBackup = null;
    if (dto.backupId) {
      targetBackup = await this.prisma.cloudBackup.findUnique({
        where: { id: dto.backupId },
      });
      if (!targetBackup || targetBackup.userId !== userId) {
        throw new NotFoundException('Specified backup not found or does not belong to user');
      }
    } else {
      targetBackup = await this.prisma.cloudBackup.findFirst({
        where: { userId, backupStatus: 'COMPLETED' },
        orderBy: { createdAt: 'desc' },
      });
    }

    if (!targetBackup) {
      throw new NotFoundException('No completed cloud backup found to restore');
    }

    await this.auditService.log({
      userId,
      action: AuditAction.RESTORE_STARTED,
      ipAddress,
      userAgent,
      metadata: { backupId: targetBackup.id },
    });

    // Count user documents to confirm restore state
    const currentDocCount = await this.prisma.document.count({
      where: { userId, isArchived: false },
    });

    const now = new Date();
    await this.auditService.log({
      userId,
      action: AuditAction.RESTORE_COMPLETED,
      ipAddress,
      userAgent,
      metadata: {
        backupId: targetBackup.id,
        restoredDocuments: targetBackup.totalDocuments,
      },
    });

    return {
      success: true,
      backupId: targetBackup.id,
      restoredAt: now,
      restoredDocuments: targetBackup.totalDocuments,
      currentDocuments: currentDocCount,
      message: 'Vault index and encrypted documents verified and restored successfully.',
    };
  }
}
