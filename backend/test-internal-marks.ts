/**
 * Unit tests for internal marks, attendance credit and quiz grading (no database).
 * Run: npx ts-node test-internal-marks.ts
 */
import { strict as assert } from 'node:assert';
import { attendanceFraction, computeInternalMark, gradeQuiz, ComponentInput } from './src/modules/internal-assessment/internal-marks';

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

// Scheme out of 40: class tests best 2 of 3 (20), assignments (10), attendance (5), participation (5)
const scheme: ComponentInput[] = [
  { id: 'ct', label: 'Class tests', type: 'EXAM', weight: 20, bestOf: 2, sourceIds: ['e1', 'e2', 'e3'] },
  { id: 'as', label: 'Assignments', type: 'ASSIGNMENT', weight: 10, bestOf: null, sourceIds: ['a1', 'a2'] },
  { id: 'at', label: 'Attendance', type: 'ATTENDANCE', weight: 5, bestOf: null, sourceIds: [] },
  { id: 'pa', label: 'Participation', type: 'MANUAL', weight: 5, bestOf: null, sourceIds: [] },
];

console.log('Internal marks & quiz grading');

test('best 2 of 3 tests, mean of assignments, attendance and manual marks', () => {
  // tests 0.9, 0.5, 0.7 -> best two 0.9, 0.7 -> mean 0.8 × 20 = 16
  // assignments 0.6, 1.0 -> 0.8 × 10 = 8; attendance 0.9 × 5 = 4.5; manual 3
  const r = computeInternalMark(scheme, { scores: { e1: 0.9, e2: 0.5, e3: 0.7, a1: 0.6, a2: 1 }, attendanceFraction: 0.9, manual: { pa: 3 } }, 40);
  assert.deepEqual(r.components.map((c) => c.score), [16, 8, 4.5, 3]);
  assert.equal(r.components[0].used, 2);
  assert.equal(r.total, 31.5);
  assert.equal(r.max, 40);
  assert.equal(r.percent, 78.75);
  assert.equal(r.complete, true);
  assert.equal(r.isWeak, false);
});

test('missing data scores 0, is reported incomplete, and can make a student weak', () => {
  const r = computeInternalMark(scheme, { scores: { e1: 0.4 }, attendanceFraction: null, manual: {} }, 40);
  assert.deepEqual(r.components.map((c) => c.score), [8, null, null, null]);
  assert.equal(r.total, 8);
  assert.equal(r.percent, 20);
  assert.equal(r.complete, false);
  assert.equal(r.isWeak, true);
});

test('fractions are clamped to 0..1 and manual marks to the weight', () => {
  const r = computeInternalMark(scheme, { scores: { e1: 1.4, e2: -0.2, a1: 2 }, attendanceFraction: 1.3, manual: { pa: 9 } }, 40);
  // best two of [1, 0] -> 0.5 × 20 = 10; assignments 1 × 10; attendance 5; manual capped 5
  assert.deepEqual(r.components.map((c) => c.score), [10, 10, 5, 5]);
});

test('bestOf larger than the number of assessments uses all of them', () => {
  const r = computeInternalMark([{ ...scheme[0], bestOf: 5 }], { scores: { e1: 0.5, e2: 1 }, attendanceFraction: null, manual: {} }, 40);
  assert.equal(r.components[0].score, 15);
  assert.equal(r.components[0].used, 2);
});

test('exactly at the pass percentage is not weak', () => {
  const r = computeInternalMark([scheme[3]], { scores: {}, attendanceFraction: null, manual: { pa: 2 } }, 40);
  assert.equal(r.percent, 40);
  assert.equal(r.isWeak, false);
});

test('attendance credit: present/late 1, half day 0.5, absent 0; none recorded = null', () => {
  assert.equal(attendanceFraction(['PRESENT', 'LATE', 'HALF_DAY', 'ABSENT']), 0.625);
  assert.equal(attendanceFraction([]), null);
});

test('quiz grading counts only exactly-matching answers', () => {
  const g = gradeQuiz(
    [
      { questionId: 'q1', marks: 2, correctOption: 1 },
      { questionId: 'q2', marks: 1, correctOption: 0 },
      { questionId: 'q3', marks: 1, correctOption: 3 },
      { questionId: 'q4', marks: 1, correctOption: null },
    ],
    { q1: 1, q2: '0', q3: 2, q4: 0, extra: 1 },
  );
  assert.deepEqual(g, { score: 2, maxScore: 5, correct: ['q1'] });
});

console.log(`\n${passed} passed${process.exitCode ? ', some FAILED' : ''}`);
