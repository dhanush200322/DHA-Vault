import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { AuditService, AuditAction } from '../audit/audit.service';
import { OcrService } from '../ocr/ocr.service';
import { DocumentIntelligenceService } from '../intelligence/document-intelligence.service';
import { RemindersService } from '../reminders/reminders.service';
import { CreateDocumentDto } from './dto/create-document.dto';
import { UpdateDocumentDto } from './dto/update-document.dto';
import { QueryDocumentDto } from './dto/query-document.dto';
import { CreateVersionDto } from './dto/create-version.dto';

@Injectable()
export class DocumentsService {
  private readonly logger = new Logger(DocumentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storageService: StorageService,
    private readonly auditService: AuditService,
    private readonly ocrService: OcrService,
    private readonly intelligenceService: DocumentIntelligenceService,
    private readonly remindersService: RemindersService,
  ) {}

  async findAll(userId: string, query: QueryDocumentDto) {
    const where: any = {
      userId,
      isArchived: query.isArchived ?? false,
    };

    if (query.categoryId) {
      where.categoryId = query.categoryId;
    }

    if (query.documentType) {
      where.documentType = query.documentType;
    }

    if (query.isFavorite !== undefined) {
      where.isFavorite = query.isFavorite;
    }

    if (query.search) {
      const searchTerms = query.search.trim();
      where.OR = [
        { title: { contains: searchTerms, mode: 'insensitive' } },
        { description: { contains: searchTerms, mode: 'insensitive' } },
        { extractedText: { contains: searchTerms, mode: 'insensitive' } },
        { documentType: { contains: searchTerms, mode: 'insensitive' } },
      ];
    }

    const now = new Date();
    if (query.isExpired) {
      where.expiryDate = {
        lt: now,
      };
    } else if (query.expiryDays) {
      const futureDate = new Date(Date.now() + query.expiryDays * 24 * 60 * 60 * 1000);
      where.expiryDate = {
        gte: now,
        lte: futureDate,
      };
    } else if (query.isExpiringSoon) {
      const in30Days = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      where.expiryDate = {
        gte: now,
        lte: in30Days,
      };
    }

    const orderBy: any = {};
    const sortField = query.sortBy || 'createdAt';
    const sortDirection = query.sortOrder || 'desc';
    orderBy[sortField] = sortDirection;

    const [total, documents] = await Promise.all([
      this.prisma.document.count({ where }),
      this.prisma.document.findMany({
        where,
        skip: query.skip,
        take: query.take,
        orderBy,
        select: {
          id: true,
          userId: true,
          categoryId: true,
          title: true,
          description: true,
          documentType: true,
          fileType: true,
          fileSize: true,
          mimeType: true,
          storagePath: true,
          thumbnailPath: true,
          extractedText: true,
          extractedFields: true,
          ocrStatus: true,
          ocrConfidence: true,
          ocrProvider: true,
          ocrProcessedAt: true,
          issueDate: true,
          expiryDate: true,
          isFavorite: true,
          isArchived: true,
          isEncrypted: true,
          createdAt: true,
          updatedAt: true,
          category: {
            select: {
              id: true,
              name: true,
              icon: true,
              color: true,
            },
          },
          tags: {
            select: {
              tag: {
                select: { id: true, name: true, color: true },
              },
            },
          },
        },
      }),
    ]);

    const page = query.page || 1;
    const limit = query.limit || 20;

    return {
      data: documents,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findOne(userId: string, id: string, ipAddress?: string, userAgent?: string) {
    const document = await this.prisma.document.findUnique({
      where: { id },
      include: {
        category: {
          select: { id: true, name: true, icon: true, color: true },
        },
        files: true,
        tags: {
          include: { tag: true },
        },
        reminders: true,
      },
    });

    if (!document) {
      throw new NotFoundException(`Document with ID "${id}" not found`);
    }

    if (document.userId !== userId) {
      throw new ForbiddenException('You do not have permission to access this document');
    }

    await this.auditService.log({
      userId,
      action: AuditAction.DOCUMENT_VIEW,
      documentId: id,
      ipAddress,
      userAgent,
      metadata: { title: document.title },
    });

    return document;
  }

  async getRecentlyViewed(userId: string, limit = 5) {
    const logs = await this.prisma.documentAccessLog.findMany({
      where: {
        userId,
        action: AuditAction.DOCUMENT_VIEW,
        documentId: { not: null },
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
      select: { documentId: true },
    });

    // Deduplicate preserving latest view order
    const seenIds = new Set<string>();
    const uniqueDocIds: string[] = [];
    for (const log of logs) {
      if (log.documentId && !seenIds.has(log.documentId)) {
        seenIds.add(log.documentId);
        uniqueDocIds.push(log.documentId);
        if (uniqueDocIds.length >= limit) break;
      }
    }

    if (uniqueDocIds.length === 0) {
      // Fallback to recent uploads if no views yet
      return this.prisma.document.findMany({
        where: { userId, isArchived: false },
        orderBy: { createdAt: 'desc' },
        take: limit,
        include: {
          category: {
            select: { id: true, name: true, icon: true, color: true },
          },
        },
      });
    }

    const docs = await this.prisma.document.findMany({
      where: {
        id: { in: uniqueDocIds },
        userId,
        isArchived: false,
      },
      include: {
        category: {
          select: { id: true, name: true, icon: true, color: true },
        },
      },
    });

    // Sort by order of uniqueDocIds
    const docMap = new Map(docs.map((d) => [d.id, d]));
    return uniqueDocIds.map((id) => docMap.get(id)).filter(Boolean);
  }

  async create(
    userId: string,
    dto: CreateDocumentDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    if (dto.categoryId) {
      const category = await this.prisma.category.findUnique({
        where: { id: dto.categoryId },
      });
      if (!category || category.userId !== userId) {
        throw new BadRequestException('Invalid category ID or category does not belong to user');
      }
    }

    const document = await this.prisma.document.create({
      data: {
        userId,
        categoryId: dto.categoryId || null,
        title: dto.title.trim(),
        description: dto.description || null,
        documentType: dto.documentType || 'OTHER',
        fileType: dto.fileType || (dto.mimeType?.includes('pdf') ? 'PDF' : 'IMAGE'),
        fileSize: dto.fileSize || 0,
        mimeType: dto.mimeType || 'application/pdf',
        storagePath: dto.storagePath,
        thumbnailPath: dto.thumbnailPath || null,
        extractedText: dto.extractedText || null,
        ocrStatus: 'PENDING',
        issueDate: dto.issueDate ? new Date(dto.issueDate) : null,
        expiryDate: dto.expiryDate ? new Date(dto.expiryDate) : null,
        isFavorite: dto.isFavorite ?? false,
        isEncrypted: dto.isEncrypted ?? false,
        syncStatus: 'SYNCED',
        checksum: dto.checksum || null,
        lastSyncedAt: new Date(),
        files: {
          create: {
            fileName: dto.storagePath.split('/').pop() || 'document',
            originalFileName: dto.originalFileName || dto.title,
            fileSize: dto.fileSize || 0,
            mimeType: dto.mimeType || 'application/pdf',
            storagePath: dto.storagePath,
            isPrimary: true,
          },
        },
        versions: {
          create: {
            versionNumber: 1,
            fileSize: dto.fileSize || 0,
            storagePath: dto.storagePath,
            checksum: dto.checksum || null,
            createdById: userId,
            deviceId: dto.deviceId || null,
            changeNotes: 'Initial document upload',
          },
        },
      },
      include: {
        category: true,
        files: true,
        versions: true,
      },
    });

    // Handle user-specified tags if any
    if (dto.tags && dto.tags.length > 0) {
      for (const tagName of dto.tags) {
        const cleanName = tagName.replace(/^#/, '').trim();
        if (!cleanName) continue;
        const tag = await this.prisma.tag.upsert({
          where: { userId_name: { userId, name: cleanName } },
          create: { userId, name: cleanName },
          update: {},
        });
        await this.prisma.documentTag.upsert({
          where: { documentId_tagId: { documentId: document.id, tagId: tag.id } },
          create: { documentId: document.id, tagId: tag.id },
          update: {},
        });
      }
    }

    await this.auditService.log({
      userId,
      action: AuditAction.DOCUMENT_UPLOAD,
      documentId: document.id,
      ipAddress,
      userAgent,
      metadata: { title: document.title, fileSize: document.fileSize },
    });

    // Schedule reminders if explicit expiry date was provided
    if (document.expiryDate) {
      this.remindersService
        .syncRemindersForDocument(userId, document.id, document.expiryDate, document.title)
        .catch(() => {});
    }

    // Trigger OCR & Document Intelligence asynchronously without blocking Fast View
    setImmediate(() => {
      this.processOcrAndIntelligenceAsync(
        document.id,
        userId,
        dto.storagePath,
        dto.mimeType,
        dto.originalFileName || dto.title,
        document.title,
      ).catch((err) => {
        this.logger.error(`Background OCR pipeline failed: ${err.message}`);
      });
    });

    return document;
  }

  /**
   * Asynchronous OCR & Intelligence processing pipeline
   */
  async processOcrAndIntelligenceAsync(
    documentId: string,
    userId: string,
    storagePath: string,
    mimeType?: string,
    fileName?: string,
    title?: string,
  ) {
    try {
      await this.prisma.document.update({
        where: { id: documentId },
        data: { ocrStatus: 'PROCESSING' },
      });

      const fullPath = this.storageService.getFilePath(storagePath);
      const ocrResult = await this.ocrService.processFile(fullPath, mimeType || 'application/pdf');

      const intelResult = await this.intelligenceService.analyzeDocument(
        ocrResult.text,
        fileName || title,
      );

      const doc = await this.prisma.document.findUnique({
        where: { id: documentId },
      });
      if (!doc) return;

      const shouldUpdateType = doc.documentType === 'OTHER' && intelResult.classification.documentType !== 'OTHER';
      const detectedType = shouldUpdateType ? intelResult.classification.documentType : doc.documentType;

      const updatedDoc = await this.prisma.document.update({
        where: { id: documentId },
        data: {
          ocrStatus: 'COMPLETED',
          ocrProvider: ocrResult.provider,
          ocrConfidence: ocrResult.confidence,
          ocrProcessedAt: new Date(),
          extractedText: ocrResult.text || null,
          extractedFields: intelResult.fields,
          ...(shouldUpdateType && { documentType: detectedType }),
          ...(!doc.expiryDate && intelResult.expiryDate && {
            expiryDate: new Date(intelResult.expiryDate),
          }),
          ...(!doc.issueDate && intelResult.issueDate && {
            issueDate: new Date(intelResult.issueDate),
          }),
        },
      });

      // Suggest/apply tags if none exist
      if (intelResult.classification.suggestedTags?.length) {
        for (const rawTag of intelResult.classification.suggestedTags) {
          const cleanName = rawTag.replace(/^#/, '').trim();
          if (!cleanName) continue;
          const tag = await this.prisma.tag.upsert({
            where: { userId_name: { userId, name: cleanName } },
            create: { userId, name: cleanName },
            update: {},
          });
          await this.prisma.documentTag.upsert({
            where: { documentId_tagId: { documentId, tagId: tag.id } },
            create: { documentId, tagId: tag.id },
            update: {},
          });
        }
      }

      // Schedule smart reminders if expiry was detected or exists
      if (updatedDoc.expiryDate) {
        await this.remindersService.syncRemindersForDocument(
          userId,
          documentId,
          updatedDoc.expiryDate,
          updatedDoc.title,
        );
      }

      // Create in-app notification
      await this.remindersService.createNotification(
        userId,
        'OCR_COMPLETE',
        `✓ ${updatedDoc.title} scanned`,
        `Identified as ${updatedDoc.documentType} with ${(ocrResult.confidence * 100).toFixed(0)}% confidence.`,
        {
          documentId,
          documentType: updatedDoc.documentType,
          confidence: ocrResult.confidence,
        },
      );
    } catch (error: any) {
      this.logger.error(`Error in OCR pipeline for doc ${documentId}: ${error.message}`);
      await this.prisma.document.update({
        where: { id: documentId },
        data: { ocrStatus: 'FAILED' },
      }).catch(() => {});
    }
  }

  /**
   * Explicit endpoint to trigger or retry OCR
   */
  async triggerOcr(userId: string, id: string) {
    const document = await this.findOne(userId, id);
    const fileName = document.files?.[0]?.originalFileName || document.title;
    await this.processOcrAndIntelligenceAsync(
      document.id,
      userId,
      document.storagePath,
      document.mimeType,
      fileName,
      document.title,
    );
    return this.findOne(userId, id);
  }

  /**
   * Confirm or edit document intelligence suggestions
   */
  async confirmIntelligence(
    userId: string,
    id: string,
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
    await this.findOne(userId, id);

    const updated = await this.prisma.document.update({
      where: { id },
      data: {
        ...(dto.title && { title: dto.title.trim() }),
        ...(dto.documentType && { documentType: dto.documentType }),
        ...(dto.extractedFields && { extractedFields: dto.extractedFields }),
        ...(dto.categoryId && { categoryId: dto.categoryId }),
        ...(dto.issueDate !== undefined && {
          issueDate: dto.issueDate ? new Date(dto.issueDate) : null,
        }),
        ...(dto.expiryDate !== undefined && {
          expiryDate: dto.expiryDate ? new Date(dto.expiryDate) : null,
        }),
      },
      include: {
        category: true,
        files: true,
        tags: { include: { tag: true } },
      },
    });

    if (dto.tags && dto.tags.length > 0) {
      for (const tagName of dto.tags) {
        const cleanName = tagName.replace(/^#/, '').trim();
        if (!cleanName) continue;
        const tag = await this.prisma.tag.upsert({
          where: { userId_name: { userId, name: cleanName } },
          create: { userId, name: cleanName },
          update: {},
        });
        await this.prisma.documentTag.upsert({
          where: { documentId_tagId: { documentId: id, tagId: tag.id } },
          create: { documentId: id, tagId: tag.id },
          update: {},
        });
      }
    }

    if (updated.expiryDate) {
      await this.remindersService.syncRemindersForDocument(
        userId,
        id,
        updated.expiryDate,
        updated.title,
      );
    }

    return this.findOne(userId, id);
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateDocumentDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const existing = await this.findOne(userId, id);

    if (dto.categoryId && dto.categoryId !== existing.categoryId) {
      const category = await this.prisma.category.findUnique({
        where: { id: dto.categoryId },
      });
      if (!category || category.userId !== userId) {
        throw new BadRequestException('Invalid category ID or category does not belong to user');
      }
    }

    const updated = await this.prisma.document.update({
      where: { id },
      data: {
        ...(dto.title !== undefined && { title: dto.title.trim() }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.categoryId !== undefined && { categoryId: dto.categoryId }),
        ...(dto.documentType !== undefined && { documentType: dto.documentType }),
        ...(dto.extractedFields !== undefined && { extractedFields: dto.extractedFields }),
        ...(dto.ocrStatus !== undefined && { ocrStatus: dto.ocrStatus }),
        ...(dto.issueDate !== undefined && {
          issueDate: dto.issueDate ? new Date(dto.issueDate) : null,
        }),
        ...(dto.expiryDate !== undefined && {
          expiryDate: dto.expiryDate ? new Date(dto.expiryDate) : null,
        }),
        ...(dto.isFavorite !== undefined && { isFavorite: dto.isFavorite }),
        ...(dto.isArchived !== undefined && { isArchived: dto.isArchived }),
        ...(dto.thumbnailPath !== undefined && { thumbnailPath: dto.thumbnailPath }),
      },
      include: {
        category: true,
        files: true,
      },
    });

    if (dto.expiryDate !== undefined) {
      await this.remindersService.syncRemindersForDocument(
        userId,
        id,
        updated.expiryDate,
        updated.title,
      );
    }

    await this.auditService.log({
      userId,
      action: AuditAction.DOCUMENT_UPDATE,
      documentId: id,
      ipAddress,
      userAgent,
      metadata: { title: updated.title },
    });

    return updated;
  }

  async delete(userId: string, id: string, ipAddress?: string, userAgent?: string) {
    const document = await this.findOne(userId, id);

    // Delete primary file from storage
    if (document.storagePath) {
      await this.storageService.delete(document.storagePath);
    }
    if (document.thumbnailPath) {
      await this.storageService.delete(document.thumbnailPath);
    }

    await this.auditService.log({
      userId,
      action: AuditAction.DOCUMENT_DELETE,
      documentId: id,
      ipAddress,
      userAgent,
      metadata: { title: document.title },
    });

    await this.prisma.document.delete({
      where: { id },
    });

    return {
      success: true,
      message: 'Document permanently deleted',
    };
  }

  async toggleFavorite(userId: string, id: string) {
    const document = await this.findOne(userId, id);
    return this.prisma.document.update({
      where: { id },
      data: { isFavorite: !document.isFavorite },
      include: { category: true },
    });
  }

  async toggleArchive(userId: string, id: string) {
    const document = await this.findOne(userId, id);
    return this.prisma.document.update({
      where: { id },
      data: { isArchived: !document.isArchived },
      include: { category: true },
    });
  }

  async getStats(userId: string) {
    const now = new Date();
    const in30Days = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    const [
      total,
      favorites,
      archived,
      expiringSoon,
      expired,
      valid,
      noExpiry,
      ocrProcessing,
      ocrCompleted,
      storageSum,
      categoryCounts,
      attentionRequired,
    ] = await Promise.all([
      this.prisma.document.count({ where: { userId, isArchived: false } }),
      this.prisma.document.count({ where: { userId, isFavorite: true, isArchived: false } }),
      this.prisma.document.count({ where: { userId, isArchived: true } }),
      this.prisma.document.count({
        where: {
          userId,
          isArchived: false,
          expiryDate: { gte: now, lte: in30Days },
        },
      }),
      this.prisma.document.count({
        where: {
          userId,
          isArchived: false,
          expiryDate: { lt: now },
        },
      }),
      this.prisma.document.count({
        where: {
          userId,
          isArchived: false,
          OR: [
            { expiryDate: null },
            { expiryDate: { gte: now } },
          ],
        },
      }),
      this.prisma.document.count({
        where: {
          userId,
          isArchived: false,
          expiryDate: null,
        },
      }),
      this.prisma.document.count({
        where: {
          userId,
          ocrStatus: 'PROCESSING',
        },
      }),
      this.prisma.document.count({
        where: {
          userId,
          ocrStatus: 'COMPLETED',
        },
      }),
      this.prisma.document.aggregate({
        where: { userId },
        _sum: { fileSize: true },
      }),
      this.prisma.category.findMany({
        where: { userId },
        select: {
          id: true,
          name: true,
          icon: true,
          color: true,
          _count: {
            select: { documents: { where: { isArchived: false } } },
          },
        },
      }),
      this.prisma.document.findMany({
        where: {
          userId,
          isArchived: false,
          expiryDate: { lte: in30Days },
        },
        orderBy: { expiryDate: 'asc' },
        take: 5,
        select: {
          id: true,
          title: true,
          documentType: true,
          expiryDate: true,
          ocrStatus: true,
          ocrConfidence: true,
        },
      }),
    ]);

    return {
      totalDocuments: total,
      validDocuments: valid,
      expiringSoonDocuments: expiringSoon,
      expiredDocuments: expired,
      noExpiryDocuments: noExpiry,
      ocrProcessingCount: ocrProcessing,
      ocrCompletedCount: ocrCompleted,
      favoriteDocuments: favorites,
      archivedDocuments: archived,
      totalStorageBytes: storageSum._sum.fileSize || 0,
      attentionRequired: attentionRequired.map((doc) => {
        const isExp = doc.expiryDate ? new Date(doc.expiryDate) < now : false;
        return {
          ...doc,
          status: isExp ? 'EXPIRED' : 'EXPIRING_SOON',
        };
      }),
      categories: categoryCounts.map((c) => ({
        id: c.id,
        name: c.name,
        icon: c.icon,
        color: c.color,
        count: c._count.documents,
      })),
    };
  }

  async getVersions(userId: string, documentId: string) {
    await this.findOne(userId, documentId);
    return this.prisma.documentVersion.findMany({
      where: { documentId },
      orderBy: { versionNumber: 'desc' },
    });
  }

  async createVersion(
    userId: string,
    documentId: string,
    dto: CreateVersionDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const document = await this.findOne(userId, documentId);

    const latestVersion = await this.prisma.documentVersion.findFirst({
      where: { documentId },
      orderBy: { versionNumber: 'desc' },
    });

    const nextVer = (latestVersion?.versionNumber || 1) + 1;
    const now = new Date();

    const [version, updatedDoc] = await this.prisma.$transaction([
      this.prisma.documentVersion.create({
        data: {
          documentId,
          versionNumber: nextVer,
          fileSize: dto.fileSize,
          storagePath: dto.storagePath,
          checksum: dto.checksum || null,
          changeNotes: dto.changeNotes || `Uploaded version ${nextVer}`,
          deviceId: dto.deviceId || null,
          createdById: userId,
        },
      }),
      this.prisma.document.update({
        where: { id: documentId },
        data: {
          storagePath: dto.storagePath,
          fileSize: dto.fileSize,
          checksum: dto.checksum || null,
          syncStatus: 'SYNCED',
          lastSyncedAt: now,
        },
        include: { category: true, versions: true },
      }),
    ]);

    await this.auditService.log({
      userId,
      action: AuditAction.DOCUMENT_UPDATE,
      documentId,
      ipAddress,
      userAgent,
      metadata: {
        newVersionNumber: nextVer,
        fileSize: dto.fileSize,
      },
    });

    return {
      version,
      document: updatedDoc,
    };
  }

  async downloadVersion(userId: string, documentId: string, versionId: string) {
    await this.findOne(userId, documentId);

    const version = await this.prisma.documentVersion.findUnique({
      where: { id: versionId },
    });

    if (!version || version.documentId !== documentId) {
      throw new NotFoundException('Document version not found');
    }

    return this.storageService.download(version.storagePath);
  }
}
