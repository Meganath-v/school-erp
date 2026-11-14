import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';

@Injectable()
export class StaffService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
  ) {}

  async getStaff(schoolId: string, query?: { search?: string; department?: string; status?: string }) {
    const where: any = { schoolId };

    if (query?.status && query.status !== 'ALL') {
      where.status = query.status;
    }
    if (query?.department && query.department !== 'ALL') {
      where.department = query.department;
    }
    if (query?.search && query.search.trim()) {
      const s = query.search.trim();
      where.OR = [
        { firstName: { contains: s } },
        { lastName: { contains: s } },
        { employeeNo: { contains: s } },
        { email: { contains: s } },
        { department: { contains: s } },
        { designation: { contains: s } },
      ];
    }

    const staff = await this.prisma.staff.findMany({
      where,
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

    const staff = await this.prisma.staff.create({
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

    await this.auditService.log({
      schoolId,
      action: 'STAFF_CREATED',
      entity: 'Staff',
      entityId: staff.id,
      details: {
        employeeNo: staff.employeeNo,
        name: `${staff.firstName} ${staff.lastName}`,
        department: staff.department,
        designation: staff.designation,
      },
    });

    return staff;
  }

  async updateStaff(schoolId: string, staffId: string, data: any, actor?: { userId?: string; name?: string }) {
    const staff = await this.prisma.staff.findFirst({ where: { id: staffId, schoolId } });
    if (!staff) {
      throw new BadRequestException('Staff member not found in this school');
    }

    const updated = await this.prisma.staff.update({
      where: { id: staffId },
      data: {
        firstName: data.firstName ?? staff.firstName,
        lastName: data.lastName ?? staff.lastName,
        designation: data.designation ?? staff.designation,
        department: data.department ?? staff.department,
        phone: data.phone ?? staff.phone,
        email: data.email ?? staff.email,
        status: data.status ?? staff.status,
      },
    });

    await this.auditService.log({
      schoolId,
      actorId: actor?.userId || 'ADMIN',
      actorName: actor?.name || 'Administrator',
      action: 'STAFF_UPDATED',
      entity: 'Staff',
      entityId: staff.id,
      details: {
        before: { firstName: staff.firstName, lastName: staff.lastName, designation: staff.designation, status: staff.status },
        after: { firstName: updated.firstName, lastName: updated.lastName, designation: updated.designation, status: updated.status },
      },
    });

    return updated;
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
    const assignment = await this.prisma.teacherAssignment.create({
      data: {
        schoolId,
        staffId: data.staffId,
        classId: data.classId,
        sectionId: data.sectionId,
        subjectId: data.subjectId,
        isClassTeacher: !!data.isClassTeacher,
      },
    });

    await this.auditService.log({
      schoolId,
      action: 'STAFF_ASSIGNED',
      entity: 'TeacherAssignment',
      entityId: assignment.id,
      details: {
        staffId: data.staffId,
        classId: data.classId,
        sectionId: data.sectionId,
        subjectId: data.subjectId,
        isClassTeacher: !!data.isClassTeacher,
      },
    });

    return assignment;
  }
}
