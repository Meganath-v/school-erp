import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class FeedbackService {
  constructor(private prisma: PrismaService) {}

  async getFeedbacks(schoolId: string, userId: string, role: string, category?: string, status?: string) {
    const where: any = { schoolId };

    // Role-based visibility
    if (role === 'PARENT' || role === 'STUDENT') {
      // Submitter can only see feedbacks they submitted
      where.submitterId = userId;
    } else if (role === 'CLASS_TEACHER' || role === 'SUBJECT_TEACHER') {
      // Teachers can see feedbacks submitted by them or targeted to them
      where.OR = [
        { submitterId: userId },
        { targetId: userId },
        { targetType: { in: ['TEACHER', 'ACADEMIC', 'STUDENT'] } },
      ];
    }
    // SCHOOL_ADMIN, PRINCIPAL, OFFICE see all

    if (category) {
      where.category = category;
    }
    if (status) {
      where.status = status;
    }

    const feedbacks = await this.prisma.feedback.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        submitter: {
          select: { id: true, firstName: true, lastName: true, email: true },
        },
      },
    });

    // Mask submitter name if anonymous and user is not admin
    return feedbacks.map((f) => {
      if (f.isAnonymous && f.submitterId !== userId && role !== 'SCHOOL_ADMIN' && role !== 'PRINCIPAL') {
        return {
          ...f,
          submitter: { id: 'ANONYMOUS', firstName: 'Anonymous', lastName: 'Member', email: '' },
        };
      }
      return f;
    });
  }

  async submitFeedback(schoolId: string, userId: string, data: any) {
    const feedback = await this.prisma.feedback.create({
      data: {
        schoolId,
        submitterId: userId,
        targetType: data.targetType || 'GENERAL',
        targetId: data.targetId,
        targetName: data.targetName,
        category: data.category || 'GENERAL',
        title: data.title,
        content: data.content,
        rating: data.rating ? Math.min(Math.max(Number(data.rating), 1), 5) : null,
        isAnonymous: !!data.isAnonymous,
        status: 'SUBMITTED',
      },
    });

    // Notify School Administrators
    const admins = await this.prisma.userSchoolMembership.findMany({
      where: {
        schoolId,
        defaultRole: { in: ['SCHOOL_ADMIN', 'PRINCIPAL'] },
      },
    });

    for (const admin of admins) {
      await this.prisma.notification.create({
        data: {
          schoolId,
          userId: admin.userId,
          title: `New Feedback Received: ${data.title}`,
          body: `Category: ${data.category}. ${data.content.slice(0, 100)}...`,
          channel: 'IN_APP',
          status: 'UNREAD',
          eventKey: 'FEEDBACK_SUBMITTED',
          metadata: JSON.stringify({ feedbackId: feedback.id }),
        },
      });
    }

    return feedback;
  }

  async respondToFeedback(
    schoolId: string,
    responderUserId: string,
    responderName: string,
    id: string,
    response: string,
    newStatus: string = 'RESOLVED',
  ) {
    const feedback = await this.prisma.feedback.findFirst({
      where: { id, schoolId },
    });

    if (!feedback) {
      throw new NotFoundException('Feedback not found');
    }

    const updated = await this.prisma.feedback.update({
      where: { id },
      data: {
        response,
        respondedById: responderUserId,
        respondedByName: responderName,
        respondedAt: new Date(),
        status: newStatus,
        updatedAt: new Date(),
      },
    });

    // Notify the submitter if not anonymous
    if (!feedback.isAnonymous) {
      await this.prisma.notification.create({
        data: {
          schoolId,
          userId: feedback.submitterId,
          title: `Resolution for your Feedback: "${feedback.title}"`,
          body: `Status: ${newStatus}. Response: ${response}`,
          channel: 'IN_APP',
          status: 'UNREAD',
          eventKey: 'FEEDBACK_RESOLVED',
          metadata: JSON.stringify({ feedbackId: feedback.id }),
        },
      });
    }

    return updated;
  }

  async updateFeedbackStatus(schoolId: string, id: string, status: string) {
    const feedback = await this.prisma.feedback.findFirst({
      where: { id, schoolId },
    });

    if (!feedback) {
      throw new NotFoundException('Feedback not found');
    }

    return this.prisma.feedback.update({
      where: { id },
      data: { status, updatedAt: new Date() },
    });
  }
}

