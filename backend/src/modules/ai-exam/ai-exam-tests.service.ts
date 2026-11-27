import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Actor, AiExamAccessService, isAdmin } from './ai-exam-access.service';
import { AiEvaluationService } from './ai-evaluation.service';
import { AI_TYPES, EVAL, round2, testPhase } from './ai-exam.constants';
import { AiQuestionDto, AssignAiTestDto, RescheduleAiTestDto, SaveAiQuestionsDto, SaveAiTestDto } from './ai-exam.dto';
import { extractNumber } from './grading/objective-grading';
import { describeProvider } from './ai/ai-provider';

const GRACE_MS = 60_000;

@Injectable()
export class AiExamTestsService {
  constructor(
    private prisma: PrismaService,
    private access: AiExamAccessService,
    private evaluation: AiEvaluationService,
  ) {}

  // ---------------------------------------------------------------- shape

  private summary(t: any, extra: Record<string, any> = {}) {
    return {
      id: t.id,
      title: t.title,
      chapter: t.chapter,
      topics: t.topics,
      status: t.status,
      phase: testPhase(t),
      class: t.class ? { id: t.class.id, name: t.class.name } : undefined,
      section: t.section ? { id: t.section.id, name: t.section.name } : null,
      subject: t.subject ? { id: t.subject.id, name: t.subject.name, code: t.subject.code } : undefined,
      academicYear: t.academicYear ? { id: t.academicYear.id, name: t.academicYear.name } : undefined,
      assignMode: t.assignMode,
      totalMarks: t.totalMarks,
      durationMinutes: t.durationMinutes,
      startsAt: t.startsAt,
      endsAt: t.endsAt,
      publishedAt: t.publishedAt,
      resultsPublishedAt: t.resultsPublishedAt,
      autoSubmit: t.autoSubmit,
      createdAt: t.createdAt,
      ...extra,
    };
  }

  // ---------------------------------------------------------------- validation

  private async validatePlacement(schoolId: string, actor: Actor, dto: SaveAiTestDto) {
    await this.access.assertEligibleClass(schoolId, dto.classId);
    const linked = await this.prisma.classSubject.count({ where: { classId: dto.classId, subjectId: dto.subjectId } });
    if (!linked) throw new BadRequestException('The subject is not taught in this class');
    const mode = dto.assignMode ?? 'CLASS';
    const sectionId = mode === 'CLASS' ? null : dto.sectionId || null;
    if (mode === 'SECTION' && !sectionId) throw new BadRequestException('Choose a section');
    if (sectionId && !(await this.prisma.section.count({ where: { id: sectionId, classId: dto.classId, schoolId } }))) {
      throw new BadRequestException('The section does not belong to the class');
    }
    const scope = await this.access.scope(schoolId, actor);
    if (!(await this.access.canManage(schoolId, scope, dto.classId, dto.subjectId, sectionId))) {
      throw new ForbiddenException(sectionId ? 'You do not teach this subject in this section' : 'You do not teach this subject in every section of the class; choose a section');
    }
    const year = dto.academicYearId
      ? await this.prisma.academicYear.findFirst({ where: { id: dto.academicYearId, schoolId } })
      : await this.access.currentYear(schoolId);
    if (!year) throw new BadRequestException('Academic year not found');
    if (dto.startsAt && dto.endsAt && new Date(dto.startsAt) >= new Date(dto.endsAt)) throw new BadRequestException('The test must end after it starts');
    let studentIds: string[] = [];
    if (mode === 'STUDENTS') {
      studentIds = [...new Set(dto.studentIds ?? [])];
      if (!studentIds.length) throw new BadRequestException('Choose at least one student');
      const ok = await this.prisma.enrollment.count({
        where: { schoolId, studentId: { in: studentIds }, classId: dto.classId, academicYearId: year.id, status: 'ACTIVE', ...(sectionId && { sectionId }) },
      });
      if (ok !== studentIds.length) throw new BadRequestException('Some students are not enrolled in this class/section');
    }
    return { mode, sectionId, yearId: year.id, studentIds };
  }

  private validateQuestion(q: AiQuestionDto, n: number) {
    const where = `Question ${n}`;
    const rubric = q.rubric ?? [];
    if (rubric.length) {
      const sum = round2(rubric.reduce((s, r) => s + r.marks, 0));
      if (Math.abs(sum - q.marks) > 0.01) throw new BadRequestException(`${where}: rubric marks add up to ${sum}, the question is worth ${q.marks}`);
    }
    switch (q.type) {
      case 'MCQ': {
        const opts = (q.options ?? []).map((o) => o.trim()).filter(Boolean);
        if (opts.length < 2) throw new BadRequestException(`${where}: add at least 2 options`);
        if (q.correctOption === null || q.correctOption === undefined || q.correctOption >= opts.length) throw new BadRequestException(`${where}: choose the correct option`);
        return { options: opts, correctOption: q.correctOption };
      }
      case 'TRUE_FALSE':
        if (q.correctOption !== 0 && q.correctOption !== 1) throw new BadRequestException(`${where}: choose True or False`);
        return { options: ['False', 'True'], correctOption: q.correctOption };
      case 'FILL_BLANK':
        if (!q.answerKey?.trim()) throw new BadRequestException(`${where}: enter the correct answer`);
        return { options: null, correctOption: null };
      case 'NUMERICAL':
        if (extractNumber(q.answerKey ?? '') === null) throw new BadRequestException(`${where}: the answer key needs the final numeric value`);
        return { options: null, correctOption: null };
      default:
        if (!q.answerKey?.trim() && !rubric.length) throw new BadRequestException(`${where}: add a model answer or a marking rubric`);
        return { options: null, correctOption: null };
    }
  }

  // ---------------------------------------------------------------- read

  options(schoolId: string, actor: Actor) {
    return this.access.options(schoolId, actor).then((o) => ({ ...o, ai: describeProvider() }));
  }

  async list(schoolId: string, actor: Actor, q: { status?: string; classId?: string; subjectId?: string; page?: number; pageSize?: number }) {
    const scope = await this.access.scope(schoolId, actor);
    const ctSlots = await this.access.classTeacherSlots(schoolId, actor);
    const visibility: Prisma.AiExamTestWhereInput = ctSlots.length
      ? { OR: [this.access.testWhere(schoolId, scope), ...ctSlots.map((c) => ({ schoolId, classId: c.classId, sectionId: c.sectionId }))] }
      : this.access.testWhere(schoolId, scope);
    const where: Prisma.AiExamTestWhereInput = {
      AND: [
        visibility,
        {
          ...(q.status === 'ACTIVE_ALL' ? { status: { not: 'ARCHIVED' } } : q.status ? { status: q.status } : {}),
          ...(q.classId && { classId: q.classId }),
          ...(q.subjectId && { subjectId: q.subjectId }),
        },
      ],
    };
    const all = await this.prisma.aiExamTest.findMany({
      where,
      include: { class: true, section: true, subject: true, _count: { select: { questions: true, submissions: true } } },
      orderBy: { createdAt: 'desc' },
    });
    const managed = new Set((await this.access.filterManageable(schoolId, scope, all)).map((t) => t.id));
    const visible = all.filter((t) => managed.has(t.id) || AiExamAccessService.isClassTeacherOf(ctSlots, t));
    const page = Math.max(1, q.page ?? 1);
    const pageSize = Math.min(100, Math.max(1, q.pageSize ?? 20));
    const slice = visible.slice((page - 1) * pageSize, page * pageSize);
    const pending = slice.length
      ? await this.prisma.aiExamSubmission.groupBy({ by: ['testId', 'evaluationStatus'], where: { testId: { in: slice.map((t) => t.id) }, status: 'SUBMITTED' }, _count: true })
      : [];
    return {
      data: slice.map((t) =>
        this.summary(t, {
          questions: t._count.questions,
          submissions: t._count.submissions,
          access: managed.has(t.id) ? 'MANAGE' : 'SCHEDULE',
          needsAttention: pending.filter((p) => p.testId === t.id && p.evaluationStatus !== EVAL.EVALUATED).reduce((s, p) => s + p._count, 0),
        }),
      ),
      meta: { page, pageSize, total: visible.length },
    };
  }

  async get(schoolId: string, actor: Actor, id: string) {
    const { test: t, access } = await this.access.accessibleTest(schoolId, actor, id);
    if (access === 'SCHEDULE') return this.scheduleView(t);
    const [questions, assignees, roster, subs] = await Promise.all([
      this.prisma.aiExamQuestion.findMany({ where: { testId: id }, include: { rubric: { orderBy: { orderIndex: 'asc' } } }, orderBy: { orderIndex: 'asc' } }),
      this.prisma.aiExamAssignee.findMany({ where: { testId: id }, include: { student: { select: { id: true, firstName: true, lastName: true, admissionNo: true } } } }),
      this.access.roster(t),
      this.prisma.aiExamSubmission.groupBy({ by: ['status', 'evaluationStatus'], where: { testId: id }, _count: true }),
    ]);
    const count = (f: (s: (typeof subs)[number]) => boolean) => subs.filter(f).reduce((s, x) => s + x._count, 0);
    return this.summary(t, {
      description: t.description,
      instructions: t.instructions,
      questions: questions.map((q) => ({ ...q, rubric: q.rubric.map((r) => ({ id: r.id, description: r.description, marks: r.marks })) })),
      assignees: assignees.map((a) => ({ id: a.student.id, name: `${a.student.firstName} ${a.student.lastName}`, admissionNo: a.student.admissionNo })),
      stats: {
        assigned: roster.length,
        started: count(() => true),
        submitted: count((s) => s.status === 'SUBMITTED'),
        inProgress: count((s) => s.status === 'IN_PROGRESS'),
        evaluated: count((s) => s.status === 'SUBMITTED' && s.evaluationStatus === EVAL.EVALUATED),
        needsReview: count((s) => s.evaluationStatus === EVAL.REVIEW),
        pendingEvaluation: count((s) => s.evaluationStatus === EVAL.PENDING || s.evaluationStatus === EVAL.PROCESSING),
        failed: count((s) => s.evaluationStatus === EVAL.FAILED),
      },
      access: 'MANAGE',
      canEditQuestions: count(() => true) === 0,
      aiQuestions: questions.filter((q) => AI_TYPES.includes(q.type as any) || q.type === 'NUMERICAL' || q.type === 'FILL_BLANK').length,
    });
  }

  // ---------------------------------------------------------------- write

  async create(schoolId: string, actor: Actor, dto: SaveAiTestDto) {
    const p = await this.validatePlacement(schoolId, actor, dto);
    const t = await this.prisma.aiExamTest.create({
      data: {
        schoolId,
        academicYearId: p.yearId,
        classId: dto.classId,
        sectionId: p.sectionId,
        subjectId: dto.subjectId,
        title: dto.title.trim(),
        description: dto.description?.trim() || null,
        chapter: dto.chapter?.trim() || null,
        topics: (dto.topics ?? []).map((x) => x.trim()).filter(Boolean),
        instructions: dto.instructions?.trim() || null,
        durationMinutes: dto.durationMinutes ?? null,
        startsAt: dto.startsAt ? new Date(dto.startsAt) : null,
        endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
        assignMode: p.mode,
        autoSubmit: dto.autoSubmit ?? true,
        createdById: actor.userId,
        ...(p.studentIds.length && { assignees: { createMany: { data: p.studentIds.map((studentId) => ({ studentId })) } } }),
      },
    });
    await this.access.log(schoolId, actor, 'AI_EXAM_CREATED', t.id, { title: t.title });
    return this.get(schoolId, actor, t.id);
  }

  async update(schoolId: string, actor: Actor, id: string, dto: SaveAiTestDto) {
    const t = await this.access.manageableTest(schoolId, actor, id);
    if (t.status === 'CLOSED' || t.status === 'ARCHIVED') throw new ConflictException('Closed or archived tests cannot be edited');
    const started = await this.prisma.aiExamSubmission.count({ where: { testId: id } });
    if (started) {
      const placementChanged =
        dto.classId !== t.classId || dto.subjectId !== t.subjectId || (dto.assignMode ?? 'CLASS') !== t.assignMode || (dto.sectionId || null) !== (t.assignMode === 'CLASS' ? null : t.sectionId);
      if (placementChanged) throw new ConflictException('Students have started this test; class, subject and assignment can no longer change');
      if (dto.durationMinutes !== undefined && dto.durationMinutes !== t.durationMinutes) throw new ConflictException('Students have started this test; the duration can no longer change');
    }
    const p = await this.validatePlacement(schoolId, actor, dto);
    await this.prisma.$transaction([
      this.prisma.aiExamTest.update({
        where: { id },
        data: {
          academicYearId: p.yearId,
          classId: dto.classId,
          sectionId: p.sectionId,
          subjectId: dto.subjectId,
          title: dto.title.trim(),
          description: dto.description?.trim() || null,
          chapter: dto.chapter?.trim() || null,
          topics: (dto.topics ?? []).map((x) => x.trim()).filter(Boolean),
          instructions: dto.instructions?.trim() || null,
          durationMinutes: dto.durationMinutes ?? null,
          startsAt: dto.startsAt ? new Date(dto.startsAt) : null,
          endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
          assignMode: p.mode,
          autoSubmit: dto.autoSubmit ?? t.autoSubmit,
        },
      }),
      this.prisma.aiExamAssignee.deleteMany({ where: { testId: id, ...(p.mode === 'STUDENTS' && { studentId: { notIn: p.studentIds } }) } }),
      ...(p.mode === 'STUDENTS' ? [this.prisma.aiExamAssignee.createMany({ data: p.studentIds.map((studentId) => ({ testId: id, studentId })), skipDuplicates: true })] : []),
    ]);
    await this.syncDeadlines({ id, durationMinutes: dto.durationMinutes ?? null, endsAt: dto.endsAt ? new Date(dto.endsAt) : null });
    await this.access.log(schoolId, actor, 'AI_EXAM_UPDATED', id, { title: dto.title });
    return this.get(schoolId, actor, id);
  }

  async assign(schoolId: string, actor: Actor, id: string, dto: AssignAiTestDto) {
    const t = await this.access.manageableTest(schoolId, actor, id);
    return this.update(schoolId, actor, id, {
      title: t.title,
      academicYearId: t.academicYearId,
      classId: t.classId,
      subjectId: t.subjectId,
      chapter: t.chapter ?? undefined,
      topics: t.topics,
      description: t.description ?? undefined,
      instructions: t.instructions ?? undefined,
      durationMinutes: t.durationMinutes,
      startsAt: t.startsAt?.toISOString() ?? null,
      endsAt: t.endsAt?.toISOString() ?? null,
      autoSubmit: t.autoSubmit,
      assignMode: dto.assignMode,
      sectionId: dto.sectionId,
      studentIds: dto.studentIds,
    });
  }

  async saveQuestions(schoolId: string, actor: Actor, id: string, dto: SaveAiQuestionsDto) {
    const t = await this.access.manageableTest(schoolId, actor, id);
    if (t.status === 'CLOSED' || t.status === 'ARCHIVED') throw new ConflictException('Closed or archived tests cannot be edited');
    if (await this.prisma.aiExamSubmission.count({ where: { testId: id } })) throw new ConflictException('Students have started this test; questions can no longer change');
    const prepared = dto.questions.map((q, i) => ({ q, extra: this.validateQuestion(q, i + 1) }));
    const total = round2(dto.questions.reduce((s, q) => s + q.marks, 0));
    await this.prisma.$transaction(
      async (tx) => {
        await tx.aiExamQuestion.deleteMany({ where: { testId: id } });
        for (const [i, { q, extra }] of prepared.entries()) {
          await tx.aiExamQuestion.create({
            data: {
              testId: id,
              orderIndex: i,
              type: q.type,
              text: q.text.trim(),
              imageUrl: q.imageUrl || null,
              marks: q.marks,
              chapter: q.chapter?.trim() || null,
              topic: q.topic?.trim() || null,
              difficulty: q.difficulty ?? 'MEDIUM',
              options: extra.options ?? Prisma.DbNull,
              correctOption: extra.correctOption,
              answerKey: q.type === 'TRUE_FALSE' ? (extra.correctOption === 1 ? 'True' : 'False') : q.answerKey?.trim() || null,
              acceptableAnswers: (q.acceptableAnswers ?? []).map((x) => x.trim()).filter(Boolean),
              keywords: (q.keywords ?? []).map((x) => x.trim()).filter(Boolean),
              concepts: (q.concepts ?? []).map((x) => x.trim()).filter(Boolean),
              explanation: q.explanation?.trim() || null,
              partialCredit: q.partialCredit?.trim() || null,
              tolerance: q.type === 'NUMERICAL' ? (q.tolerance ?? 0) : null,
              rubric: { createMany: { data: (q.rubric ?? []).map((r, j) => ({ description: r.description.trim(), marks: r.marks, orderIndex: j })) } },
            },
          });
        }
        await tx.aiExamTest.update({ where: { id }, data: { totalMarks: total } });
      },
      { timeout: 30_000, maxWait: 10_000 },
    );
    await this.access.log(schoolId, actor, 'AI_EXAM_QUESTIONS_SAVED', id, { questions: dto.questions.length, totalMarks: total });
    return this.get(schoolId, actor, id);
  }

  /** What a class teacher sees: details and progress counts, no questions, answer keys or answers. */
  private async scheduleView(t: any) {
    const [questions, roster, subs] = await Promise.all([
      this.prisma.aiExamQuestion.count({ where: { testId: t.id } }),
      this.access.roster(t),
      this.prisma.aiExamSubmission.groupBy({ by: ['status'], where: { testId: t.id }, _count: true }),
    ]);
    const n = (st: string) => subs.find((x) => x.status === st)?._count ?? 0;
    return this.summary(t, {
      access: 'SCHEDULE',
      description: t.description,
      instructions: t.instructions,
      questionCount: questions,
      questions: [],
      assignees: [],
      stats: { assigned: roster.length, started: n('IN_PROGRESS') + n('SUBMITTED'), submitted: n('SUBMITTED'), inProgress: n('IN_PROGRESS') },
      canEditQuestions: false,
    });
  }

  /** Keeps open attempts' deadlines in step with the test's duration and end time. */
  private async syncDeadlines(test: { id: string; durationMinutes: number | null; endsAt: Date | null }) {
    const open = await this.prisma.aiExamSubmission.findMany({ where: { testId: test.id, status: 'IN_PROGRESS' }, select: { id: true, startedAt: true } });
    for (const s of open) {
      const byDuration = test.durationMinutes ? new Date(s.startedAt.getTime() + test.durationMinutes * 60_000) : null;
      const deadline = byDuration && test.endsAt ? (byDuration < test.endsAt ? byDuration : test.endsAt) : (byDuration ?? test.endsAt);
      await this.prisma.aiExamSubmission.update({ where: { id: s.id }, data: { deadline } });
    }
    return open.length;
  }

  /**
   * Changes a test's start/end time. Allowed for administrators, the subject teacher and the class
   * teacher of the test's section. A closed test with a future end time is reopened for students who
   * have not submitted; tests whose results are published cannot be rescheduled.
   */
  async reschedule(schoolId: string, actor: Actor, id: string, dto: RescheduleAiTestDto) {
    const { test: t, access } = await this.access.accessibleTest(schoolId, actor, id);
    if (t.status === 'ARCHIVED') throw new ConflictException('Archived tests cannot be rescheduled');
    if (t.resultsPublishedAt) throw new ConflictException('Results are already published; this test can no longer be rescheduled');
    const started = await this.prisma.aiExamSubmission.count({ where: { testId: id } });
    const startsAt = dto.startsAt === undefined ? t.startsAt : dto.startsAt ? new Date(dto.startsAt) : null;
    const endsAt = dto.endsAt === undefined ? t.endsAt : dto.endsAt ? new Date(dto.endsAt) : null;
    if (started && (startsAt?.getTime() ?? null) !== (t.startsAt?.getTime() ?? null)) {
      throw new ConflictException('Students have already started this test; only the end time can change');
    }
    if (startsAt && endsAt && startsAt >= endsAt) throw new BadRequestException('The test must end after it starts');
    if (t.status !== 'DRAFT' && endsAt && endsAt.getTime() <= Date.now()) throw new BadRequestException('The new end time must be in the future');
    const reopened = t.status === 'CLOSED';
    await this.prisma.aiExamTest.update({ where: { id }, data: { startsAt, endsAt, ...(reopened && { status: 'PUBLISHED' }) } });
    const adjusted = await this.syncDeadlines({ id, durationMinutes: t.durationMinutes, endsAt });
    await this.access.log(schoolId, actor, 'AI_EXAM_RESCHEDULED', id, {
      from: { startsAt: t.startsAt, endsAt: t.endsAt },
      to: { startsAt, endsAt },
      reason: dto.reason.trim(),
      reopened,
      openAttemptsAdjusted: adjusted,
      as: access === 'SCHEDULE' ? 'CLASS_TEACHER' : isAdmin(actor) ? 'ADMIN' : 'SUBJECT_TEACHER',
    });
    return this.get(schoolId, actor, id);
  }

  async publish(schoolId: string, actor: Actor, id: string) {
    const t = await this.access.manageableTest(schoolId, actor, id);
    if (t.status !== 'DRAFT') throw new ConflictException('Only draft tests can be published');
    await this.access.assertEligibleClass(schoolId, t.classId);
    const questions = await this.prisma.aiExamQuestion.count({ where: { testId: id } });
    if (!questions) throw new BadRequestException('Add at least one question before publishing');
    if (t.endsAt && t.endsAt <= new Date()) throw new BadRequestException('The end time has already passed');
    if (t.assignMode === 'STUDENTS' && !(await this.prisma.aiExamAssignee.count({ where: { testId: id } }))) throw new BadRequestException('Choose the students first');
    await this.prisma.aiExamTest.update({ where: { id }, data: { status: 'PUBLISHED', publishedAt: new Date() } });
    await this.access.log(schoolId, actor, 'AI_EXAM_PUBLISHED', id, {});
    return this.get(schoolId, actor, id);
  }

  /** Closes the test; attempts still open are submitted with what was saved. */
  async close(schoolId: string, actor: Actor, id: string) {
    const t = await this.access.manageableTest(schoolId, actor, id);
    if (t.status !== 'PUBLISHED') throw new ConflictException('Only published tests can be closed');
    await this.prisma.aiExamTest.update({ where: { id }, data: { status: 'CLOSED', endsAt: t.endsAt && t.endsAt < new Date() ? t.endsAt : new Date() } });
    const open = await this.prisma.aiExamSubmission.findMany({ where: { testId: id, status: 'IN_PROGRESS' }, select: { id: true } });
    for (const s of open) await this.evaluation.finalize(s.id, { auto: true });
    await this.access.log(schoolId, actor, 'AI_EXAM_CLOSED', id, { autoSubmitted: open.length });
    return this.get(schoolId, actor, id);
  }

  async archive(schoolId: string, actor: Actor, id: string) {
    const t = await this.access.manageableTest(schoolId, actor, id);
    if (t.status === 'PUBLISHED') throw new ConflictException('Close the test before archiving it');
    await this.prisma.aiExamTest.update({ where: { id }, data: { status: 'ARCHIVED' } });
    await this.access.log(schoolId, actor, 'AI_EXAM_ARCHIVED', id, {});
    return this.get(schoolId, actor, id);
  }

  async remove(schoolId: string, actor: Actor, id: string) {
    await this.access.manageableTest(schoolId, actor, id);
    if (await this.prisma.aiExamSubmission.count({ where: { testId: id } })) throw new ConflictException('Students have attempted this test; archive it instead');
    await this.prisma.aiExamTest.delete({ where: { id } });
    await this.access.log(schoolId, actor, 'AI_EXAM_DELETED', id, {});
    return { deleted: true };
  }

  /** Releases results to students once every submission is evaluated and the test has ended. */
  async publishResults(schoolId: string, actor: Actor, id: string) {
    const t = await this.access.manageableTest(schoolId, actor, id);
    const ended = t.status === 'CLOSED' || t.status === 'ARCHIVED' || (t.endsAt && t.endsAt.getTime() < Date.now() - GRACE_MS);
    if (!ended) throw new ConflictException('Close the test (or wait until it ends) before publishing results');
    await this.evaluation.autoSubmitExpired();
    const open = await this.prisma.aiExamSubmission.count({ where: { testId: id, status: 'IN_PROGRESS' } });
    if (open) throw new ConflictException(`${open} attempt(s) are still open; close the test first`);
    const notReady = await this.prisma.aiExamSubmission.groupBy({ by: ['evaluationStatus'], where: { testId: id, status: 'SUBMITTED', evaluationStatus: { not: EVAL.EVALUATED } }, _count: true });
    if (notReady.length) {
      throw new ConflictException(`Not every answer is evaluated yet (${notReady.map((n) => `${n._count} ${n.evaluationStatus.toLowerCase()}`).join(', ')}). Review or mark them first.`);
    }
    await this.prisma.aiExamTest.update({ where: { id }, data: { resultsPublishedAt: new Date() } });
    await this.access.log(schoolId, actor, 'AI_EXAM_RESULTS_PUBLISHED', id, {});
    return this.get(schoolId, actor, id);
  }

  // ---------------------------------------------------------------- roster & submissions

  /** Students of the class/section, for choosing individual students. */
  async candidates(schoolId: string, actor: Actor, classId: string, sectionId?: string) {
    await this.access.assertEligibleClass(schoolId, classId);
    const scope = await this.access.scope(schoolId, actor);
    const sections = await this.prisma.section.findMany({ where: { schoolId, classId, ...(sectionId && { id: sectionId }) }, select: { id: true } });
    const allowed: string[] = [];
    for (const s of sections) if (scope === null || scope.some((x) => x.classId === classId && x.sectionId === s.id)) allowed.push(s.id);
    const year = await this.access.currentYear(schoolId);
    const rows = await this.prisma.enrollment.findMany({
      where: { schoolId, classId, sectionId: { in: allowed }, academicYearId: year.id, status: 'ACTIVE' },
      include: { student: { select: { id: true, firstName: true, lastName: true, admissionNo: true } }, section: { select: { name: true } } },
      orderBy: [{ section: { name: 'asc' } }, { rollNo: 'asc' }],
    });
    return rows.map((r) => ({ id: r.student.id, name: `${r.student.firstName} ${r.student.lastName}`, admissionNo: r.student.admissionNo, section: r.section.name, sectionId: r.sectionId }));
  }

  async submissions(schoolId: string, actor: Actor, id: string, q: { status?: string; page?: number; pageSize?: number }) {
    const t = await this.access.manageableTest(schoolId, actor, id);
    const rosterIds = await this.access.roster(t);
    const [students, subs] = await Promise.all([
      this.prisma.student.findMany({
        where: { id: { in: rosterIds } },
        select: { id: true, firstName: true, lastName: true, admissionNo: true, enrollments: { where: { academicYearId: t.academicYearId }, select: { section: { select: { name: true } }, rollNo: true } } },
      }),
      this.prisma.aiExamSubmission.findMany({ where: { testId: id } }),
    ]);
    const byStudent = new Map(subs.map((s) => [s.studentId, s]));
    let rows = students
      .map((s) => {
        const sub = byStudent.get(s.id);
        return {
          studentId: s.id,
          name: `${s.firstName} ${s.lastName}`,
          admissionNo: s.admissionNo,
          section: s.enrollments[0]?.section.name ?? '',
          rollNo: s.enrollments[0]?.rollNo ?? null,
          submissionId: sub?.id ?? null,
          status: sub ? sub.status : 'NOT_STARTED',
          evaluationStatus: sub?.evaluationStatus ?? null,
          score: sub?.score ?? null,
          maxScore: sub?.maxScore || t.totalMarks,
          percent: sub?.score !== null && sub?.score !== undefined && sub.maxScore ? round2((sub.score / sub.maxScore) * 100) : null,
          startedAt: sub?.startedAt ?? null,
          submittedAt: sub?.submittedAt ?? null,
          late: sub?.late ?? false,
          autoSubmitted: sub?.autoSubmitted ?? false,
        };
      })
      .sort((a, b) => (a.rollNo ?? 9999) - (b.rollNo ?? 9999) || a.name.localeCompare(b.name));
    if (q.status) rows = rows.filter((r) => r.status === q.status || r.evaluationStatus === q.status);
    const page = Math.max(1, q.page ?? 1);
    const pageSize = Math.min(200, Math.max(1, q.pageSize ?? 50));
    return { data: rows.slice((page - 1) * pageSize, page * pageSize), meta: { page, pageSize, total: rows.length } };
  }

  async submission(schoolId: string, actor: Actor, testId: string, submissionId: string) {
    const t = await this.access.manageableTest(schoolId, actor, testId);
    const sub = await this.prisma.aiExamSubmission.findFirst({
      where: { id: submissionId, testId },
      include: {
        student: { select: { firstName: true, lastName: true, admissionNo: true } },
        answers: { include: { question: { include: { rubric: { orderBy: { orderIndex: 'asc' } } } }, evaluation: { include: { events: { orderBy: { createdAt: 'asc' } } } } } },
      },
    });
    if (!sub) throw new NotFoundException('Submission not found');
    return {
      id: sub.id,
      test: this.summary(t),
      student: { id: sub.studentId, name: `${sub.student.firstName} ${sub.student.lastName}`, admissionNo: sub.student.admissionNo },
      status: sub.status,
      evaluationStatus: sub.evaluationStatus,
      score: sub.score,
      maxScore: sub.maxScore,
      startedAt: sub.startedAt,
      submittedAt: sub.submittedAt,
      late: sub.late,
      autoSubmitted: sub.autoSubmitted,
      answers: sub.answers
        .sort((a, b) => a.question.orderIndex - b.question.orderIndex)
        .map((a) => ({
          answerId: a.id,
          text: a.text,
          choice: a.choice,
          inputMethod: a.inputMethod,
          question: { ...a.question, rubric: a.question.rubric.map((r) => ({ description: r.description, marks: r.marks })) },
          evaluation: a.evaluation,
        })),
    };
  }

  /** Loads an evaluation the actor may review. */
  async reviewableEvaluation(schoolId: string, actor: Actor, evaluationId: string) {
    const ev = await this.prisma.aiExamEvaluation.findFirst({
      where: { id: evaluationId, answer: { submission: { schoolId } } },
      include: { answer: { include: { submission: { select: { id: true, testId: true } } } } },
    });
    if (!ev) throw new NotFoundException('Evaluation not found');
    await this.access.manageableTest(schoolId, actor, ev.answer.submission.testId);
    return ev;
  }

  async override(schoolId: string, actor: Actor, evaluationId: string, marks: number, reason: string) {
    const ev = await this.reviewableEvaluation(schoolId, actor, evaluationId);
    try {
      const final = await this.evaluation.override(evaluationId, marks, reason.trim(), actor.userId);
      await this.evaluation.recompute(ev.answer.submission.id);
      await this.access.log(schoolId, actor, 'AI_EXAM_MARKS_OVERRIDDEN', evaluationId, { from: ev.finalMarks, aiMarks: ev.aiMarks, to: final, reason });
      return { evaluationId, finalMarks: final };
    } catch (e: any) {
      if (e instanceof RangeError) throw new BadRequestException(e.message);
      if (e?.message === 'PROCESSING') throw new ConflictException('This answer is being evaluated right now; try again in a moment');
      throw e;
    }
  }

  async accept(schoolId: string, actor: Actor, evaluationId: string) {
    const ev = await this.reviewableEvaluation(schoolId, actor, evaluationId);
    try {
      const final = await this.evaluation.accept(evaluationId, actor.userId);
      await this.evaluation.recompute(ev.answer.submission.id);
      await this.access.log(schoolId, actor, 'AI_EXAM_EVALUATION_ACCEPTED', evaluationId, { marks: final });
      return { evaluationId, finalMarks: final };
    } catch (e: any) {
      if (e?.message === 'NOT_REVIEWABLE') throw new ConflictException('Only AI evaluations waiting for review can be accepted');
      throw e;
    }
  }

  /** Teacher dashboard: tests, pending evaluations, recent submissions. */
  async dashboard(schoolId: string, actor: Actor) {
    const scope = await this.access.scope(schoolId, actor);
    const tests = await this.access.filterManageable(
      schoolId,
      scope,
      await this.prisma.aiExamTest.findMany({
        where: { AND: [this.access.testWhere(schoolId, scope), { status: { not: 'ARCHIVED' } }] },
        include: { class: true, section: true, subject: true, _count: { select: { questions: true, submissions: true } } },
        orderBy: { createdAt: 'desc' },
      }),
    );
    const ids = tests.map((t) => t.id);
    const [byStatus, recent, perTest] = await Promise.all([
      ids.length ? this.prisma.aiExamSubmission.groupBy({ by: ['evaluationStatus'], where: { testId: { in: ids }, status: 'SUBMITTED' }, _count: true }) : [],
      ids.length
        ? this.prisma.aiExamSubmission.findMany({
            where: { testId: { in: ids }, status: 'SUBMITTED' },
            include: { student: { select: { firstName: true, lastName: true } }, test: { select: { id: true, title: true } } },
            orderBy: { submittedAt: 'desc' },
            take: 8,
          })
        : [],
      ids.length ? this.prisma.aiExamSubmission.groupBy({ by: ['testId'], where: { testId: { in: ids }, evaluationStatus: EVAL.EVALUATED }, _sum: { score: true, maxScore: true }, _count: true }) : [],
    ]);
    const n = (s: string) => byStatus.find((b) => b.evaluationStatus === s)?._count ?? 0;
    const phases = tests.map((t) => ({ t, phase: testPhase(t) }));
    const classPerf = new Map<string, { label: string; score: number; max: number; tests: number }>();
    for (const p of perTest) {
      const t = tests.find((x) => x.id === p.testId)!;
      const key = `${t.classId}|${t.subjectId}`;
      const cur = classPerf.get(key) ?? { label: `${t.class.name} · ${t.subject.name}`, score: 0, max: 0, tests: 0 };
      classPerf.set(key, { ...cur, score: cur.score + (p._sum.score ?? 0), max: cur.max + (p._sum.maxScore ?? 0), tests: cur.tests + 1 });
    }
    return {
      ai: describeProvider(),
      counts: {
        tests: tests.length,
        drafts: phases.filter((p) => p.phase === 'DRAFT').length,
        active: phases.filter((p) => p.phase === 'ACTIVE').length,
        scheduled: phases.filter((p) => p.phase === 'SCHEDULED').length,
        pendingEvaluation: n(EVAL.PENDING) + n(EVAL.PROCESSING),
        needsReview: n(EVAL.REVIEW),
        failed: n(EVAL.FAILED),
        evaluated: n(EVAL.EVALUATED),
      },
      activeTests: phases.filter((p) => p.phase === 'ACTIVE').slice(0, 6).map((p) => this.summary(p.t, { submissions: p.t._count.submissions })),
      scheduledTests: phases.filter((p) => p.phase === 'SCHEDULED').slice(0, 6).map((p) => this.summary(p.t)),
      recentSubmissions: recent.map((s) => ({ submissionId: s.id, testId: s.test.id, test: s.test.title, student: `${s.student.firstName} ${s.student.lastName}`, submittedAt: s.submittedAt, evaluationStatus: s.evaluationStatus, score: s.score, maxScore: s.maxScore })),
      classPerformance: [...classPerf.values()].map((c) => ({ label: c.label, tests: c.tests, percent: c.max ? round2((c.score / c.max) * 100) : null })),
      isAdmin: isAdmin(actor),
    };
  }
}
