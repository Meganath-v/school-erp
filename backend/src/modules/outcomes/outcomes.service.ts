import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import {
  averagePoAttainment,
  computeCoAttainment,
  computePoAttainment,
  AttainmentRuleConfig,
  AssessmentType,
  DEFAULT_RULE,
  validateRule,
} from './attainment';
import {
  CreateOutcomeForSubjectDto,
  CreateProgramDto,
  CreateProgramOutcomeDto,
  CreateQuestionDto,
  SaveAttainmentRuleDto,
  SaveIndirectDto,
  SaveMappingDto,
  SavePaperDto,
  SaveQuestionMarksDto,
  UpdateCourseOutcomeDto,
  UpdateProgramDto,
  UpdateProgramOutcomeDto,
  UpdateQuestionDto,
} from './outcomes.dto';

/** The signed-in user, as provided by JwtStrategy. */
export interface Actor {
  userId: string;
  name?: string;
  role: string;
}

const ADMIN_ROLES = ['SCHOOL_ADMIN', 'PRINCIPAL'];
const RULE_FIELDS: (keyof AttainmentRuleConfig)[] = [
  'studentTargetPercent',
  'level1Percent',
  'level2Percent',
  'level3Percent',
  'internalWeight',
  'externalWeight',
  'directWeight',
  'indirectWeight',
  'targetLevel',
];

type PaperOwner = { kind: 'exam'; examSubjectId: string } | { kind: 'assignment'; assignmentId: string };

@Injectable()
export class OutcomesService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
  ) {}

  // ================================================================ access helpers

  private isAdmin(actor: Actor) {
    return ADMIN_ROLES.includes(actor.role);
  }

  /** Subjects a teacher is assigned to in this school (via TeacherAssignment). */
  private async teacherSubjectIds(schoolId: string, actor: Actor): Promise<Set<string>> {
    const staff = await this.prisma.staff.findFirst({ where: { schoolId, userId: actor.userId }, select: { id: true } });
    if (!staff) return new Set();
    const rows = await this.prisma.teacherAssignment.findMany({
      where: { schoolId, staffId: staff.id, subjectId: { not: null } },
      select: { subjectId: true },
    });
    return new Set(rows.map((r) => r.subjectId!));
  }

  private async getSubject(schoolId: string, subjectId: string) {
    const subject = await this.prisma.subject.findFirst({ where: { id: subjectId, schoolId } });
    if (!subject) throw new NotFoundException('Subject not found');
    return subject;
  }

  /** Admins can edit every subject; teachers only the subjects they teach. */
  private async assertCanEditSubject(schoolId: string, subjectId: string, actor: Actor) {
    const subject = await this.getSubject(schoolId, subjectId);
    if (this.isAdmin(actor)) return subject;
    const mine = await this.teacherSubjectIds(schoolId, actor);
    if (!mine.has(subjectId)) {
      throw new ForbiddenException('You can only manage outcomes and assessments for subjects you teach');
    }
    return subject;
  }

  private async logChange(schoolId: string, actor: Actor, action: string, entity: string, entityId: string, details: Record<string, any>) {
    await this.audit.log({
      schoolId,
      actorId: actor.userId,
      actorName: actor.name ?? 'Staff',
      action,
      entity,
      entityId,
      details,
    });
  }

  // ================================================================ programs & program outcomes

  async listPrograms(schoolId: string) {
    const programs = await this.prisma.program.findMany({
      where: { schoolId },
      include: {
        outcomes: { orderBy: [{ type: 'asc' }, { orderIndex: 'asc' }, { code: 'asc' }] },
        classes: { select: { id: true, name: true, code: true }, orderBy: { orderIndex: 'asc' } },
      },
      orderBy: { code: 'asc' },
    });
    return programs;
  }

  async getProgram(schoolId: string, id: string) {
    const program = await this.prisma.program.findFirst({
      where: { id, schoolId },
      include: {
        outcomes: { orderBy: [{ type: 'asc' }, { orderIndex: 'asc' }, { code: 'asc' }] },
        classes: { select: { id: true, name: true, code: true }, orderBy: { orderIndex: 'asc' } },
      },
    });
    if (!program) throw new NotFoundException('Program not found');
    return program;
  }

  async createProgram(schoolId: string, dto: CreateProgramDto, actor: Actor) {
    try {
      const program = await this.prisma.program.create({
        data: { schoolId, code: dto.code.trim().toUpperCase(), name: dto.name.trim(), description: dto.description },
      });
      await this.logChange(schoolId, actor, 'PROGRAM_CREATED', 'Program', program.id, { code: program.code });
      return program;
    } catch (e) {
      throw this.uniqueError(e, 'A program with this code already exists');
    }
  }

  async updateProgram(schoolId: string, id: string, dto: UpdateProgramDto, actor: Actor) {
    await this.getProgram(schoolId, id);
    try {
      const program = await this.prisma.program.update({
        where: { id },
        data: {
          ...(dto.code !== undefined && { code: dto.code.trim().toUpperCase() }),
          ...(dto.name !== undefined && { name: dto.name.trim() }),
          ...(dto.description !== undefined && { description: dto.description }),
        },
      });
      await this.logChange(schoolId, actor, 'PROGRAM_UPDATED', 'Program', id, dto);
      return program;
    } catch (e) {
      throw this.uniqueError(e, 'A program with this code already exists');
    }
  }

  async deleteProgram(schoolId: string, id: string, actor: Actor) {
    const program = await this.getProgram(schoolId, id);
    await this.prisma.program.delete({ where: { id } });
    await this.logChange(schoolId, actor, 'PROGRAM_DELETED', 'Program', id, { code: program.code });
    return { deleted: true };
  }

  async setProgramClasses(schoolId: string, id: string, classIds: string[], actor: Actor) {
    await this.getProgram(schoolId, id);
    const unique = [...new Set(classIds)];
    const found = await this.prisma.class.count({ where: { schoolId, id: { in: unique } } });
    if (found !== unique.length) throw new BadRequestException('One or more classes do not belong to this school');
    await this.prisma.$transaction([
      this.prisma.class.updateMany({ where: { schoolId, programId: id, id: { notIn: unique } }, data: { programId: null } }),
      this.prisma.class.updateMany({ where: { schoolId, id: { in: unique } }, data: { programId: id } }),
    ]);
    await this.logChange(schoolId, actor, 'PROGRAM_CLASSES_SET', 'Program', id, { classIds: unique });
    return this.getProgram(schoolId, id);
  }

  async createProgramOutcome(schoolId: string, programId: string, dto: CreateProgramOutcomeDto, actor: Actor) {
    await this.getProgram(schoolId, programId);
    try {
      const po = await this.prisma.programOutcome.create({
        data: {
          schoolId,
          programId,
          type: dto.type,
          code: dto.code.trim().toUpperCase(),
          title: dto.title,
          description: dto.description.trim(),
          orderIndex: dto.orderIndex ?? 0,
        },
      });
      await this.logChange(schoolId, actor, 'PROGRAM_OUTCOME_CREATED', 'ProgramOutcome', po.id, { code: po.code, programId });
      return po;
    } catch (e) {
      throw this.uniqueError(e, 'This program already has an outcome with that code');
    }
  }

  private async getProgramOutcome(schoolId: string, id: string) {
    const po = await this.prisma.programOutcome.findFirst({ where: { id, schoolId } });
    if (!po) throw new NotFoundException('Program outcome not found');
    return po;
  }

  async updateProgramOutcome(schoolId: string, id: string, dto: UpdateProgramOutcomeDto, actor: Actor) {
    await this.getProgramOutcome(schoolId, id);
    try {
      const po = await this.prisma.programOutcome.update({
        where: { id },
        data: {
          ...(dto.type !== undefined && { type: dto.type }),
          ...(dto.code !== undefined && { code: dto.code.trim().toUpperCase() }),
          ...(dto.title !== undefined && { title: dto.title }),
          ...(dto.description !== undefined && { description: dto.description.trim() }),
          ...(dto.orderIndex !== undefined && { orderIndex: dto.orderIndex }),
        },
      });
      await this.logChange(schoolId, actor, 'PROGRAM_OUTCOME_UPDATED', 'ProgramOutcome', id, dto);
      return po;
    } catch (e) {
      throw this.uniqueError(e, 'This program already has an outcome with that code');
    }
  }

  async deleteProgramOutcome(schoolId: string, id: string, actor: Actor) {
    const po = await this.getProgramOutcome(schoolId, id);
    await this.prisma.programOutcome.delete({ where: { id } });
    await this.logChange(schoolId, actor, 'PROGRAM_OUTCOME_DELETED', 'ProgramOutcome', id, { code: po.code });
    return { deleted: true };
  }

  // ================================================================ subjects visible to the caller

  /** Subjects with outcome counts; teachers see only the subjects they teach. */
  async listSubjects(schoolId: string, actor: Actor) {
    const where: Prisma.SubjectWhereInput = { schoolId };
    let editable: Set<string> | null = null;
    if (!this.isAdmin(actor)) {
      editable = await this.teacherSubjectIds(schoolId, actor);
      where.id = { in: [...editable] };
    }
    const subjects = await this.prisma.subject.findMany({
      where,
      include: {
        _count: { select: { courseOutcomes: true, questions: true } },
        classSubjects: { include: { class: { select: { id: true, name: true, programId: true } } } },
      },
      orderBy: { name: 'asc' },
    });
    return subjects.map((s) => ({
      id: s.id,
      name: s.name,
      code: s.code,
      courseOutcomeCount: s._count.courseOutcomes,
      questionCount: s._count.questions,
      classes: s.classSubjects.map((cs) => cs.class),
      canEdit: editable === null || editable.has(s.id),
    }));
  }

  /** Programs whose classes study the subject (used to pick which POs to map). */
  private async programsForSubject(schoolId: string, subjectId: string) {
    const classSubjects = await this.prisma.classSubject.findMany({
      where: { subjectId, class: { schoolId } },
      select: { class: { select: { programId: true } } },
    });
    const ids = [...new Set(classSubjects.map((c) => c.class.programId).filter((x): x is string => !!x))];
    return ids;
  }

  // ================================================================ course outcomes & mapping

  async listCourseOutcomes(schoolId: string, subjectId: string) {
    await this.getSubject(schoolId, subjectId);
    return this.prisma.courseOutcome.findMany({
      where: { schoolId, subjectId },
      orderBy: [{ orderIndex: 'asc' }, { code: 'asc' }],
      include: { _count: { select: { questions: true } } },
    });
  }

  async createCourseOutcome(schoolId: string, subjectId: string, dto: CreateOutcomeForSubjectDto, actor: Actor) {
    await this.assertCanEditSubject(schoolId, subjectId, actor);
    try {
      const co = await this.prisma.courseOutcome.create({
        data: {
          schoolId,
          subjectId,
          code: dto.code.trim().toUpperCase(),
          description: dto.description.trim(),
          bloomLevel: dto.bloomLevel,
          targetAttainment: dto.targetAttainment ?? 70,
          orderIndex: dto.orderIndex ?? 0,
        },
      });
      await this.logChange(schoolId, actor, 'COURSE_OUTCOME_CREATED', 'CourseOutcome', co.id, { code: co.code, subjectId });
      return co;
    } catch (e) {
      throw this.uniqueError(e, 'This subject already has a course outcome with that code');
    }
  }

  private async getCourseOutcome(schoolId: string, id: string) {
    const co = await this.prisma.courseOutcome.findFirst({ where: { id, schoolId } });
    if (!co) throw new NotFoundException('Course outcome not found');
    return co;
  }

  async updateCourseOutcome(schoolId: string, id: string, dto: UpdateCourseOutcomeDto, actor: Actor) {
    const co = await this.getCourseOutcome(schoolId, id);
    await this.assertCanEditSubject(schoolId, co.subjectId, actor);
    try {
      const updated = await this.prisma.courseOutcome.update({
        where: { id },
        data: {
          ...(dto.code !== undefined && { code: dto.code.trim().toUpperCase() }),
          ...(dto.description !== undefined && { description: dto.description.trim() }),
          ...(dto.bloomLevel !== undefined && { bloomLevel: dto.bloomLevel }),
          ...(dto.targetAttainment !== undefined && { targetAttainment: dto.targetAttainment }),
          ...(dto.orderIndex !== undefined && { orderIndex: dto.orderIndex }),
        },
      });
      await this.logChange(schoolId, actor, 'COURSE_OUTCOME_UPDATED', 'CourseOutcome', id, dto);
      return updated;
    } catch (e) {
      throw this.uniqueError(e, 'This subject already has a course outcome with that code');
    }
  }

  async deleteCourseOutcome(schoolId: string, id: string, actor: Actor) {
    const co = await this.getCourseOutcome(schoolId, id);
    await this.assertCanEditSubject(schoolId, co.subjectId, actor);
    await this.prisma.courseOutcome.delete({ where: { id } }); // questions keep existing, unmapped (SetNull)
    await this.logChange(schoolId, actor, 'COURSE_OUTCOME_DELETED', 'CourseOutcome', id, { code: co.code });
    return { deleted: true };
  }

  /**
   * CO × PO matrix for a subject. Program outcomes come from the programs whose classes
   * study the subject, or from `programId` when given.
   */
  async getMapping(schoolId: string, subjectId: string, programId?: string) {
    await this.getSubject(schoolId, subjectId);
    const programIds = programId ? [programId] : await this.programsForSubject(schoolId, subjectId);
    const [courseOutcomes, programOutcomes] = await Promise.all([
      this.prisma.courseOutcome.findMany({
        where: { schoolId, subjectId },
        orderBy: [{ orderIndex: 'asc' }, { code: 'asc' }],
        include: { poMappings: true },
      }),
      this.prisma.programOutcome.findMany({
        where: { schoolId, programId: { in: programIds } },
        include: { program: { select: { id: true, code: true, name: true } } },
        orderBy: [{ program: { code: 'asc' } }, { type: 'asc' }, { orderIndex: 'asc' }, { code: 'asc' }],
      }),
    ]);
    const poIds = new Set(programOutcomes.map((p) => p.id));
    return {
      programIds,
      courseOutcomes: courseOutcomes.map((c) => ({ id: c.id, code: c.code, description: c.description, bloomLevel: c.bloomLevel })),
      programOutcomes: programOutcomes.map((p) => ({
        id: p.id,
        code: p.code,
        type: p.type,
        title: p.title,
        description: p.description,
        program: p.program,
      })),
      entries: courseOutcomes.flatMap((c) =>
        c.poMappings
          .filter((m) => poIds.has(m.programOutcomeId))
          .map((m) => ({ courseOutcomeId: c.id, programOutcomeId: m.programOutcomeId, strength: m.strength })),
      ),
    };
  }

  async saveMapping(schoolId: string, subjectId: string, dto: SaveMappingDto, actor: Actor) {
    await this.assertCanEditSubject(schoolId, subjectId, actor);
    const coIds = [...new Set(dto.entries.map((e) => e.courseOutcomeId))];
    const poIds = [...new Set(dto.entries.map((e) => e.programOutcomeId))];
    const [cos, pos] = await Promise.all([
      this.prisma.courseOutcome.count({ where: { schoolId, subjectId, id: { in: coIds } } }),
      this.prisma.programOutcome.count({ where: { schoolId, id: { in: poIds } } }),
    ]);
    if (cos !== coIds.length) throw new BadRequestException('Every course outcome must belong to this subject');
    if (pos !== poIds.length) throw new BadRequestException('One or more program outcomes were not found');

    // Last value wins per cell; then one delete and one bulk upsert.
    const cells = new Map<string, { courseOutcomeId: string; programOutcomeId: string; strength: number }>();
    for (const e of dto.entries) cells.set(`${e.courseOutcomeId}|${e.programOutcomeId}`, e);
    const removals = [...cells.values()].filter((e) => e.strength === 0);
    const upserts = [...cells.values()].filter((e) => e.strength > 0);
    await this.prisma.$transaction(
      async (tx) => {
        if (removals.length) {
          await tx.coPoMapping.deleteMany({
            where: { OR: removals.map((e) => ({ courseOutcomeId: e.courseOutcomeId, programOutcomeId: e.programOutcomeId })) },
          });
        }
        if (upserts.length) {
          await tx.$executeRaw`
            INSERT INTO "CoPoMapping" ("id", "courseOutcomeId", "programOutcomeId", "strength")
            VALUES ${Prisma.join(upserts.map((e) => Prisma.sql`(gen_random_uuid()::text, ${e.courseOutcomeId}, ${e.programOutcomeId}, ${e.strength})`))}
            ON CONFLICT ("courseOutcomeId", "programOutcomeId") DO UPDATE SET "strength" = EXCLUDED."strength"`;
        }
      },
      { timeout: 20_000, maxWait: 10_000 },
    );
    await this.logChange(schoolId, actor, 'CO_PO_MAPPING_SAVED', 'Subject', subjectId, { entries: dto.entries.length });
    return this.getMapping(schoolId, subjectId);
  }

  async saveIndirect(schoolId: string, subjectId: string, dto: SaveIndirectDto, actor: Actor) {
    await this.assertCanEditSubject(schoolId, subjectId, actor);
    const ids = [...new Set(dto.entries.map((e) => e.courseOutcomeId))];
    const count = await this.prisma.courseOutcome.count({ where: { schoolId, subjectId, id: { in: ids } } });
    if (count !== ids.length) throw new BadRequestException('Every course outcome must belong to this subject');
    await this.prisma.$transaction(
      dto.entries.map((e) =>
        this.prisma.courseOutcome.update({ where: { id: e.courseOutcomeId }, data: { indirectLevel: e.level ?? null } }),
      ),
    );
    await this.logChange(schoolId, actor, 'INDIRECT_ATTAINMENT_SAVED', 'Subject', subjectId, { entries: dto.entries.length });
    return this.listCourseOutcomes(schoolId, subjectId);
  }

  // ================================================================ attainment rules

  private toConfig(rule: Partial<AttainmentRuleConfig> | null | undefined): AttainmentRuleConfig {
    const out = { ...DEFAULT_RULE };
    if (rule) for (const f of RULE_FIELDS) if (typeof rule[f] === 'number') out[f] = rule[f] as number;
    return out;
  }

  /** Effective rule for a subject: subject rule → school default → built-in default. */
  async getRule(schoolId: string, subjectId?: string) {
    if (subjectId) await this.getSubject(schoolId, subjectId);
    const rules = await this.prisma.attainmentRule.findMany({
      where: { schoolId, subjectId: subjectId ? { in: [subjectId] } : null },
    });
    const schoolDefault = subjectId
      ? await this.prisma.attainmentRule.findFirst({ where: { schoolId, subjectId: null } })
      : rules[0] ?? null;
    const subjectRule = subjectId ? rules.find((r) => r.subjectId === subjectId) ?? null : null;
    const source = subjectRule ? 'SUBJECT' : schoolDefault ? 'SCHOOL' : 'DEFAULT';
    return { source, rule: this.toConfig(subjectRule ?? schoolDefault) };
  }

  async saveRule(schoolId: string, subjectId: string | null, dto: SaveAttainmentRuleDto, actor: Actor) {
    if (subjectId) await this.assertCanEditSubject(schoolId, subjectId, actor);
    else if (!this.isAdmin(actor)) throw new ForbiddenException('Only school administrators can change the school default rule');
    const config = this.toConfig(dto);
    try {
      validateRule(config);
    } catch (e: any) {
      throw new BadRequestException(e.message);
    }
    const existing = await this.prisma.attainmentRule.findFirst({ where: { schoolId, subjectId } });
    const saved = existing
      ? await this.prisma.attainmentRule.update({ where: { id: existing.id }, data: config })
      : await this.prisma.attainmentRule.create({ data: { schoolId, subjectId, ...config } });
    await this.logChange(schoolId, actor, 'ATTAINMENT_RULE_SAVED', 'AttainmentRule', saved.id, { subjectId, ...config });
    return { source: subjectId ? 'SUBJECT' : 'SCHOOL', rule: this.toConfig(saved) };
  }

  async deleteSubjectRule(schoolId: string, subjectId: string, actor: Actor) {
    await this.assertCanEditSubject(schoolId, subjectId, actor);
    await this.prisma.attainmentRule.deleteMany({ where: { schoolId, subjectId } });
    return this.getRule(schoolId, subjectId);
  }

  // ================================================================ question bank

  async listQuestions(schoolId: string, subjectId: string, filter: { courseOutcomeId?: string; bloomLevel?: string; search?: string }) {
    await this.getSubject(schoolId, subjectId);
    return this.prisma.question.findMany({
      where: {
        schoolId,
        subjectId,
        ...(filter.courseOutcomeId && { courseOutcomeId: filter.courseOutcomeId }),
        ...(filter.bloomLevel && { bloomLevel: filter.bloomLevel }),
        ...(filter.search && { text: { contains: filter.search, mode: 'insensitive' } }),
      },
      include: {
        courseOutcome: { select: { id: true, code: true } },
        _count: { select: { paperItems: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  private async assertOutcomeInSubject(schoolId: string, subjectId: string, courseOutcomeId?: string | null) {
    if (!courseOutcomeId) return;
    const ok = await this.prisma.courseOutcome.count({ where: { id: courseOutcomeId, schoolId, subjectId } });
    if (!ok) throw new BadRequestException('The course outcome must belong to the same subject');
  }

  /** MCQ questions need 2-6 options and a correct answer; other types store neither. */
  private mcqFields(type: string, options?: string[] | null, correct?: number | null) {
    if (type !== 'MCQ') return { options: Prisma.DbNull, correctOption: null };
    const opts = (options ?? []).map((o) => o.trim()).filter((o) => o.length > 0);
    if (opts.length < 2) throw new BadRequestException('A multiple-choice question needs at least 2 options');
    if (correct === null || correct === undefined || correct < 0 || correct >= opts.length) {
      throw new BadRequestException('Choose which option is correct');
    }
    return { options: opts, correctOption: correct };
  }

  async createQuestion(schoolId: string, subjectId: string, dto: CreateQuestionDto, actor: Actor) {
    await this.assertCanEditSubject(schoolId, subjectId, actor);
    await this.assertOutcomeInSubject(schoolId, subjectId, dto.courseOutcomeId);
    const q = await this.prisma.question.create({
      data: {
        schoolId,
        subjectId,
        text: dto.text.trim(),
        marks: dto.marks,
        bloomLevel: dto.bloomLevel,
        courseOutcomeId: dto.courseOutcomeId || null,
        type: dto.type ?? 'DESCRIPTIVE',
        ...this.mcqFields(dto.type ?? 'DESCRIPTIVE', dto.options, dto.correctOption),
        createdById: actor.userId,
      },
      include: { courseOutcome: { select: { id: true, code: true } } },
    });
    await this.logChange(schoolId, actor, 'QUESTION_CREATED', 'Question', q.id, { subjectId });
    return q;
  }

  private async getQuestion(schoolId: string, id: string) {
    const q = await this.prisma.question.findFirst({ where: { id, schoolId } });
    if (!q) throw new NotFoundException('Question not found');
    return q;
  }

  async updateQuestion(schoolId: string, id: string, dto: UpdateQuestionDto, actor: Actor) {
    const q = await this.getQuestion(schoolId, id);
    await this.assertCanEditSubject(schoolId, q.subjectId, actor);
    if (dto.courseOutcomeId !== undefined) await this.assertOutcomeInSubject(schoolId, q.subjectId, dto.courseOutcomeId);
    const updated = await this.prisma.question.update({
      where: { id },
      data: {
        ...(dto.text !== undefined && { text: dto.text.trim() }),
        ...(dto.marks !== undefined && { marks: dto.marks }),
        ...(dto.bloomLevel !== undefined && { bloomLevel: dto.bloomLevel }),
        ...(dto.courseOutcomeId !== undefined && { courseOutcomeId: dto.courseOutcomeId || null }),
        ...(dto.type !== undefined && { type: dto.type }),
        ...((dto.type !== undefined || dto.options !== undefined || dto.correctOption !== undefined) &&
          this.mcqFields(dto.type ?? q.type, dto.options ?? (Array.isArray(q.options) ? (q.options as string[]) : []), dto.correctOption ?? q.correctOption)),
      },
      include: { courseOutcome: { select: { id: true, code: true } } },
    });
    await this.logChange(schoolId, actor, 'QUESTION_UPDATED', 'Question', id, dto);
    return updated;
  }

  async deleteQuestion(schoolId: string, id: string, actor: Actor) {
    const q = await this.getQuestion(schoolId, id);
    await this.assertCanEditSubject(schoolId, q.subjectId, actor);
    const used = await this.prisma.questionPaperItem.count({ where: { questionId: id } });
    if (used > 0) throw new ConflictException(`This question is used in ${used} question paper(s); remove it from them first`);
    const inQuiz = await this.prisma.quizQuestion.count({ where: { questionId: id } });
    if (inQuiz > 0) throw new ConflictException(`This question is used in ${inQuiz} quiz(zes); remove it from them first`);
    await this.prisma.question.delete({ where: { id } });
    await this.logChange(schoolId, actor, 'QUESTION_DELETED', 'Question', id, {});
    return { deleted: true };
  }

  // ================================================================ question papers

  /** Resolve the exam subject / assignment, its subject, roster scope and max marks. */
  private async resolveOwner(schoolId: string, owner: PaperOwner) {
    if (owner.kind === 'exam') {
      const es = await this.prisma.examSubject.findFirst({
        where: { id: owner.examSubjectId, exam: { schoolId } },
        include: {
          exam: { select: { id: true, name: true, academicYearId: true } },
          subject: { select: { id: true, name: true, code: true } },
          class: { select: { id: true, name: true } },
        },
      });
      if (!es) throw new NotFoundException('Exam subject not found');
      return {
        subjectId: es.subjectId,
        maxMarks: es.maxMarks,
        assessmentType: (es.assessmentType === 'EXTERNAL' ? 'EXTERNAL' : 'INTERNAL') as AssessmentType,
        rosterWhere: { schoolId, classId: es.classId, academicYearId: es.exam.academicYearId, status: 'ACTIVE' } as Prisma.EnrollmentWhereInput,
        label: `${es.exam.name} · ${es.subject.name} · ${es.class.name}`,
        paperWhere: { examSubjectId: es.id } as Prisma.QuestionPaperWhereInput,
        link: { examSubjectId: es.id },
      };
    }
    const a = await this.prisma.assignment.findFirst({
      where: { id: owner.assignmentId, schoolId },
      include: { subject: { select: { name: true } }, class: { select: { name: true } }, section: { select: { name: true } } },
    });
    if (!a) throw new NotFoundException('Assignment not found');
    return {
      subjectId: a.subjectId,
      maxMarks: a.maxMarks,
      assessmentType: 'INTERNAL' as AssessmentType,
      rosterWhere: { schoolId, classId: a.classId, sectionId: a.sectionId, status: 'ACTIVE' } as Prisma.EnrollmentWhereInput,
      label: `${a.title} · ${a.subject.name} · ${a.class.name} ${a.section.name}`,
      paperWhere: { assignmentId: a.id } as Prisma.QuestionPaperWhereInput,
      link: { assignmentId: a.id },
    };
  }

  private paperInclude = {
    sections: {
      orderBy: { orderIndex: 'asc' as const },
      include: {
        items: {
          orderBy: { orderIndex: 'asc' as const },
          include: {
            question: {
              select: { id: true, text: true, bloomLevel: true, type: true, courseOutcome: { select: { id: true, code: true } } },
            },
          },
        },
      },
    },
  };

  private shapePaper(paper: any, owner: { maxMarks: number; label: string; assessmentType: AssessmentType; subjectId: string }) {
    if (!paper) return { paper: null, ...owner, totalMarks: 0 };
    const totalMarks = paper.sections.reduce((s: number, sec: any) => s + sec.items.reduce((a: number, i: any) => a + i.marks, 0), 0);
    return { paper, ...owner, totalMarks };
  }

  async getPaper(schoolId: string, owner: PaperOwner) {
    const o = await this.resolveOwner(schoolId, owner);
    const paper = await this.prisma.questionPaper.findFirst({ where: { schoolId, ...o.paperWhere }, include: this.paperInclude });
    return this.shapePaper(paper, o);
  }

  /** Replaces the paper's sections and questions. Refused once marks have been entered. */
  async savePaper(schoolId: string, owner: PaperOwner, dto: SavePaperDto, actor: Actor) {
    const o = await this.resolveOwner(schoolId, owner);
    await this.assertCanEditSubject(schoolId, o.subjectId, actor);

    const questionIds = [...new Set(dto.sections.flatMap((s) => s.items.map((i) => i.questionId)))];
    const questions = await this.prisma.question.findMany({
      where: { schoolId, subjectId: o.subjectId, id: { in: questionIds } },
      select: { id: true, marks: true },
    });
    if (questions.length !== questionIds.length) {
      throw new BadRequestException('Every question must come from this subject’s question bank');
    }
    const bankMarks = new Map(questions.map((q) => [q.id, q.marks]));
    const labels = dto.sections.flatMap((s) => s.items.map((i) => i.label.trim().toLowerCase()));
    if (new Set(labels).size !== labels.length) throw new BadRequestException('Question labels must be unique within a paper');
    const total = dto.sections.reduce((s, sec) => s + sec.items.reduce((a, i) => a + (i.marks ?? bankMarks.get(i.questionId)!), 0), 0);
    if (total > o.maxMarks + 1e-9) {
      throw new BadRequestException(`The paper totals ${total} marks but the maximum for this assessment is ${o.maxMarks}`);
    }

    const existing = await this.prisma.questionPaper.findFirst({ where: { schoolId, ...o.paperWhere }, select: { id: true } });
    if (existing) {
      const marked = await this.prisma.questionMark.count({ where: { paperItem: { section: { paperId: existing.id } } } });
      if (marked > 0) {
        throw new ConflictException('Marks have already been entered for this paper. Clear the marks before changing its questions.');
      }
    }

    // IDs are generated here so sections and items can be inserted with one createMany each
    // (nested creates would cost one ~200 ms round trip per row).
    const paperId = randomUUID();
    const sectionRows = dto.sections.map((sec, si) => ({
      id: randomUUID(),
      paperId,
      title: sec.title.trim(),
      instructions: sec.instructions,
      orderIndex: si,
    }));
    const itemRows = dto.sections.flatMap((sec, si) =>
      sec.items.map((it, ii) => ({
        sectionId: sectionRows[si].id,
        questionId: it.questionId,
        label: it.label.trim(),
        marks: it.marks ?? bankMarks.get(it.questionId)!,
        orderIndex: ii,
      })),
    );
    await this.prisma.$transaction(
      async (tx) => {
        if (existing) await tx.questionPaper.delete({ where: { id: existing.id } });
        await tx.questionPaper.create({
          data: {
            id: paperId,
            schoolId,
            ...o.link,
            title: dto.title.trim(),
            durationMinutes: dto.durationMinutes,
            instructions: dto.instructions,
          },
        });
        if (sectionRows.length) await tx.questionPaperSection.createMany({ data: sectionRows });
        if (itemRows.length) await tx.questionPaperItem.createMany({ data: itemRows });
      },
      { timeout: 20_000, maxWait: 10_000 },
    );
    const paper = await this.prisma.questionPaper.findUniqueOrThrow({ where: { id: paperId }, include: this.paperInclude });
    await this.logChange(schoolId, actor, 'QUESTION_PAPER_SAVED', 'QuestionPaper', paper.id, { ...o.link, total });
    return this.shapePaper(paper, o);
  }

  async deletePaper(schoolId: string, owner: PaperOwner, actor: Actor) {
    const o = await this.resolveOwner(schoolId, owner);
    await this.assertCanEditSubject(schoolId, o.subjectId, actor);
    const existing = await this.prisma.questionPaper.findFirst({ where: { schoolId, ...o.paperWhere }, select: { id: true } });
    if (!existing) throw new NotFoundException('No question paper exists for this assessment');
    const marked = await this.prisma.questionMark.count({ where: { paperItem: { section: { paperId: existing.id } } } });
    if (marked > 0) throw new ConflictException('Marks have already been entered for this paper. Clear the marks first.');
    await this.prisma.questionPaper.delete({ where: { id: existing.id } });
    await this.logChange(schoolId, actor, 'QUESTION_PAPER_DELETED', 'QuestionPaper', existing.id, o.link);
    return { deleted: true };
  }

  async setAssessmentType(schoolId: string, examSubjectId: string, assessmentType: string, actor: Actor) {
    const o = await this.resolveOwner(schoolId, { kind: 'exam', examSubjectId });
    await this.assertCanEditSubject(schoolId, o.subjectId, actor);
    const updated = await this.prisma.examSubject.update({ where: { id: examSubjectId }, data: { assessmentType } });
    await this.logChange(schoolId, actor, 'ASSESSMENT_TYPE_SET', 'ExamSubject', examSubjectId, { assessmentType });
    return { id: updated.id, assessmentType: updated.assessmentType };
  }

  /** Assessments of a subject that can carry a question paper. */
  async listAssessments(schoolId: string, subjectId: string) {
    await this.getSubject(schoolId, subjectId);
    const [examSubjects, assignments] = await Promise.all([
      this.prisma.examSubject.findMany({
        where: { subjectId, exam: { schoolId } },
        include: {
          exam: { select: { id: true, name: true, term: true, status: true } },
          class: { select: { id: true, name: true } },
          questionPaper: { select: { id: true, _count: { select: { sections: true } } } },
        },
        orderBy: { examDate: 'desc' },
      }),
      this.prisma.assignment.findMany({
        where: { schoolId, subjectId },
        include: {
          class: { select: { id: true, name: true } },
          section: { select: { id: true, name: true } },
          questionPaper: { select: { id: true } },
        },
        orderBy: { dueDate: 'desc' },
      }),
    ]);
    return [
      ...examSubjects.map((e) => ({
        kind: 'exam',
        id: e.id,
        title: e.exam.name,
        subtitle: `${e.class.name} · ${e.exam.term}`,
        date: e.examDate,
        maxMarks: e.maxMarks,
        assessmentType: e.assessmentType,
        hasPaper: !!e.questionPaper,
      })),
      ...assignments.map((a) => ({
        kind: 'assignment',
        id: a.id,
        title: a.title,
        subtitle: `${a.class.name} ${a.section.name} · Assignment`,
        date: a.dueDate,
        maxMarks: a.maxMarks,
        assessmentType: 'INTERNAL',
        hasPaper: !!a.questionPaper,
      })),
    ];
  }

  // ================================================================ question-wise marks

  async getPaperMarks(schoolId: string, owner: PaperOwner) {
    const o = await this.resolveOwner(schoolId, owner);
    const paper = await this.prisma.questionPaper.findFirst({ where: { schoolId, ...o.paperWhere }, include: this.paperInclude });
    if (!paper) throw new NotFoundException('Create the question paper before entering marks');
    const items = paper.sections.flatMap((s) =>
      s.items.map((i) => ({
        id: i.id,
        label: i.label,
        marks: i.marks,
        section: s.title,
        courseOutcome: i.question.courseOutcome,
        bloomLevel: i.question.bloomLevel,
      })),
    );
    const [enrollments, marks] = await Promise.all([
      this.prisma.enrollment.findMany({
        where: o.rosterWhere,
        include: { student: { select: { id: true, firstName: true, lastName: true, admissionNo: true } } },
        orderBy: [{ rollNo: 'asc' }],
      }),
      this.prisma.questionMark.findMany({ where: { paperItemId: { in: items.map((i) => i.id) } } }),
    ]);
    const byStudent = new Map<string, Record<string, number>>();
    for (const m of marks) {
      const rec = byStudent.get(m.studentId) ?? {};
      rec[m.paperItemId] = m.marksObtained;
      byStudent.set(m.studentId, rec);
    }
    return {
      paperId: paper.id,
      title: paper.title,
      label: o.label,
      maxMarks: o.maxMarks,
      items,
      students: enrollments.map((e) => {
        const rec = byStudent.get(e.studentId) ?? {};
        const values = Object.values(rec);
        return {
          studentId: e.studentId,
          rollNo: e.rollNo,
          admissionNo: e.student.admissionNo,
          name: `${e.student.firstName} ${e.student.lastName}`,
          marks: rec,
          total: values.length ? Math.round(values.reduce((a, b) => a + b, 0) * 100) / 100 : null,
        };
      }),
    };
  }

  /**
   * Upserts question-wise marks (null clears an entry) and keeps the per-student total
   * in Mark (exams) or Submission (assignments) in sync, rounded to whole marks.
   */
  async saveMarks(schoolId: string, owner: PaperOwner, dto: SaveQuestionMarksDto, actor: Actor) {
    const o = await this.resolveOwner(schoolId, owner);
    await this.assertCanEditSubject(schoolId, o.subjectId, actor);
    const paper = await this.prisma.questionPaper.findFirst({
      where: { schoolId, ...o.paperWhere },
      include: { sections: { include: { items: { select: { id: true, marks: true, label: true } } } } },
    });
    if (!paper) throw new NotFoundException('Create the question paper before entering marks');
    const itemMax = new Map(paper.sections.flatMap((s) => s.items.map((i) => [i.id, i] as const)));

    const studentIds = [...new Set(dto.entries.map((e) => e.studentId))];
    const enrolled = await this.prisma.enrollment.findMany({
      where: { ...o.rosterWhere, studentId: { in: studentIds } },
      select: { studentId: true },
    });
    const enrolledSet = new Set(enrolled.map((e) => e.studentId));
    for (const e of dto.entries) {
      const item = itemMax.get(e.itemId);
      if (!item) throw new BadRequestException('A question in the request does not belong to this paper');
      if (!enrolledSet.has(e.studentId)) throw new BadRequestException('A student in the request is not on this assessment’s roster');
      if (e.marks !== null && e.marks !== undefined && e.marks > item.marks + 1e-9) {
        throw new BadRequestException(`Marks for question ${item.label} cannot exceed ${item.marks}`);
      }
    }

    // Last value wins if the same (student, question) appears twice in one request.
    const latest = new Map<string, { studentId: string; itemId: string; marks: number | null }>();
    for (const e of dto.entries) latest.set(`${e.itemId}|${e.studentId}`, { studentId: e.studentId, itemId: e.itemId, marks: e.marks ?? null });
    const toSet = [...latest.values()].filter((e) => e.marks !== null) as { studentId: string; itemId: string; marks: number }[];
    const toClear = [...latest.values()].filter((e) => e.marks === null);

    // Bulk statements: the database is a ~200 ms round trip away, so per-row queries
    // inside one transaction would exceed the transaction time limit.
    await this.prisma.$transaction(
      async (tx) => {
        if (toClear.length) {
          await tx.questionMark.deleteMany({
            where: { OR: toClear.map((e) => ({ paperItemId: e.itemId, studentId: e.studentId })) },
          });
        }
        if (toSet.length) {
          await tx.$executeRaw`
            INSERT INTO "QuestionMark" ("id", "paperItemId", "studentId", "marksObtained", "updatedAt")
            VALUES ${Prisma.join(toSet.map((e) => Prisma.sql`(gen_random_uuid()::text, ${e.itemId}, ${e.studentId}, ${e.marks}, NOW())`))}
            ON CONFLICT ("paperItemId", "studentId")
            DO UPDATE SET "marksObtained" = EXCLUDED."marksObtained", "updatedAt" = NOW()`;
        }

        const sums = await tx.questionMark.groupBy({
          by: ['studentId'],
          where: { studentId: { in: studentIds }, paperItemId: { in: [...itemMax.keys()] } },
          _sum: { marksObtained: true },
        });
        const totals = sums.map((s) => ({ studentId: s.studentId, total: Math.round(s._sum.marksObtained ?? 0) }));
        const withoutMarks = studentIds.filter((id) => !totals.some((t) => t.studentId === id));

        if ('examSubjectId' in o.link) {
          const examSubjectId = o.link.examSubjectId;
          if (totals.length) {
            await tx.$executeRaw`
              INSERT INTO "Mark" ("id", "examSubjectId", "studentId", "marksObtained", "isAbsent")
              VALUES ${Prisma.join(totals.map((t) => Prisma.sql`(gen_random_uuid()::text, ${examSubjectId}, ${t.studentId}, ${t.total}, false)`))}
              ON CONFLICT ("examSubjectId", "studentId")
              DO UPDATE SET "marksObtained" = EXCLUDED."marksObtained", "isAbsent" = false`;
          }
          if (withoutMarks.length) {
            await tx.mark.updateMany({ where: { examSubjectId, studentId: { in: withoutMarks } }, data: { marksObtained: null } });
          }
        } else {
          const assignmentId = o.link.assignmentId;
          if (totals.length) {
            await tx.$executeRaw`
              INSERT INTO "Submission" ("id", "assignmentId", "studentId", "marksObtained", "status", "submittedAt")
              VALUES ${Prisma.join(totals.map((t) => Prisma.sql`(gen_random_uuid()::text, ${assignmentId}, ${t.studentId}, ${t.total}, 'REVIEWED', NOW())`))}
              ON CONFLICT ("assignmentId", "studentId")
              DO UPDATE SET "marksObtained" = EXCLUDED."marksObtained", "status" = 'REVIEWED'`;
          }
          if (withoutMarks.length) {
            await tx.submission.updateMany({ where: { assignmentId, studentId: { in: withoutMarks } }, data: { marksObtained: null } });
          }
        }
      },
      { timeout: 20_000, maxWait: 10_000 },
    );
    await this.logChange(schoolId, actor, 'QUESTION_MARKS_SAVED', 'QuestionPaper', paper.id, { entries: dto.entries.length });
    return this.getPaperMarks(schoolId, owner);
  }

  // ================================================================ attainment reports

  /**
   * CO and PO attainment for a subject from all question-wise marks on its exam papers
   * and assignment papers. `classId` narrows to one class.
   */
  async subjectAttainment(schoolId: string, subjectId: string, filter: { classId?: string; programId?: string } = {}) {
    const subject = await this.getSubject(schoolId, subjectId);
    const { rule, source } = await this.getRule(schoolId, subjectId);

    const [outcomes, items] = await Promise.all([
      this.prisma.courseOutcome.findMany({
        where: { schoolId, subjectId },
        orderBy: [{ orderIndex: 'asc' }, { code: 'asc' }],
        include: { poMappings: true },
      }),
      this.prisma.questionPaperItem.findMany({
        where: {
          section: {
            paper: {
              schoolId,
              OR: [
                { examSubject: { subjectId, ...(filter.classId && { classId: filter.classId }) } },
                { assignment: { subjectId, ...(filter.classId && { classId: filter.classId }) } },
              ],
            },
          },
        },
        include: {
          question: { select: { courseOutcomeId: true } },
          section: { select: { paper: { select: { examSubject: { select: { assessmentType: true } }, assignmentId: true } } } },
          marksEntries: { select: { studentId: true, marksObtained: true } },
        },
      }),
    ]);

    const assessed = items.map((i) => ({
      itemId: i.id,
      courseOutcomeId: i.question.courseOutcomeId,
      maxMarks: i.marks,
      assessmentType: (i.section.paper.examSubject?.assessmentType === 'EXTERNAL' ? 'EXTERNAL' : 'INTERNAL') as AssessmentType,
    }));
    const marks = items.flatMap((i) => i.marksEntries.map((m) => ({ itemId: i.id, studentId: m.studentId, marks: m.marksObtained })));
    const coResults = computeCoAttainment(
      outcomes.map((o) => ({ id: o.id, code: o.code, description: o.description, indirectLevel: o.indirectLevel })),
      assessed,
      marks,
      rule,
    );

    const programIds = filter.programId ? [filter.programId] : await this.programsForSubject(schoolId, subjectId);
    const programOutcomes = await this.prisma.programOutcome.findMany({
      where: { schoolId, programId: { in: programIds } },
      orderBy: [{ type: 'asc' }, { orderIndex: 'asc' }, { code: 'asc' }],
    });
    const links = outcomes.flatMap((o) =>
      o.poMappings.map((m) => ({ courseOutcomeId: o.id, programOutcomeId: m.programOutcomeId, strength: m.strength })),
    );
    const poResults = computePoAttainment(
      programOutcomes.map((p) => ({ id: p.id, code: p.code, type: p.type, description: p.description })),
      links,
      coResults,
    );

    const unmappedQuestions = assessed.filter((a) => !a.courseOutcomeId).length;
    return {
      subject: { id: subject.id, name: subject.name, code: subject.code },
      rule,
      ruleSource: source,
      courseOutcomes: coResults,
      programOutcomes: poResults,
      summary: {
        questionsAssessed: assessed.length,
        unmappedQuestions,
        marksEntries: marks.length,
        outcomesBelowTarget: coResults.filter((c) => c.meetsTarget === false).length,
        outcomesNotAssessed: coResults.filter((c) => c.finalLevel === null).length,
      },
    };
  }

  /** Program-level PO attainment: mean of each course's PO attainment. */
  async programAttainment(schoolId: string, programId: string) {
    const program = await this.getProgram(schoolId, programId);
    const subjectIds = [
      ...new Set(
        (
          await this.prisma.classSubject.findMany({
            where: { class: { schoolId, programId } },
            select: { subjectId: true },
          })
        ).map((c) => c.subjectId),
      ),
    ];
    const perSubject = await Promise.all(subjectIds.map((id) => this.subjectAttainment(schoolId, id, { programId })));
    const averaged = averagePoAttainment(perSubject.flatMap((s) => s.programOutcomes));
    return {
      program: { id: program.id, code: program.code, name: program.name },
      programOutcomes: program.outcomes.map((po) => ({
        programOutcomeId: po.id,
        code: po.code,
        type: po.type,
        description: po.description,
        attainment: averaged.get(po.id)?.attainment ?? null,
        courses: averaged.get(po.id)?.courses ?? 0,
      })),
      subjects: perSubject.map((s) => ({
        subject: s.subject,
        programOutcomes: s.programOutcomes.map((p) => ({ programOutcomeId: p.programOutcomeId, code: p.code, attainment: p.attainment })),
      })),
    };
  }

  // ================================================================ misc

  private uniqueError(e: unknown, message: string) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') return new ConflictException(message);
    return e;
  }
}
