import { ForbiddenException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Actor, AiExamAccessService } from './ai-exam-access.service';
import { AiEvaluationService } from './ai-evaluation.service';
import { EVAL, classGrade, isEligibleClass, round2, testPhase } from './ai-exam.constants';
import { AnswerRecord, improvementPlan, pct, Performance, Plan, studentPerformance, TestRecord, trend } from './analytics/performance';
import { describeProvider, readAiConfig, withRetries } from './ai/ai-provider';

export interface AnalyticsFilter {
  classId?: string;
  sectionId?: string;
  subjectId?: string;
  testId?: string;
  academicYearId?: string;
  from?: string;
  to?: string;
}

const strs = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);

@Injectable()
export class AiExamAnalyticsService {
  private readonly logger = new Logger('AiExamAnalytics');
  constructor(
    private prisma: PrismaService,
    private access: AiExamAccessService,
    private evaluation: AiEvaluationService,
  ) {}

  /** Evaluated records of one student, optionally limited to some tests. */
  private async records(studentId: string, where: Prisma.AiExamTestWhereInput, publishedOnly: boolean) {
    const subs = await this.prisma.aiExamSubmission.findMany({
      where: {
        studentId,
        status: 'SUBMITTED',
        evaluationStatus: EVAL.EVALUATED,
        test: { AND: [where, publishedOnly ? { resultsPublishedAt: { not: null } } : {}] },
      },
      include: {
        test: { include: { subject: true } },
        answers: { include: { question: { select: { topic: true, chapter: true, marks: true } }, evaluation: { select: { finalMarks: true, maxMarks: true, feedback: true } } } },
      },
    });
    const tests: TestRecord[] = [];
    const answers: AnswerRecord[] = [];
    for (const s of subs) {
      const date = s.submittedAt ?? s.startedAt;
      tests.push({ testId: s.testId, title: s.test.title, subjectId: s.test.subjectId, subject: s.test.subject.name, date, score: s.score ?? 0, max: s.maxScore });
      for (const a of s.answers) {
        if (!a.evaluation || a.evaluation.finalMarks === null) continue;
        const fb: any = a.evaluation.feedback ?? {};
        answers.push({
          testId: s.testId,
          subjectId: s.test.subjectId,
          subject: s.test.subject.name,
          topic: a.question.topic || a.question.chapter || s.test.chapter || 'General',
          date,
          marks: a.evaluation.finalMarks,
          max: a.evaluation.maxMarks,
          missingPoints: strs(fb.missing_points),
          errors: [...strs(fb.conceptual_errors), ...strs(fb.incorrect_points)],
        });
      }
    }
    return { tests, answers };
  }

  // ---------------------------------------------------------------- student

  async myPerformance(schoolId: string, userId: string) {
    const s = await this.access.student(schoolId, userId);
    if (!s.eligible) throw new ForbiddenException('AI Examination is available for Classes 10, 11 and 12 only');
    const { tests, answers } = await this.records(s.studentId, { schoolId }, true);
    return { student: { name: s.name, className: s.className }, ...studentPerformance(tests, answers) };
  }

  /** Cached plan; regenerated when newer published results exist (or on request). */
  async myPlan(schoolId: string, userId: string, refresh = false) {
    const s = await this.access.student(schoolId, userId);
    if (!s.eligible) throw new ForbiddenException('AI Examination is available for Classes 10, 11 and 12 only');
    const { tests, answers } = await this.records(s.studentId, { schoolId }, true);
    const perf = studentPerformance(tests, answers);
    const plan = improvementPlan(perf);
    if (!plan) return { enoughData: false, message: 'Your improvement plan appears after your first evaluated test result is published.', plan: null };
    const latestResult = await this.prisma.aiExamTest.findFirst({
      where: { resultsPublishedAt: { not: null }, submissions: { some: { studentId: s.studentId, status: 'SUBMITTED' } } },
      orderBy: { resultsPublishedAt: 'desc' },
      select: { resultsPublishedAt: true },
    });
    const cached = await this.prisma.aiExamImprovementPlan.findFirst({ where: { studentId: s.studentId }, orderBy: { createdAt: 'desc' } });
    if (!refresh && cached && cached.basedOn === plan.basedOnTests && latestResult?.resultsPublishedAt && cached.createdAt >= latestResult.resultsPublishedAt) {
      return { enoughData: plan.enoughData, source: cached.source, plan: cached.plan, generatedAt: cached.createdAt };
    }
    const { source, plan: finalPlan } = await this.phrase(plan, perf);
    const saved = await this.prisma.aiExamImprovementPlan.create({ data: { schoolId, studentId: s.studentId, source, plan: finalPlan as any, basedOn: plan.basedOnTests } });
    return { enoughData: plan.enoughData, source, plan: finalPlan, generatedAt: saved.createdAt };
  }

  /**
   * The ranking and numbers always come from the records. When a real AI provider is configured it
   * only rewrites the step wording from aggregated data; any problem falls back to the rule-based text.
   */
  private async phrase(plan: Plan, perf: Performance): Promise<{ source: string; plan: Plan }> {
    const provider = this.evaluation.provider;
    if (!provider || provider.isMock || !plan.priorities.length) return { source: 'RULES', plan };
    try {
      const facts = {
        tests: perf.overall.tests,
        averagePercent: perf.overall.averagePercent,
        trend: perf.overall.trend,
        subjects: perf.subjects.map((x) => ({ subject: x.subject, average: x.average, tests: x.tests })),
        priorities: plan.priorities,
        topicDetails: perf.topics.filter((t) => plan.priorities.some((p) => p.topic === t.topic && p.subject === t.subject)).map((t) => ({ topic: t.topic, subject: t.subject, commonMissing: t.commonMissing.map((m) => m.text), commonErrors: t.commonErrors.map((m) => m.text) })),
      };
      const raw = await withRetries(
        () =>
          provider.complete(
            [
              {
                role: 'system',
                content:
                  'You write short, practical study plans for a school student. Use ONLY the facts given; do not invent topics, scores or weaknesses. ' +
                  'Reply with JSON: {"steps":[{"title":"...","detail":"..."}]} with 3 to 6 steps, most important first.',
              },
              { role: 'user', content: JSON.stringify(facts) },
            ],
            { json: true, maxTokens: 900 },
          ),
        readAiConfig().maxRetries,
      );
      const o = JSON.parse(raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, ''));
      const steps = (Array.isArray(o?.steps) ? o.steps : [])
        .filter((x: any) => typeof x?.title === 'string' && typeof x?.detail === 'string')
        .slice(0, 6)
        .map((x: any) => ({ title: x.title.slice(0, 160), detail: x.detail.slice(0, 600) }));
      if (steps.length < 2) throw new Error('too few steps');
      return { source: 'AI', plan: { ...plan, steps } };
    } catch (e: any) {
      this.logger.warn(`AI plan wording failed, using rules: ${e?.message}`);
      return { source: 'RULES', plan };
    }
  }

  // ---------------------------------------------------------------- teacher / admin

  private async scopedTests(schoolId: string, actor: Actor, f: AnalyticsFilter) {
    const scope = await this.access.scope(schoolId, actor);
    const where: Prisma.AiExamTestWhereInput = {
      AND: [
        this.access.testWhere(schoolId, scope),
        {
          status: { not: 'DRAFT' },
          ...(f.classId && { classId: f.classId }),
          ...(f.sectionId && { OR: [{ sectionId: f.sectionId }, { sectionId: null }] }),
          ...(f.subjectId && { subjectId: f.subjectId }),
          ...(f.testId && { id: f.testId }),
          ...(f.academicYearId && { academicYearId: f.academicYearId }),
          ...((f.from || f.to) && { createdAt: { ...(f.from && { gte: new Date(f.from) }), ...(f.to && { lte: new Date(f.to) }) } }),
        },
      ],
    };
    const tests = await this.prisma.aiExamTest.findMany({ where, include: { class: true, section: true, subject: true }, orderBy: { createdAt: 'asc' } });
    return { scope, tests: await this.access.filterManageable(schoolId, scope, tests) };
  }

  async classAnalytics(schoolId: string, actor: Actor, f: AnalyticsFilter) {
    const { tests } = await this.scopedTests(schoolId, actor, f);
    const ids = tests.map((t) => t.id);
    const subs = ids.length
      ? await this.prisma.aiExamSubmission.findMany({
          where: {
            testId: { in: ids },
            ...(f.sectionId && { student: { enrollments: { some: { sectionId: f.sectionId } } } }),
          },
          include: {
            student: { select: { id: true, firstName: true, lastName: true, admissionNo: true } },
            answers: { include: { question: { select: { id: true, text: true, topic: true, chapter: true, orderIndex: true, testId: true } }, evaluation: { select: { finalMarks: true, maxMarks: true, feedback: true } } } },
          },
        })
      : [];
    let assigned = 0;
    for (const t of tests) {
      const roster = await this.access.roster(t);
      if (f.sectionId && !t.sectionId) {
        assigned += await this.prisma.enrollment.count({ where: { studentId: { in: roster }, sectionId: f.sectionId, academicYearId: t.academicYearId } });
      } else assigned += roster.length;
    }
    const submitted = subs.filter((s) => s.status === 'SUBMITTED');
    const evaluated = submitted.filter((s) => s.evaluationStatus === EVAL.EVALUATED && s.maxScore > 0);
    const percents = evaluated.map((s) => pct(s.score ?? 0, s.maxScore));

    // Per test (chronological) for the class trend.
    const perTest = tests.map((t) => {
      const es = evaluated.filter((s) => s.testId === t.id);
      const ps = es.map((s) => pct(s.score ?? 0, s.maxScore));
      return {
        testId: t.id,
        title: t.title,
        subject: t.subject.name,
        className: `${t.class.name}${t.section ? ` ${t.section.name}` : ''}`,
        phase: testPhase(t),
        date: t.endsAt ?? t.publishedAt ?? t.createdAt,
        submissions: submitted.filter((s) => s.testId === t.id).length,
        evaluated: es.length,
        average: ps.length ? round2(ps.reduce((a, b) => a + b, 0) / ps.length) : null,
        highest: ps.length ? Math.max(...ps) : null,
        lowest: ps.length ? Math.min(...ps) : null,
      };
    });

    // Per subject.
    const subjMap = new Map<string, { subject: string; score: number; max: number; n: number }>();
    for (const s of evaluated) {
      const t = tests.find((x) => x.id === s.testId)!;
      const cur = subjMap.get(t.subjectId) ?? { subject: t.subject.name, score: 0, max: 0, n: 0 };
      subjMap.set(t.subjectId, { ...cur, score: cur.score + (s.score ?? 0), max: cur.max + s.maxScore, n: cur.n + 1 });
    }

    // Per topic and per question, from evaluated answers.
    const topicMap = new Map<string, { topic: string; subject: string; marks: number; max: number; answers: number; weak: number }>();
    const questionMap = new Map<string, { questionId: string; testId: string; test: string; text: string; topic: string; answers: number; failed: number; marks: number; max: number }>();
    const misunderstood: string[] = [];
    for (const s of evaluated) {
      const t = tests.find((x) => x.id === s.testId)!;
      for (const a of s.answers) {
        const e = a.evaluation;
        if (!e || e.finalMarks === null) continue;
        const topic = a.question.topic || a.question.chapter || t.chapter || 'General';
        const weak = pct(e.finalMarks, e.maxMarks) < 50;
        const tk = `${t.subjectId}|${topic}`;
        const tc = topicMap.get(tk) ?? { topic, subject: t.subject.name, marks: 0, max: 0, answers: 0, weak: 0 };
        topicMap.set(tk, { ...tc, marks: tc.marks + e.finalMarks, max: tc.max + e.maxMarks, answers: tc.answers + 1, weak: tc.weak + (weak ? 1 : 0) });
        const qc = questionMap.get(a.question.id) ?? { questionId: a.question.id, testId: t.id, test: t.title, text: a.question.text.slice(0, 160), topic, answers: 0, failed: 0, marks: 0, max: 0 };
        questionMap.set(a.question.id, { ...qc, answers: qc.answers + 1, failed: qc.failed + (weak ? 1 : 0), marks: qc.marks + e.finalMarks, max: qc.max + e.maxMarks });
        const fb: any = e.feedback ?? {};
        misunderstood.push(...strs(fb.conceptual_errors), ...strs(fb.incorrect_points));
      }
    }
    const counts = new Map<string, number>();
    for (const m of misunderstood) counts.set(m.trim(), (counts.get(m.trim()) ?? 0) + 1);

    // Students needing support: low average or declining across at least two tests.
    const byStudent = new Map<string, { name: string; admissionNo: string; percents: number[] }>();
    for (const s of [...evaluated].sort((a, b) => (a.submittedAt?.getTime() ?? 0) - (b.submittedAt?.getTime() ?? 0))) {
      const cur = byStudent.get(s.studentId) ?? { name: `${s.student.firstName} ${s.student.lastName}`, admissionNo: s.student.admissionNo, percents: [] };
      cur.percents.push(pct(s.score ?? 0, s.maxScore));
      byStudent.set(s.studentId, cur);
    }
    const students = [...byStudent.entries()].map(([studentId, v]) => {
      const avg = round2(v.percents.reduce((a, b) => a + b, 0) / v.percents.length);
      const tr = trend(v.percents);
      return { studentId, name: v.name, admissionNo: v.admissionNo, tests: v.percents.length, average: avg, trend: tr, needsSupport: avg < 40 || tr?.direction === 'declining' };
    });

    const classTrend = trend(perTest.filter((p) => p.average !== null).map((p) => p.average!));
    return {
      filters: f,
      summary: {
        tests: tests.length,
        assigned,
        submissions: submitted.length,
        completionRate: assigned ? round2((submitted.length / assigned) * 100) : null,
        evaluated: evaluated.length,
        awaitingEvaluation: submitted.length - evaluated.length,
        average: percents.length ? round2(percents.reduce((a, b) => a + b, 0) / percents.length) : null,
        highest: percents.length ? Math.max(...percents) : null,
        lowest: percents.length ? Math.min(...percents) : null,
        trend: classTrend,
      },
      tests: perTest,
      subjects: [...subjMap.values()].map((x) => ({ subject: x.subject, submissions: x.n, average: pct(x.score, x.max) })).sort((a, b) => a.average - b.average),
      topics: [...topicMap.values()].map((x) => ({ topic: x.topic, subject: x.subject, answers: x.answers, percent: pct(x.marks, x.max), weakShare: round2((x.weak / x.answers) * 100) })).sort((a, b) => a.percent - b.percent),
      hardestQuestions: [...questionMap.values()]
        .map((q) => ({ ...q, failureRate: round2((q.failed / q.answers) * 100), percent: pct(q.marks, q.max) }))
        .sort((a, b) => b.failureRate - a.failureRate)
        .slice(0, 10),
      misunderstoodConcepts: [...counts.entries()]
        .filter(([k]) => k)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10)
        .map(([text, count]) => ({ text, count })),
      students: students.sort((a, b) => a.average - b.average),
      studentsNeedingSupport: students.filter((s) => s.needsSupport).sort((a, b) => a.average - b.average),
    };
  }

  async testAnalytics(schoolId: string, actor: Actor, testId: string) {
    await this.access.manageableTest(schoolId, actor, testId);
    return this.classAnalytics(schoolId, actor, { testId });
  }

  /** One student's analytics, limited to tests the teacher manages. */
  async studentDrilldown(schoolId: string, actor: Actor, studentId: string) {
    const student = await this.prisma.student.findFirst({ where: { id: studentId, schoolId }, select: { id: true, firstName: true, lastName: true, admissionNo: true } });
    if (!student) throw new NotFoundException('Student not found');
    const { tests } = await this.scopedTests(schoolId, actor, {});
    const ids = tests.map((t) => t.id);
    const took = ids.length ? await this.prisma.aiExamSubmission.count({ where: { studentId, testId: { in: ids } } }) : 0;
    if (!took) throw new ForbiddenException('This student has no tests in your classes');
    const { tests: tr, answers } = await this.records(studentId, { id: { in: ids } }, false);
    return { student: { id: student.id, name: `${student.firstName} ${student.lastName}`, admissionNo: student.admissionNo }, ...studentPerformance(tr, answers) };
  }

  async adminOverview(schoolId: string) {
    const [tests, classes, byEval, settings] = await Promise.all([
      this.prisma.aiExamTest.findMany({ where: { schoolId }, include: { class: true, subject: true, _count: { select: { submissions: true } } } }),
      this.prisma.class.findMany({ where: { schoolId }, select: { id: true, name: true, code: true } }),
      this.prisma.aiExamSubmission.groupBy({ by: ['evaluationStatus'], where: { schoolId, status: 'SUBMITTED' }, _count: true }),
      this.prisma.aiExamSettings.findUnique({ where: { schoolId } }),
    ]);
    const evaluated = await this.prisma.aiExamSubmission.findMany({
      where: { schoolId, evaluationStatus: EVAL.EVALUATED },
      select: { score: true, maxScore: true, test: { select: { classId: true, subjectId: true, class: { select: { name: true } }, subject: { select: { name: true } } } } },
    });
    const group = (key: (s: (typeof evaluated)[number]) => string, label: (s: (typeof evaluated)[number]) => string) => {
      const m = new Map<string, { label: string; score: number; max: number; n: number }>();
      for (const s of evaluated) {
        const k = key(s);
        const c = m.get(k) ?? { label: label(s), score: 0, max: 0, n: 0 };
        m.set(k, { ...c, score: c.score + (s.score ?? 0), max: c.max + s.maxScore, n: c.n + 1 });
      }
      return [...m.values()].map((x) => ({ label: x.label, submissions: x.n, average: pct(x.score, x.max) })).sort((a, b) => a.average - b.average);
    };
    const n = (s: string) => byEval.find((b) => b.evaluationStatus === s)?._count ?? 0;
    return {
      ai: describeProvider(),
      settings: { autoEvaluate: settings?.autoEvaluate ?? true, reviewConfidence: settings?.reviewConfidence ?? 0.6, allowVoice: settings?.allowVoice ?? true },
      eligibleClasses: classes.filter((c) => isEligibleClass(c.name, c.code)).map((c) => ({ id: c.id, name: c.name, grade: classGrade(c.name, c.code) })),
      counts: {
        tests: tests.length,
        draft: tests.filter((t) => t.status === 'DRAFT').length,
        active: tests.filter((t) => testPhase(t) === 'ACTIVE').length,
        scheduled: tests.filter((t) => testPhase(t) === 'SCHEDULED').length,
        closed: tests.filter((t) => t.status === 'CLOSED' || testPhase(t) === 'ENDED').length,
        submissions: tests.reduce((s, t) => s + t._count.submissions, 0),
        evaluated: n(EVAL.EVALUATED),
        pendingEvaluation: n(EVAL.PENDING) + n(EVAL.PROCESSING),
        needsReview: n(EVAL.REVIEW),
        failed: n(EVAL.FAILED),
      },
      byClass: group((s) => s.test.classId, (s) => s.test.class.name),
      bySubject: group((s) => s.test.subjectId, (s) => s.test.subject.name),
    };
  }

  async saveSettings(schoolId: string, actor: Actor, dto: { autoEvaluate?: boolean; reviewConfidence?: number; allowVoice?: boolean }) {
    const saved = await this.prisma.aiExamSettings.upsert({ where: { schoolId }, create: { schoolId, ...dto }, update: dto });
    await this.access.log(schoolId, actor, 'AI_EXAM_SETTINGS_SAVED', saved.id, dto);
    return { autoEvaluate: saved.autoEvaluate, reviewConfidence: saved.reviewConfidence, allowVoice: saved.allowVoice };
  }
}
