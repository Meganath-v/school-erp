import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { OFFICE_STAFF, TEACHERS } from '../../common/decorators/roles.decorator';
import { schoolToday } from './schedule.util';

export interface ScheduleActor {
  userId: string;
  name?: string;
  role: string;
  activeSchool?: { timezone?: string | null } | null;
}

/** Who may do what with timetables, substitutions and period attendance. */
@Injectable()
export class ScheduleAccessService {
  constructor(private prisma: PrismaService, private audit: AuditService) {}

  /** Office, school admin and principal: full control over every section. */
  isOffice(actor: ScheduleActor) {
    return OFFICE_STAFF.includes(actor.role);
  }

  today(actor: ScheduleActor) {
    return schoolToday(actor.activeSchool?.timezone);
  }

  staffOf(schoolId: string, userId: string) {
    return this.prisma.staff.findFirst({ where: { schoolId, userId, status: 'ACTIVE' } });
  }

  /** The section this user is class teacher of (each section has at most one class teacher). */
  async classTeacherSection(schoolId: string, userId: string) {
    const staff = await this.staffOf(schoolId, userId);
    if (!staff) return null;
    const a = await this.prisma.teacherAssignment.findFirst({
      where: { schoolId, staffId: staff.id, isClassTeacher: true },
      include: { section: { include: { class: true } } },
    });
    return a ? { sectionId: a.sectionId, classId: a.classId, section: a.section } : null;
  }

  async section(schoolId: string, sectionId: string) {
    const section = await this.prisma.section.findFirst({ where: { id: sectionId, schoolId }, include: { class: true } });
    if (!section) throw new NotFoundException('Section not found');
    return section;
  }

  /** Office staff edit any section; a class teacher edits only their own section. */
  async canEditSection(schoolId: string, actor: ScheduleActor, sectionId: string) {
    if (this.isOffice(actor)) return true;
    if (actor.role !== 'CLASS_TEACHER') return false;
    const mine = await this.classTeacherSection(schoolId, actor.userId);
    return mine?.sectionId === sectionId;
  }

  async assertCanEditSection(schoolId: string, actor: ScheduleActor, sectionId: string) {
    if (!(await this.canEditSection(schoolId, actor, sectionId))) {
      throw new ForbiddenException('Only the office or the class teacher of this section can change it');
    }
  }

  /** Staff may view a section's timetable; students and parents use their own endpoints. */
  async assertCanViewSection(schoolId: string, actor: ScheduleActor, _sectionId: string) {
    if (this.isOffice(actor) || TEACHERS.includes(actor.role)) return;
    throw new ForbiddenException('You cannot view this timetable');
  }

  /**
   * Finds the teacher for a username or email typed by the class teacher.
   * The account must belong to an active teacher of this school.
   */
  async resolveTeacher(schoolId: string, identifier: string) {
    const text = (identifier || '').trim();
    if (!text) throw new BadRequestException('Enter the teacher’s username or email');
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: { equals: text, mode: 'insensitive' } }, { username: { equals: text, mode: 'insensitive' } }] },
      select: { id: true, email: true, username: true, firstName: true, lastName: true, status: true },
    });
    if (!user || user.status !== 'ACTIVE') throw new BadRequestException(`No active user with username or email "${text}"`);
    const membership = await this.prisma.userSchoolMembership.findFirst({
      where: { userId: user.id, schoolId, status: 'ACTIVE' },
      select: { defaultRole: true },
    });
    if (!membership || !TEACHERS.includes(membership.defaultRole)) {
      throw new BadRequestException(`${user.firstName} ${user.lastName} is not a teacher in this school`);
    }
    const staff = await this.staffOf(schoolId, user.id);
    if (!staff) throw new BadRequestException(`${user.firstName} ${user.lastName} has no active staff record in this school`);
    return { staff, user };
  }

  teacherView(staff: { id: string; firstName: string; lastName: string; email?: string | null; user?: { username?: string | null; email?: string } | null } | null) {
    if (!staff) return null;
    return {
      staffId: staff.id,
      name: `${staff.firstName} ${staff.lastName}`,
      email: staff.user?.email ?? staff.email ?? null,
      username: staff.user?.username ?? null,
    };
  }

  log(schoolId: string, actor: ScheduleActor, action: string, entity: string, entityId: string, details: Record<string, any>, client?: any) {
    return this.audit.log(
      { schoolId, actorId: actor.userId, actorName: actor.name ?? 'User', action, entity, entityId, details },
      client,
    );
  }
}
