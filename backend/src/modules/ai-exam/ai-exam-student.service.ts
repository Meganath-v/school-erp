import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AiExamAccessService, StudentContext } from './ai-exam-access.service';
import { AiEvaluationService } from './ai-evaluation.service';
import { round2, testPhase } from './ai-exam.constants';
import { SaveAnswersDto } from './ai-exam.dto';

const GRACE_MS = 60_000;

@Injectable()
export class AiExamStudentService {
  constructor(
    private prisma: PrismaService,
    private access: AiExamAccessService,
    private evaluation: AiEvaluationService,
  ) {}

  private async me(schoolId: string, userId: string, requireEligible = true): Promise<StudentContext> {
    const s = await this.access.student(schoolId, userId);
    if (requireEligible && !s.eligible) throw new ForbiddenException('AI Examination is available for Classes 10, 11 and 12 only');
    return s;
  }

  /** A test assigned to this student (404 otherwise, so ids of other classes' tests reveal nothing). */
  private async myTest(schoolId: string, s: StudentContext, testId: string) {
    const t = await this.prisma.aiExamTest.findFirst({
      where: { AND: [{ id: testId }, this.access.studentTestWhere(schoolId, s)] },
      include: { subject: true, class: true, _count: { select: { questions: true } } },
    });
    if (!t) throw new NotFoundException('Test not found');
    return t;
  }

  private deadline(t: { durationMinutes: number | null; endsAt: Date | null }, startedAt: Date) {
    const byDuration = t.durationMinutes ? new Date(startedAt.getTime() + t.durationMinutes * 60_000) : null;
    if (byDuration && t.endsAt) return byDuration < t.endsAt ? byDuration : t.endsAt;
    return byDuration ?? t.endsAt;
  }

  private card(t: any, sub: any) {
    const phase = testPhase(t);
    const submitted = sub?.status === 'SUBMITTED';
    return {
      id: t.id,
      title: t.title,
      subject: t.subject.name,
      chapter: t.chapter,
      totalMarks: t.totalMarks,
      durationMinutes: t.durationMinutes,
      questions: t._count.questions,
      startsAt: t.startsAt,
      endsAt: t.endsAt,
      phase,
      attempt: sub ? { status: sub.status, submittedAt: sub.submittedAt, deadline: sub.deadline } : null,
      resultPublished: submitted && !!t.resultsPublishedAt,
      score: submitted && t.resultsPublishedAt ? sub.score : null,
      maxScore: submitted ? sub.maxScore : t.totalMarks,
      percent: submitted && t.resultsPublishedAt && sub.score !== null && sub.maxScore ? round2((sub.score / sub.maxScore) * 100) : null,
    };
  }

  async list(schoolId: string, userId: string) {
    const s = await this.me(schoolId, userId, false);
    const base = { student: { name: s.name, className: s.className, sectionName: s.sectionName, grade: s.grade }, eligible: s.eligible };
    if (!s.eligible) return { ...base, available: [], upcoming: [], completed: [] };
    // Close out attempts whose time ran out before listing.
    await this.evaluation.autoSubmitExpired();
    const tests = await this.prisma.aiExamTest.findMany({
      where: this.access.studentTestWhere(schoolId, s),
      include: { subject: true, _count: { select: { questions: true } }, submissions: { where: { studentId: s.studentId } } },
      orderBy: [{ startsAt: 'asc' }, { createdAt: 'desc' }],
    });
    const available: any[] = [];
    const upcoming: any[] = [];
    const completed: any[] = [];
    for (const t of tests) {
      const sub = t.submissions[0];
      const c = this.card(t, sub);
      if (sub?.status === 'SUBMITTED') completed.push(c);
      else if (t.status === 'PUBLISHED' && c.phase === 'ACTIVE') available.push(c);
      else if (t.status === 'PUBLISHED' && c.phase === 'SCHEDULED') upcoming.push(c);
      else if (t.status !== 'ARCHIVED') completed.push({ ...c, missed: true });
    }
    completed.sort((a, b) => new Date(b.attempt?.submittedAt ?? b.endsAt ?? 0).getTime() - new Date(a.attempt?.submittedAt ?? a.endsAt ?? 0).getTime());
    return { ...base, available, upcoming, completed };
  }

  async get(schoolId: string, userId: string, testId: string) {
    const s = await this.me(schoolId, userId);
    const t = await this.myTest(schoolId, s, testId);
    const sub = await this.prisma.aiExamSubmission.findUnique({ where: { testId_studentId: { testId, studentId: s.studentId } } });
    return { ...this.card(t, sub), description: t.description, instructions: t.instructions, className: t.class.name, autoSubmit: t.autoSubmit, serverTime: new Date() };
  }

  /** Starts or resumes the attempt; returns questions without answer keys plus saved answers. */
  async start(schoolId: string, userId: string, testId: string) {
    const s = await this.me(schoolId, userId);
    const t = await this.myTest(schoolId, s, testId);
    let sub = await this.prisma.aiExamSubmission.findUnique({ where: { testId_studentId: { testId, studentId: s.studentId } } });
    if (sub?.status === 'SUBMITTED') throw new ConflictException('You have already submitted this test');
    const now = new Date();
    if (sub && sub.deadline && now.getTime() > sub.deadline.getTime() + GRACE_MS) {
      if (t.autoSubmit) {
        await this.evaluation.finalize(sub.id, { auto: true });
        throw new ConflictException('Time is up; your saved answers were submitted');
      }
      throw new ForbiddenException('Time is up for this test');
    }
    if (!sub) {
      if (t.status !== 'PUBLISHED' || testPhase(t, now) !== 'ACTIVE') throw new ForbiddenException('This test is not open now');
      try {
        sub = await this.prisma.aiExamSubmission.create({
          data: { schoolId, testId, studentId: s.studentId, startedAt: now, deadline: this.deadline(t, now), maxScore: t.totalMarks },
        });
      } catch {
        // Two devices started at once: the unique (test, student) keeps a single attempt.
        sub = await this.prisma.aiExamSubmission.findUniqueOrThrow({ where: { testId_studentId: { testId, studentId: s.studentId } } });
      }
    } else if (t.status !== 'PUBLISHED') {
      throw new ForbiddenException('This test has been closed');
    }
    const [questions, answers, settings] = await Promise.all([
      this.prisma.aiExamQuestion.findMany({
        where: { testId },
        orderBy: { orderIndex: 'asc' },
        select: { id: true, type: true, text: true, imageUrl: true, marks: true, options: true, topic: true },
      }),
      this.prisma.aiExamAnswer.findMany({ where: { submissionId: sub.id }, select: { questionId: true, text: true, choice: true, inputMethod: true, updatedAt: true } }),
      this.prisma.aiExamSettings.findUnique({ where: { schoolId } }),
    ]);
    return {
      submissionId: sub.id,
      test: { id: t.id, title: t.title, subject: t.subject.name, totalMarks: t.totalMarks, instructions: t.instructions, durationMinutes: t.durationMinutes, endsAt: t.endsAt, autoSubmit: t.autoSubmit },
      startedAt: sub.startedAt,
      deadline: sub.deadline,
      serverTime: now,
      allowVoice: settings?.allowVoice ?? true,
      questions: questions.map((q) => ({ ...q, options: Array.isArray(q.options) ? q.options : q.type === 'TRUE_FALSE' ? ['False', 'True'] : null })),
      answers,
    };
  }

  private async openAttempt(schoolId: string, userId: string, testId: string) {
    const s = await this.me(schoolId, userId);
    const t = await this.myTest(schoolId, s, testId);
    const sub = await this.prisma.aiExamSubmission.findUnique({ where: { testId_studentId: { testId, studentId: s.studentId } } });
    if (!sub) throw new BadRequestException('Start the test first');
    if (sub.status === 'SUBMITTED') throw new ConflictException('You have already submitted this test');
    return { s, t, sub };
  }

  /** Autosave: upserts the given answers while the attempt is open. */
  async saveAnswers(schoolId: string, userId: string, testId: string, dto: SaveAnswersDto) {
    const { t, sub } = await this.openAttempt(schoolId, userId, testId);
    if (t.status !== 'PUBLISHED') throw new ForbiddenException('This test has been closed');
    if (sub.deadline && Date.now() > sub.deadline.getTime() + GRACE_MS) throw new ForbiddenException('Time is up; answers can no longer be changed');
    const questions = await this.prisma.aiExamQuestion.findMany({ where: { testId }, select: { id: true, type: true, options: true } });
    const qById = new Map(questions.map((q) => [q.id, q]));
    const ops = [];
    for (const a of dto.answers) {
      const q = qById.get(a.questionId);
      if (!q) throw new BadRequestException('Answer for a question that is not in this test');
      let choice: number | null = null;
      if (q.type === 'MCQ' || q.type === 'TRUE_FALSE') {
        const count = q.type === 'TRUE_FALSE' ? 2 : Array.isArray(q.options) ? q.options.length : 0;
        if (a.choice !== null && a.choice !== undefined && (a.choice < 0 || a.choice >= count)) throw new BadRequestException('Invalid option');
        choice = a.choice ?? null;
      }
      const text = q.type === 'MCQ' || q.type === 'TRUE_FALSE' ? '' : (a.text ?? '');
      const inputMethod = a.inputMethod ?? 'TYPED';
      ops.push(
        this.prisma.aiExamAnswer.upsert({
          where: { submissionId_questionId: { submissionId: sub.id, questionId: q.id } },
          create: { submissionId: sub.id, questionId: q.id, text, choice, inputMethod },
          update: { text, choice, inputMethod },
        }),
      );
    }
    const savedAt = new Date();
    await this.prisma.$transaction([...ops, this.prisma.aiExamSubmission.update({ where: { id: sub.id }, data: { lastSavedAt: savedAt } })]);
    return { saved: dto.answers.length, savedAt, deadline: sub.deadline };
  }

  async submit(schoolId: string, userId: string, testId: string, dto?: SaveAnswersDto) {
    const { t, sub } = await this.openAttempt(schoolId, userId, testId);
    const overdue = !!sub.deadline && Date.now() > sub.deadline.getTime() + GRACE_MS;
    if (dto?.answers?.length && !overdue && t.status === 'PUBLISHED') await this.saveAnswers(schoolId, userId, testId, dto);
    if (overdue && !t.autoSubmit) throw new ForbiddenException('Time is up for this test');
    const done = await this.evaluation.finalize(sub.id, { auto: overdue, late: false });
    if (!done) throw new ConflictException('You have already submitted this test');
    const fresh = await this.prisma.aiExamSubmission.findUniqueOrThrow({ where: { id: sub.id } });
    return { submissionId: sub.id, status: fresh.status, submittedAt: fresh.submittedAt, autoSubmitted: fresh.autoSubmitted, evaluationStatus: fresh.evaluationStatus, resultsPublished: !!t.resultsPublishedAt };
  }

  /** Question-wise result; only after the teacher publishes results. */
  async result(schoolId: string, userId: string, testId: string) {
    const s = await this.me(schoolId, userId);
    const t = await this.myTest(schoolId, s, testId);
    const sub = await this.prisma.aiExamSubmission.findUnique({
      where: { testId_studentId: { testId, studentId: s.studentId } },
      include: { answers: { include: { question: { include: { rubric: { orderBy: { orderIndex: 'asc' } } } }, evaluation: true } } },
    });
    if (!sub || sub.status !== 'SUBMITTED') throw new NotFoundException('You have not submitted this test');
    if (!t.resultsPublishedAt) return { published: false, test: { id: t.id, title: t.title, subject: t.subject.name }, submittedAt: sub.submittedAt };
    const questions = sub.answers
      .sort((a, b) => a.question.orderIndex - b.question.orderIndex)
      .map((a) => {
        const q = a.question;
        const e = a.evaluation;
        const fb: any = e?.feedback ?? {};
        return {
          questionId: q.id,
          type: q.type,
          text: q.text,
          imageUrl: q.imageUrl,
          topic: q.topic ?? q.chapter ?? t.chapter,
          options: Array.isArray(q.options) ? q.options : null,
          correctOption: q.correctOption,
          yourAnswer: a.text,
          yourChoice: a.choice,
          inputMethod: a.inputMethod,
          marks: e?.finalMarks ?? 0,
          maxMarks: q.marks,
          evaluatedBy: e?.teacherMarks !== null && e?.teacherMarks !== undefined ? 'TEACHER' : e?.method,
          teacherNote: e?.overrideReason ?? null,
          criteria: e?.criteria ?? null,
          feedback: {
            overall: fb.overall_assessment ?? '',
            correctPoints: fb.correct_points ?? [],
            missingPoints: fb.missing_points ?? [],
            incorrectPoints: [...(fb.incorrect_points ?? []), ...(fb.conceptual_errors ?? [])],
            improvement: fb.improvement_suggestions ?? [],
            topicAssessment: fb.topic_assessment ?? [],
          },
          modelAnswer: q.answerKey || fb.ideal_answer || null,
          explanation: q.explanation,
        };
      });
    return {
      published: true,
      test: { id: t.id, title: t.title, subject: t.subject.name, className: t.class.name, chapter: t.chapter, date: sub.submittedAt },
      score: sub.score,
      maxScore: sub.maxScore,
      percent: sub.score !== null && sub.maxScore ? round2((sub.score / sub.maxScore) * 100) : null,
      questions,
    };
  }
}
