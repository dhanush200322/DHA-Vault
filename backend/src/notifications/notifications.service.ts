import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(userId: string) {
    const [items, unreadCount] = await Promise.all([
      this.prisma.notification.findMany({
        where: { userId },
        orderBy: [{ isRead: 'asc' }, { createdAt: 'desc' }],
        take: 50,
      }),
      this.prisma.notification.count({
        where: { userId, isRead: false },
      }),
    ]);

    return { items, unreadCount };
  }

  async markAsRead(userId: string, id: string) {
    const notification = await this.prisma.notification.findUnique({
      where: { id },
    });

    if (!notification || notification.userId !== userId) {
      throw new NotFoundException('Notification not found');
    }

    return this.prisma.notification.update({
      where: { id },
      data: { isRead: true },
    });
  }

  async markAllAsRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });

    return { success: true };
  }

  async createNotification(
    userId: string,
    title: string,
    message: string,
    type = 'GENERAL',
    metadata?: Record<string, any>,
  ) {
    return this.prisma.notification.create({
      data: {
        userId,
        title,
        message,
        type,
        metadata: metadata || undefined,
      },
    });
  }
}
