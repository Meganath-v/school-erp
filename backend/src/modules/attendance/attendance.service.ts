import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AttendanceService {
  constructor(private prisma: PrismaService) {}

  async getTodayAttendance(schoolId: string, sectionId?: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const targetSection = sectionId
      ? await this.prisma.section.findFirst({ where: { id: sectionId, schoolId } })
      : await this.prisma.section.findFirst({ where: { schoolId } });

    if (!targetSection) {
      return { session: null, students: [] };
    }

    // Find active enrollments in this section
    const enrollments = await this.prisma.enrollment.findMany({
      where: {
        schoolId,
        sectionId: targetSection.id,
        status: 'ACTIVE',
      },
      include: {
        student: true,
      },
      orderBy: { rollNo: 'asc' },
    });

    // Check if session exists for today
    const session = await this.prisma.attendanceSession.findFirst({
      where: {
        schoolId,
        sectionId: targetSection.id,
        date: today,
        sessionType: 'DAILY',
      },
      include: {
        records: true,
      },
    });

    const recordsMap = new Map();
    if (session) {
      for (const r of session.records) {
        recordsMap.set(r.studentId, { status: r.status, remarks: r.remarks });
      }
    }

    const students = enrollments.map((e) => ({
      studentId: e.student.id,
      admissionNo: e.student.admissionNo,
      fullName: `${e.student.firstName} ${e.student.lastName}`,
      rollNo: e.rollNo,
      status: recordsMap.get(e.student.id)?.status || 'PRESENT',
      remarks: recordsMap.get(e.student.id)?.remarks || '',
    }));

    return {
      section: {
        id: targetSection.id,
        name: targetSection.name,
      },
      session: session
        ? {
            id: session.id,
            status: session.status,
            date: session.date,
            createdBy: session.createdBy,
          }
        : null,
      students,
    };
  }

  async saveAttendance(schoolId: string, data: { sectionId: string; date?: string; records: { studentId: string; status: string; remarks?: string }[]; markedBy?: string }) {
    const date = data.date ? new Date(data.date) : new Date();
    date.setHours(0, 0, 0, 0);

    // Upsert AttendanceSession
    let session = await this.prisma.attendanceSession.findFirst({
      where: {
        schoolId,
        sectionId: data.sectionId,
        date,
        sessionType: 'DAILY',
      },
    });

    if (!session) {
      session = await this.prisma.attendanceSession.create({
        data: {
          schoolId,
          sectionId: data.sectionId,
          date,
          sessionType: 'DAILY',
          status: 'SUBMITTED',
          createdBy: data.markedBy || 'Teacher',
        },
      });
    } else {
      session = await this.prisma.attendanceSession.update({
        where: { id: session.id },
        data: {
          status: 'SUBMITTED',
          createdBy: data.markedBy || session.createdBy,
        },
      });
    }

    // Save records
    for (const rec of data.records) {
      await this.prisma.attendanceRecord.upsert({
        where: {
          sessionId_studentId: {
            sessionId: session.id,
            studentId: rec.studentId,
          },
        },
        update: {
          status: rec.status,
          remarks: rec.remarks,
        },
        create: {
          sessionId: session.id,
          studentId: rec.studentId,
          status: rec.status,
          remarks: rec.remarks,
        },
      });
    }

    // Log to AuditLog
    const presentCount = data.records.filter((r) => r.status === 'PRESENT').length;
    const absentCount = data.records.filter((r) => r.status === 'ABSENT').length;
    await this.prisma.auditLog.create({
      data: {
        schoolId,
        actorId: data.markedBy || 'Teacher',
        actorName: data.markedBy || 'Teacher',
        action: 'ATTENDANCE_MARKED',
        entity: 'AttendanceSession',
        entityId: session.id,
        details: JSON.stringify({ sectionId: data.sectionId, present: presentCount, absent: absentCount }),
      },
    });

    return {
      message: 'Attendance saved successfully',
      sessionId: session.id,
      date,
      summary: {
        total: data.records.length,
        present: presentCount,
        absent: absentCount,
        late: data.records.filter((r) => r.status === 'LATE').length,
      },
    };
  }

  async getAttendanceReports(schoolId: string, sectionId?: string) {
    const sessions = await this.prisma.attendanceSession.findMany({
      where: {
        schoolId,
        ...(sectionId ? { sectionId } : {}),
      },
      include: {
        records: {
          include: { student: true },
        },
        section: {
          include: { class: true },
        },
      },
      orderBy: { date: 'desc' },
      take: 15,
    });

    return sessions.map((s) => {
      const present = s.records.filter((r) => r.status === 'PRESENT').length;
      const absent = s.records.filter((r) => r.status === 'ABSENT').length;
      const late = s.records.filter((r) => r.status === 'LATE').length;
      const total = s.records.length;
      const rate = total > 0 ? Math.round((present / total) * 100) : 0;

      return {
        id: s.id,
        date: s.date,
        className: s.section.class.name,
        sectionName: s.section.name,
        status: s.status,
        total,
        present,
        absent,
        late,
        rate,
        createdBy: s.createdBy,
      };
    });
  }
}
