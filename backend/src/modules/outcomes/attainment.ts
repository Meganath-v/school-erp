/**
 * Course-outcome (CO) and program-outcome (PO) attainment, using the threshold
 * method common in outcome-based education:
 *
 *  1. For each CO and assessment category (internal / external), a student's score
 *     is (marks obtained ÷ maximum marks) over the questions mapped to that CO that
 *     the student was assessed on. The student "attains" the CO when the score is at
 *     least `studentTargetPercent`.
 *  2. The share of assessed students who attain it gives the level:
 *     ≥ level3Percent → 3, ≥ level2Percent → 2, ≥ level1Percent → 1, otherwise 0.
 *  3. Direct attainment = weighted mean of the internal and external levels (weights
 *     renormalised when only one category has data).
 *  4. Final attainment = weighted mean of direct and indirect (course exit survey,
 *     0–3) levels; the indirect part is skipped when no survey result exists.
 *  5. A PO's attainment for a course = Σ(mapping strength × CO attainment) ÷ Σ strength,
 *     over the COs mapped to it that have an attainment value.
 *
 * Pure functions only, so the arithmetic can be tested without a database.
 */

export type AssessmentType = 'INTERNAL' | 'EXTERNAL';

export interface AttainmentRuleConfig {
  studentTargetPercent: number;
  level1Percent: number;
  level2Percent: number;
  level3Percent: number;
  internalWeight: number;
  externalWeight: number;
  directWeight: number;
  indirectWeight: number;
  targetLevel: number;
}

export const DEFAULT_RULE: AttainmentRuleConfig = {
  studentTargetPercent: 60,
  level1Percent: 40,
  level2Percent: 50,
  level3Percent: 60,
  internalWeight: 40,
  externalWeight: 60,
  directWeight: 80,
  indirectWeight: 20,
  targetLevel: 2,
};

export interface AssessedItem {
  itemId: string;
  courseOutcomeId: string | null;
  maxMarks: number;
  assessmentType: AssessmentType;
}

export interface ItemMark {
  itemId: string;
  studentId: string;
  marks: number;
}

export interface OutcomeInput {
  id: string;
  code: string;
  description?: string;
  indirectLevel: number | null;
}

export interface CategoryResult {
  studentsAssessed: number;
  studentsAttained: number;
  percentAttained: number;
  level: number;
  questionsMapped: number;
}

export interface CoAttainment {
  courseOutcomeId: string;
  code: string;
  description?: string;
  internal: CategoryResult | null;
  external: CategoryResult | null;
  directLevel: number | null;
  indirectLevel: number | null;
  finalLevel: number | null;
  meetsTarget: boolean | null;
}

export interface CoPoLink {
  courseOutcomeId: string;
  programOutcomeId: string;
  strength: number;
}

export interface ProgramOutcomeInput {
  id: string;
  code: string;
  type: string;
  description?: string;
}

export interface PoAttainment {
  programOutcomeId: string;
  code: string;
  type: string;
  description?: string;
  attainment: number | null;
  contributingOutcomes: number;
  totalStrength: number;
}

const round2 = (n: number) => Math.round(n * 100) / 100;

/** Attainment level (0–3) for the given % of students who attained the outcome. */
export function levelFor(percentAttained: number, rule: AttainmentRuleConfig): number {
  if (percentAttained >= rule.level3Percent) return 3;
  if (percentAttained >= rule.level2Percent) return 2;
  if (percentAttained >= rule.level1Percent) return 1;
  return 0;
}

/** Throws when thresholds or weights cannot produce meaningful levels. */
export function validateRule(rule: AttainmentRuleConfig): void {
  const pct = (n: number) => Number.isFinite(n) && n >= 0 && n <= 100;
  if (![rule.studentTargetPercent, rule.level1Percent, rule.level2Percent, rule.level3Percent].every(pct)) {
    throw new Error('Percentages must be between 0 and 100.');
  }
  if (!(rule.level1Percent <= rule.level2Percent && rule.level2Percent <= rule.level3Percent)) {
    throw new Error('Level thresholds must increase: level 1 ≤ level 2 ≤ level 3.');
  }
  const w = [rule.internalWeight, rule.externalWeight, rule.directWeight, rule.indirectWeight];
  if (!w.every((x) => Number.isFinite(x) && x >= 0)) throw new Error('Weights cannot be negative.');
  if (rule.internalWeight + rule.externalWeight <= 0) throw new Error('Internal and external weights cannot both be 0.');
  if (rule.directWeight <= 0) throw new Error('Direct weight must be greater than 0.');
  if (!(rule.targetLevel >= 0 && rule.targetLevel <= 3)) throw new Error('Target level must be between 0 and 3.');
}

function categoryResult(
  coId: string,
  type: AssessmentType,
  items: AssessedItem[],
  marksByItem: Map<string, ItemMark[]>,
  rule: AttainmentRuleConfig,
): CategoryResult | null {
  const mapped = items.filter((i) => i.courseOutcomeId === coId && i.assessmentType === type && i.maxMarks > 0);
  if (mapped.length === 0) return null;

  const perStudent = new Map<string, { got: number; max: number }>();
  for (const item of mapped) {
    for (const m of marksByItem.get(item.itemId) ?? []) {
      const acc = perStudent.get(m.studentId) ?? { got: 0, max: 0 };
      acc.got += Math.max(0, Math.min(m.marks, item.maxMarks));
      acc.max += item.maxMarks;
      perStudent.set(m.studentId, acc);
    }
  }
  if (perStudent.size === 0) return null;

  let attained = 0;
  for (const { got, max } of perStudent.values()) {
    if ((got / max) * 100 >= rule.studentTargetPercent) attained++;
  }
  const percentAttained = round2((attained / perStudent.size) * 100);
  return {
    studentsAssessed: perStudent.size,
    studentsAttained: attained,
    percentAttained,
    level: levelFor(percentAttained, rule),
    questionsMapped: mapped.length,
  };
}

export function computeCoAttainment(
  outcomes: OutcomeInput[],
  items: AssessedItem[],
  marks: ItemMark[],
  rule: AttainmentRuleConfig,
): CoAttainment[] {
  const marksByItem = new Map<string, ItemMark[]>();
  for (const m of marks) {
    const list = marksByItem.get(m.itemId) ?? [];
    list.push(m);
    marksByItem.set(m.itemId, list);
  }

  return outcomes.map((co) => {
    const internal = categoryResult(co.id, 'INTERNAL', items, marksByItem, rule);
    const external = categoryResult(co.id, 'EXTERNAL', items, marksByItem, rule);

    let directLevel: number | null = null;
    if (internal && external) {
      const wSum = rule.internalWeight + rule.externalWeight;
      directLevel = (rule.internalWeight * internal.level + rule.externalWeight * external.level) / wSum;
    } else if (internal) {
      directLevel = internal.level;
    } else if (external) {
      directLevel = external.level;
    }

    const indirect = co.indirectLevel ?? null;
    let finalLevel: number | null = null;
    if (directLevel !== null) {
      finalLevel =
        indirect === null
          ? directLevel
          : (rule.directWeight * directLevel + rule.indirectWeight * indirect) / (rule.directWeight + rule.indirectWeight);
    }

    return {
      courseOutcomeId: co.id,
      code: co.code,
      description: co.description,
      internal,
      external,
      directLevel: directLevel === null ? null : round2(directLevel),
      indirectLevel: indirect,
      finalLevel: finalLevel === null ? null : round2(finalLevel),
      meetsTarget: finalLevel === null ? null : finalLevel >= rule.targetLevel,
    };
  });
}

export function computePoAttainment(
  programOutcomes: ProgramOutcomeInput[],
  links: CoPoLink[],
  coResults: CoAttainment[],
): PoAttainment[] {
  const coLevel = new Map(coResults.map((c) => [c.courseOutcomeId, c.finalLevel]));
  return programOutcomes.map((po) => {
    let weighted = 0;
    let strengthSum = 0;
    let contributing = 0;
    let totalStrength = 0;
    for (const l of links) {
      if (l.programOutcomeId !== po.id || l.strength <= 0) continue;
      totalStrength += l.strength;
      const level = coLevel.get(l.courseOutcomeId);
      if (level === null || level === undefined) continue;
      weighted += l.strength * level;
      strengthSum += l.strength;
      contributing++;
    }
    return {
      programOutcomeId: po.id,
      code: po.code,
      type: po.type,
      description: po.description,
      attainment: strengthSum > 0 ? round2(weighted / strengthSum) : null,
      contributingOutcomes: contributing,
      totalStrength,
    };
  });
}

/** Mean of per-course PO attainment values (ignores courses with no value). */
export function averagePoAttainment(perCourse: Array<{ programOutcomeId: string; attainment: number | null }>): Map<string, { attainment: number | null; courses: number }> {
  const acc = new Map<string, { sum: number; n: number }>();
  for (const r of perCourse) {
    if (r.attainment === null) {
      if (!acc.has(r.programOutcomeId)) acc.set(r.programOutcomeId, { sum: 0, n: 0 });
      continue;
    }
    const a = acc.get(r.programOutcomeId) ?? { sum: 0, n: 0 };
    a.sum += r.attainment;
    a.n += 1;
    acc.set(r.programOutcomeId, a);
  }
  const out = new Map<string, { attainment: number | null; courses: number }>();
  for (const [k, v] of acc) out.set(k, { attainment: v.n ? round2(v.sum / v.n) : null, courses: v.n });
  return out;
}
