import { Injectable, Logger, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface CreateCustomReminderDto {
  reminderDate: string;
  notes?: string;
}

@Injectable()
export class RemindersService {
  private readonly logger = new Logger(RemindersService.name);

  // Default reminder intervals in days prior to expiry
  private readonly reminderIntervals = [90, 30, 15, 7, 1];

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Idempotently schedule 90, 30, 15, 7, and 1-day reminders for an expiring document
   */
  async syncRemindersForDocument(
    userId: string,
    documentId: string,
    expiryDate?: Date | null,
    documentTitle?: string,
  ): Promise<number> {
    if (!expiryDate) {
      // If expiry date was removed, delete untriggered reminders
      await this.prisma.documentReminder.deleteMany({
        where: {
          documentId,
          userId,
          isTriggered: false,
        },
      });
      return 0;
    }

    const expiryTime = new Date(expiryDate).getTime();
    const nowTime = Date.now();
    let scheduledCount = 0;

    for (const days of this.reminderIntervals) {
      const targetTime = expiryTime - days * 24 * 60 * 60 * 1000;
      // Only schedule if the reminder date is in the future
      if (targetTime > nowTime) {
        const reminderDate = new Date(targetTime);

        // Check if an untriggered reminder already exists near this date (within same day)
        const dayStart = new Date(targetTime);
        dayStart.setUTCHours(0, 0, 0, 0);
        const dayEnd = new Date(targetTime);
        dayEnd.setUTCHours(23, 59, 59, 999);

        const existing = await this.prisma.documentReminder.findFirst({
          where: {
            documentId,
            userId,
            reminderDate: {
              gte: dayStart,
              lte: dayEnd,
            },
          },
        });

        if (!existing) {
          await this.prisma.documentReminder.create({
            data: {
              userId,
              documentId,
              reminderDate,
              notes: `${documentTitle || 'Document'} expires in ${days} days`,
              isTriggered: false,
            },
          });
          scheduledCount++;
        }
      }
    }

    this.logger.log(`Synced ${scheduledCount} reminder(s) for document ${documentId}`);
    return scheduledCount;
  }

  /**
   * Scan and trigger any reminders due, generating in-app Notifications
   */
  async checkAndTriggerReminders(): Promise<{ triggeredCount: number; notificationsCreated: number }> {
    const now = new Date();

    const dueReminders = await this.prisma.documentReminder.findMany({
      where: {
        isTriggered: false,
        reminderDate: { lte: now },
      },
      include: {
        document: true,
      },
    });

    let notificationsCreated = 0;

    for (const rem of dueReminders) {
      const doc = rem.document;
      if (!doc || doc.isArchived) {
        // Mark as triggered so we don't re-query archived/deleted items
        await this.prisma.documentReminder.update({
          where: { id: rem.id },
          data: { isTriggered: true },
        });
        continue;
      }

      // Calculate days remaining
      const expiry = doc.expiryDate ? new Date(doc.expiryDate) : null;
      let daysRemaining = 0;
      let isExpired = false;

      if (expiry) {
        const diffMs = expiry.getTime() - now.getTime();
        daysRemaining = Math.ceil(diffMs / (24 * 60 * 60 * 1000));
        isExpired = daysRemaining <= 0;
      }

      const type = isExpired ? 'DOCUMENT_EXPIRED' : 'DOCUMENT_EXPIRING';
      const title = isExpired
        ? `Document Expired: ${doc.title}`
        : `Expiry Alert: ${doc.title}`;
      const message = isExpired
        ? `Your document "${doc.title}" expired on ${expiry?.toLocaleDateString() || 'recently'}. Please renew or archive.`
        : `Your document "${doc.title}" expires in ${daysRemaining} day${daysRemaining === 1 ? '' : 's'}.`;

      await this.prisma.notification.create({
        data: {
          userId: rem.userId,
          title,
          message,
          type,
          metadata: {
            documentId: doc.id,
            documentTitle: doc.title,
            daysRemaining,
            expiryDate: doc.expiryDate,
          },
        },
      });

      await this.prisma.documentReminder.update({
        where: { id: rem.id },
        data: { isTriggered: true },
      });

      notificationsCreated++;
    }

    return {
      triggeredCount: dueReminders.length,
      notificationsCreated,
    };
  }

  /**
   * Create an in-app notification directly (e.g. for OCR_COMPLETE or DOCUMENT_CLASSIFIED)
   */
  async createNotification(
    userId: string,
    type: 'DOCUMENT_EXPIRING' | 'DOCUMENT_EXPIRED' | 'OCR_COMPLETE' | 'DOCUMENT_CLASSIFIED' | 'SECURITY' | 'GENERAL',
    title: string,
    message: string,
    metadata?: Record<string, any>,
  ) {
    return this.prisma.notification.create({
      data: {
        userId,
        type,
        title,
        message,
        metadata: metadata || {},
      },
    });
  }

  async getRemindersForDocument(userId: string, documentId: string) {
    return this.prisma.documentReminder.findMany({
      where: { userId, documentId },
      orderBy: { reminderDate: 'asc' },
    });
  }

  async addCustomReminder(userId: string, documentId: string, dto: CreateCustomReminderDto) {
    const doc = await this.prisma.document.findUnique({
      where: { id: documentId },
    });
    if (!doc) throw new NotFoundException('Document not found');
    if (doc.userId !== userId) throw new ForbiddenException('Not authorized');

    return this.prisma.documentReminder.create({
      data: {
        userId,
        documentId,
        reminderDate: new Date(dto.reminderDate),
        notes: dto.notes || `Reminder for ${doc.title}`,
        isTriggered: false,
      },
    });
  }

  async deleteReminder(userId: string, reminderId: string) {
    const reminder = await this.prisma.documentReminder.findUnique({
      where: { id: reminderId },
    });
    if (!reminder) throw new NotFoundException('Reminder not found');
    if (reminder.userId !== userId) throw new ForbiddenException('Not authorized');

    await this.prisma.documentReminder.delete({
      where: { id: reminderId },
    });

    return { success: true };
  }
}
