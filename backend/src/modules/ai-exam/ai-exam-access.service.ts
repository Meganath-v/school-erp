import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { classGrade, isEligibleClass } from './ai-exam.constants';

export interface Actor {
  userId: string;
  name?: string;
  role: string;
}

export const ADMIN_ROLES = ['SCHOOL_ADMIN', 'PRINCIPAL'];
export const isAdmin = (a: Actor) => ADMIN_ROLES.includes(a.role);

/** (class, section, subject) a teacher teaches; null scope = administrator (everything). */
export interface TeachingSlot {
  classId: string;
  sectionId: string;
  subjectId: string;
}

export interface StudentContext {
  studentId: string;
  name: string;
  classId: string;
  className: string;
  sectionId: string;
  sectionName: string;
  academicYearId: string;
  grade: number | null;
  eligible: boolean;
}

@Injectable()
export class AiExamAccessService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
  ) {}

  log(schoolId: string, actor: Actor, action: string, entityId: string, details: Record<string, any>) {
    return this.audit.log({ schoolId, actorId: actor.userId, actorName: actor.name ?? 'User', action, entity: 'AiExam', entityId, details });
  }

  async currentYear(schoolId: string) {
    const year = await this.prisma.academicYear.findFirst({ where: { schoolId, isCurrent: true } });
    if (!year) throw new NotFoundException('No current academic year is set for the school');
    return year;
  }

  /** Teaching slots of a teacher; null for administrators. */
  async scope(schoolId: string, actor: Actor): Promise<TeachingSlot[] | null> {
    if (isAdmin(actor)) return null;
    const staff = await this.prisma.staff.findFirst({ where: { schoolId, userId: actor.userId }, select: { id: true } });
    if (!staff) return [];
    const rows = await this.prisma.teacherAssignment.findMany({
      where: { schoolId, staffId: staff.id, subjectId: { not: null } },
      select: { classId: true, sectionId: true, subjectId: true },
    });
    return rows.map((r) => ({ classId: r.classId, sectionId: r.sectionId, subjectId: r.subjectId! }));
  }

  /**
   * A teacher manages a section test if they teach the subject in that section, and a whole-class
   * test only if they teach the subject in every section of the class.
   */
  async canManage(schoolId: string, scope: TeachingSlot[] | null, classId: string, subjectId: string, sectionId: string | null) {
    if (scope === null) return true;
    const slots = scope.filter((s) => s.classId === classId && s.subjectId === subjectId);
    if (!slots.length) return false;
    if (sectionId) return slots.some((s) => s.sectionId === sectionId);
    const sections = await this.sectionIds(schoolId, classId);
    return sections.every((id) => slots.some((s) => s.sectionId === id));
  }

  private sectionCache = new Map<string, { ids: string[]; at: number }>();
  private async sectionIds(schoolId: string, classId: string) {
    const hit = this.sectionCache.get(classId);
    if (hit && Date.now() - hit.at < 30_000) return hit.ids;
    const ids = (await this.prisma.section.findMany({ where: { schoolId, classId }, select: { id: true } })).map((s) => s.id);
    this.sectionCache.set(classId, { ids, at: Date.now() });
    return ids;
  }

  /** Prisma filter for tests visible to a scope. */
  testWhere(schoolId: string, scope: TeachingSlot[] | null): Prisma.AiExamTestWhereInput {
    if (scope === null) return { schoolId };
    if (!scope.length) return { schoolId, id: '__none__' };
    return {
      schoolId,
      OR: scope.map((s) => ({ classId: s.classId, subjectId: s.subjectId, OR: [{ sectionId: s.sectionId }, { sectionId: null }] })),
    };
  }

  /** Drops tests the scope cannot fully manage (whole-class tests need every section). */
  async filterManageable<T extends { classId: string; subjectId: string; sectionId: string | null }>(schoolId: string, scope: TeachingSlot[] | null, tests: T[]) {
    if (scope === null) return tests;
    const out: T[] = [];
    for (const t of tests) if (await this.canManage(schoolId, scope, t.classId, t.subjectId, t.sectionId)) out.push(t);
    return out;
  }

  /** Loads a test the actor may manage (404 when it does not exist or is out of scope). */
  async manageableTest(schoolId: string, actor: Actor, testId: string) {
    const test = await this.prisma.aiExamTest.findFirst({
      where: { id: testId, schoolId },
      include: { class: true, section: true, subject: true, academicYear: true },
    });
    if (!test) throw new NotFoundException('Test not found');
    const scope = await this.scope(schoolId, actor);
    if (!(await this.canManage(schoolId, scope, test.classId, test.subjectId, test.sectionId))) {
      throw new ForbiddenException('You can only manage tests for classes and subjects you teach');
    }
    return test;
  }

  async assertEligibleClass(schoolId: string, classId: string) {
    const klass = await this.prisma.class.findFirst({ where: { id: classId, schoolId } });
    if (!klass) throw new NotFoundException('Class not found');
    if (!isEligibleClass(klass.name, klass.code)) throw new ForbiddenException('AI Examination is available for Classes 10, 11 and 12 only');
    return klass;
  }

  /** Classes, sections and subjects the actor can create tests for (eligible classes only). */
  async options(schoolId: string, actor: Actor) {
    const scope = await this.scope(schoolId, actor);
    const classes = await this.prisma.class.findMany({
      where: { schoolId },
      include: { sections: { orderBy: { name: 'asc' } }, classSubjects: { include: { subject: true } } },
      orderBy: { orderIndex: 'asc' },
    });
    const years = await this.prisma.academicYear.findMany({ where: { schoolId }, orderBy: { startDate: 'desc' }, select: { id: true, name: true, isCurrent: true } });
    const out: any[] = [];
    for (const c of classes.filter((k) => isEligibleClass(k.name, k.code))) {
      const subjects: any[] = [];
      for (const cs of c.classSubjects) {
        const sections = [];
        for (const sec of c.sections) if (await this.canManage(schoolId, scope, c.id, cs.subjectId, sec.id)) sections.push({ id: sec.id, name: sec.name });
        if (!sections.length) continue;
        const wholeClass = await this.canManage(schoolId, scope, c.id, cs.subjectId, null);
        subjects.push({ id: cs.subject.id, name: cs.subject.name, code: cs.subject.code, sections, wholeClass });
      }
      if (subjects.length) out.push({ id: c.id, name: c.name, grade: classGrade(c.name, c.code), subjects });
    }
    return { classes: out, academicYears: years };
  }

  /** The signed-in student's current enrolment. */
  async student(schoolId: string, userId: string): Promise<StudentContext> {
    const student = await this.prisma.student.findFirst({ where: { schoolId, userId }, select: { id: true, firstName: true, lastName: true } });
    if (!student) throw new ForbiddenException('No student profile is linked to this account');
    const year = await this.currentYear(schoolId);
    const e = await this.prisma.enrollment.findFirst({
      where: { schoolId, studentId: student.id, academicYearId: year.id, status: 'ACTIVE' },
      include: { class: true, section: true },
    });
    if (!e) throw new ForbiddenException('You are not enrolled in a class this year');
    return {
      studentId: student.id,
      name: `${student.firstName} ${student.lastName}`,
      classId: e.classId,
      className: e.class.name,
      sectionId: e.sectionId,
      sectionName: e.section.name,
      academicYearId: e.academicYearId,
      grade: classGrade(e.class.name, e.class.code),
      eligible: isEligibleClass(e.class.name, e.class.code),
    };
  }

  /** Tests a student is assigned to (published, closed or archived). */
  studentTestWhere(schoolId: string, s: StudentContext): Prisma.AiExamTestWhereInput {
    return {
      schoolId,
      classId: s.classId,
      academicYearId: s.academicYearId,
      status: { in: ['PUBLISHED', 'CLOSED', 'ARCHIVED'] },
      OR: [{ assignMode: 'CLASS' }, { assignMode: 'SECTION', sectionId: s.sectionId }, { assignMode: 'STUDENTS', assignees: { some: { studentId: s.studentId } } }],
    };
  }

  /** Student ids a test is assigned to. */
  async roster(test: { schoolId: string; id: string; classId: string; sectionId: string | null; academicYearId: string; assignMode: string }) {
    if (test.assignMode === 'STUDENTS') {
      return (await this.prisma.aiExamAssignee.findMany({ where: { testId: test.id }, select: { studentId: true } })).map((a) => a.studentId);
    }
    const rows = await this.prisma.enrollment.findMany({
      where: { schoolId: test.schoolId, classId: test.classId, academicYearId: test.academicYearId, status: 'ACTIVE', ...(test.sectionId && { sectionId: test.sectionId }) },
      select: { studentId: true },
    });
    return rows.map((r) => r.studentId);
  }
}
