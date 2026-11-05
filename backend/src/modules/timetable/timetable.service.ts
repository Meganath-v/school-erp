import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class TimetableService {
  constructor(private prisma: PrismaService) {}

  async getEntries(schoolId: string, query: { sectionId?: string; staffId?: string; classId?: string }) {
    const where: any = { schoolId };
    if (query.sectionId) where.sectionId = query.sectionId;
    if (query.staffId) where.staffId = query.staffId;
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
}
