import { roundMarks } from '../ai-exam.constants';

export interface ObjectiveQuestion {
  type: string;
  marks: number;
  correctOption?: number | null;
  answerKey?: string | null;
  acceptableAnswers?: string[];
  tolerance?: number | null;
}

export interface ObjectiveAnswer {
  text?: string | null;
  choice?: number | null;
}

/**
 * Result of marking against the answer key.
 * `decided: false` means the key cannot decide (e.g. a numerical answer with working
 * that is not an exact match) and the answer goes to the AI evaluator or a teacher.
 */
export interface ObjectiveResult {
  decided: boolean;
  marks: number;
  correct: boolean;
  reason: string;
}

export const normalizeText = (s: string) =>
  s
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9.+\-/ ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/^[.\-/+ ]+|[.\-/+ ]+$/g, '');

/** Last number in a text ("v = 12.5 m/s" -> 12.5); supports 1,000 and 1.2e3. */
export function extractNumber(s: string): number | null {
  const matches = s.replace(/(\d),(?=\d{3}\b)/g, '$1').match(/-?\d+(?:\.\d+)?(?:e-?\d+)?/gi);
  if (!matches) return null;
  const n = Number(matches[matches.length - 1]);
  return Number.isFinite(n) ? n : null;
}

export function gradeObjective(q: ObjectiveQuestion, a: ObjectiveAnswer): ObjectiveResult {
  const text = (a.text ?? '').trim();
  switch (q.type) {
    case 'MCQ':
    case 'TRUE_FALSE': {
      if (a.choice === null || a.choice === undefined) return { decided: true, marks: 0, correct: false, reason: 'Not answered' };
      const ok = a.choice === q.correctOption;
      return { decided: true, marks: ok ? q.marks : 0, correct: ok, reason: ok ? 'Correct option' : 'Incorrect option' };
    }
    case 'FILL_BLANK': {
      if (!text) return { decided: true, marks: 0, correct: false, reason: 'Not answered' };
      const accepted = [q.answerKey ?? '', ...(q.acceptableAnswers ?? [])].map(normalizeText).filter(Boolean);
      if (accepted.includes(normalizeText(text))) return { decided: true, marks: q.marks, correct: true, reason: 'Matches the answer key' };
      return { decided: false, marks: 0, correct: false, reason: 'Does not exactly match the answer key' };
    }
    case 'NUMERICAL': {
      if (!text) return { decided: true, marks: 0, correct: false, reason: 'Not answered' };
      const expected = extractNumber(q.answerKey ?? '');
      const got = extractNumber(text);
      if (expected === null) return { decided: false, marks: 0, correct: false, reason: 'Answer key has no numeric value' };
      const tol = Math.abs(q.tolerance ?? 0) || Math.max(1e-9, Math.abs(expected) * 1e-6);
      if (got !== null && Math.abs(got - expected) <= tol) {
        return { decided: true, marks: q.marks, correct: true, reason: `Final value ${got} within ±${q.tolerance ?? 0} of ${expected}` };
      }
      // Wrong or missing final value: working may still earn partial credit.
      return { decided: false, marks: 0, correct: false, reason: got === null ? 'No final value found' : `Final value ${got} differs from ${expected}` };
    }
    default:
      return { decided: false, marks: 0, correct: false, reason: 'Descriptive answer' };
  }
}

/** Clamp marks to [0, max] in quarter steps. */
export const clampMarks = (marks: number, max: number) => roundMarks(Math.min(Math.max(Number.isFinite(marks) ? marks : 0, 0), max));
