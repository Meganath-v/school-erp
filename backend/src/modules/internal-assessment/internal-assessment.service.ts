import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { attendanceFraction, computeInternalMark, ComponentInput, ComponentType } from './internal-marks';
import { SaveManualMarksDto, SaveSchemeDto } from './internal-assessment.dto';

export interface Actor {
  userId: string;
  name?: string;
  role: string;
}

const ADMIN_ROLES = ['SCHOOL_ADMIN', 'PRINCIPAL'];

@Injectable()
export class InternalAssessmentService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
  ) {}

  // ---------------------------------------------------------------- access

  /** Admins: any subject. Teachers: subjects they are assigned to. */
  async assertCanEditSubject(schoolId: string, subjectId: string, actor: Actor) {
    const subject = await this.prisma.subject.findFirst({ where: { id: subjectId, schoolId } });
    if (!subject) throw new NotFoundException('Subject not found');
    if (ADMIN_ROLES.includes(actor.role)) return subject;
    const staff = await this.prisma.staff.findFirst({ where: { schoolId, userId: actor.userId }, select: { id: true } });
    const ok = staff && (await this.prisma.teacherAssignment.count({ where: { schoolId, staffId: staff.id, subjectId } })) > 0;
    if (!ok) throw new ForbiddenException('You can only manage assessments for subjects you teach');
    return subject;
  }

  private async log(schoolId: string, actor: Actor, action: string, entity: string, entityId: string, details: Record<string, any>) {
    await this.audit.log({ schoolId, actorId: actor.userId, actorName: actor.name ?? 'Staff', action, entity, entityId, details });
  }

  // ---------------------------------------------------------------- schemes

  async listSchemes(schoolId: string, subjectId: string) {
    return this.prisma.internalMarkScheme.findMany({
      where: { schoolId, subjectId },
      include: { components: { orderBy: { orderIndex: 'asc' } } },
      orderBy: { createdAt: 'asc' },
    });
  }

  private async getScheme(schoolId: string, id: string) {
    const scheme = await this.prisma.internalMarkScheme.findFirst({
      where: { id, schoolId },
      include: { components: { orderBy: { orderIndex: 'asc' } } },
    });
    if (!scheme) throw new NotFoundException('Internal mark scheme not found');
    return scheme;
  }

  /** Checks that every source belongs to the subject (and class, when the scheme is class-specific). */
  private async validateComponents(schoolId: string, subjectId: string, classId: string | null, dto: SaveSchemeDto) {
    if (classId) {
      const ok = await this.prisma.class.count({ where: { id: classId, schoolId } });
      if (!ok) throw new BadRequestException('Class not found');
    }
    const types = dto.components.map((c) => c.type);
    if (types.filter((t) => t === 'ATTENDANCE').length > 1) throw new BadRequestException('Use at most one attendance component');
    for (const c of dto.components) {
      const ids = [...new Set(c.sourceIds ?? [])];
      if ((c.type === 'EXAM' || c.type === 'ASSIGNMENT') && ids.length === 0) {
        throw new BadRequestException(`"${c.label}" needs at least one ${c.type === 'EXAM' ? 'exam' : 'assignment'}`);
      }
      if (c.type === 'EXAM') {
        const n = await this.prisma.examSubject.count({
          where: { id: { in: ids }, subjectId, exam: { schoolId }, ...(classId && { classId }) },
        });
        if (n !== ids.length) throw new BadRequestException(`"${c.label}": every exam must be for this subject${classId ? ' and class' : ''}`);
      }
      if (c.type === 'ASSIGNMENT') {
        const n = await this.prisma.assignment.count({ where: { id: { in: ids }, schoolId, subjectId, ...(classId && { classId }) } });
        if (n !== ids.length) throw new BadRequestException(`"${c.label}": every assignment must be for this subject${classId ? ' and class' : ''}`);
      }
    }
  }

  async createScheme(schoolId: string, subjectId: string, dto: SaveSchemeDto, actor: Actor) {
    await this.assertCanEditSubject(schoolId, subjectId, actor);
    const classId = dto.classId || null;
    await this.validateComponents(schoolId, subjectId, classId, dto);
    const scheme = await this.prisma.internalMarkScheme.create({
      data: {
        schoolId,
        subjectId,
        classId,
        name: dto.name.trim(),
        passPercent: dto.passPercent ?? 40,
        components: {
          create: dto.components.map((c, i) => ({
            label: c.label.trim(),
            type: c.type,
            weight: c.weight,
            bestOf: c.type === 'EXAM' || c.type === 'ASSIGNMENT' ? c.bestOf ?? null : null,
            sourceIds: c.type === 'EXAM' || c.type === 'ASSIGNMENT' ? [...new Set(c.sourceIds ?? [])] : [],
            orderIndex: i,
          })),
        },
      },
      include: { components: { orderBy: { orderIndex: 'asc' } } },
    });
    await this.log(schoolId, actor, 'INTERNAL_SCHEME_CREATED', 'InternalMarkScheme', scheme.id, { subjectId, name: scheme.name });
    return scheme;
  }

  /** Updates in place: components with an id are kept (with their manual marks), others are replaced. */
  async updateScheme(schoolId: string, id: string, dto: SaveSchemeDto, actor: Actor) {
    const existing = await this.getScheme(schoolId, id);
    await this.assertCanEditSubject(schoolId, existing.subjectId, actor);
    const classId = dto.classId === undefined ? existing.classId : dto.classId || null;
    await this.validateComponents(schoolId, existing.subjectId, classId, dto);
    const keepIds = new Set(dto.components.filter((c) => c.id).map((c) => c.id!));
    const known = new Set(existing.components.map((c) => c.id));
    for (const k of keepIds) if (!known.has(k)) throw new BadRequestException('A component id does not belong to this scheme');

    await this.prisma.$transaction(
      async (tx) => {
        await tx.internalMarkScheme.update({
          where: { id },
          data: { name: dto.name.trim(), classId, passPercent: dto.passPercent ?? existing.passPercent },
        });
        await tx.internalMarkComponent.deleteMany({ where: { schemeId: id, id: { notIn: [...keepIds] } } });
        for (const [i, c] of dto.components.entries()) {
          const data = {
            label: c.label.trim(),
            type: c.type,
            weight: c.weight,
            bestOf: c.type === 'EXAM' || c.type === 'ASSIGNMENT' ? c.bestOf ?? null : null,
            sourceIds: c.type === 'EXAM' || c.type === 'ASSIGNMENT' ? [...new Set(c.sourceIds ?? [])] : [],
            orderIndex: i,
          };
          if (c.id) await tx.internalMarkComponent.update({ where: { id: c.id }, data });
          else await tx.internalMarkComponent.create({ data: { ...data, schemeId: id } });
        }
      },
      { timeout: 20_000, maxWait: 10_000 },
    );
    await this.log(schoolId, actor, 'INTERNAL_SCHEME_UPDATED', 'InternalMarkScheme', id, { name: dto.name });
    return this.getScheme(schoolId, id);
  }

  async deleteScheme(schoolId: string, id: string, actor: Actor) {
    const s = await this.getScheme(schoolId, id);
    await this.assertCanEditSubject(schoolId, s.subjectId, actor);
    await this.prisma.internalMarkScheme.delete({ where: { id } });
    await this.log(schoolId, actor, 'INTERNAL_SCHEME_DELETED', 'InternalMarkScheme', id, { name: s.name });
    return { deleted: true };
  }

  // ---------------------------------------------------------------- roster & sheet

  private async roster(schoolId: string, classId: string) {
    const year = await this.prisma.academicYear.findFirst({ where: { schoolId, isCurrent: true }, select: { id: true } });
    return this.prisma.enrollment.findMany({
      where: { schoolId, classId, status: 'ACTIVE', ...(year && { academicYearId: year.id }) },
      include: {
        student: { select: { id: true, firstName: true, lastName: true, admissionNo: true } },
        section: { select: { id: true, name: true } },
      },
      orderBy: [{ sectionId: 'asc' }, { rollNo: 'asc' }],
    });
  }

  /** Internal mark sheet for every student of the class. */
  async sheet(schoolId: string, schemeId: string, classIdParam?: string) {
    const scheme = await this.getScheme(schoolId, schemeId);
    const classId = scheme.classId ?? classIdParam;
    if (!classId) throw new BadRequestException('Choose a class: this scheme applies to every class of the subject');
    const enrollments = await this.roster(schoolId, classId);
    const studentIds = enrollments.map((e) => e.studentId);

    const examIds = scheme.components.filter((c) => c.type === 'EXAM').flatMap((c) => c.sourceIds);
    const assignmentIds = scheme.components.filter((c) => c.type === 'ASSIGNMENT').flatMap((c) => c.sourceIds);
    const manualIds = scheme.components.filter((c) => c.type === 'MANUAL').map((c) => c.id);
    const needsAttendance = scheme.components.some((c) => c.type === 'ATTENDANCE');

    const [examSubjects, marks, assignments, submissions, manual, attendance] = await Promise.all([
      this.prisma.examSubject.findMany({
        where: { id: { in: examIds } },
        select: { id: true, maxMarks: true, exam: { select: { name: true } } },
      }),
      this.prisma.mark.findMany({
        where: { examSubjectId: { in: examIds }, studentId: { in: studentIds } },
        select: { examSubjectId: true, studentId: true, marksObtained: true, isAbsent: true },
      }),
      this.prisma.assignment.findMany({ where: { id: { in: assignmentIds } }, select: { id: true, maxMarks: true, title: true } }),
      this.prisma.submission.findMany({
        where: { assignmentId: { in: assignmentIds }, studentId: { in: studentIds }, marksObtained: { not: null } },
        select: { assignmentId: true, studentId: true, marksObtained: true },
      }),
      this.prisma.internalManualMark.findMany({ where: { componentId: { in: manualIds }, studentId: { in: studentIds } } }),
      needsAttendance
        ? this.prisma.attendanceRecord.findMany({
            where: { studentId: { in: studentIds }, session: { schoolId, sessionType: 'DAILY' } },
            select: { studentId: true, status: true, session: { select: { sectionId: true } } },
          })
        : Promise.resolve([] as { studentId: string; status: string; session: { sectionId: string } }[]),
    ]);

    const examMax = new Map(examSubjects.map((e) => [e.id, e.maxMarks]));
    const asgMax = new Map(assignments.map((a) => [a.id, a.maxMarks]));
    const components: ComponentInput[] = scheme.components.map((c) => ({
      id: c.id,
      label: c.label,
      type: c.type as ComponentType,
      weight: c.weight,
      bestOf: c.bestOf,
      sourceIds: c.sourceIds,
    }));

    const students = enrollments.map((e) => {
      const scores: Record<string, number> = {};
      for (const m of marks) {
        if (m.studentId !== e.studentId) continue;
        const max = examMax.get(m.examSubjectId) ?? 0;
        if (max <= 0) continue;
        if (m.isAbsent) scores[m.examSubjectId] = 0;
        else if (m.marksObtained !== null) scores[m.examSubjectId] = m.marksObtained / max;
      }
      for (const s of submissions) {
        if (s.studentId !== e.studentId) continue;
        const max = asgMax.get(s.assignmentId) ?? 0;
        if (max > 0 && s.marksObtained !== null) scores[s.assignmentId] = s.marksObtained / max;
      }
      const manualMarks: Record<string, number> = {};
      for (const mm of manual) if (mm.studentId === e.studentId) manualMarks[mm.componentId] = mm.marks;
      const statuses = attendance.filter((a) => a.studentId === e.studentId && a.session.sectionId === e.sectionId).map((a) => a.status);
      const result = computeInternalMark(
        components,
        { scores, attendanceFraction: attendanceFraction(statuses), manual: manualMarks },
        scheme.passPercent,
      );
      return {
        studentId: e.studentId,
        name: `${e.student.firstName} ${e.student.lastName}`,
        admissionNo: e.student.admissionNo,
        rollNo: e.rollNo,
        section: e.section.name,
        ...result,
      };
    });

    return {
      scheme: {
        id: scheme.id,
        name: scheme.name,
        passPercent: scheme.passPercent,
        classId,
        components: scheme.components.map((c) => ({
          id: c.id,
          label: c.label,
          type: c.type,
          weight: c.weight,
          bestOf: c.bestOf,
          sources: c.sourceIds.map((sid) => ({
            id: sid,
            title: examSubjects.find((x) => x.id === sid)?.exam.name ?? assignments.find((x) => x.id === sid)?.title ?? 'Unknown',
          })),
        })),
      },
      students,
      summary: {
        students: students.length,
        weak: students.filter((s) => s.isWeak).length,
        incomplete: students.filter((s) => !s.complete).length,
        average: students.length ? Math.round((students.reduce((a, s) => a + s.percent, 0) / students.length) * 100) / 100 : null,
      },
    };
  }

  async saveManualMarks(schoolId: string, componentId: string, dto: SaveManualMarksDto, actor: Actor) {
    const component = await this.prisma.internalMarkComponent.findFirst({
      where: { id: componentId, scheme: { schoolId } },
      include: { scheme: true },
    });
    if (!component) throw new NotFoundException('Component not found');
    if (component.type !== 'MANUAL') throw new BadRequestException('Marks can only be entered for manual components');
    await this.assertCanEditSubject(schoolId, component.scheme.subjectId, actor);

    const ids = [...new Set(dto.entries.map((e) => e.studentId))];
    const enrolled = await this.prisma.enrollment.count({
      where: { schoolId, studentId: { in: ids }, status: 'ACTIVE', ...(component.scheme.classId && { classId: component.scheme.classId }) },
    });
    if (enrolled < ids.length) throw new BadRequestException('A student in the request is not enrolled for this subject’s class');
    for (const e of dto.entries) {
      if (e.marks !== null && e.marks !== undefined && e.marks > component.weight + 1e-9) {
        throw new BadRequestException(`Marks cannot exceed ${component.weight}`);
      }
    }
    const toSet = dto.entries.filter((e) => e.marks !== null && e.marks !== undefined);
    const toClear = dto.entries.filter((e) => e.marks === null || e.marks === undefined).map((e) => e.studentId);
    await this.prisma.$transaction(
      async (tx) => {
        if (toClear.length) await tx.internalManualMark.deleteMany({ where: { componentId, studentId: { in: toClear } } });
        if (toSet.length) {
          await tx.$executeRaw`
            INSERT INTO "InternalManualMark" ("id", "componentId", "studentId", "marks", "updatedAt")
            VALUES ${Prisma.join(toSet.map((e) => Prisma.sql`(gen_random_uuid()::text, ${componentId}, ${e.studentId}, ${e.marks}, NOW())`))}
            ON CONFLICT ("componentId", "studentId") DO UPDATE SET "marks" = EXCLUDED."marks", "updatedAt" = NOW()`;
        }
      },
      { timeout: 20_000, maxWait: 10_000 },
    );
    await this.log(schoolId, actor, 'INTERNAL_MANUAL_MARKS_SAVED', 'InternalMarkComponent', componentId, { entries: dto.entries.length });
    return { saved: dto.entries.length };
  }

  // ---------------------------------------------------------------- weak students

  /**
   * Students below a threshold, either on one exam subject (`examSubjectId`) or on the
   * internal mark of a scheme (`schemeId`, threshold = the scheme's pass %).
   */
  async weakStudents(schoolId: string, q: { examSubjectId?: string; schemeId?: string; classId?: string; threshold?: number }) {
    if (q.examSubjectId) {
      const es = await this.prisma.examSubject.findFirst({
        where: { id: q.examSubjectId, exam: { schoolId } },
        include: { exam: { select: { name: true, academicYearId: true } }, subject: { select: { name: true } } },
      });
      if (!es) throw new NotFoundException('Exam subject not found');
      const threshold = q.threshold ?? 50;
      const [enrollments, marks] = await Promise.all([
        this.prisma.enrollment.findMany({
          where: { schoolId, classId: es.classId, academicYearId: es.exam.academicYearId, status: 'ACTIVE' },
          include: { student: { select: { firstName: true, lastName: true, admissionNo: true } }, section: { select: { name: true } } },
        }),
        this.prisma.mark.findMany({ where: { examSubjectId: es.id } }),
      ]);
      const byStudent = new Map(marks.map((m) => [m.studentId, m]));
      const rows = enrollments
        .map((e) => {
          const m = byStudent.get(e.studentId);
          const percent = m && !m.isAbsent && m.marksObtained !== null ? Math.round((m.marksObtained / es.maxMarks) * 10000) / 100 : m?.isAbsent ? 0 : null;
          return {
            studentId: e.studentId,
            name: `${e.student.firstName} ${e.student.lastName}`,
            admissionNo: e.student.admissionNo,
            section: e.section.name,
            percent,
            reason: m?.isAbsent ? 'Absent' : percent === null ? 'No mark entered' : `${percent}% (below ${threshold}%)`,
          };
        })
        .filter((r) => r.percent === null || r.percent < threshold)
        .sort((a, b) => (a.percent ?? -1) - (b.percent ?? -1));
      return { source: `${es.exam.name} · ${es.subject.name}`, threshold, students: rows };
    }
    if (q.schemeId) {
      const sheet = await this.sheet(schoolId, q.schemeId, q.classId);
      const threshold = q.threshold ?? sheet.scheme.passPercent;
      const rows = sheet.students
        .filter((s) => s.percent < threshold)
        .sort((a, b) => a.percent - b.percent)
        .map((s) => ({
          studentId: s.studentId,
          name: s.name,
          admissionNo: s.admissionNo,
          section: s.section,
          percent: s.percent,
          reason: `${s.total}/${s.max} (${s.percent}%)${s.complete ? '' : ' · some components have no data'}`,
        }));
      return { source: sheet.scheme.name, threshold, students: rows };
    }
    throw new BadRequestException('Give examSubjectId or schemeId');
  }
}
