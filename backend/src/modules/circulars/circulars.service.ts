import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class CircularsService {
  constructor(private prisma: PrismaService) {}

  async getCirculars(schoolId: string, userId: string, role: string, classId?: string) {
    const where: any = { schoolId, status: 'PUBLISHED' };

    // Determine target audiences this role can see
    if (role === 'PARENT') {
      where.targetAudience = { in: ['ALL', 'ALL_PARENTS', 'CLASS_PARENTS'] };
    } else if (role === 'STUDENT') {
      where.targetAudience = { in: ['ALL', 'CLASS_STUDENTS'] };
    } else if (role === 'CLASS_TEACHER' || role === 'SUBJECT_TEACHER') {
      where.targetAudience = { in: ['ALL', 'ALL_TEACHERS', 'CLASS_PARENTS', 'CLASS_STUDENTS'] };
    } else if (role === 'OFFICE') {
      where.targetAudience = { in: ['ALL', 'OFFICE_STAFF', 'ALL_TEACHERS', 'ALL_PARENTS'] };
    }
    // SCHOOL_ADMIN and PRINCIPAL can see all

    const circulars = await this.prisma.circular.findMany({
      where,
      orderBy: { publishedAt: 'desc' },
      include: {
        class: { select: { id: true, name: true } },
        section: { select: { id: true, name: true } },
        acknowledgements: {
          where: { userId },
          select: { id: true, acknowledgedAt: true, remarks: true },
        },
      },
    });

    return circulars.map((c) => ({
      ...c,
      isAcknowledged: c.acknowledgements.length > 0,
      acknowledgedAt: c.acknowledgements[0]?.acknowledgedAt || null,
    }));
  }

  async createCircular(
    schoolId: string,
    sender: { userId: string; name: string; role: string },
    data: any,
  ) {
    // 1. Role Verification & Scope Guard
    if (sender.role === 'CLASS_TEACHER') {
      // Class Teacher can ONLY send circulars to their class / section
      if (data.targetAudience === 'ALL' || data.targetAudience === 'ALL_PARENTS' || data.targetAudience === 'ALL_TEACHERS') {
        throw new ForbiddenException(
          'Class teachers can only dispatch circulars targeted to their assigned class and section parents/students (CIR-CT-01). School-wide circulars must be dispatched by Office or School Admin.',
        );
      }
      if (!data.classId) {
        // Find assigned class if not explicitly passed
        const assignment = await this.prisma.teacherAssignment.findFirst({
          where: {
            schoolId,
            staff: { userId: sender.userId },
            isClassTeacher: true,
          },
        });
        if (assignment) {
          data.classId = assignment.classId;
          data.sectionId = assignment.sectionId;
        }
      }
    }

    // 2. Sequential Circular Number Generation
    const count = await this.prisma.circular.count({ where: { schoolId } });
    const year = new Date().getFullYear();
    const circularNumber = `CIR/${year}/${String(count + 1).padStart(3, '0')}`;

    // 3. Sender Type determination
    let senderType = 'OFFICE_EMPLOYEE';
    if (sender.role === 'CLASS_TEACHER') {
      senderType = 'CLASS_TEACHER';
    } else if (sender.role === 'PRINCIPAL') {
      senderType = 'PRINCIPAL';
    } else if (sender.role === 'SCHOOL_ADMIN') {
      senderType = 'SCHOOL_ADMIN';
    }

    const circular = await this.prisma.circular.create({
      data: {
        schoolId,
        circularNumber,
        title: data.title,
        content: data.content,
        senderType,
        senderId: sender.userId,
        senderName: sender.name || (sender.role === 'CLASS_TEACHER' ? 'Class Teacher' : 'Office Administration'),
        targetAudience: data.targetAudience || 'ALL',
        classId: data.classId || null,
        sectionId: data.sectionId || null,
        priority: data.priority || 'NORMAL',
        requiresAck: !!data.requiresAck,
        ackDeadline: data.ackDeadline ? new Date(data.ackDeadline) : null,
        attachments: data.attachments ? JSON.stringify(data.attachments) : null,
        status: 'PUBLISHED',
      },
    });

    // 4. Audit Log
    await this.prisma.auditLog.create({
      data: {
        schoolId,
        actorId: sender.userId,
        actorName: sender.name,
        action: 'CIRCULAR_DISPATCHED',
        entity: 'Circular',
        entityId: circular.id,
        details: JSON.stringify({
          circularNumber,
          title: data.title,
          senderType,
          targetAudience: data.targetAudience,
        }),
      },
    });

    // 5. Create In-App Notifications for targets
    await this.notifyAudience(schoolId, circular);

    return circular;
  }

  async acknowledgeCircular(
    schoolId: string,
    userId: string,
    userName: string,
    userRole: string,
    circularId: string,
    remarks?: string,
  ) {
    const circular = await this.prisma.circular.findFirst({
      where: { id: circularId, schoolId },
    });

    if (!circular) {
      throw new NotFoundException('Circular not found');
    }

    return this.prisma.circularAcknowledgement.upsert({
      where: {
        circularId_userId: {
          circularId,
          userId,
        },
      },
      update: {
        acknowledgedAt: new Date(),
        remarks,
      },
      create: {
        circularId,
        userId,
        userName,
        userRole,
        acknowledgedAt: new Date(),
        remarks,
      },
    });
  }

  async getAcknowledgements(schoolId: string, circularId: string) {
    const circular = await this.prisma.circular.findFirst({
      where: { id: circularId, schoolId },
      include: {
        acknowledgements: {
          orderBy: { acknowledgedAt: 'desc' },
        },
      },
    });

    if (!circular) {
      throw new NotFoundException('Circular not found');
    }

    return {
      circularId: circular.id,
      circularNumber: circular.circularNumber,
      title: circular.title,
      totalAcknowledgements: circular.acknowledgements.length,
      acknowledgements: circular.acknowledgements,
    };
  }

  private async notifyAudience(schoolId: string, circular: any) {
    // Collect target user IDs
    let targetUserIds: string[] = [];

    if (circular.targetAudience === 'ALL' || circular.targetAudience === 'ALL_PARENTS') {
      const guardians = await this.prisma.guardian.findMany({
        where: { schoolId, userId: { not: null } },
        select: { userId: true },
      });
      targetUserIds.push(...guardians.map((g) => g.userId!).filter(Boolean));
    }

    if (circular.targetAudience === 'ALL' || circular.targetAudience === 'ALL_TEACHERS') {
      const staffMembers = await this.prisma.staff.findMany({
        where: { schoolId, userId: { not: null } },
        select: { userId: true },
      });
      targetUserIds.push(...staffMembers.map((s) => s.userId!).filter(Boolean));
    }

    if (circular.classId && circular.targetAudience.includes('CLASS')) {
      const enrollments = await this.prisma.enrollment.findMany({
        where: { classId: circular.classId, status: 'ACTIVE' },
        include: {
          student: {
            include: {
              studentGuardians: {
                include: { guardian: true },
              },
            },
          },
        },
      });

      for (const e of enrollments) {
        for (const sg of e.student.studentGuardians) {
          if (sg.guardian.userId) {
            targetUserIds.push(sg.guardian.userId);
          }
        }
      }
    }

    // Deduplicate IDs
    const uniqueIds = Array.from(new Set(targetUserIds)).slice(0, 100);

    for (const uId of uniqueIds) {
      await this.prisma.notification.create({
        data: {
          schoolId,
          userId: uId,
          title: `New Circular: ${circular.title}`,
          body: `From: ${circular.senderName} (${circular.circularNumber}). ${circular.content.slice(0, 120)}...`,
          channel: 'IN_APP',
          status: 'UNREAD',
          eventKey: 'CIRCULAR_ISSUED',
          metadata: JSON.stringify({ circularId: circular.id, circularNumber: circular.circularNumber }),
        },
      });
    }
  }
}

