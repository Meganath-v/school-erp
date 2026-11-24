/**
 * Unit tests for the outcome attainment calculation (no database needed).
 * Run: npx ts-node test-attainment.ts
 */
import { strict as assert } from 'node:assert';
import {
  averagePoAttainment,
  computeCoAttainment,
  computePoAttainment,
  DEFAULT_RULE,
  levelFor,
  validateRule,
  AssessedItem,
  ItemMark,
} from './src/modules/outcomes/attainment';

let passed = 0;
function test(name: string, fn: () => void) {
  try {
    fn();
    passed++;
    console.log(`  PASS  ${name}`);
  } catch (e: any) {
    console.error(`  FAIL  ${name}\n        ${e.message}`);
    process.exitCode = 1;
  }
}

const rule = { ...DEFAULT_RULE }; // target 60%, levels 40/50/60, internal 40 / external 60, direct 80 / indirect 20

const items: AssessedItem[] = [
  { itemId: 'i1', courseOutcomeId: 'CO1', maxMarks: 10, assessmentType: 'INTERNAL' },
  { itemId: 'i2', courseOutcomeId: 'CO1', maxMarks: 10, assessmentType: 'INTERNAL' },
  { itemId: 'e1', courseOutcomeId: 'CO1', maxMarks: 20, assessmentType: 'EXTERNAL' },
  { itemId: 'i3', courseOutcomeId: 'CO2', maxMarks: 5, assessmentType: 'INTERNAL' },
  { itemId: 'i4', courseOutcomeId: null, maxMarks: 10, assessmentType: 'INTERNAL' }, // not mapped: ignored
];
const m = (itemId: string, studentId: string, marks: number): ItemMark => ({ itemId, studentId, marks });
const marks: ItemMark[] = [
  // CO1 internal: s1 75% ✓, s2 55% ✗, s3 90% ✓, s4 60% ✓ (boundary), s5 only i1 → 30% ✗  ⇒ 3/5 = 60% ⇒ level 3
  m('i1', 's1', 8), m('i2', 's1', 7),
  m('i1', 's2', 5), m('i2', 's2', 6),
  m('i1', 's3', 9), m('i2', 's3', 9),
  m('i1', 's4', 6), m('i2', 's4', 6),
  m('i1', 's5', 3),
  // CO1 external: s1 70% ✓, s2 50% ✗, s3 90% ✓, s4 55% ✗, s5 absent ⇒ 2/4 = 50% ⇒ level 2
  m('e1', 's1', 14), m('e1', 's2', 10), m('e1', 's3', 18), m('e1', 's4', 11),
  // CO2 internal: 40%, 20%, 100% (7 clamped to 5), 0% ⇒ 1/4 = 25% ⇒ level 0
  m('i3', 's1', 2), m('i3', 's2', 1), m('i3', 's3', 7), m('i3', 's4', 0),
  m('i4', 's1', 10),
];
const outcomes = [
  { id: 'CO1', code: 'CO1', indirectLevel: 3 },
  { id: 'CO2', code: 'CO2', indirectLevel: null },
  { id: 'CO3', code: 'CO3', indirectLevel: 2 },
];

console.log('Outcome attainment calculation');

test('level thresholds are inclusive', () => {
  assert.equal(levelFor(39.99, rule), 0);
  assert.equal(levelFor(40, rule), 1);
  assert.equal(levelFor(49.99, rule), 1);
  assert.equal(levelFor(50, rule), 2);
  assert.equal(levelFor(59.99, rule), 2);
  assert.equal(levelFor(60, rule), 3);
  assert.equal(levelFor(100, rule), 3);
});

const co = computeCoAttainment(outcomes, items, marks, rule);
const byId = Object.fromEntries(co.map((c) => [c.courseOutcomeId, c]));

test('CO1 internal: 3 of 5 students attain (missing question excluded, 60% counts)', () => {
  assert.deepEqual(byId.CO1.internal, { studentsAssessed: 5, studentsAttained: 3, percentAttained: 60, level: 3, questionsMapped: 2 });
});

test('CO1 external: absent student not counted, 2 of 4 attain', () => {
  assert.deepEqual(byId.CO1.external, { studentsAssessed: 4, studentsAttained: 2, percentAttained: 50, level: 2, questionsMapped: 1 });
});

test('CO1 direct = 0.4×3 + 0.6×2 = 2.4; final = 0.8×2.4 + 0.2×3 = 2.52, meets target 2', () => {
  assert.equal(byId.CO1.directLevel, 2.4);
  assert.equal(byId.CO1.finalLevel, 2.52);
  assert.equal(byId.CO1.meetsTarget, true);
});

test('CO2: marks above the maximum are clamped; internal only; no survey ⇒ final = direct = 0', () => {
  assert.equal(byId.CO2.internal!.studentsAttained, 1);
  assert.equal(byId.CO2.internal!.percentAttained, 25);
  assert.equal(byId.CO2.external, null);
  assert.equal(byId.CO2.directLevel, 0);
  assert.equal(byId.CO2.finalLevel, 0);
  assert.equal(byId.CO2.meetsTarget, false);
});

test('CO3 with no assessed questions has no attainment (survey alone is not enough)', () => {
  assert.equal(byId.CO3.internal, null);
  assert.equal(byId.CO3.external, null);
  assert.equal(byId.CO3.finalLevel, null);
  assert.equal(byId.CO3.meetsTarget, null);
});

test('only external data ⇒ direct uses external level alone', () => {
  const r = computeCoAttainment([{ id: 'CO1', code: 'CO1', indirectLevel: null }], items.filter((i) => i.assessmentType === 'EXTERNAL'), marks, rule);
  assert.equal(r[0].directLevel, 2);
  assert.equal(r[0].finalLevel, 2);
});

const pos = [
  { id: 'PO1', code: 'PO1', type: 'PO' },
  { id: 'PO2', code: 'PO2', type: 'PO' },
  { id: 'PSO1', code: 'PSO1', type: 'PSO' },
];
const links = [
  { courseOutcomeId: 'CO1', programOutcomeId: 'PO1', strength: 3 },
  { courseOutcomeId: 'CO2', programOutcomeId: 'PO1', strength: 1 },
  { courseOutcomeId: 'CO3', programOutcomeId: 'PO2', strength: 2 },
];
const po = computePoAttainment(pos, links, co);
const poById = Object.fromEntries(po.map((p) => [p.programOutcomeId, p]));

test('PO1 = (3×2.52 + 1×0) / (3+1) = 1.89', () => {
  assert.equal(poById.PO1.attainment, 1.89);
  assert.equal(poById.PO1.contributingOutcomes, 2);
  assert.equal(poById.PO1.totalStrength, 4);
});

test('PO mapped only to an unassessed CO, and unmapped PSO, have no attainment', () => {
  assert.equal(poById.PO2.attainment, null);
  assert.equal(poById.PO2.contributingOutcomes, 0);
  assert.equal(poById.PO2.totalStrength, 2);
  assert.equal(poById.PSO1.attainment, null);
});

test('program-level PO = mean over courses that have a value', () => {
  const avg = averagePoAttainment([
    { programOutcomeId: 'PO1', attainment: 1.89 },
    { programOutcomeId: 'PO1', attainment: 2.11 },
    { programOutcomeId: 'PO2', attainment: null },
  ]);
  assert.deepEqual(avg.get('PO1'), { attainment: 2, courses: 2 });
  assert.deepEqual(avg.get('PO2'), { attainment: null, courses: 0 });
});

test('rule validation rejects bad thresholds and weights', () => {
  assert.doesNotThrow(() => validateRule(rule));
  assert.throws(() => validateRule({ ...rule, level1Percent: 70 }), /increase/);
  assert.throws(() => validateRule({ ...rule, studentTargetPercent: 120 }), /between 0 and 100/);
  assert.throws(() => validateRule({ ...rule, internalWeight: 0, externalWeight: 0 }), /both be 0/);
  assert.throws(() => validateRule({ ...rule, directWeight: 0 }), /Direct weight/);
  assert.throws(() => validateRule({ ...rule, targetLevel: 4 }), /Target level/);
});

console.log(`\n${passed} passed${process.exitCode ? ', some FAILED' : ''}`);
