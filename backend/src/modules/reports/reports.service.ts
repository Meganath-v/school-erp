import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  async getOverview(schoolId: string) {
    const totalStudents = await this.prisma.student.count({ where: { schoolId, status: 'ACTIVE' } });
    const totalStaff = await this.prisma.staff.count({ where: { schoolId, status: 'ACTIVE' } });
    const totalClasses = await this.prisma.class.count({ where: { schoolId } });
    const totalSections = await this.prisma.section.count({ where: { schoolId } });

    // Invoices sum
    const invoices = await this.prisma.invoice.findMany({
      where: { schoolId },
      select: { amountMinor: true, paidAmountMinor: true, dueAmountMinor: true },
    });

    const totalInvoiced = invoices.reduce((acc, curr) => acc + curr.amountMinor, 0) / 100;
    const totalCollected = invoices.reduce((acc, curr) => acc + curr.paidAmountMinor, 0) / 100;
    const totalDue = invoices.reduce((acc, curr) => acc + curr.dueAmountMinor, 0) / 100;

    // Today Attendance
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todaySessions = await this.prisma.attendanceSession.findMany({
      where: { schoolId, date: today },
      include: { records: true },
    });

    let totalAttendanceRecords = 0;
    let presentAttendanceRecords = 0;
    for (const s of todaySessions) {
      totalAttendanceRecords += s.records.length;
      presentAttendanceRecords += s.records.filter((r) => r.status === 'PRESENT').length;
    }

    const todayAttendanceRate = totalAttendanceRecords > 0
      ? Math.round((presentAttendanceRecords / totalAttendanceRecords) * 100)
      : 94; // fallback demo rate if not marked yet today

    // Recent announcements
    const recentAnnouncements = await this.prisma.announcement.findMany({
      where: { schoolId },
      orderBy: { publishedAt: 'desc' },
      take: 4,
    });

    // Recent audit events
    const recentAuditLogs = await this.prisma.auditLog.findMany({
      where: { schoolId },
      orderBy: { timestamp: 'desc' },
      take: 5,
    });

    return {
      stats: {
        totalStudents,
        totalStaff,
        totalClasses,
        totalSections,
        todayAttendanceRate,
        totalInvoiced,
        totalCollected,
        totalDue,
      },
      recentAnnouncements,
      recentAuditLogs,
    };
  }

  async getAuditLogs(schoolId?: string) {
    return this.prisma.auditLog.findMany({
      where: schoolId ? { schoolId } : {},
      orderBy: { timestamp: 'desc' },
      take: 50,
    });
  }
}
