import { Injectable, BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
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
        { firstName: { contains: s, mode: 'insensitive' } },
        { lastName: { contains: s, mode: 'insensitive' } },
        { employeeNo: { contains: s, mode: 'insensitive' } },
        { email: { contains: s, mode: 'insensitive' } },
        { department: { contains: s, mode: 'insensitive' } },
        { designation: { contains: s, mode: 'insensitive' } },
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

  async createAssignment(schoolId: string, data: any, actor?: { userId?: string; name?: string }) {
    const [staff, section] = await Promise.all([
      this.prisma.staff.findFirst({ where: { id: data.staffId, schoolId } }),
      this.prisma.section.findFirst({ where: { id: data.sectionId, schoolId }, include: { class: true } }),
    ]);
    if (!staff) throw new BadRequestException('Staff member not found');
    if (!section || section.classId !== data.classId) throw new BadRequestException('Section not found in that class');
    if (data.subjectId) {
      const subject = await this.prisma.subject.findFirst({ where: { id: data.subjectId, schoolId } });
      if (!subject) throw new BadRequestException('Subject not found');
    }

    const assignment = await this.prisma.$transaction(async (tx) => {
      if (data.isClassTeacher) {
        // Each class (section) has exactly one class teacher.
        const current = await tx.teacherAssignment.findMany({
          where: { schoolId, sectionId: data.sectionId, isClassTeacher: true, NOT: { staffId: data.staffId } },
          include: { staff: true },
        });
        if (current.length && !data.replaceClassTeacher) {
          const who = current[0].staff;
          throw new ConflictException(
            `${section.class.name} ${section.name} already has a class teacher: ${who.firstName} ${who.lastName}. Replace them or remove that assignment first.`,
          );
        }
        for (const old of current) {
          // Keep the old teacher's subject; drop a class-teacher-only row.
          if (old.subjectId) await tx.teacherAssignment.update({ where: { id: old.id }, data: { isClassTeacher: false } });
          else await tx.teacherAssignment.delete({ where: { id: old.id } });
        }
        const mine = await tx.teacherAssignment.findFirst({
          where: { schoolId, staffId: data.staffId, sectionId: data.sectionId, subjectId: data.subjectId ?? null },
        });
        if (mine) return tx.teacherAssignment.update({ where: { id: mine.id }, data: { isClassTeacher: true, source: null } });
      }
      return tx.teacherAssignment.create({
        data: {
          schoolId,
          staffId: data.staffId,
          classId: data.classId,
          sectionId: data.sectionId,
          subjectId: data.subjectId,
          isClassTeacher: !!data.isClassTeacher,
        },
      });
    });

    await this.auditService.log({
      schoolId,
      actorId: actor?.userId,
      actorName: actor?.name,
      action: 'STAFF_ASSIGNED',
      entity: 'TeacherAssignment',
      entityId: assignment.id,
      details: {
        staffId: data.staffId,
        classId: data.classId,
        sectionId: data.sectionId,
        subjectId: data.subjectId,
        isClassTeacher: !!data.isClassTeacher,
        replacedClassTeacher: !!data.replaceClassTeacher,
      },
    });

    return assignment;
  }

  async deleteAssignment(schoolId: string, id: string, actor?: { userId?: string; name?: string }) {
    const assignment = await this.prisma.teacherAssignment.findFirst({ where: { id, schoolId } });
    if (!assignment) throw new NotFoundException('Assignment not found');
    await this.prisma.teacherAssignment.delete({ where: { id } });
    await this.auditService.log({
      schoolId,
      actorId: actor?.userId,
      actorName: actor?.name,
      action: 'STAFF_UNASSIGNED',
      entity: 'TeacherAssignment',
      entityId: id,
      details: {
        staffId: assignment.staffId,
        sectionId: assignment.sectionId,
        subjectId: assignment.subjectId,
        isClassTeacher: assignment.isClassTeacher,
      },
    });
    return { id };
  }
}
