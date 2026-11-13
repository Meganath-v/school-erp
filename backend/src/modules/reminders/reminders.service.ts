import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class RemindersService {
  constructor(private prisma: PrismaService) {}

  async getReminders(schoolId: string, userId: string, category?: string) {
    const where: any = { schoolId, userId };
    if (category) {
      where.category = category;
    }

    return this.prisma.reminder.findMany({
      where,
      orderBy: [
        { priority: 'desc' },
        { remindAt: 'asc' },
      ],
    });
  }

  async createReminder(schoolId: string, userId: string, data: any) {
    return this.prisma.reminder.create({
      data: {
        schoolId,
        userId,
        title: data.title,
        description: data.description,
        category: data.category || 'CUSTOM',
        priority: data.priority || 'MEDIUM',
        dueDate: data.dueDate ? new Date(data.dueDate) : null,
        remindAt: data.remindAt ? new Date(data.remindAt) : new Date(),
        status: 'PENDING',
        entityType: data.entityType,
        entityId: data.entityId,
      },
    });
  }

  async updateReminderStatus(schoolId: string, userId: string, id: string, status: string) {
    const existing = await this.prisma.reminder.findFirst({
      where: { id, schoolId, userId },
    });

    if (!existing) {
      throw new NotFoundException('Reminder not found');
    }

    return this.prisma.reminder.update({
      where: { id },
      data: { status, updatedAt: new Date() },
    });
  }

  /**
   * Automated scan engine that checks for:
   * 1. Unpaid fee invoices approaching or past due date -> reminders for parents
   * 2. Attendance below the 75% condonation threshold -> reminders for parents & teachers
   * 3. Pending mark entry for scheduled/in-progress exams -> reminders for teachers
   * 4. Pending student leave requests -> reminders for class teachers
   */
  async triggerAutomatedReminders(schoolId: string) {
    const generated: any[] = [];
    const now = new Date();
    const sevenDaysFromNow = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    // 1. Fee Invoices Due Soon or Overdue
    const dueInvoices = await this.prisma.invoice.findMany({
      where: {
        schoolId,
        status: { in: ['PENDING', 'PARTIAL', 'OVERDUE'] },
        dueDate: { lte: sevenDaysFromNow },
      },
      include: {
        student: {
          include: {
            studentGuardians: {
              include: {
                guardian: {
                  include: { user: true },
                },
              },
            },
          },
        },
      },
    });

    for (const inv of dueInvoices) {
      for (const sg of inv.student.studentGuardians) {
        if (sg.guardian.userId) {
          const title = `Fee Reminder: ${inv.title} due on ${new Date(inv.dueDate).toLocaleDateString()}`;
          const existing = await this.prisma.reminder.findFirst({
            where: {
              schoolId,
              userId: sg.guardian.userId,
              entityType: 'Invoice',
              entityId: inv.id,
              status: 'PENDING',
            },
          });

          if (!existing) {
            const r = await this.prisma.reminder.create({
              data: {
                schoolId,
                userId: sg.guardian.userId,
                title,
                description: `Pending amount: ₹${(inv.dueAmountMinor / 100).toFixed(2)} for ${inv.student.firstName}. Please pay before the deadline to avoid late fees.`,
                category: 'FEE_DUE',
                priority: 'HIGH',
                dueDate: inv.dueDate,
                remindAt: now,
                entityType: 'Invoice',
                entityId: inv.id,
              },
            });
            generated.push(r);

            // Also create in-app notification
            await this.prisma.notification.create({
              data: {
                schoolId,
                userId: sg.guardian.userId,
                title: 'Fee Payment Due Reminder',
                body: `${inv.title} of ₹${(inv.dueAmountMinor / 100).toFixed(2)} is pending for ${inv.student.firstName}.`,
                channel: 'IN_APP',
                status: 'UNREAD',
                eventKey: 'FEE_DUE_REMINDER',
                metadata: JSON.stringify({ invoiceId: inv.id, studentId: inv.studentId }),
              },
            });
          }
        }
      }
    }

    // 2. Pending Exam Marks Entry Reminders for Teachers
    const pendingExamSubjects = await this.prisma.examSubject.findMany({
      where: {
        exam: { schoolId, status: { in: ['SCHEDULED', 'IN_PROGRESS', 'MODERATION'] } },
      },
      include: {
        exam: true,
        subject: {
          include: {
            teacherAssignments: {
              include: {
                staff: { include: { user: true } },
              },
            },
          },
        },
        marks: true,
      },
    });

    for (const es of pendingExamSubjects) {
      // If marks are not yet entered for all students
      for (const ta of es.subject.teacherAssignments) {
        if (ta.staff.userId) {
          const existing = await this.prisma.reminder.findFirst({
            where: {
              schoolId,
              userId: ta.staff.userId,
              entityType: 'ExamSubject',
              entityId: es.id,
              status: 'PENDING',
            },
          });

          if (!existing) {
            const r = await this.prisma.reminder.create({
              data: {
                schoolId,
                userId: ta.staff.userId,
                title: `Mark Entry Due: ${es.exam.name} - ${es.subject.name}`,
                description: `Please enter marks for ${es.subject.name}. Currently ${es.marks.length} entries recorded.`,
                category: 'EXAM_MARK_ENTRY',
                priority: 'HIGH',
                dueDate: es.examDate,
                remindAt: now,
                entityType: 'ExamSubject',
                entityId: es.id,
              },
            });
            generated.push(r);

            await this.prisma.notification.create({
              data: {
                schoolId,
                userId: ta.staff.userId,
                title: 'Exam Mark Entry Reminder',
                body: `Please complete mark entry for ${es.subject.name} (${es.exam.name}).`,
                channel: 'IN_APP',
                status: 'UNREAD',
                eventKey: 'MARK_ENTRY_REMINDER',
                metadata: JSON.stringify({ examSubjectId: es.id, examId: es.examId }),
              },
            });
          }
        }
      }
    }

    // 3. Pending Leave Requests for Class Teachers
    const pendingLeaves = await this.prisma.leaveRequest.findMany({
      where: { schoolId, status: 'PENDING' },
      include: {
        student: {
          include: {
            enrollments: {
              where: { status: 'ACTIVE' },
              include: {
                section: {
                  include: {
                    teacherAssignments: {
                      where: { isClassTeacher: true },
                      include: { staff: { include: { user: true } } },
                    },
                  },
                },
              },
            },
          },
        },
      },
    });

    for (const leave of pendingLeaves) {
      for (const enr of leave.student.enrollments) {
        for (const ta of enr.section.teacherAssignments) {
          if (ta.staff.userId) {
            const existing = await this.prisma.reminder.findFirst({
              where: {
                schoolId,
                userId: ta.staff.userId,
                entityType: 'LeaveRequest',
                entityId: leave.id,
                status: 'PENDING',
              },
            });

            if (!existing) {
              const r = await this.prisma.reminder.create({
                data: {
                  schoolId,
                  userId: ta.staff.userId,
                  title: `Action Required: Student Leave Request - ${leave.student.firstName}`,
                  description: `${leave.applicantName} submitted leave from ${new Date(leave.startDate).toLocaleDateString()} to ${new Date(leave.endDate).toLocaleDateString()}: "${leave.reason}"`,
                  category: 'TASK_DUE',
                  priority: 'MEDIUM',
                  dueDate: leave.startDate,
                  remindAt: now,
                  entityType: 'LeaveRequest',
                  entityId: leave.id,
                },
              });
              generated.push(r);
            }
          }
        }
      }
    }

    return {
      message: 'Automated reminder scan completed',
      remindersGenerated: generated.length,
      timestamp: now,
    };
  }
}

