import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { gradeQuiz } from './internal-marks';
import { Actor, InternalAssessmentService } from './internal-assessment.service';
import { SaveQuizDto, SetQuizQuestionsDto } from './internal-assessment.dto';

const GRACE_MS = 60_000; // allowance for network delay when submitting

@Injectable()
export class QuizzesService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
    private internal: InternalAssessmentService,
  ) {}

  private async getQuiz(schoolId: string, id: string) {
    const quiz = await this.prisma.quiz.findFirst({
      where: { id, schoolId },
      include: {
        questions: {
          orderBy: { orderIndex: 'asc' },
          include: { question: { select: { id: true, text: true, options: true, correctOption: true, bloomLevel: true, courseOutcomeId: true } } },
        },
        _count: { select: { attempts: true } },
      },
    });
    if (!quiz) throw new NotFoundException('Quiz not found');
    return quiz;
  }

  private async log(schoolId: string, actor: Actor, action: string, id: string, details: Record<string, any>) {
    await this.audit.log({ schoolId, actorId: actor.userId, actorName: actor.name ?? 'Staff', action, entity: 'Quiz', entityId: id, details });
  }

  // ---------------------------------------------------------------- staff

  async list(schoolId: string, subjectId: string) {
    return this.prisma.quiz.findMany({
      where: { schoolId, subjectId },
      include: { _count: { select: { questions: true, attempts: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async get(schoolId: string, id: string) {
    return this.getQuiz(schoolId, id);
  }

  private async validatePlacement(schoolId: string, dto: SaveQuizDto) {
    const klass = await this.prisma.class.findFirst({ where: { id: dto.classId, schoolId } });
    if (!klass) throw new BadRequestException('Class not found');
    if (dto.sectionId) {
      const ok = await this.prisma.section.count({ where: { id: dto.sectionId, classId: dto.classId } });
      if (!ok) throw new BadRequestException('Section does not belong to the class');
    }
    if (dto.opensAt && dto.closesAt && new Date(dto.opensAt) >= new Date(dto.closesAt)) {
      throw new BadRequestException('The quiz must close after it opens');
    }
  }

  async create(schoolId: string, dto: SaveQuizDto, actor: Actor) {
    await this.internal.assertCanEditSubject(schoolId, dto.subjectId, actor);
    await this.validatePlacement(schoolId, dto);
    const quiz = await this.prisma.quiz.create({
      data: {
        schoolId,
        subjectId: dto.subjectId,
        classId: dto.classId,
        sectionId: dto.sectionId || null,
        title: dto.title.trim(),
        instructions: dto.instructions,
        durationMinutes: dto.durationMinutes ?? null,
        opensAt: dto.opensAt ? new Date(dto.opensAt) : null,
        closesAt: dto.closesAt ? new Date(dto.closesAt) : null,
        showAnswers: dto.showAnswers ?? true,
        createdById: actor.userId,
      },
    });
    await this.log(schoolId, actor, 'QUIZ_CREATED', quiz.id, { title: quiz.title });
    return quiz;
  }

  async update(schoolId: string, id: string, dto: SaveQuizDto, actor: Actor) {
    const quiz = await this.getQuiz(schoolId, id);
    await this.internal.assertCanEditSubject(schoolId, quiz.subjectId, actor);
    if (dto.subjectId !== quiz.subjectId) throw new BadRequestException('The subject of a quiz cannot be changed');
    await this.validatePlacement(schoolId, dto);
    const updated = await this.prisma.quiz.update({
      where: { id },
      data: {
        classId: dto.classId,
        sectionId: dto.sectionId || null,
        title: dto.title.trim(),
        instructions: dto.instructions,
        durationMinutes: dto.durationMinutes ?? null,
        opensAt: dto.opensAt ? new Date(dto.opensAt) : null,
        closesAt: dto.closesAt ? new Date(dto.closesAt) : null,
        showAnswers: dto.showAnswers ?? quiz.showAnswers,
      },
    });
    await this.log(schoolId, actor, 'QUIZ_UPDATED', id, { title: updated.title });
    return updated;
  }

  async setQuestions(schoolId: string, id: string, dto: SetQuizQuestionsDto, actor: Actor) {
    const quiz = await this.getQuiz(schoolId, id);
    await this.internal.assertCanEditSubject(schoolId, quiz.subjectId, actor);
    if (quiz._count.attempts > 0) throw new ConflictException('Students have already attempted this quiz; its questions cannot change');
    const ids = dto.questions.map((q) => q.questionId);
    if (new Set(ids).size !== ids.length) throw new BadRequestException('A question appears twice');
    const bank = await this.prisma.question.findMany({
      where: { schoolId, subjectId: quiz.subjectId, id: { in: ids } },
      select: { id: true, type: true, marks: true, options: true, correctOption: true },
    });
    if (bank.length !== ids.length) throw new BadRequestException('Every question must come from this subject’s question bank');
    for (const q of bank) {
      const opts = Array.isArray(q.options) ? q.options : [];
      if (q.type !== 'MCQ' || opts.length < 2 || q.correctOption === null || q.correctOption >= opts.length) {
        throw new BadRequestException('Quizzes can only use multiple-choice questions that have options and a correct answer');
      }
    }
    const marks = new Map(bank.map((q) => [q.id, q.marks]));
    await this.prisma.$transaction([
      this.prisma.quizQuestion.deleteMany({ where: { quizId: id } }),
      this.prisma.quizQuestion.createMany({
        data: dto.questions.map((q, i) => ({ quizId: id, questionId: q.questionId, marks: q.marks ?? marks.get(q.questionId)!, orderIndex: i })),
      }),
    ]);
    await this.log(schoolId, actor, 'QUIZ_QUESTIONS_SET', id, { count: ids.length });
    return this.getQuiz(schoolId, id);
  }

  async setStatus(schoolId: string, id: string, status: 'PUBLISHED' | 'CLOSED' | 'DRAFT', actor: Actor) {
    const quiz = await this.getQuiz(schoolId, id);
    await this.internal.assertCanEditSubject(schoolId, quiz.subjectId, actor);
    if (status === 'PUBLISHED' && quiz.questions.length === 0) throw new BadRequestException('Add questions before publishing');
    if (status === 'DRAFT' && quiz._count.attempts > 0) throw new ConflictException('A quiz with attempts cannot go back to draft');
    await this.prisma.quiz.update({ where: { id }, data: { status } });
    await this.log(schoolId, actor, `QUIZ_${status}`, id, {});
    return this.getQuiz(schoolId, id);
  }

  async remove(schoolId: string, id: string, actor: Actor) {
    const quiz = await this.getQuiz(schoolId, id);
    await this.internal.assertCanEditSubject(schoolId, quiz.subjectId, actor);
    await this.prisma.quiz.delete({ where: { id } });
    await this.log(schoolId, actor, 'QUIZ_DELETED', id, { title: quiz.title, attempts: quiz._count.attempts });
    return { deleted: true };
  }

  async results(schoolId: string, id: string) {
    const quiz = await this.getQuiz(schoolId, id);
    const year = await this.prisma.academicYear.findFirst({ where: { schoolId, isCurrent: true }, select: { id: true } });
    const [enrollments, attempts] = await Promise.all([
      this.prisma.enrollment.findMany({
        where: {
          schoolId,
          classId: quiz.classId,
          status: 'ACTIVE',
          ...(quiz.sectionId && { sectionId: quiz.sectionId }),
          ...(year && { academicYearId: year.id }),
        },
        include: { student: { select: { firstName: true, lastName: true, admissionNo: true } } },
        orderBy: { rollNo: 'asc' },
      }),
      this.prisma.quizAttempt.findMany({ where: { quizId: id } }),
    ]);
    const byStudent = new Map(attempts.map((a) => [a.studentId, a]));
    const maxScore = quiz.questions.reduce((s, q) => s + q.marks, 0);
    const rows = enrollments.map((e) => {
      const a = byStudent.get(e.studentId);
      return {
        studentId: e.studentId,
        name: `${e.student.firstName} ${e.student.lastName}`,
        admissionNo: e.student.admissionNo,
        rollNo: e.rollNo,
        status: !a ? 'NOT_STARTED' : a.submittedAt ? 'SUBMITTED' : 'IN_PROGRESS',
        score: a?.score ?? null,
        late: a?.late ?? false,
        submittedAt: a?.submittedAt ?? null,
      };
    });
    const submitted = rows.filter((r) => r.score !== null);
    return {
      quiz: { id: quiz.id, title: quiz.title, status: quiz.status, maxScore },
      students: rows,
      summary: {
        students: rows.length,
        submitted: submitted.length,
        average: submitted.length ? Math.round((submitted.reduce((s, r) => s + (r.score ?? 0), 0) / submitted.length) * 100) / 100 : null,
      },
    };
  }

  // ---------------------------------------------------------------- students

  private async studentFor(schoolId: string, userId: string) {
    const student = await this.prisma.student.findFirst({ where: { schoolId, userId }, select: { id: true } });
    if (!student) throw new ForbiddenException('No student profile is linked to this account');
    const year = await this.prisma.academicYear.findFirst({ where: { schoolId, isCurrent: true }, select: { id: true } });
    const enrollment = await this.prisma.enrollment.findFirst({
      where: { schoolId, studentId: student.id, status: 'ACTIVE', ...(year && { academicYearId: year.id }) },
      select: { classId: true, sectionId: true },
    });
    if (!enrollment) throw new ForbiddenException('You are not enrolled in a class this year');
    return { studentId: student.id, ...enrollment };
  }

  private isOpen(quiz: { status: string; opensAt: Date | null; closesAt: Date | null }, now = new Date()) {
    return quiz.status === 'PUBLISHED' && (!quiz.opensAt || quiz.opensAt <= now) && (!quiz.closesAt || now <= quiz.closesAt);
  }

  async myQuizzes(schoolId: string, userId: string) {
    const me = await this.studentFor(schoolId, userId);
    const quizzes = await this.prisma.quiz.findMany({
      where: { schoolId, classId: me.classId, status: { in: ['PUBLISHED', 'CLOSED'] }, OR: [{ sectionId: null }, { sectionId: me.sectionId }] },
      include: {
        subject: { select: { name: true } },
        questions: { select: { marks: true } },
        attempts: { where: { studentId: me.studentId } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return quizzes.map((q) => {
      const a = q.attempts[0];
      return {
        id: q.id,
        title: q.title,
        subject: q.subject.name,
        durationMinutes: q.durationMinutes,
        opensAt: q.opensAt,
        closesAt: q.closesAt,
        questions: q.questions.length,
        maxScore: q.questions.reduce((s, x) => s + x.marks, 0),
        open: this.isOpen(q),
        attempt: a ? { status: a.submittedAt ? 'SUBMITTED' : 'IN_PROGRESS', score: a.score, startedAt: a.startedAt } : null,
      };
    });
  }

  /** Starts (or resumes) an attempt and returns the questions without answers. */
  async start(schoolId: string, userId: string, quizId: string) {
    const me = await this.studentFor(schoolId, userId);
    const quiz = await this.getQuiz(schoolId, quizId);
    if (quiz.classId !== me.classId || (quiz.sectionId && quiz.sectionId !== me.sectionId)) {
      throw new ForbiddenException('This quiz is not for your class');
    }
    let attempt = await this.prisma.quizAttempt.findUnique({ where: { quizId_studentId: { quizId, studentId: me.studentId } } });
    if (attempt?.submittedAt) return this.review(quiz, attempt);
    if (!this.isOpen(quiz)) throw new ForbiddenException('This quiz is not open');
    if (!attempt) {
      attempt = await this.prisma.quizAttempt.create({
        data: { quizId, studentId: me.studentId, maxScore: quiz.questions.reduce((s, q) => s + q.marks, 0) },
      });
    }
    const deadline = this.deadline(quiz, attempt.startedAt);
    return {
      attemptId: attempt.id,
      status: 'IN_PROGRESS',
      title: quiz.title,
      instructions: quiz.instructions,
      startedAt: attempt.startedAt,
      deadline,
      questions: quiz.questions.map((q) => ({
        questionId: q.questionId,
        text: q.question.text,
        options: Array.isArray(q.question.options) ? q.question.options : [],
        marks: q.marks,
      })),
    };
  }

  private deadline(quiz: { durationMinutes: number | null; closesAt: Date | null }, startedAt: Date): Date | null {
    const byDuration = quiz.durationMinutes ? new Date(startedAt.getTime() + quiz.durationMinutes * 60_000) : null;
    if (byDuration && quiz.closesAt) return byDuration < quiz.closesAt ? byDuration : quiz.closesAt;
    return byDuration ?? quiz.closesAt;
  }

  async submit(schoolId: string, userId: string, quizId: string, answers: Record<string, unknown>) {
    const me = await this.studentFor(schoolId, userId);
    const quiz = await this.getQuiz(schoolId, quizId);
    const attempt = await this.prisma.quizAttempt.findUnique({ where: { quizId_studentId: { quizId, studentId: me.studentId } } });
    if (!attempt) throw new BadRequestException('Start the quiz before submitting');
    if (attempt.submittedAt) throw new ConflictException('You have already submitted this quiz');
    const deadline = this.deadline(quiz, attempt.startedAt);
    const now = new Date();
    if (quiz.closesAt && now.getTime() > quiz.closesAt.getTime() + GRACE_MS) throw new ForbiddenException('This quiz has closed');
    const late = !!deadline && now.getTime() > deadline.getTime() + GRACE_MS;

    const valid: Record<string, number> = {};
    for (const q of quiz.questions) {
      const a = answers?.[q.questionId];
      if (typeof a === 'number' && Number.isInteger(a)) valid[q.questionId] = a;
    }
    const graded = gradeQuiz(
      quiz.questions.map((q) => ({ questionId: q.questionId, marks: q.marks, correctOption: q.question.correctOption })),
      valid,
    );
    const saved = await this.prisma.quizAttempt.update({
      where: { id: attempt.id },
      data: { answers: valid, score: graded.score, maxScore: graded.maxScore, submittedAt: now, late },
    });
    return this.review(quiz, saved);
  }

  private review(quiz: Awaited<ReturnType<QuizzesService['getQuiz']>>, attempt: { id: string; answers: any; score: number | null; maxScore: number; late: boolean; submittedAt: Date | null }) {
    const answers = (attempt.answers ?? {}) as Record<string, number>;
    return {
      attemptId: attempt.id,
      status: 'SUBMITTED',
      title: quiz.title,
      score: attempt.score,
      maxScore: attempt.maxScore,
      late: attempt.late,
      submittedAt: attempt.submittedAt,
      questions: quiz.questions.map((q) => ({
        questionId: q.questionId,
        text: q.question.text,
        options: Array.isArray(q.question.options) ? q.question.options : [],
        marks: q.marks,
        chosen: answers[q.questionId] ?? null,
        ...(quiz.showAnswers && { correctOption: q.question.correctOption }),
      })),
    };
  }
}
