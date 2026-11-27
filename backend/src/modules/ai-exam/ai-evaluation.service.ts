import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AI_TYPES, EVAL, round2 } from './ai-exam.constants';
import { AiNotConfiguredError, AiProvider, AiProviderError, createProvider, readAiConfig, withRetries } from './ai/ai-provider';
import { buildEvaluationMessages, EvaluationInput, InvalidAiResponseError, looksLikeManipulation, validateEvaluation } from './ai/evaluation';
import { clampMarks, gradeObjective } from './grading/objective-grading';

const STALE_MS = 10 * 60_000;
const GRACE_MS = 60_000;

/** Aggregate status of a submission from its answer evaluations. */
export function submissionStatus(statuses: string[]): string {
  if (statuses.includes(EVAL.PROCESSING)) return EVAL.PROCESSING;
  if (statuses.includes(EVAL.PENDING)) return EVAL.PENDING;
  if (statuses.includes(EVAL.FAILED)) return EVAL.FAILED;
  if (statuses.includes(EVAL.REVIEW)) return EVAL.REVIEW;
  return EVAL.EVALUATED;
}

/**
 * Evaluates submitted answers.
 * - Objective questions are marked from the answer key immediately (method AUTO).
 * - Descriptive answers (and numerical / fill-in answers the key cannot decide) go to the AI provider.
 * Without a configured provider they stay PENDING; a teacher can mark them manually.
 * An in-process queue processes evaluation ids; claiming is an atomic status change, so the
 * same answer is never evaluated twice, even with retries, restarts or several instances.
 */
@Injectable()
export class AiEvaluationService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('AiEvaluation');
  private queue: string[] = [];
  private queued = new Set<string>();
  private running = 0;
  private readonly concurrency = 2;
  private timer?: NodeJS.Timeout;
  /** Replaceable for tests. */
  providerFactory: () => AiProvider | null = () => createProvider();

  constructor(private prisma: PrismaService) {}

  onModuleInit() {
    if (process.env.AI_EXAM_WORKER === 'off') return;
    // Recover after restarts, auto-submit expired attempts, keep the queue moving.
    this.timer = setInterval(() => void this.tick().catch((e) => this.logger.warn(`tick failed: ${e?.message}`)), 60_000);
    setTimeout(() => void this.tick().catch(() => undefined), 5_000);
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  get provider() {
    return this.providerFactory();
  }

  async tick() {
    await this.autoSubmitExpired();
    await this.prisma.aiExamEvaluation.updateMany({
      where: { status: EVAL.PROCESSING, claimedAt: { lt: new Date(Date.now() - STALE_MS) } },
      data: { status: EVAL.PENDING },
    });
    if (!this.provider) return;
    const toRun = await this.prisma.aiExamEvaluation.findMany({
      where: {
        status: EVAL.PENDING,
        OR: [{ answer: { submission: { test: { school: { aiExamSettings: null } } } } }, { answer: { submission: { test: { school: { aiExamSettings: { autoEvaluate: true } } } } } }],
      },
      select: { id: true },
      take: 200,
      orderBy: { createdAt: 'asc' },
    });
    this.enqueue(toRun.map((e) => e.id));
  }

  // ------------------------------------------------------------------ submission finalisation

  /**
   * Marks a submission SUBMITTED (once), creates an evaluation per question, marks objective answers
   * from the key and queues the rest. Returns false when it was already submitted.
   */
  async finalize(submissionId: string, opts: { auto: boolean; late?: boolean }): Promise<boolean> {
    const now = new Date();
    const claimed = await this.prisma.aiExamSubmission.updateMany({
      where: { id: submissionId, status: 'IN_PROGRESS' },
      data: { status: 'SUBMITTED', submittedAt: now, autoSubmitted: opts.auto, late: !!opts.late, evaluationStatus: EVAL.PENDING },
    });
    if (claimed.count === 0) return false;

    const sub = await this.prisma.aiExamSubmission.findUniqueOrThrow({
      where: { id: submissionId },
      include: { answers: true, test: { include: { questions: true } } },
    });
    // Every question gets an answer row (blank when unanswered).
    const have = new Set(sub.answers.map((a) => a.questionId));
    const missing = sub.test.questions.filter((q) => !have.has(q.id));
    if (missing.length) {
      await this.prisma.aiExamAnswer.createMany({ data: missing.map((q) => ({ submissionId, questionId: q.id })), skipDuplicates: true });
    }
    const answers = await this.prisma.aiExamAnswer.findMany({ where: { submissionId } });
    const qById = new Map(sub.test.questions.map((q) => [q.id, q]));

    const evals: Prisma.AiExamEvaluationCreateManyInput[] = [];
    const events: { answerId: string; kind: string; marks: number; details: any }[] = [];
    for (const a of answers) {
      const q = qById.get(a.questionId);
      if (!q) continue;
      const blank = !a.text.trim() && (a.choice === null || a.choice === undefined);
      const objective = gradeObjective(
        { type: q.type, marks: q.marks, correctOption: q.correctOption, answerKey: q.answerKey, acceptableAnswers: q.acceptableAnswers, tolerance: q.tolerance },
        { text: a.text, choice: a.choice },
      );
      if (blank || objective.decided) {
        const marks = blank ? 0 : objective.marks;
        const reason = blank ? 'Not answered' : objective.reason;
        evals.push({
          answerId: a.id,
          status: EVAL.EVALUATED,
          method: 'AUTO',
          maxMarks: q.marks,
          finalMarks: marks,
          feedback: { overall_assessment: reason, correct_points: objective.correct ? [reason] : [], missing_points: [], incorrect_points: !blank && !objective.correct ? [reason] : [], conceptual_errors: [], irrelevant_points: [], improvement_suggestions: [], ideal_answer: q.answerKey ?? '', topic_assessment: [] },
          reviewReasons: [],
        });
        events.push({ answerId: a.id, kind: 'AUTO_RESULT', marks, details: { reason } });
      } else {
        evals.push({ answerId: a.id, status: EVAL.PENDING, maxMarks: q.marks, reviewReasons: [], lastError: AI_TYPES.includes(q.type as any) ? null : objective.reason });
      }
    }
    await this.prisma.aiExamEvaluation.createMany({ data: evals, skipDuplicates: true });
    const created = await this.prisma.aiExamEvaluation.findMany({ where: { answerId: { in: answers.map((a) => a.id) } }, select: { id: true, answerId: true, status: true } });
    const idByAnswer = new Map(created.map((e) => [e.answerId, e.id]));
    if (events.length) {
      await this.prisma.aiExamEvaluationEvent.createMany({
        data: events.map((e) => ({ evaluationId: idByAnswer.get(e.answerId)!, kind: e.kind, marks: e.marks, details: e.details })),
      });
    }
    await this.recompute(submissionId);
    const settings = await this.prisma.aiExamSettings.findUnique({ where: { schoolId: sub.schoolId } });
    if (settings?.autoEvaluate !== false) this.enqueue(created.filter((e) => e.status === EVAL.PENDING).map((e) => e.id));
    return true;
  }

  /** Auto-submits attempts whose time ran out (tests with autoSubmit on). */
  async autoSubmitExpired() {
    const expired = await this.prisma.aiExamSubmission.findMany({
      where: { status: 'IN_PROGRESS', deadline: { lt: new Date(Date.now() - GRACE_MS) }, test: { autoSubmit: true } },
      select: { id: true },
      take: 100,
    });
    for (const s of expired) await this.finalize(s.id, { auto: true });
    return expired.length;
  }

  async recompute(submissionId: string) {
    const evals = await this.prisma.aiExamEvaluation.findMany({ where: { answer: { submissionId } }, select: { status: true, finalMarks: true, maxMarks: true } });
    const status = submissionStatus(evals.map((e) => e.status));
    const maxScore = round2(evals.reduce((s, e) => s + e.maxMarks, 0));
    const score = status === EVAL.EVALUATED ? round2(evals.reduce((s, e) => s + (e.finalMarks ?? 0), 0)) : null;
    await this.prisma.aiExamSubmission.update({ where: { id: submissionId }, data: { evaluationStatus: status, score, maxScore } });
    return { status, score, maxScore };
  }

  // ------------------------------------------------------------------ queue

  /** Re-queues PENDING / FAILED evaluations of a submission or test (manual "run evaluation"). */
  async requeue(where: Prisma.AiExamEvaluationWhereInput, actorId?: string) {
    if (!this.provider) throw new AiNotConfiguredError();
    const rows = await this.prisma.aiExamEvaluation.findMany({ where: { ...where, status: { in: [EVAL.PENDING, EVAL.FAILED] } }, select: { id: true, status: true } });
    const failed = rows.filter((r) => r.status === EVAL.FAILED).map((r) => r.id);
    if (failed.length) {
      await this.prisma.aiExamEvaluation.updateMany({ where: { id: { in: failed }, status: EVAL.FAILED }, data: { status: EVAL.PENDING, attempts: 0 } });
      await this.prisma.aiExamEvaluationEvent.createMany({ data: failed.map((id) => ({ evaluationId: id, kind: 'REQUEUED', actorId })) });
    }
    this.enqueue(rows.map((r) => r.id));
    return { queued: rows.length };
  }

  enqueue(ids: string[]) {
    for (const id of ids) {
      if (this.queued.has(id)) continue;
      this.queued.add(id);
      this.queue.push(id);
    }
    this.pump();
  }

  /** Resolves when the queue is empty (used by tests and the manual evaluate endpoint). */
  async drain(timeoutMs = 120_000) {
    const until = Date.now() + timeoutMs;
    while ((this.queue.length || this.running) && Date.now() < until) await new Promise((r) => setTimeout(r, 100));
  }

  private pump() {
    while (this.running < this.concurrency && this.queue.length) {
      const id = this.queue.shift()!;
      this.running++;
      void this.evaluate(id)
        .catch((e) => this.logger.warn(`evaluation ${id} crashed: ${e?.message}`))
        .finally(() => {
          this.running--;
          this.queued.delete(id);
          this.pump();
        });
    }
  }

  /** Evaluates one answer with the AI provider. Safe to call concurrently for the same id. */
  async evaluate(evaluationId: string) {
    const provider = this.provider;
    if (!provider) return;
    const claim = await this.prisma.aiExamEvaluation.updateMany({
      where: { id: evaluationId, status: EVAL.PENDING },
      data: { status: EVAL.PROCESSING, claimedAt: new Date(), attempts: { increment: 1 } },
    });
    if (claim.count === 0) return; // someone else has it, or it is already done
    const ev = await this.prisma.aiExamEvaluation.findUniqueOrThrow({
      where: { id: evaluationId },
      include: {
        answer: {
          include: {
            question: { include: { rubric: { orderBy: { orderIndex: 'asc' } } } },
            submission: { include: { test: { include: { subject: true, class: true, school: { select: { aiExamSettings: true } } } } } },
          },
        },
      },
    });
    const q = ev.answer.question;
    const test = ev.answer.submission.test;
    const threshold = test.school.aiExamSettings?.reviewConfidence ?? 0.6;
    const keyCheck = AI_TYPES.includes(q.type as any) ? null : gradeObjective({ type: q.type, marks: q.marks, answerKey: q.answerKey, acceptableAnswers: q.acceptableAnswers, tolerance: q.tolerance }, { text: ev.answer.text }).reason;
    const input: EvaluationInput = {
      subject: test.subject.name,
      classLabel: test.class.name,
      chapter: q.chapter ?? test.chapter,
      topic: q.topic,
      questionType: q.type,
      question: q.text,
      maxMarks: q.marks,
      modelAnswer: q.answerKey,
      acceptableAnswers: q.acceptableAnswers,
      concepts: q.concepts,
      keywords: q.keywords,
      partialCredit: q.partialCredit,
      rubric: q.rubric.map((r) => ({ description: r.description, marks: r.marks })),
      studentAnswer: ev.answer.text,
      keyCheck,
    };
    const cfg = readAiConfig();
    try {
      const messages = buildEvaluationMessages(input);
      let result;
      // One extra call when the model returns malformed output.
      for (let i = 0; ; i++) {
        const raw = await withRetries(() => provider.complete(messages, { json: true }), cfg.maxRetries);
        try {
          result = validateEvaluation(raw, input, threshold);
          break;
        } catch (e) {
          if (!(e instanceof InvalidAiResponseError) || i >= 1) throw e;
        }
      }
      const reasons = [...result.reviewReasons];
      if (provider.isMock) reasons.unshift('Marked by the development evaluator, not AI');
      if (looksLikeManipulation(input.studentAnswer) && !reasons.some((r) => r.includes('instructions'))) reasons.push('Answer contains instructions aimed at the evaluator');
      const status = reasons.length ? EVAL.REVIEW : EVAL.EVALUATED;
      await this.prisma.$transaction([
        this.prisma.aiExamEvaluation.update({
          where: { id: evaluationId },
          data: {
            status,
            method: provider.isMock ? 'MOCK' : 'AI',
            aiMarks: result.marks,
            finalMarks: status === EVAL.EVALUATED ? result.marks : null,
            feedback: result.feedback as any,
            criteria: result.criteria as any,
            confidence: result.confidence,
            reviewReasons: reasons,
            provider: provider.name,
            model: provider.model,
            lastError: null,
          },
        }),
        this.prisma.aiExamEvaluationEvent.create({
          data: { evaluationId, kind: 'AI_RESULT', marks: result.marks, details: { criteria: result.criteria, confidence: result.confidence, reviewReasons: reasons, model: provider.model } as any },
        }),
      ]);
    } catch (e: any) {
      const message = e instanceof AiProviderError || e instanceof InvalidAiResponseError ? e.message : 'Evaluation failed';
      if (!(e instanceof AiProviderError || e instanceof InvalidAiResponseError)) this.logger.warn(`evaluation ${evaluationId}: ${e?.message}`);
      await this.prisma.$transaction([
        this.prisma.aiExamEvaluation.update({ where: { id: evaluationId }, data: { status: EVAL.FAILED, lastError: message } }),
        this.prisma.aiExamEvaluationEvent.create({ data: { evaluationId, kind: 'AI_FAILED', details: { error: message } } }),
      ]);
    }
    await this.recompute(ev.answer.submissionId);
  }

  // ------------------------------------------------------------------ teacher review

  async override(evaluationId: string, marks: number, reason: string, actorId: string) {
    const ev = await this.prisma.aiExamEvaluation.findUniqueOrThrow({ where: { id: evaluationId } });
    if (ev.status === EVAL.PROCESSING) throw new Error('PROCESSING');
    if (marks > ev.maxMarks + 1e-9) throw new RangeError(`Marks cannot exceed ${ev.maxMarks}`);
    const final = clampMarks(marks, ev.maxMarks);
    await this.prisma.$transaction([
      this.prisma.aiExamEvaluation.update({
        where: { id: evaluationId },
        data: { status: EVAL.EVALUATED, teacherMarks: final, finalMarks: final, overrideReason: reason, reviewedById: actorId, reviewedAt: new Date(), method: ev.method ?? 'TEACHER' },
      }),
      this.prisma.aiExamEvaluationEvent.create({ data: { evaluationId, kind: 'TEACHER_OVERRIDE', marks: final, actorId, details: { previous: ev.finalMarks, aiMarks: ev.aiMarks, reason } } }),
    ]);
    return final;
  }

  async accept(evaluationId: string, actorId: string) {
    const ev = await this.prisma.aiExamEvaluation.findUniqueOrThrow({ where: { id: evaluationId } });
    if (ev.status !== EVAL.REVIEW || ev.aiMarks === null) throw new Error('NOT_REVIEWABLE');
    await this.prisma.$transaction([
      this.prisma.aiExamEvaluation.update({ where: { id: evaluationId }, data: { status: EVAL.EVALUATED, finalMarks: ev.aiMarks, reviewedById: actorId, reviewedAt: new Date() } }),
      this.prisma.aiExamEvaluationEvent.create({ data: { evaluationId, kind: 'TEACHER_ACCEPTED', marks: ev.aiMarks, actorId } }),
    ]);
    return ev.aiMarks;
  }
}
