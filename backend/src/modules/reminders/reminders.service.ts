import { Injectable, Logger, NotFoundException, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateReminderDto } from './reminders.dto';

@Injectable()
export class RemindersService implements OnApplicationBootstrap, OnApplicationShutdown {
  private readonly logger = new Logger(RemindersService.name);
  private schedulerInterval: NodeJS.Timeout | null = null;
  private isScanRunning = false;

  constructor(private prisma: PrismaService) {}

  onApplicationBootstrap() {
    this.logger.log('Initializing Timezone-Aware Scheduled Reminder & Notification Engine...');
    // Initial evaluation 15 seconds after bootstrap
    setTimeout(() => {
      this.executeScheduledCycle().catch((err) =>
        this.logger.error(`Initial reminder scan failed: ${err.message}`, err.stack),
      );
    }, 15000);

    // Recurring evaluation every 30 minutes
    this.schedulerInterval = setInterval(() => {
      this.executeScheduledCycle().catch((err) =>
        this.logger.error(`Scheduled cycle execution error: ${err.message}`, err.stack),
      );
    }, 30 * 60 * 1000);
  }

  onApplicationShutdown() {
    if (this.schedulerInterval) {
      clearInterval(this.schedulerInterval);
      this.schedulerInterval = null;
      this.logger.log('Scheduled Reminder Engine safely halted.');
    }
  }

  /**
   * Automated cycle execution across all active schools
   */
  async executeScheduledCycle(): Promise<void> {
    if (this.isScanRunning) {
      this.logger.warn('Previous reminder scan cycle is still executing. Skipping overlapping interval.');
      return;
    }

    this.isScanRunning = true;
    try {
      const activeSchools = await this.prisma.school.findMany({
        where: { status: 'ACTIVE' },
        select: { id: true, name: true, code: true, timezone: true },
      });

      for (const school of activeSchools) {
        try {
          await this.triggerAutomatedReminders(school.id);
        } catch (schoolErr: any) {
          this.logger.error(`Automated scan error for school ${school.code}: ${schoolErr.message}`);
        }
      }
    } finally {
      this.isScanRunning = false;
    }
  }

  /**
   * List user reminders with optional category and status filtering
   */
  async getReminders(schoolId: string, userId: string, category?: string, status?: string) {
    const where: any = { schoolId, userId };
    if (category && category !== 'ALL') {
      where.category = category;
    }
    if (status && status !== 'ALL') {
      where.status = status;
    }

    return this.prisma.reminder.findMany({
      where,
      orderBy: [
        { priority: 'desc' },
        { dueDate: 'asc' },
        { remindAt: 'desc' },
      ],
      take: 100,
    });
  }

  /**
   * Schedule a custom user reminder (Condition 7)
   */
  async createReminder(schoolId: string, userId: string, data: CreateReminderDto) {
    const dedupKey = `CUSTOM:${userId}:${Date.now()}`;
    const priority = data.priority || 'MEDIUM';

    const reminder = await this.prisma.reminder.create({
      data: {
        schoolId,
        userId,
        title: data.title,
        description: data.description,
        category: data.category || 'CUSTOM',
        priority,
        dueDate: data.dueDate ? new Date(data.dueDate) : null,
        remindAt: data.remindAt ? new Date(data.remindAt) : new Date(),
        status: 'PENDING',
        entityType: data.entityType || 'Custom',
        entityId: data.entityId || null,
        dedupKey,
      },
    });

    // Mirror to in-app notification inbox
    const notification = await this.prisma.notification.create({
      data: {
        schoolId,
        userId,
        title: `Reminder: ${data.title}`,
        body: data.description || 'Scheduled reminder deadline approaching.',
        channel: 'IN_APP',
        status: 'UNREAD',
        priority: priority === 'URGENT' ? 'URGENT' : priority === 'HIGH' ? 'HIGH' : 'NORMAL',
        eventKey: 'CUSTOM_REMINDER',
        dedupKey: `NOTIF:${dedupKey}`,
        metadata: JSON.stringify({ reminderId: reminder.id, category: reminder.category }),
      },
    });

    // Record delivery log
    await this.recordDeliveryLog({
      schoolId,
      notificationId: notification.id,
      reminderId: reminder.id,
      recipientId: userId,
      channel: 'IN_APP',
      status: 'SUCCESS',
      triggerContext: { condition: 'CUSTOM_REMINDER', reminderId: reminder.id },
    });

    return reminder;
  }

  /**
   * Update reminder state (e.g. COMPLETED or DISMISSED)
   */
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
   * Complete, Dependable Trigger Evaluation Engine covering all 7 institutional conditions
   */
  async triggerAutomatedReminders(schoolId: string, options?: { force?: boolean }) {
    const school = await this.prisma.school.findUnique({
      where: { id: schoolId },
      select: { id: true, code: true, name: true, timezone: true },
    });

    if (!school) {
      throw new NotFoundException(`School ${schoolId} not found`);
    }

    const schoolTz = school.timezone || 'Asia/Kolkata';
    const nowUtc = new Date();
    const localizedDateStr = new Intl.DateTimeFormat('en-CA', {
      timeZone: schoolTz,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(nowUtc); // YYYY-MM-DD
    const monthKey = localizedDateStr.substring(0, 7); // YYYY-MM

    const generated = {
      feeReminders: 0,
      lowAttendanceAlerts: 0,
      examDeadlineReminders: 0,
      leaveApprovalAlerts: 0,
      assignmentDeadlines: 0,
      circularSignoffs: 0,
      failures: 0,
    };

    // =========================================================================
    // TRIGGER 1: FEE INVOICE APPROACHING DUE DATE
    // =========================================================================
    try {
      const sevenDaysFromNow = new Date(nowUtc.getTime() + 7 * 24 * 60 * 60 * 1000);
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
                include: { guardian: { select: { id: true, userId: true, name: true } } },
              },
            },
          },
        },
      });

      for (const inv of dueInvoices) {
        const isOverdue = new Date(inv.dueDate).getTime() < nowUtc.getTime();
        const priority = isOverdue ? 'URGENT' : 'HIGH';
        const dueAmount = ((inv.dueAmountMinor || 0) / 100).toFixed(2);
        const dueDateFormatted = new Date(inv.dueDate).toLocaleDateString();

        // Target: linked parent / guardian
        for (const sg of inv.student.studentGuardians) {
          if (sg.guardian?.userId) {
            const userId = sg.guardian.userId;
            const dedupKey = `FEE_DUE:${inv.id}:${userId}`;

            const created = await this.safelyCreateAlertPair({
              schoolId,
              userId,
              dedupKey,
              title: `Fee Due Alert: ${inv.title}`,
              description: `Amount due ₹${dueAmount} for student ${inv.student.firstName}. Due date: ${dueDateFormatted}.`,
              category: 'FEE_DUE',
              priority,
              dueDate: inv.dueDate,
              entityType: 'Invoice',
              entityId: inv.id,
              eventKey: 'FEE_DUE_ALERT',
              notifBody: `Tuition invoice #${inv.invoiceNo} (₹${dueAmount}) for ${inv.student.firstName} is due on ${dueDateFormatted}.`,
              metadata: { invoiceId: inv.id, invoiceNo: inv.invoiceNo, amount: dueAmount, studentId: inv.studentId, isOverdue },
              timezone: schoolTz,
              force: options?.force,
            });

            if (created) generated.feeReminders++;
          }
        }
      }
    } catch (err: any) {
      this.logger.error(`Error processing Fee Invoices trigger: ${err.message}`);
      generated.failures++;
    }

    // =========================================================================
    // TRIGGER 2: LOW ATTENDANCE (< 75% CONDONATION THRESHOLD)
    // =========================================================================
    try {
      const activeStudents = await this.prisma.student.findMany({
        where: { schoolId, status: 'ACTIVE' },
        include: {
          enrollments: {
            where: { status: 'ACTIVE' },
            include: {
              section: {
                include: {
                  teacherAssignments: {
                    where: { isClassTeacher: true },
                    include: { staff: { select: { id: true, userId: true, firstName: true, lastName: true } } },
                  },
                },
              },
            },
          },
          studentGuardians: {
            include: { guardian: { select: { id: true, userId: true, name: true } } },
          },
        },
      });

      for (const s of activeStudents) {
        const totalSessions = await this.prisma.attendanceRecord.count({
          where: { studentId: s.id, session: { schoolId } },
        });

        if (totalSessions >= 5) {
          const presentSessions = await this.prisma.attendanceRecord.count({
            where: {
              studentId: s.id,
              status: { in: ['PRESENT', 'EXCUSED'] },
              session: { schoolId },
            },
          });

          const attendancePct = Math.round((presentSessions / totalSessions) * 100);

          if (attendancePct < 75) {
            // Target 1: Parent
            for (const sg of s.studentGuardians) {
              if (sg.guardian?.userId) {
                const parentUserId = sg.guardian.userId;
                const dedupKey = `ATTENDANCE_LOW:${s.id}:${monthKey}:${parentUserId}`;

                const created = await this.safelyCreateAlertPair({
                  schoolId,
                  userId: parentUserId,
                  dedupKey,
                  title: `Condonation Warning: Low Attendance (${attendancePct}%)`,
                  description: `${s.firstName} has attended ${presentSessions}/${totalSessions} sessions (${attendancePct}%). Mandatory institutional threshold is 75%.`,
                  category: 'ATTENDANCE_LOW',
                  priority: 'URGENT',
                  entityType: 'AttendanceDefaulter',
                  entityId: s.id,
                  eventKey: 'ATTENDANCE_DEFICIENCY',
                  notifBody: `Attendance for ${s.firstName} has fallen to ${attendancePct}%. Please consult the class teacher.`,
                  metadata: { studentId: s.id, attendancePct, totalSessions, presentSessions },
                  timezone: schoolTz,
                  force: options?.force,
                });
                if (created) generated.lowAttendanceAlerts++;
              }
            }

            // Target 2: Class Teacher
            for (const enr of s.enrollments) {
              for (const ta of enr.section?.teacherAssignments || []) {
                if (ta.staff?.userId) {
                  const teacherUserId = ta.staff.userId;
                  const dedupKey = `ATTENDANCE_LOW_TEACHER:${s.id}:${monthKey}:${teacherUserId}`;

                  const created = await this.safelyCreateAlertPair({
                    schoolId,
                    userId: teacherUserId,
                    dedupKey,
                    title: `Defaulter Alert: ${s.firstName} ${s.lastName} (${attendancePct}%)`,
                    description: `Learner in Section ${enr.section.name} has fallen below 75% attendance threshold.`,
                    category: 'ATTENDANCE_LOW',
                    priority: 'HIGH',
                    entityType: 'AttendanceDefaulter',
                    entityId: s.id,
                    eventKey: 'ATTENDANCE_DEFICIENCY_TEACHER',
                    notifBody: `Student ${s.firstName} ${s.lastName} has ${attendancePct}% attendance (${totalSessions} sessions).`,
                    metadata: { studentId: s.id, classId: enr.classId, sectionId: enr.sectionId, attendancePct },
                    timezone: schoolTz,
                    force: options?.force,
                  });
                  if (created) generated.lowAttendanceAlerts++;
                }
              }
            }
          }
        }
      }
    } catch (err: any) {
      this.logger.error(`Error processing Low Attendance trigger: ${err.message}`);
      generated.failures++;
    }

    // =========================================================================
    // TRIGGER 3: EXAMINATION MARK SUBMISSION DEADLINE
    // =========================================================================
    try {
      const activeExamSubjects = await this.prisma.examSubject.findMany({
        where: {
          exam: {
            schoolId,
            status: { in: ['SCHEDULED', 'IN_PROGRESS', 'MODERATION'] },
          },
        },
        include: {
          exam: { select: { id: true, name: true, status: true } },
          subject: { select: { id: true, name: true, code: true } },
          class: { select: { id: true, name: true } },
        },
      });

      for (const es of activeExamSubjects) {
        const totalEnrolled = await this.prisma.enrollment.count({
          where: { classId: es.classId, status: 'ACTIVE' },
        });

        const enteredMarks = await this.prisma.mark.count({
          where: { examSubjectId: es.id },
        });

        if (totalEnrolled > 0 && enteredMarks < totalEnrolled) {
          // Identify assigned subject teachers
          const teacherAssignments = await this.prisma.teacherAssignment.findMany({
            where: {
              classId: es.classId,
              subjectId: es.subjectId,
            },
            include: { staff: { select: { id: true, userId: true, firstName: true, lastName: true } } },
          });

          for (const ta of teacherAssignments) {
            if (ta.staff?.userId) {
              const teacherUserId = ta.staff.userId;
              const dedupKey = `MARK_ENTRY:${es.id}:${teacherUserId}`;
              const remaining = totalEnrolled - enteredMarks;

              const created = await this.safelyCreateAlertPair({
                schoolId,
                userId: teacherUserId,
                dedupKey,
                title: `Mark Entry Due: ${es.subject.name} (${es.exam.name})`,
                description: `Grades pending for Grade ${es.class.name}. ${enteredMarks}/${totalEnrolled} recorded (${remaining} missing).`,
                category: 'EXAM_MARK_ENTRY',
                priority: 'HIGH',
                dueDate: es.examDate,
                entityType: 'ExamSubject',
                entityId: es.id,
                eventKey: 'MARK_ENTRY_DEADLINE',
                notifBody: `Grade entry pending for ${es.subject.name} (${es.exam.name}). ${remaining} grades remaining.`,
                metadata: { examSubjectId: es.id, examId: es.examId, totalEnrolled, enteredMarks, remaining },
                timezone: schoolTz,
                force: options?.force,
              });
              if (created) generated.examDeadlineReminders++;
            }
          }
        }
      }
    } catch (err: any) {
      this.logger.error(`Error processing Exam Mark Deadline trigger: ${err.message}`);
      generated.failures++;
    }

    // =========================================================================
    // TRIGGER 4: PENDING LEAVE APPLICATION
    // =========================================================================
    try {
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
                        include: { staff: { select: { id: true, userId: true, firstName: true, lastName: true } } },
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
        const startStr = new Date(leave.startDate).toLocaleDateString();
        const endStr = new Date(leave.endDate).toLocaleDateString();

        if (leave.student) {
          // Student leave -> notify Class Teacher
          for (const enr of leave.student.enrollments) {
            for (const ta of enr.section?.teacherAssignments || []) {
              if (ta.staff?.userId) {
                const teacherUserId = ta.staff.userId;
                const dedupKey = `LEAVE_APPROVAL:${leave.id}:${teacherUserId}`;

                const created = await this.safelyCreateAlertPair({
                  schoolId,
                  userId: teacherUserId,
                  dedupKey,
                  title: `Leave Approval Required: ${leave.student.firstName}`,
                  description: `${leave.applicantName} submitted leave from ${startStr} to ${endStr}: "${leave.reason}".`,
                  category: 'LEAVE_APPROVAL',
                  priority: 'MEDIUM',
                  dueDate: leave.startDate,
                  entityType: 'LeaveRequest',
                  entityId: leave.id,
                  eventKey: 'LEAVE_REQUEST_PENDING',
                  notifBody: `Student leave pending for ${leave.student.firstName} (${startStr} - ${endStr}).`,
                  metadata: { leaveId: leave.id, studentId: leave.studentId, reason: leave.reason },
                  timezone: schoolTz,
                  force: options?.force,
                });
                if (created) generated.leaveApprovalAlerts++;
              }
            }
          }
        }
      }
    } catch (err: any) {
      this.logger.error(`Error processing Pending Leaves trigger: ${err.message}`);
      generated.failures++;
    }

    // =========================================================================
    // TRIGGER 5: ASSIGNMENT DEADLINE
    // =========================================================================
    try {
      const twoDaysAhead = new Date(nowUtc.getTime() + 48 * 60 * 60 * 1000);
      const approachingAssignments = await this.prisma.assignment.findMany({
        where: {
          schoolId,
          status: 'ACTIVE',
          dueDate: { gte: nowUtc, lte: twoDaysAhead },
        },
        include: {
          subject: { select: { id: true, name: true } },
          class: { select: { id: true, name: true } },
          section: { select: { id: true, name: true } },
          submissions: { select: { studentId: true } },
        },
      });

      for (const a of approachingAssignments) {
        const submittedStudentIds = new Set(a.submissions.map((sub) => sub.studentId));
        const activeEnrolled = await this.prisma.enrollment.findMany({
          where: {
            classId: a.classId,
            sectionId: a.sectionId,
            status: 'ACTIVE',
          },
          include: {
            student: {
              include: {
                studentGuardians: {
                  include: { guardian: { select: { id: true, userId: true } } },
                },
              },
            },
          },
        });

        const dueFormatted = new Date(a.dueDate).toLocaleDateString();

        for (const enr of activeEnrolled) {
          if (!submittedStudentIds.has(enr.studentId)) {
            // Student has not submitted
            const targets: string[] = [];
            if (enr.student.userId) targets.push(enr.student.userId);
            for (const sg of enr.student.studentGuardians) {
              if (sg.guardian?.userId) targets.push(sg.guardian.userId);
            }

            for (const recipientUserId of targets) {
              const dedupKey = `ASSIGNMENT_DEADLINE:${a.id}:${recipientUserId}`;

              const created = await this.safelyCreateAlertPair({
                schoolId,
                userId: recipientUserId,
                dedupKey,
                title: `Assignment Due Soon: ${a.title}`,
                description: `${a.subject.name} assignment is due on ${dueFormatted} (Max marks: ${a.maxMarks}). Submission pending.`,
                category: 'ASSIGNMENT_DEADLINE',
                priority: 'MEDIUM',
                dueDate: a.dueDate,
                entityType: 'Assignment',
                entityId: a.id,
                eventKey: 'ASSIGNMENT_DEADLINE_APPROACHING',
                notifBody: `Submission for ${a.title} (${a.subject.name}) is due on ${dueFormatted}.`,
                metadata: { assignmentId: a.id, subjectId: a.subjectId, dueDate: a.dueDate },
                timezone: schoolTz,
                force: options?.force,
              });
              if (created) generated.assignmentDeadlines++;
            }
          }
        }
      }
    } catch (err: any) {
      this.logger.error(`Error processing Assignment Deadline trigger: ${err.message}`);
      generated.failures++;
    }

    // =========================================================================
    // TRIGGER 6: PENDING CIRCULAR ACKNOWLEDGMENT
    // =========================================================================
    try {
      const pendingCirculars = await this.prisma.circular.findMany({
        where: {
          schoolId,
          status: 'PUBLISHED',
          requiresAck: true,
        },
        include: {
          acknowledgements: { select: { userId: true } },
        },
      });

      for (const circ of pendingCirculars) {
        const acknowledgedUserIds = new Set(circ.acknowledgements.map((ack) => ack.userId));
        let candidateUserIds: string[] = [];

        if (circ.targetAudience === 'ALL') {
          const members = await this.prisma.userSchoolMembership.findMany({
            where: { schoolId, status: 'ACTIVE' },
            select: { userId: true },
          });
          candidateUserIds = members.map((m) => m.userId);
        } else if (circ.targetAudience === 'ALL_PARENTS' || circ.targetAudience === 'CLASS_PARENTS') {
          const guardians = await this.prisma.guardian.findMany({
            where: { schoolId, userId: { not: null } },
            select: { userId: true },
          });
          candidateUserIds = guardians.map((g) => g.userId!).filter(Boolean);
        } else if (circ.targetAudience === 'ALL_TEACHERS') {
          const teachers = await this.prisma.staff.findMany({
            where: { schoolId, status: 'ACTIVE', userId: { not: null } },
            select: { userId: true },
          });
          candidateUserIds = teachers.map((t) => t.userId!).filter(Boolean);
        }

        const priority = circ.priority === 'URGENT' ? 'URGENT' : 'HIGH';

        for (const uid of candidateUserIds) {
          if (!acknowledgedUserIds.has(uid)) {
            const dedupKey = `CIRCULAR_ACK:${circ.id}:${uid}`;

            const created = await this.safelyCreateAlertPair({
              schoolId,
              userId: uid,
              dedupKey,
              title: `Sign-off Required: Circular #${circ.circularNumber}`,
              description: `Institutional circular "${circ.title}" requires mandatory digital acknowledgment.`,
              category: 'CIRCULAR_ACK',
              priority,
              dueDate: circ.ackDeadline,
              entityType: 'Circular',
              entityId: circ.id,
              eventKey: 'CIRCULAR_ACK_PENDING',
              notifBody: `Please acknowledge circular #${circ.circularNumber}: "${circ.title}".`,
              metadata: { circularId: circ.id, circularNumber: circ.circularNumber },
              timezone: schoolTz,
              force: options?.force,
            });
            if (created) generated.circularSignoffs++;
          }
        }
      }
    } catch (err: any) {
      this.logger.error(`Error processing Circular Signoff trigger: ${err.message}`);
      generated.failures++;
    }

    const totalGenerated =
      generated.feeReminders +
      generated.lowAttendanceAlerts +
      generated.examDeadlineReminders +
      generated.leaveApprovalAlerts +
      generated.assignmentDeadlines +
      generated.circularSignoffs;

    this.logger.log(
      `School ${school.code} trigger evaluation complete. Generated: ${totalGenerated} alerts (Fees: ${generated.feeReminders}, Attendance: ${generated.lowAttendanceAlerts}, Exams: ${generated.examDeadlineReminders}, Leaves: ${generated.leaveApprovalAlerts}, Assignments: ${generated.assignmentDeadlines}, Circulars: ${generated.circularSignoffs}). Failures: ${generated.failures}.`,
    );

    return {
      message: 'Automated reminder and notification engine scan completed successfully',
      schoolCode: school.code,
      timezone: schoolTz,
      evaluatedAt: localizedDateStr,
      summary: generated,
      totalGenerated,
    };
  }

  /**
   * Atomic, deduplicated creation of Reminder + Notification + DeliveryLog
   */
  private async safelyCreateAlertPair(params: {
    schoolId: string;
    userId: string;
    dedupKey: string;
    title: string;
    description: string;
    category: string;
    priority: string;
    dueDate?: Date | null;
    entityType: string;
    entityId: string;
    eventKey: string;
    notifBody: string;
    metadata: any;
    timezone: string;
    force?: boolean;
  }): Promise<boolean> {
    try {
      if (!params.force) {
        // Strict duplicate prevention: check both Reminder and Notification dedupKeys
        const existingReminder = await this.prisma.reminder.findFirst({
          where: {
            schoolId: params.schoolId,
            userId: params.userId,
            dedupKey: params.dedupKey,
          },
        });

        if (existingReminder) {
          return false; // Skip duplicate
        }

        const existingNotif = await this.prisma.notification.findFirst({
          where: {
            schoolId: params.schoolId,
            userId: params.userId,
            dedupKey: `NOTIF:${params.dedupKey}`,
          },
        });

        if (existingNotif) {
          return false; // Skip duplicate
        }
      }

      const now = new Date();

      // 1. Create Reminder
      const reminder = await this.prisma.reminder.create({
        data: {
          schoolId: params.schoolId,
          userId: params.userId,
          title: params.title,
          description: params.description,
          category: params.category,
          priority: params.priority,
          dueDate: params.dueDate || null,
          remindAt: now,
          status: 'PENDING',
          entityType: params.entityType,
          entityId: params.entityId,
          dedupKey: params.dedupKey,
        },
      });

      // 2. Create In-App Notification
      const notification = await this.prisma.notification.create({
        data: {
          schoolId: params.schoolId,
          userId: params.userId,
          title: params.title,
          body: params.notifBody,
          channel: 'IN_APP',
          status: 'UNREAD',
          priority: params.priority === 'URGENT' ? 'URGENT' : params.priority === 'HIGH' ? 'HIGH' : 'NORMAL',
          eventKey: params.eventKey,
          dedupKey: `NOTIF:${params.dedupKey}`,
          metadata: JSON.stringify(params.metadata),
        },
      });

      // 3. Record Successful Delivery Log
      await this.recordDeliveryLog({
        schoolId: params.schoolId,
        notificationId: notification.id,
        reminderId: reminder.id,
        recipientId: params.userId,
        channel: 'IN_APP',
        status: 'SUCCESS',
        triggerContext: {
          condition: params.category,
          entityType: params.entityType,
          entityId: params.entityId,
          timezone: params.timezone,
        },
      });

      return true;
    } catch (err: any) {
      // Record failure log for auditing & retry
      await this.recordDeliveryLog({
        schoolId: params.schoolId,
        recipientId: params.userId,
        channel: 'IN_APP',
        status: 'FAILED',
        errorDetails: err.message,
        triggerContext: {
          condition: params.category,
          entityType: params.entityType,
          entityId: params.entityId,
          timezone: params.timezone,
        },
      });
      return false;
    }
  }

  /**
   * Record delivery attempt, error, or retry in NotificationDeliveryLog
   */
  async recordDeliveryLog(data: {
    schoolId: string;
    recipientId: string;
    channel: string;
    status: string;
    notificationId?: string;
    reminderId?: string;
    attemptCount?: number;
    errorDetails?: string;
    triggerContext?: any;
  }) {
    try {
      return await this.prisma.notificationDeliveryLog.create({
        data: {
          schoolId: data.schoolId,
          recipientId: data.recipientId,
          notificationId: data.notificationId || null,
          reminderId: data.reminderId || null,
          channel: data.channel || 'IN_APP',
          status: data.status,
          attemptCount: data.attemptCount || 1,
          errorDetails: data.errorDetails || null,
          triggerContext: data.triggerContext ? JSON.stringify(data.triggerContext) : null,
        },
      });
    } catch (err: any) {
      this.logger.error(`Failed to write NotificationDeliveryLog: ${err.message}`);
    }
  }

  /**
   * Retry failed notifications (max 3 attempts)
   */
  async retryFailedDeliveries(schoolId: string) {
    const failedLogs = await this.prisma.notificationDeliveryLog.findMany({
      where: {
        schoolId,
        status: 'FAILED',
        attemptCount: { lt: 3 },
      },
      take: 50,
    });

    let recovered = 0;
    for (const log of failedLogs) {
      try {
        const user = await this.prisma.user.findUnique({ where: { id: log.recipientId } });
        if (user) {
          // Re-attempt creating in-app notification if missing
          if (!log.notificationId) {
            const ctx = log.triggerContext ? JSON.parse(log.triggerContext) : {};
            const notif = await this.prisma.notification.create({
              data: {
                schoolId: log.schoolId,
                userId: log.recipientId,
                title: `Retried Notice: ${ctx.condition || 'Institutional Notification'}`,
                body: `System recovered notification dispatch for ${ctx.entityType || 'record'}.`,
                channel: log.channel,
                status: 'UNREAD',
                priority: 'HIGH',
                eventKey: 'RETRY_DISPATCH',
                metadata: JSON.stringify(ctx),
              },
            });
            await this.prisma.notificationDeliveryLog.update({
              where: { id: log.id },
              data: {
                status: 'RECOVERED',
                attemptCount: log.attemptCount + 1,
                notificationId: notif.id,
                errorDetails: 'Recovered on scheduled retry.',
              },
            });
            recovered++;
          }
        }
      } catch (err: any) {
        await this.prisma.notificationDeliveryLog.update({
          where: { id: log.id },
          data: {
            attemptCount: log.attemptCount + 1,
            errorDetails: `Retry attempt failed: ${err.message}`,
          },
        });
      }
    }

    return {
      message: 'Retry cycle completed',
      attempted: failedLogs.length,
      recovered,
    };
  }

  /**
   * Delivery audit logs inspection
   */
  async getDeliveryLogs(schoolId: string, limit = 50) {
    return this.prisma.notificationDeliveryLog.findMany({
      where: { schoolId },
      orderBy: { executedAt: 'desc' },
      take: limit,
      include: {
        user: { select: { id: true, firstName: true, lastName: true, email: true } },
      },
    });
  }
}
