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

    // Compute cumulative attendance percentage and condonation shortage risk
    const condonationThreshold = Number(process.env.ATTENDANCE_CONDONATION_THRESHOLD || 75);
    const pastSessions = await this.prisma.attendanceSession.findMany({
      where: { schoolId, sectionId: targetSection.id },
      include: { records: true },
    });
    const totalSessionsConducted = pastSessions.length;

    const students = enrollments.map((e) => {
      let attendedCount = 0;
      for (const sess of pastSessions) {
        const rec = sess.records.find((r) => r.studentId === e.student.id);
        if (rec && (rec.status === 'PRESENT' || rec.status === 'LATE' || rec.status === 'HALF_DAY')) {
          attendedCount += rec.status === 'HALF_DAY' ? 0.5 : 1;
        }
      }
      const percentage = totalSessionsConducted > 0
        ? Math.round((attendedCount / totalSessionsConducted) * 100)
        : 100;
      const isShortageRisk = totalSessionsConducted > 0 && percentage < condonationThreshold;

      return {
        studentId: e.student.id,
        admissionNo: e.student.admissionNo,
        fullName: `${e.student.firstName} ${e.student.lastName}`,
        rollNo: e.rollNo,
        status: recordsMap.get(e.student.id)?.status || 'PRESENT',
        remarks: recordsMap.get(e.student.id)?.remarks || '',
        totalSessionsConducted,
        attendedCount,
        attendancePercentage: percentage,
        isShortageRisk,
      };
    });

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

  async getAttendanceMatrix(schoolId: string, sectionId?: string, month?: number, year?: number) {
    const targetSection = sectionId
      ? await this.prisma.section.findFirst({ where: { id: sectionId, schoolId }, include: { class: true } })
      : await this.prisma.section.findFirst({ where: { schoolId }, include: { class: true } });

    if (!targetSection) {
      return {
        section: null,
        sessions: [],
        students: [],
        stats: { totalStudents: 0, condonationThreshold: 75, defaultersCount: 0, averageAttendance: 0 },
      };
    }

    // 1. Fetch active enrollments in this section
    const enrollments = await this.prisma.enrollment.findMany({
      where: {
        schoolId,
        sectionId: targetSection.id,
        status: 'ACTIVE',
      },
      include: { student: true },
      orderBy: [{ rollNo: 'asc' }, { student: { lastName: 'asc' } }],
    });

    // 2. Fetch all daily sessions recorded for this section
    const sessions = await this.prisma.attendanceSession.findMany({
      where: {
        schoolId,
        sectionId: targetSection.id,
        sessionType: 'DAILY',
      },
      include: {
        records: true,
      },
      orderBy: { date: 'asc' },
    });

    const dates = sessions.map((s) => ({
      sessionId: s.id,
      date: s.date.toISOString().split('T')[0],
      displayDate: new Date(s.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
    }));

    const condonationThreshold = Number(process.env.ATTENDANCE_CONDONATION_THRESHOLD || 75);

    const students = enrollments.map((enr, idx) => {
      let attended = 0;
      const dailyStatus: Record<string, string> = {};

      for (const sess of sessions) {
        const rec = sess.records.find((r) => r.studentId === enr.student.id);
        const status = rec ? rec.status : 'ABSENT';
        const dateKey = sess.date.toISOString().split('T')[0];
        dailyStatus[dateKey] = status;

        if (status === 'PRESENT' || status === 'LATE' || status === 'HALF_DAY') {
          attended += status === 'HALF_DAY' ? 0.5 : 1;
        }
      }

      const totalConducted = sessions.length;
      const percentage = totalConducted > 0 ? Math.round((attended / totalConducted) * 100) : 100;
      const isCondonationRisk = totalConducted > 0 && percentage < condonationThreshold;

      return {
        studentId: enr.student.id,
        admissionNo: enr.student.admissionNo,
        rollNo: enr.rollNo ?? idx + 1,
        fullName: `${enr.student.firstName} ${enr.student.lastName}`,
        dailyStatus,
        totalConducted,
        attended,
        attendancePercentage: percentage,
        isCondonationRisk,
      };
    });

    const defaultersCount = students.filter((s) => s.isCondonationRisk).length;
    const avg =
      students.length > 0
        ? Math.round(students.reduce((acc, curr) => acc + curr.attendancePercentage, 0) / students.length)
        : 100;

    return {
      section: {
        id: targetSection.id,
        name: targetSection.name,
        className: targetSection.class.name,
      },
      sessions: dates,
      students,
      stats: {
        totalStudents: students.length,
        totalSessions: sessions.length,
        condonationThreshold,
        defaultersCount,
        averageAttendance: avg,
      },
    };
  }
}
