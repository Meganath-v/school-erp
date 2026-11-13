import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { assertStudentAccess, getLinkedStudentIds } from '../../common/access/student-access';

const LEAVE_DECISIONS = ['APPROVED', 'REJECTED', 'MORE_INFO_REQUIRED'];

@Injectable()
export class LeaveService {
  constructor(private prisma: PrismaService) {}

  async getLeaveRequests(schoolId: string, query: { studentId?: string; userId: string; role: string }) {
    const where: any = { schoolId };
    if (query.role === 'PARENT') {
      const linked = await getLinkedStudentIds(this.prisma, schoolId, query.userId);
      where.studentId = { in: query.studentId ? linked.filter((id) => id === query.studentId) : linked };
    } else if (query.studentId) {
      where.studentId = query.studentId;
    }

    const requests = await this.prisma.leaveRequest.findMany({
      where,
      include: {
        student: {
          include: {
            enrollments: {
              where: { status: 'ACTIVE' },
              include: { class: true, section: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return requests.map((r) => ({
      id: r.id,
      studentId: r.studentId,
      studentName: `${r.student.firstName} ${r.student.lastName}`,
      admissionNo: r.student.admissionNo,
      className: r.student.enrollments[0]?.class?.name || 'N/A',
      sectionName: r.student.enrollments[0]?.section?.name || 'N/A',
      applicantName: r.applicantName,
      startDate: r.startDate,
      endDate: r.endDate,
      reason: r.reason,
      status: r.status,
      decisionRemarks: r.decisionRemarks,
      decidedBy: r.decidedBy,
      createdAt: r.createdAt,
    }));
  }

  async getLeaveInbox(schoolId: string, query: { userId: string; role: string }) {
    const where: any = { schoolId };

    // Class teachers can only see and decide leave requests in their assigned class/section (LEV-01, LEV-02)
    if (query.role === 'CLASS_TEACHER') {
      const staff = await this.prisma.staff.findFirst({
        where: { schoolId, userId: query.userId },
        include: {
          teacherAssignments: {
            where: { isClassTeacher: true },
          },
        },
      });

      if (staff && staff.teacherAssignments.length > 0) {
        const assignedSectionIds = staff.teacherAssignments.map((a) => a.sectionId);
        // Find students currently enrolled in these sections
        const enrollments = await this.prisma.enrollment.findMany({
          where: {
            schoolId,
            sectionId: { in: assignedSectionIds },
            status: 'ACTIVE',
          },
          select: { studentId: true },
        });
        const enrolledStudentIds = enrollments.map((e) => e.studentId);
        where.studentId = { in: enrolledStudentIds };
      }
    }

    const requests = await this.prisma.leaveRequest.findMany({
      where,
      include: {
        student: {
          include: {
            enrollments: {
              where: { status: 'ACTIVE' },
              include: { class: true, section: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return requests.map((r) => ({
      id: r.id,
      studentId: r.studentId,
      studentName: `${r.student.firstName} ${r.student.lastName}`,
      admissionNo: r.student.admissionNo,
      className: r.student.enrollments[0]?.class?.name || 'N/A',
      sectionName: r.student.enrollments[0]?.section?.name || 'N/A',
      applicantName: r.applicantName,
      startDate: r.startDate,
      endDate: r.endDate,
      reason: r.reason,
      status: r.status,
      decisionRemarks: r.decisionRemarks,
      decidedBy: r.decidedBy,
      createdAt: r.createdAt,
    }));
  }

  async createLeaveRequest(schoolId: string, user: { userId: string; role: string }, data: any) {
    if (!data?.studentId || !data.startDate || !data.endDate || !data.reason) {
      throw new BadRequestException('studentId, startDate, endDate and reason are required');
    }
    const startDate = new Date(data.startDate);
    const endDate = new Date(data.endDate);
    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime()) || endDate < startDate) {
      throw new BadRequestException('Invalid leave dates');
    }
    await assertStudentAccess(this.prisma, schoolId, user, data.studentId);

    const student = await this.prisma.student.findFirst({
      where: { id: data.studentId, schoolId },
      include: {
        studentGuardians: {
          include: { guardian: true },
        },
      },
    });

    if (!student) {
      throw new NotFoundException('Student not found in this institution');
    }

    const request = await this.prisma.leaveRequest.create({
      data: {
        schoolId,
        studentId: data.studentId,
        applicantName: data.applicantName || 'Parent / Guardian',
        startDate,
        endDate,
        reason: String(data.reason),
        status: 'PENDING',
      },
    });

    // Notify assigned class teacher
    const activeEnrollment = await this.prisma.enrollment.findFirst({
      where: { schoolId, studentId: student.id, status: 'ACTIVE' },
    });
    if (activeEnrollment) {
      const classTeacherAssignment = await this.prisma.teacherAssignment.findFirst({
        where: { schoolId, sectionId: activeEnrollment.sectionId, isClassTeacher: true },
        include: { staff: true },
      });
      if (classTeacherAssignment?.staff?.userId) {
        await this.prisma.notification.create({
          data: {
            schoolId,
            userId: classTeacherAssignment.staff.userId,
            title: 'New Student Leave Application',
            body: `Leave requested for ${student.firstName} ${student.lastName} from ${String(data.startDate).split('T')[0]} to ${String(data.endDate).split('T')[0]}`,
            channel: 'IN_APP',
            status: 'UNREAD',
            eventKey: `LEAVE_${request.id}`,
          },
        });
      }
    }

    return request;
  }

  async decideLeave(
    schoolId: string,
    leaveId: string,
    data: { status: 'APPROVED' | 'REJECTED' | 'MORE_INFO_REQUIRED'; remarks?: string; decidedBy: string; actorId: string },
  ) {
    if (!LEAVE_DECISIONS.includes(data.status)) {
      throw new BadRequestException(`status must be one of ${LEAVE_DECISIONS.join(', ')}`);
    }
    const leave = await this.prisma.leaveRequest.findFirst({
      where: { id: leaveId, schoolId },
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

    if (!leave) {
      throw new NotFoundException('Leave request not found');
    }
    if (leave.status === 'APPROVED' || leave.status === 'REJECTED') {
      throw new BadRequestException(`Leave request has already been ${leave.status.toLowerCase()}`);
    }

    const updated = await this.prisma.leaveRequest.update({
      where: { id: leaveId },
      data: {
        status: data.status,
        decisionRemarks: data.remarks || `Decision: ${data.status}`,
        decidedBy: data.decidedBy,
      },
    });

    // Audit log
    await this.prisma.auditLog.create({
      data: {
        schoolId: leave.schoolId,
        actorId: data.actorId,
        actorName: data.decidedBy,
        action: `LEAVE_${data.status}`,
        entity: 'LeaveRequest',
        entityId: leaveId,
        details: JSON.stringify({
          studentId: leave.studentId,
          decision: data.status,
          remarks: data.remarks,
          timestamp: new Date().toISOString(),
        }),
      },
    });

    // Notify student's guardians
    for (const sg of leave.student.studentGuardians) {
      if (sg.guardian.userId) {
        await this.prisma.notification.create({
          data: {
            schoolId: leave.schoolId,
            userId: sg.guardian.userId,
            title: `Leave Request ${data.status === 'APPROVED' ? 'Approved ✅' : data.status === 'REJECTED' ? 'Rejected ❌' : 'Requires More Info ℹ️'}`,
            body: `Leave for ${leave.student.firstName} has been marked ${data.status} by ${data.decidedBy || 'Class Teacher'}. Remarks: ${data.remarks || 'None'}`,
            channel: 'IN_APP',
            status: 'UNREAD',
            eventKey: `LEAVE_DECISION_${leave.id}`,
          },
        });
      }
    }

    return updated;
  }
}
