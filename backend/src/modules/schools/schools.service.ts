import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class SchoolsService {
  constructor(private prisma: PrismaService) {}

  async getCurrentSchool(schoolId: string) {
    const school = await this.prisma.school.findUnique({
      where: { id: schoolId },
      include: {
        subscriptions: {
          include: { plan: true },
          orderBy: { startsAt: 'desc' },
          take: 1,
        },
      },
    });

    if (!school) {
      throw new NotFoundException('School not found');
    }

    return school;
  }

  async updateSchool(schoolId: string, data: any) {
    return this.prisma.school.update({
      where: { id: schoolId },
      data: {
        name: data.name,
        address: data.address,
        contactEmail: data.contactEmail,
        contactPhone: data.contactPhone,
        currency: data.currency,
        timezone: data.timezone,
      },
    });
  }

  async getAcademicYears(schoolId: string) {
    return this.prisma.academicYear.findMany({
      where: { schoolId },
      orderBy: { startDate: 'desc' },
    });
  }

  async createAcademicYear(schoolId: string, data: any) {
    if (data.isCurrent) {
      await this.prisma.academicYear.updateMany({
        where: { schoolId, isCurrent: true },
        data: { isCurrent: false },
      });
    }

    return this.prisma.academicYear.create({
      data: {
        schoolId,
        name: data.name,
        startDate: new Date(data.startDate),
        endDate: new Date(data.endDate),
        isCurrent: !!data.isCurrent,
        status: 'ACTIVE',
      },
    });
  }

  async getClasses(schoolId: string) {
    return this.prisma.class.findMany({
      where: { schoolId },
      include: {
        sections: {
          include: {
            _count: {
              select: { enrollments: true },
            },
          },
        },
        classSubjects: {
          include: { subject: true },
        },
      },
      orderBy: { orderIndex: 'asc' },
    });
  }

  async createClass(schoolId: string, data: any) {
    return this.prisma.class.create({
      data: {
        schoolId,
        name: data.name,
        code: data.code,
        orderIndex: data.orderIndex || 0,
      },
    });
  }

  async createSection(schoolId: string, data: any) {
    return this.prisma.section.create({
      data: {
        schoolId,
        classId: data.classId,
        name: data.name,
        room: data.room,
        capacity: data.capacity || 40,
      },
    });
  }

  async getSubjects(schoolId: string) {
    return this.prisma.subject.findMany({
      where: { schoolId },
      orderBy: { name: 'asc' },
    });
  }

  async createSubject(schoolId: string, data: any) {
    return this.prisma.subject.create({
      data: {
        schoolId,
        name: data.name,
        code: data.code,
        type: data.type || 'CORE',
      },
    });
  }
}
