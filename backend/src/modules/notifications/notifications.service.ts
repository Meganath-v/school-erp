import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { GetNotificationsQueryDto } from './notifications.dto';

@Injectable()
export class NotificationsService {
  constructor(private prisma: PrismaService) {}

  async getNotifications(schoolId: string, userId: string, query?: GetNotificationsQueryDto) {
    const where: any = { schoolId, userId };

    if (query?.status && query.status !== 'ALL') {
      where.status = query.status;
    }

    if (query?.priority && query.priority !== 'ALL') {
      where.priority = query.priority;
    }

    if (query?.search && query.search.trim()) {
      const s = query.search.trim();
      where.OR = [
        { title: { contains: s } },
        { body: { contains: s } },
      ];
    }

    const page = Math.max(1, query?.page ? Number(query.page) : 1);
    const limit = Math.max(1, Math.min(100, query?.limit ? Number(query.limit) : 20));
    const skip = (page - 1) * limit;

    const [totalCount, list, unreadCount] = await Promise.all([
      this.prisma.notification.count({ where }),
      this.prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.notification.count({
        where: { schoolId, userId, status: 'UNREAD' },
      }),
    ]);

    return {
      unreadCount,
      totalCount,
      page,
      limit,
      totalPages: Math.ceil(totalCount / limit),
      notifications: list,
    };
  }

  async markAsRead(schoolId: string, userId: string, id: string) {
    const notification = await this.prisma.notification.findFirst({
      where: { id, schoolId, userId },
    });

    if (!notification) {
      throw new NotFoundException('Notification not found');
    }

    return this.prisma.notification.update({
      where: { id },
      data: {
        status: 'READ',
        readAt: new Date(),
      },
    });
  }

  async markAllAsRead(schoolId: string, userId: string) {
    const res = await this.prisma.notification.updateMany({
      where: { schoolId, userId, status: 'UNREAD' },
      data: {
        status: 'READ',
        readAt: new Date(),
      },
    });

    return {
      message: 'All unread notifications marked as read',
      count: res.count,
    };
  }

  async updatePreferences(schoolId: string, userId: string, preferences: any) {
    return {
      message: 'Notification preferences updated successfully',
      preferences,
    };
  }

  async getDeliveryLogs(schoolId: string, recipientId?: string, limit = 50) {
    const where: any = { schoolId };
    if (recipientId) {
      where.recipientId = recipientId;
    }

    return this.prisma.notificationDeliveryLog.findMany({
      where,
      orderBy: { executedAt: 'desc' },
      take: Math.min(100, Number(limit)),
      include: {
        user: { select: { id: true, firstName: true, lastName: true, email: true } },
      },
    });
  }
}
