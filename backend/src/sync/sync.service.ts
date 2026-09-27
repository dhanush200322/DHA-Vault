import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService, AuditAction } from '../audit/audit.service';
import { ConflictResolution, ResolveConflictDto, StartSyncDto } from './dto/sync.dto';

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async getStatus(userId: string) {
    const [
      total,
      synced,
      pending,
      conflictCount,
      lastSyncDoc,
      openConflicts,
    ] = await Promise.all([
      this.prisma.document.count({ where: { userId, isArchived: false } }),
      this.prisma.document.count({ where: { userId, syncStatus: 'SYNCED', isArchived: false } }),
      this.prisma.document.count({
        where: {
          userId,
          syncStatus: { in: ['PENDING_UPLOAD', 'UPLOADING', 'PENDING_DOWNLOAD', 'DOWNLOADING'] },
          isArchived: false,
        },
      }),
      this.prisma.document.count({ where: { userId, syncStatus: 'CONFLICT', isArchived: false } }),
      this.prisma.document.findFirst({
        where: { userId, lastSyncedAt: { not: null } },
        orderBy: { lastSyncedAt: 'desc' },
        select: { lastSyncedAt: true },
      }),
      this.prisma.syncConflict.findMany({
        where: { userId, status: 'OPEN' },
        include: {
          document: {
            select: { id: true, title: true, documentType: true, updatedAt: true },
          },
        },
      }),
    ]);

    const status =
      conflictCount > 0 ? 'CONFLICT' : pending > 0 ? 'SYNCING' : 'SYNCED';

    return {
      status,
      totalDocuments: total,
      syncedDocuments: synced,
      pendingCount: pending,
      conflictCount,
      lastSyncedAt: lastSyncDoc?.lastSyncedAt || null,
      openConflicts,
    };
  }

  async getPending(userId: string) {
    const pendingDocs = await this.prisma.document.findMany({
      where: {
        userId,
        OR: [
          { syncStatus: { not: 'SYNCED' } },
          { lastSyncedAt: null },
        ],
      },
      select: {
        id: true,
        title: true,
        syncStatus: true,
        checksum: true,
        updatedAt: true,
        lastSyncedAt: true,
        fileSize: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    const openConflicts = await this.prisma.syncConflict.findMany({
      where: { userId, status: 'OPEN' },
      include: {
        document: {
          select: { id: true, title: true, documentType: true, checksum: true },
        },
      },
    });

    return {
      pendingDocuments: pendingDocs,
      openConflicts,
    };
  }

  async startSync(userId: string, dto: StartSyncDto, ipAddress?: string, userAgent?: string) {
    const now = new Date();
    const clientItems = dto.items || [];
    const clientDocMap = new Map(clientItems.map((item) => [item.documentId, item]));

    // Fetch all user's non-archived documents
    const serverDocs = await this.prisma.document.findMany({
      where: { userId, isArchived: false },
      include: {
        versions: {
          orderBy: { versionNumber: 'desc' },
          take: 1,
        },
      },
    });

    const toPull: any[] = [];
    const toPush: string[] = [];
    const conflicts: any[] = [];

    for (const sDoc of serverDocs) {
      const cItem = clientDocMap.get(sDoc.id);

      if (!cItem) {
        // Document exists on server but not reported by client -> pull to client
        toPull.push({
          id: sDoc.id,
          title: sDoc.title,
          checksum: sDoc.checksum,
          versionNumber: sDoc.versions[0]?.versionNumber || 1,
          updatedAt: sDoc.updatedAt,
        });
      } else {
        // Both sides have document. Check for checksum or version difference
        const serverVersion = sDoc.versions[0]?.versionNumber || 1;
        const clientVersion = cItem.versionNumber || 1;
        const checksumMatch = cItem.checksum && sDoc.checksum && cItem.checksum === sDoc.checksum;

        if (checksumMatch) {
          // Identical binary -> Mark SYNCED
          if (sDoc.syncStatus !== 'SYNCED') {
            await this.prisma.document.update({
              where: { id: sDoc.id },
              data: { syncStatus: 'SYNCED', lastSyncedAt: now },
            });
          }
        } else if (clientVersion > serverVersion) {
          // Client has newer version -> Client should push
          toPush.push(sDoc.id);
        } else if (serverVersion > clientVersion) {
          // Server has newer version -> Client should pull
          toPull.push({
            id: sDoc.id,
            title: sDoc.title,
            checksum: sDoc.checksum,
            versionNumber: serverVersion,
            updatedAt: sDoc.updatedAt,
          });
        } else if (cItem.checksum && sDoc.checksum && cItem.checksum !== sDoc.checksum) {
          // Same version number but different checksums -> Concurrent edit CONFLICT!
          const existingConflict = await this.prisma.syncConflict.findFirst({
            where: { userId, documentId: sDoc.id, status: 'OPEN' },
          });

          if (!existingConflict) {
            const conflict = await this.prisma.syncConflict.create({
              data: {
                userId,
                documentId: sDoc.id,
                status: 'OPEN',
              },
            });
            await this.prisma.document.update({
              where: { id: sDoc.id },
              data: { syncStatus: 'CONFLICT' },
            });
            conflicts.push(conflict);
          }
        }
      }
    }

    // Update device sync status if deviceId provided
    if (dto.deviceId) {
      await this.prisma.device.updateMany({
        where: { userId, deviceId: dto.deviceId },
        data: { lastSyncedAt: now, syncStatus: 'SYNCED' },
      });
    }

    await this.auditService.log({
      userId,
      action: AuditAction.DOCUMENT_SYNCED,
      ipAddress,
      userAgent,
      metadata: {
        pulledCount: toPull.length,
        pushedCount: toPush.length,
        conflictCount: conflicts.length,
        deviceId: dto.deviceId,
      },
    });

    return {
      syncedAt: now,
      toPull,
      toPush,
      conflicts,
      message: `Sync computed: ${toPull.length} to pull, ${toPush.length} to push, ${conflicts.length} conflicts.`,
    };
  }

  async resolveConflict(
    userId: string,
    dto: ResolveConflictDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const conflict = await this.prisma.syncConflict.findUnique({
      where: { id: dto.conflictId },
      include: { document: true },
    });

    if (!conflict || conflict.userId !== userId) {
      throw new NotFoundException('Sync conflict not found or does not belong to user');
    }

    if (conflict.status === 'RESOLVED') {
      return { success: true, message: 'Conflict is already resolved' };
    }

    const doc = conflict.document;
    const now = new Date();

    if (dto.resolution === ConflictResolution.KEEP_LOCAL) {
      // Create new version marking local as accepted
      const latestVersion = await this.prisma.documentVersion.findFirst({
        where: { documentId: doc.id },
        orderBy: { versionNumber: 'desc' },
      });
      const nextVer = (latestVersion?.versionNumber || 1) + 1;

      await this.prisma.$transaction([
        this.prisma.documentVersion.create({
          data: {
            documentId: doc.id,
            versionNumber: nextVer,
            fileSize: doc.fileSize,
            storagePath: doc.storagePath,
            checksum: doc.checksum,
            changeNotes: dto.changeNotes || 'Resolved conflict: kept local version',
            createdById: userId,
          },
        }),
        this.prisma.document.update({
          where: { id: doc.id },
          data: { syncStatus: 'SYNCED', lastSyncedAt: now },
        }),
        this.prisma.syncConflict.update({
          where: { id: conflict.id },
          data: {
            status: 'RESOLVED',
            resolution: ConflictResolution.KEEP_LOCAL,
            resolvedAt: now,
          },
        }),
      ]);
    } else if (dto.resolution === ConflictResolution.KEEP_REMOTE) {
      // Revert to remote
      await this.prisma.$transaction([
        this.prisma.document.update({
          where: { id: doc.id },
          data: { syncStatus: 'SYNCED', lastSyncedAt: now },
        }),
        this.prisma.syncConflict.update({
          where: { id: conflict.id },
          data: {
            status: 'RESOLVED',
            resolution: ConflictResolution.KEEP_REMOTE,
            resolvedAt: now,
          },
        }),
      ]);
    } else if (dto.resolution === ConflictResolution.CREATE_NEW_VERSION) {
      // Both are kept: bump version and keep both
      const latestVersion = await this.prisma.documentVersion.findFirst({
        where: { documentId: doc.id },
        orderBy: { versionNumber: 'desc' },
      });
      const nextVer = (latestVersion?.versionNumber || 1) + 1;

      await this.prisma.$transaction([
        this.prisma.documentVersion.create({
          data: {
            documentId: doc.id,
            versionNumber: nextVer,
            fileSize: doc.fileSize,
            storagePath: doc.storagePath,
            checksum: doc.checksum,
            changeNotes: dto.changeNotes || 'Resolved conflict: branched as new version',
            createdById: userId,
          },
        }),
        this.prisma.document.update({
          where: { id: doc.id },
          data: { syncStatus: 'SYNCED', lastSyncedAt: now },
        }),
        this.prisma.syncConflict.update({
          where: { id: conflict.id },
          data: {
            status: 'RESOLVED',
            resolution: ConflictResolution.CREATE_NEW_VERSION,
            resolvedAt: now,
          },
        }),
      ]);
    }

    await this.auditService.log({
      userId,
      action: AuditAction.SYNC_CONFLICT,
      documentId: doc.id,
      ipAddress,
      userAgent,
      metadata: {
        conflictId: conflict.id,
        resolution: dto.resolution,
      },
    });

    return {
      success: true,
      message: `Conflict resolved via ${dto.resolution}`,
      resolution: dto.resolution,
    };
  }

  async getConflicts(userId: string) {
    return this.prisma.syncConflict.findMany({
      where: { userId },
      include: {
        document: {
          select: { id: true, title: true, documentType: true, fileSize: true, updatedAt: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}
