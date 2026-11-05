import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class StaffService {
  constructor(private prisma: PrismaService) {}

  async getStaff(schoolId: string) {
    const staff = await this.prisma.staff.findMany({
      where: { schoolId },
      include: {
        teacherAssignments: {
          include: {
            class: true,
            section: true,
            subject: true,
          },
        },
      },
      orderBy: { firstName: 'asc' },
    });

    return staff.map((s) => ({
      id: s.id,
      employeeNo: s.employeeNo,
      firstName: s.firstName,
      lastName: s.lastName,
      fullName: `${s.firstName} ${s.lastName}`,
      designation: s.designation,
      department: s.department,
      phone: s.phone,
      email: s.email,
      joiningDate: s.joiningDate,
      status: s.status,
      assignments: s.teacherAssignments.map((a) => ({
        id: a.id,
        className: a.class.name,
        sectionName: a.section.name,
        subjectName: a.subject?.name || 'Class Teacher',
        isClassTeacher: a.isClassTeacher,
      })),
    }));
  }

  async createStaff(schoolId: string, data: any) {
    const count = await this.prisma.staff.count({ where: { schoolId } });
    const employeeNo = data.employeeNo || `EMP-${100 + count + 1}`;

    return this.prisma.staff.create({
      data: {
        schoolId,
        employeeNo,
        firstName: data.firstName,
        lastName: data.lastName,
        designation: data.designation,
        department: data.department || 'General',
        phone: data.phone,
        email: data.email,
        joiningDate: new Date(data.joiningDate || Date.now()),
        status: 'ACTIVE',
      },
    });
  }

  async getAssignments(schoolId: string) {
    return this.prisma.teacherAssignment.findMany({
      where: { schoolId },
      include: {
        staff: true,
        class: true,
        section: true,
        subject: true,
      },
    });
  }

  async createAssignment(schoolId: string, data: any) {
    return this.prisma.teacherAssignment.create({
      data: {
        schoolId,
        staffId: data.staffId,
        classId: data.classId,
        sectionId: data.sectionId,
        subjectId: data.subjectId,
        isClassTeacher: !!data.isClassTeacher,
      },
    });
  }
}
