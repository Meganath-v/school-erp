/**
 * Internal-mark calculation (pure functions).
 *
 * A scheme has components, each worth `weight` marks:
 *  - EXAM / ASSIGNMENT: the student's fraction (marks ÷ max) on each selected
 *    assessment; only the best `bestOf` count when set; component score =
 *    mean of those fractions × weight.
 *  - ATTENDANCE: attendance fraction × weight.
 *  - MANUAL: marks entered by the teacher (capped at the weight).
 * A component with no data scores 0 and marks the student's result incomplete.
 */

export type ComponentType = 'EXAM' | 'ASSIGNMENT' | 'ATTENDANCE' | 'MANUAL';

export interface ComponentInput {
  id: string;
  label: string;
  type: ComponentType;
  weight: number;
  bestOf: number | null;
  sourceIds: string[];
}

export interface StudentInputs {
  /** fraction 0..1 per exam-subject / assignment id; absent key = not assessed */
  scores: Record<string, number>;
  /** 0..1, or null when no attendance was recorded */
  attendanceFraction: number | null;
  /** component id -> marks entered */
  manual: Record<string, number>;
}

export interface ComponentResult {
  componentId: string;
  label: string;
  type: ComponentType;
  score: number | null;
  max: number;
  used: number; // assessments counted (EXAM / ASSIGNMENT)
}

export interface InternalResult {
  components: ComponentResult[];
  total: number;
  max: number;
  percent: number;
  complete: boolean;
  isWeak: boolean;
}

const round2 = (n: number) => Math.round(n * 100) / 100;
const clamp01 = (n: number) => Math.max(0, Math.min(1, n));

export function computeInternalMark(components: ComponentInput[], inputs: StudentInputs, passPercent: number): InternalResult {
  const results: ComponentResult[] = components.map((c) => {
    if (c.type === 'EXAM' || c.type === 'ASSIGNMENT') {
      const fractions = c.sourceIds
        .filter((id) => inputs.scores[id] !== undefined)
        .map((id) => clamp01(inputs.scores[id]))
        .sort((a, b) => b - a);
      const taken = c.bestOf && c.bestOf > 0 ? fractions.slice(0, c.bestOf) : fractions;
      if (taken.length === 0) return { componentId: c.id, label: c.label, type: c.type, score: null, max: c.weight, used: 0 };
      const mean = taken.reduce((a, b) => a + b, 0) / taken.length;
      return { componentId: c.id, label: c.label, type: c.type, score: round2(mean * c.weight), max: c.weight, used: taken.length };
    }
    if (c.type === 'ATTENDANCE') {
      const f = inputs.attendanceFraction;
      return { componentId: c.id, label: c.label, type: c.type, score: f === null ? null : round2(clamp01(f) * c.weight), max: c.weight, used: 0 };
    }
    const m = inputs.manual[c.id];
    return {
      componentId: c.id,
      label: c.label,
      type: c.type,
      score: m === undefined ? null : round2(Math.max(0, Math.min(m, c.weight))),
      max: c.weight,
      used: 0,
    };
  });

  const max = round2(components.reduce((a, c) => a + c.weight, 0));
  const total = round2(results.reduce((a, r) => a + (r.score ?? 0), 0));
  const percent = max > 0 ? round2((total / max) * 100) : 0;
  return {
    components: results,
    total,
    max,
    percent,
    complete: results.every((r) => r.score !== null),
    isWeak: percent < passPercent,
  };
}

/** Attendance fraction from record statuses (PRESENT/LATE = 1, HALF_DAY = 0.5, ABSENT = 0). */
export function attendanceFraction(statuses: string[]): number | null {
  if (statuses.length === 0) return null;
  const credit = statuses.reduce((a, s) => {
    const v = s.toUpperCase();
    return a + (v === 'PRESENT' || v === 'LATE' ? 1 : v === 'HALF_DAY' ? 0.5 : 0);
  }, 0);
  return credit / statuses.length;
}

/** Fraction of correct answers' marks for an MCQ quiz. */
export function gradeQuiz(
  questions: Array<{ questionId: string; marks: number; correctOption: number | null }>,
  answers: Record<string, unknown>,
): { score: number; maxScore: number; correct: string[] } {
  let score = 0;
  const correct: string[] = [];
  for (const q of questions) {
    const a = answers[q.questionId];
    if (q.correctOption !== null && typeof a === 'number' && a === q.correctOption) {
      score += q.marks;
      correct.push(q.questionId);
    }
  }
  return { score: round2(score), maxScore: round2(questions.reduce((s, q) => s + q.marks, 0)), correct };
}
