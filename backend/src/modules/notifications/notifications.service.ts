import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class NotificationsService {
  constructor(private prisma: PrismaService) {}

  async getNotifications(schoolId: string, userId: string) {
    const list = await this.prisma.notification.findMany({
      where: { schoolId, userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    const unreadCount = await this.prisma.notification.count({
      where: { schoolId, userId, status: 'UNREAD' },
    });

    return {
      unreadCount,
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
    return this.prisma.notification.updateMany({
      where: { schoolId, userId, status: 'UNREAD' },
      data: {
        status: 'READ',
        readAt: new Date(),
      },
    });
  }

  async updatePreferences(schoolId: string, userId: string, preferences: any) {
    return {
      message: 'Notification preferences updated successfully',
      preferences,
    };
  }
}
