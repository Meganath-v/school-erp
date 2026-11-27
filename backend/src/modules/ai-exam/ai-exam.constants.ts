export const QUESTION_TYPES = ['MCQ', 'SHORT', 'LONG', 'FILL_BLANK', 'TRUE_FALSE', 'NUMERICAL'] as const;
export type QuestionType = (typeof QUESTION_TYPES)[number];

/** Questions the AI evaluator marks (objective types are marked from the answer key). */
export const AI_TYPES: QuestionType[] = ['SHORT', 'LONG'];

export const DIFFICULTIES = ['EASY', 'MEDIUM', 'HARD'] as const;
export const TEST_STATUSES = ['DRAFT', 'PUBLISHED', 'CLOSED', 'ARCHIVED'] as const;
export const ASSIGN_MODES = ['CLASS', 'SECTION', 'STUDENTS'] as const;

/** Evaluation statuses; REVIEW = needs a teacher before results can be published. */
export const EVAL = {
  PENDING: 'PENDING',
  PROCESSING: 'PROCESSING',
  EVALUATED: 'EVALUATED',
  FAILED: 'FAILED',
  REVIEW: 'REVIEW',
} as const;

export const ELIGIBLE_GRADES = [10, 11, 12];

/**
 * Grade of a class read from its name or code ("Grade 10", "Class XI", "G12", "12-A").
 * The schema has no grade column, so this is the single place eligibility is decided.
 */
export function classGrade(name: string, code?: string | null): number | null {
  for (const raw of [name, code ?? '']) {
    const s = raw.toUpperCase();
    const num = s.match(/(?:^|[^0-9])(1[0-2]|[1-9])(?![0-9])/);
    if (num) return Number(num[1]);
    const roman = s.match(/(?:^|[^A-Z])(XII|XI|X|IX|VIII|VII|VI|V|IV|III|II|I)(?![A-Z])/);
    if (roman) return ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'].indexOf(roman[1]) + 1;
  }
  return null;
}

export function isEligibleClass(name: string, code?: string | null): boolean {
  const g = classGrade(name, code);
  return g !== null && ELIGIBLE_GRADES.includes(g);
}

/** Lifecycle shown to people: published tests are scheduled / active / ended by their times. */
export function testPhase(t: { status: string; startsAt: Date | null; endsAt: Date | null }, now = new Date()): string {
  if (t.status !== 'PUBLISHED') return t.status;
  if (t.startsAt && now < t.startsAt) return 'SCHEDULED';
  if (t.endsAt && now > t.endsAt) return 'ENDED';
  return 'ACTIVE';
}

export const round2 = (n: number) => Math.round(n * 100) / 100;
/** Marks are awarded in quarter steps. */
export const roundMarks = (n: number) => Math.round(n * 4) / 4;
