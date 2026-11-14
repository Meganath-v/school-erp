import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class TimetableService {
  constructor(private prisma: PrismaService) {}

  async getEntries(
    schoolId: string,
    query: { sectionId?: string; staffId?: string; classId?: string; userId?: string; role?: string },
  ) {
    const where: any = { schoolId };
    let sectionId = query.sectionId;
    let staffId = query.staffId;

    if (!sectionId && query.role === 'STUDENT' && query.userId) {
      const student = await this.prisma.student.findFirst({
        where: { schoolId, userId: query.userId },
        include: { enrollments: { where: { status: 'ACTIVE' } } },
      });
      if (student && student.enrollments.length > 0) {
        sectionId = student.enrollments[0].sectionId;
      }
    } else if (!staffId && (query.role === 'SUBJECT_TEACHER' || query.role === 'CLASS_TEACHER') && query.userId) {
      const staff = await this.prisma.staff.findFirst({
        where: { schoolId, userId: query.userId },
      });
      if (staff) {
        staffId = staff.id;
      }
    }

    if (sectionId) where.sectionId = sectionId;
    if (staffId) where.staffId = staffId;
    if (query.classId) where.classId = query.classId;

    const entries = await this.prisma.timetableEntry.findMany({
      where,
      include: {
        subject: true,
        staff: true,
        section: {
          include: { class: true },
        },
      },
      orderBy: [
        { dayOfWeek: 'asc' },
        { periodNumber: 'asc' },
      ],
    });

    return entries.map((e) => ({
      id: e.id,
      dayOfWeek: e.dayOfWeek,
      periodNumber: e.periodNumber,
      startTime: e.startTime,
      endTime: e.endTime,
      room: e.room,
      subjectName: e.subject.name,
      subjectCode: e.subject.code,
      teacherName: `${e.staff.firstName} ${e.staff.lastName}`,
      className: e.section.class.name,
      sectionName: e.section.name,
    }));
  }

  async createEntry(schoolId: string, data: any) {
    const activeYear = await this.prisma.academicYear.findFirst({
      where: { schoolId, isCurrent: true },
    });

    if (!activeYear) {
      throw new BadRequestException('No active academic year found');
    }

    // 1. Conflict Check: Teacher Clash (is teacher already teaching another class in same day and period?)
    const teacherClash = await this.prisma.timetableEntry.findFirst({
      where: {
        schoolId,
        academicYearId: activeYear.id,
        staffId: data.staffId,
        dayOfWeek: data.dayOfWeek,
        periodNumber: data.periodNumber,
      },
      include: {
        section: { include: { class: true } },
        staff: true,
      },
    });

    if (teacherClash) {
      throw new BadRequestException(
        `Teacher Conflict: ${teacherClash.staff.firstName} ${teacherClash.staff.lastName} is already assigned to ${teacherClash.section.class.name} (${teacherClash.section.name}) at Day ${data.dayOfWeek}, Period ${data.periodNumber}`,
      );
    }

    // 2. Conflict Check: Room Clash (is room already occupied?)
    if (data.room) {
      const roomClash = await this.prisma.timetableEntry.findFirst({
        where: {
          schoolId,
          academicYearId: activeYear.id,
          room: data.room,
          dayOfWeek: data.dayOfWeek,
          periodNumber: data.periodNumber,
        },
        include: {
          section: { include: { class: true } },
        },
      });

      if (roomClash) {
        throw new BadRequestException(
          `Room Conflict: Room ${data.room} is already booked for ${roomClash.section.class.name} (${roomClash.section.name}) at Day ${data.dayOfWeek}, Period ${data.periodNumber}`,
        );
      }
    }

    return this.prisma.timetableEntry.create({
      data: {
        schoolId,
        academicYearId: activeYear.id,
        classId: data.classId,
        sectionId: data.sectionId,
        subjectId: data.subjectId,
        staffId: data.staffId,
        dayOfWeek: data.dayOfWeek,
        periodNumber: data.periodNumber,
        startTime: data.startTime || '09:00',
        endTime: data.endTime || '09:45',
        room: data.room,
      },
    });
  }

  async getTimetableGrid(
    schoolId: string,
    query: { sectionId?: string; staffId?: string; classId?: string; userId?: string; role?: string },
  ) {
    const entries = await this.getEntries(schoolId, query);

    const dayNames: { [key: number]: string } = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
    };

    const standardPeriods = [
      { periodNumber: 1, startTime: '09:00', endTime: '09:45' },
      { periodNumber: 2, startTime: '09:45', endTime: '10:30' },
      { periodNumber: 3, startTime: '10:45', endTime: '11:30' },
      { periodNumber: 4, startTime: '11:30', endTime: '12:15' },
      { periodNumber: 5, startTime: '13:00', endTime: '13:45' },
      { periodNumber: 6, startTime: '13:45', endTime: '14:30' },
      { periodNumber: 7, startTime: '14:35', endTime: '15:20' },
      { periodNumber: 8, startTime: '15:20', endTime: '16:00' },
    ];

    const grid = [1, 2, 3, 4, 5, 6].map((dayOfWeek) => {
      const dayEntries = entries.filter((e) => e.dayOfWeek === dayOfWeek);
      const periods = standardPeriods.map((p) => {
        const slot = dayEntries.find((e) => e.periodNumber === p.periodNumber);
        return {
          periodNumber: p.periodNumber,
          startTime: slot?.startTime || p.startTime,
          endTime: slot?.endTime || p.endTime,
          isAssigned: !!slot,
          entry: slot || null,
        };
      });

      return {
        dayOfWeek,
        dayName: dayNames[dayOfWeek],
        periods,
      };
    });

    return {
      periodsHeader: standardPeriods,
      days: grid,
    };
  }

  async checkTeacherAvailability(schoolId: string, staffId: string, dayOfWeek: number, periodNumber: number) {
    const clash = await this.prisma.timetableEntry.findFirst({
      where: { schoolId, staffId, dayOfWeek, periodNumber },
      include: {
        section: { include: { class: true } },
        subject: true,
      },
    });

    return {
      available: !clash,
      clash: clash
        ? {
            className: clash.section.class.name,
            sectionName: clash.section.name,
            subjectName: clash.subject.name,
            room: clash.room,
          }
        : null,
    };
  }
}
