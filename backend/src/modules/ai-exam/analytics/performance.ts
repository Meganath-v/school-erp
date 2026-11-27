import { round2 } from '../ai-exam.constants';

/** One evaluated test of a student (results published). */
export interface TestRecord {
  testId: string;
  title: string;
  subjectId: string;
  subject: string;
  date: Date;
  score: number;
  max: number;
}

/** One evaluated answer of a student. */
export interface AnswerRecord {
  testId: string;
  subjectId: string;
  subject: string;
  topic: string;
  date: Date;
  marks: number;
  max: number;
  missingPoints: string[];
  errors: string[];
}

export const pct = (a: number, b: number) => (b > 0 ? round2((a / b) * 100) : 0);

export function subjectStatus(p: number) {
  return p >= 80 ? 'Strong' : p >= 65 ? 'Good' : p >= 50 ? 'Average' : 'Needs improvement';
}

export function topicLevel(p: number) {
  return p >= 75 ? 'Strong' : p >= 50 ? 'Moderate' : 'Weak';
}

const TOPIC_ADVICE: Record<string, string> = {
  Strong: 'Practise advanced and application questions',
  Moderate: 'Revise core concepts and practise mixed questions',
  Weak: 'Relearn the fundamentals, then practise basic questions',
};

/** Change between the mean of the earlier and the later half (needs at least 2 points). */
export function trend(values: number[]): { change: number; direction: 'improving' | 'declining' | 'steady' } | null {
  if (values.length < 2) return null;
  const half = Math.floor(values.length / 2);
  const mean = (a: number[]) => a.reduce((s, x) => s + x, 0) / a.length;
  const change = round2(mean(values.slice(values.length - half)) - mean(values.slice(0, half)));
  return { change, direction: change > 3 ? 'improving' : change < -3 ? 'declining' : 'steady' };
}

const monthKey = (d: Date) => `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;

function topCounts(items: string[], n = 5) {
  const m = new Map<string, number>();
  for (const i of items) {
    const k = i.trim();
    if (k) m.set(k, (m.get(k) ?? 0) + 1);
  }
  return [...m.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, n)
    .map(([text, count]) => ({ text, count }));
}

export function studentPerformance(tests: TestRecord[], answers: AnswerRecord[]) {
  const sorted = [...tests].sort((a, b) => a.date.getTime() - b.date.getTime());
  const percents = sorted.map((t) => pct(t.score, t.max));
  const totalScore = sorted.reduce((s, t) => s + t.score, 0);
  const totalMax = sorted.reduce((s, t) => s + t.max, 0);

  const bySubject = new Map<string, TestRecord[]>();
  for (const t of sorted) bySubject.set(t.subjectId, [...(bySubject.get(t.subjectId) ?? []), t]);
  const subjects = [...bySubject.values()]
    .map((ts) => {
      const p = pct(
        ts.reduce((s, t) => s + t.score, 0),
        ts.reduce((s, t) => s + t.max, 0),
      );
      return { subjectId: ts[0].subjectId, subject: ts[0].subject, tests: ts.length, average: p, status: subjectStatus(p), trend: trend(ts.map((t) => pct(t.score, t.max))) };
    })
    .sort((a, b) => b.average - a.average);

  const byTopic = new Map<string, AnswerRecord[]>();
  for (const a of answers) {
    const k = `${a.subjectId}|${a.topic}`;
    byTopic.set(k, [...(byTopic.get(k) ?? []), a]);
  }
  const topics = [...byTopic.values()]
    .map((as) => {
      const ordered = [...as].sort((a, b) => a.date.getTime() - b.date.getTime());
      const marks = as.reduce((s, a) => s + a.marks, 0);
      const max = as.reduce((s, a) => s + a.max, 0);
      const p = pct(marks, max);
      const level = topicLevel(p);
      const testsSeen = new Set(as.map((a) => a.testId)).size;
      return {
        subjectId: as[0].subjectId,
        subject: as[0].subject,
        topic: as[0].topic,
        questions: as.length,
        tests: testsSeen,
        percent: p,
        marksLost: round2(max - marks),
        mistakes: as.filter((a) => pct(a.marks, a.max) < 50).length,
        level,
        recommendation: TOPIC_ADVICE[level],
        trend: trend(ordered.map((a) => pct(a.marks, a.max))),
        commonMissing: topCounts(as.flatMap((a) => a.missingPoints), 3),
        commonErrors: topCounts(as.flatMap((a) => a.errors), 3),
      };
    })
    .sort((a, b) => a.percent - b.percent);

  const months = new Map<string, { score: number; max: number; tests: number }>();
  for (const t of sorted) {
    const k = monthKey(t.date);
    const m = months.get(k) ?? { score: 0, max: 0, tests: 0 };
    months.set(k, { score: m.score + t.score, max: m.max + t.max, tests: m.tests + 1 });
  }

  return {
    hasData: sorted.length > 0,
    overall: {
      tests: sorted.length,
      averagePercent: sorted.length ? round2(percents.reduce((s, x) => s + x, 0) / percents.length) : null,
      overallPercent: sorted.length ? pct(totalScore, totalMax) : null,
      trend: trend(percents),
      strongestSubject: subjects.length >= 2 ? subjects[0] : null,
      weakestSubject: subjects.length >= 2 ? subjects[subjects.length - 1] : null,
    },
    subjects,
    topics,
    // Patterns need repetition: a single wrong answer is not called a repeated mistake.
    repeatedMistakes: topics.filter((t) => t.mistakes >= 2),
    consistentlyCorrect: topics.filter((t) => t.questions >= 2 && t.mistakes === 0 && t.percent >= 75),
    history: sorted.map((t) => ({ testId: t.testId, title: t.title, subject: t.subject, date: t.date, score: t.score, max: t.max, percent: pct(t.score, t.max) })),
    monthly: [...months.entries()].map(([month, m]) => ({ month, tests: m.tests, percent: pct(m.score, m.max) })),
  };
}

export type Performance = ReturnType<typeof studentPerformance>;

/**
 * Practical plan from the student's own records. Topics are ranked by marks lost, number of
 * weak answers, recency and lack of improvement. Returns null when there is not enough data.
 */
export function improvementPlan(perf: Performance, now = new Date()) {
  if (!perf.hasData) return null;
  const weak = perf.topics
    .filter((t) => t.percent < 75 && t.marksLost > 0)
    .map((t) => {
      const declining = t.trend?.direction === 'declining' ? 1 : 0;
      const notImproving = t.trend && t.trend.direction !== 'improving' ? 1 : 0;
      const priority = round2(t.marksLost * 1 + t.mistakes * 2 + (100 - t.percent) / 20 + declining * 3 + notImproving);
      return { ...t, priority };
    })
    .sort((a, b) => b.priority - a.priority)
    .slice(0, 5);

  const weakSubject = perf.subjects.length ? [...perf.subjects].sort((a, b) => a.average - b.average)[0] : null;
  const steps: { title: string; detail: string }[] = [];
  for (const t of weak.slice(0, 3)) {
    const missing = t.commonMissing.map((m) => m.text).slice(0, 2);
    steps.push({
      title: `${t.level === 'Weak' ? 'Relearn' : 'Revise'} ${t.topic} (${t.subject})`,
      detail:
        `You scored ${t.percent}% on ${t.questions} question${t.questions === 1 ? '' : 's'} and lost ${t.marksLost} marks.` +
        (missing.length ? ` Focus on: ${missing.join('; ')}.` : '') +
        ` ${t.recommendation}.`,
    });
  }
  if (weak.length) {
    steps.push({ title: `Practise ${weak[0].level === 'Weak' ? 10 : 5} questions on ${weak[0].topic}`, detail: 'Start with the concepts you missed, then time yourself.' });
    steps.push({ title: `Review your mistakes from the last ${Math.min(3, perf.history.length)} test${perf.history.length === 1 ? '' : 's'}`, detail: 'Compare each answer with the model answer and note what was missing.' });
    steps.push({ title: 'Take a short self-test, then compare with your previous score', detail: `Your latest score was ${perf.history[perf.history.length - 1].percent}%.` });
  }
  return {
    generatedAt: now,
    basedOnTests: perf.overall.tests,
    enoughData: perf.overall.tests >= 2,
    weakSubject: weakSubject && perf.subjects.length >= 2 ? { subject: weakSubject.subject, average: weakSubject.average } : null,
    priorities: weak.map((t) => ({ subject: t.subject, topic: t.topic, percent: t.percent, marksLost: t.marksLost, mistakes: t.mistakes, level: t.level, priority: t.priority })),
    steps,
    note: weak.length ? null : 'No weak topics in your evaluated answers so far. Keep practising advanced questions.',
  };
}

export type Plan = NonNullable<ReturnType<typeof improvementPlan>>;
