import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  UpdateSchoolDto,
  CreateAcademicYearDto,
  CreateAcademicTermDto,
  CreateCampusDto,
  CreateClassDto,
  CreateSectionDto,
  CreateSubjectDto,
} from './schools.dto';

@Injectable()
export class SchoolsService {
  constructor(private prisma: PrismaService) {}

  async getCurrentSchool(schoolId: string) {
    const school = await this.prisma.school.findUnique({
      where: { id: schoolId },
      include: {
        campuses: true,
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

  async updateSchool(schoolId: string, data: UpdateSchoolDto) {
    return this.prisma.school.update({
      where: { id: schoolId },
      data: {
        ...(data.name && { name: data.name }),
        ...(data.address && { address: data.address }),
        ...(data.contactEmail && { contactEmail: data.contactEmail }),
        ...(data.contactPhone && { contactPhone: data.contactPhone }),
        ...(data.currency && { currency: data.currency }),
        ...(data.timezone && { timezone: data.timezone }),
      },
    });
  }

  // Campuses
  async getCampuses(schoolId: string) {
    return this.prisma.campus.findMany({
      where: { schoolId },
      orderBy: { isMain: 'desc' },
    });
  }

  async createCampus(schoolId: string, data: CreateCampusDto) {
    return this.prisma.$transaction(async (tx) => {
      if (data.isMain) {
        await tx.campus.updateMany({
          where: { schoolId, isMain: true },
          data: { isMain: false },
        });
      }
      return tx.campus.create({
        data: {
          schoolId,
          name: data.name,
          code: data.code.toUpperCase(),
          address: data.address,
          contactPhone: data.contactPhone,
          isMain: !!data.isMain,
        },
      });
    });
  }

  // Academic Years & Terms
  async getAcademicYears(schoolId: string) {
    return this.prisma.academicYear.findMany({
      where: { schoolId },
      include: { terms: true },
      orderBy: { startDate: 'desc' },
    });
  }

  async createAcademicYear(schoolId: string, data: CreateAcademicYearDto) {
    return this.prisma.$transaction(async (tx) => {
      if (data.isCurrent) {
        await tx.academicYear.updateMany({
          where: { schoolId, isCurrent: true },
          data: { isCurrent: false },
        });
      }

      return tx.academicYear.create({
        data: {
          schoolId,
          name: data.name,
          startDate: new Date(data.startDate),
          endDate: new Date(data.endDate),
          isCurrent: !!data.isCurrent,
          status: 'ACTIVE',
        },
      });
    });
  }

  async getAcademicTerms(schoolId: string, academicYearId?: string) {
    const where: any = { schoolId };
    if (academicYearId) where.academicYearId = academicYearId;

    return this.prisma.academicTerm.findMany({
      where,
      orderBy: { startDate: 'asc' },
    });
  }

  async createAcademicTerm(schoolId: string, data: CreateAcademicTermDto) {
    return this.prisma.$transaction(async (tx) => {
      if (data.isCurrent) {
        await tx.academicTerm.updateMany({
          where: { schoolId, academicYearId: data.academicYearId, isCurrent: true },
          data: { isCurrent: false },
        });
      }

      return tx.academicTerm.create({
        data: {
          schoolId,
          academicYearId: data.academicYearId,
          name: data.name,
          code: data.code.toUpperCase(),
          startDate: new Date(data.startDate),
          endDate: new Date(data.endDate),
          isCurrent: !!data.isCurrent,
        },
      });
    });
  }

  // Classes & Sections
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

  async createClass(schoolId: string, data: CreateClassDto) {
    return this.prisma.class.create({
      data: {
        schoolId,
        name: data.name,
        code: data.code.toUpperCase(),
        orderIndex: data.orderIndex || 0,
      },
    });
  }

  async createSection(schoolId: string, data: CreateSectionDto) {
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

  // Subjects
  async getSubjects(schoolId: string) {
    return this.prisma.subject.findMany({
      where: { schoolId },
      include: {
        classSubjects: {
          include: { class: true },
        },
      },
      orderBy: { code: 'asc' },
    });
  }

  async createSubject(schoolId: string, data: CreateSubjectDto) {
    return this.prisma.$transaction(async (tx) => {
      const subject = await tx.subject.create({
        data: {
          schoolId,
          name: data.name,
          code: data.code.toUpperCase(),
          type: data.type || 'CORE',
        },
      });

      if (data.classId) {
        await tx.classSubject.create({
          data: {
            schoolId,
            classId: data.classId,
            subjectId: subject.id,
          },
        });
      }

      return subject;
    });
  }
}
