import { Injectable, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AnnouncementsService {
  constructor(private prisma: PrismaService) {}

  async getAnnouncements(schoolId: string, role?: string) {
    const where: any = { schoolId };
    if (role && role !== 'SCHOOL_ADMIN' && role !== 'PLATFORM_OWNER' && role !== 'PRINCIPAL') {
      where.targetRole = { in: ['ALL', role] };
    }

    return this.prisma.announcement.findMany({
      where,
      orderBy: { publishedAt: 'desc' },
    });
  }

  async createAnnouncement(schoolId: string, data: any, sender?: { userId: string; role: string; name: string }) {
    // Section 8 & ANN-02, ANN-03: Class teacher audience restriction
    if (sender?.role === 'CLASS_TEACHER') {
      if (data.targetRole === 'ALL' || data.isSchoolWide) {
        throw new ForbiddenException(
          'Class teachers are restricted from publishing school-wide announcements. You may only broadcast notices to your assigned class and parents (ANN-02, ANN-03).',
        );
      }
    }

    const announcement = await this.prisma.announcement.create({
      data: {
        schoolId,
        title: data.title,
        content: data.content,
        targetRole: data.targetRole || 'ALL',
        priority: data.priority || 'NORMAL',
        authorName: data.authorName || sender?.name || 'School Administration',
      },
    });

    // Audit log
    await this.prisma.auditLog.create({
      data: {
        schoolId,
        actorId: sender?.userId || 'System',
        actorName: sender?.name || 'Author',
        action: 'ANNOUNCEMENT_PUBLISHED',
        entity: 'Announcement',
        entityId: announcement.id,
        details: JSON.stringify({ title: data.title, targetRole: data.targetRole, priority: data.priority }),
      },
    });

    return announcement;
  }

  async deleteAnnouncement(schoolId: string, id: string) {
    return this.prisma.announcement.deleteMany({
      where: { id, schoolId },
    });
  }
}
