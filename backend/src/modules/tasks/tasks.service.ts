import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class TasksService {
  constructor(private prisma: PrismaService) {}

  async getTasks(schoolId: string, userId: string, role?: string, status?: string) {
    const where: any = { schoolId, assignedToId: userId };
    if (status) {
      where.status = status;
    }

    const tasks = await this.prisma.task.findMany({
      where,
      orderBy: [
        { priority: 'desc' },
        { dueDate: 'asc' },
        { createdAt: 'desc' },
      ],
      include: {
        createdBy: {
          select: { firstName: true, lastName: true },
        },
      },
    });

    // If user has zero tasks, generate contextual initial action tasks based on their role
    if (tasks.length === 0) {
      return this.generateDefaultTasksForRole(schoolId, userId, role);
    }

    return tasks;
  }

  async getTaskStats(schoolId: string, userId: string) {
    const total = await this.prisma.task.count({ where: { schoolId, assignedToId: userId } });
    const pending = await this.prisma.task.count({ where: { schoolId, assignedToId: userId, status: 'PENDING' } });
    const inProgress = await this.prisma.task.count({ where: { schoolId, assignedToId: userId, status: 'IN_PROGRESS' } });
    const completed = await this.prisma.task.count({ where: { schoolId, assignedToId: userId, status: 'COMPLETED' } });
    const urgent = await this.prisma.task.count({
      where: { schoolId, assignedToId: userId, status: { in: ['PENDING', 'IN_PROGRESS'] }, priority: 'URGENT' },
    });

    return {
      total,
      pending,
      inProgress,
      completed,
      urgent,
      completionRate: total > 0 ? Math.round((completed / total) * 100) : 100,
    };
  }

  async createTask(schoolId: string, createdById: string, data: any) {
    return this.prisma.task.create({
      data: {
        schoolId,
        assignedToId: data.assignedToId || createdById,
        createdById,
        title: data.title,
        description: data.description,
        category: data.category || 'GENERAL',
        priority: data.priority || 'NORMAL',
        status: 'PENDING',
        dueDate: data.dueDate ? new Date(data.dueDate) : null,
        actionUrl: data.actionUrl,
        metadata: data.metadata ? JSON.stringify(data.metadata) : null,
      },
    });
  }

  async updateTaskStatus(schoolId: string, userId: string, id: string, status: string) {
    const task = await this.prisma.task.findFirst({
      where: { id, schoolId, assignedToId: userId },
    });

    if (!task) {
      throw new NotFoundException('Task not found');
    }

    return this.prisma.task.update({
      where: { id },
      data: {
        status,
        completedAt: status === 'COMPLETED' ? new Date() : null,
        updatedAt: new Date(),
      },
    });
  }

  private async generateDefaultTasksForRole(schoolId: string, userId: string, role?: string) {
    const defaultTasks: any[] = [];
    const today = new Date();
    const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const endOfWeek = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000);

    if (role === 'CLASS_TEACHER') {
      defaultTasks.push(
        {
          title: 'Mark Today’s Attendance',
          description: 'Submit morning session attendance roster and review absentees for Class 10-A.',
          category: 'ATTENDANCE',
          priority: 'URGENT',
          dueDate: today,
          actionUrl: '/attendance',
        },
        {
          title: 'Review Pending Student Leave Requests',
          description: 'Verify medical notes and grant approval for pending student leave applications.',
          category: 'LEAVE_APPROVAL',
          priority: 'HIGH',
          dueDate: tomorrow,
          actionUrl: '/leave-requests',
        },
        {
          title: 'Dispatch Class Circular for Sports Day',
          description: 'Send circular to parents regarding sports meet schedule and consent slips.',
          category: 'CIRCULAR',
          priority: 'NORMAL',
          dueDate: endOfWeek,
          actionUrl: '/circulars',
        },
      );
    } else if (role === 'SUBJECT_TEACHER') {
      defaultTasks.push(
        {
          title: 'Complete Mid-Term Exam Mark Entry',
          description: 'Enter marks for Grade 10 Mathematics or import via Excel template.',
          category: 'MARK_ENTRY',
          priority: 'HIGH',
          dueDate: tomorrow,
          actionUrl: '/exams',
        },
        {
          title: 'Submit Weekly Teaching Diary',
          description: 'Log topics taught, teaching methodology, and student engagement notes for Unit 2.',
          category: 'SYLLABUS',
          priority: 'NORMAL',
          dueDate: endOfWeek,
          actionUrl: '/teaching-diary',
        },
        {
          title: 'Grade Assignment Submissions',
          description: 'Evaluate uploaded homework assignments for Quadratic Equations.',
          category: 'ASSIGNMENT',
          priority: 'NORMAL',
          dueDate: endOfWeek,
          actionUrl: '/assignments',
        },
      );
    } else if (role === 'OFFICE' || role === 'SCHOOL_ADMIN') {
      defaultTasks.push(
        {
          title: 'Send Fee Reminder Circular to Defaulters',
          description: 'Issue official circular and notifications for upcoming Term 1 tuition fee payments.',
          category: 'FEE_PAYMENT',
          priority: 'HIGH',
          dueDate: tomorrow,
          actionUrl: '/fees',
        },
        {
          title: 'Audit Student Attendance Thresholds',
          description: 'Generate condonation eligibility list for students with less than 75% attendance.',
          category: 'ATTENDANCE',
          priority: 'NORMAL',
          dueDate: endOfWeek,
          actionUrl: '/reports',
        },
      );
    } else if (role === 'PARENT') {
      defaultTasks.push(
        {
          title: 'Pay Term 1 Tuition Fee',
          description: 'Complete fee invoice payment securely online before the due date.',
          category: 'FEE_PAYMENT',
          priority: 'HIGH',
          dueDate: endOfWeek,
          actionUrl: '/fees/pay',
        },
        {
          title: 'Acknowledge Annual Day Circular',
          description: 'Read and digitally sign the school circular regarding the Annual Cultural Fest.',
          category: 'CIRCULAR',
          priority: 'NORMAL',
          dueDate: endOfWeek,
          actionUrl: '/circulars',
        },
      );
    } else {
      defaultTasks.push({
        title: 'Complete Student Profile Information',
        description: 'Verify emergency contact details and blood group.',
        category: 'GENERAL',
        priority: 'NORMAL',
        dueDate: endOfWeek,
        actionUrl: '/profile',
      });
    }

    const createdList = [];
    for (const dt of defaultTasks) {
      const created = await this.prisma.task.create({
        data: {
          schoolId,
          assignedToId: userId,
          title: dt.title,
          description: dt.description,
          category: dt.category,
          priority: dt.priority,
          dueDate: dt.dueDate,
          actionUrl: dt.actionUrl,
          status: 'PENDING',
        },
      });
      createdList.push(created);
    }

    return createdList;
  }
}

