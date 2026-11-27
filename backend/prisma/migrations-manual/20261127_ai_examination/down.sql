-- DropForeignKey
ALTER TABLE "AiExamSettings" DROP CONSTRAINT "AiExamSettings_schoolId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamTest" DROP CONSTRAINT "AiExamTest_schoolId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamTest" DROP CONSTRAINT "AiExamTest_academicYearId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamTest" DROP CONSTRAINT "AiExamTest_classId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamTest" DROP CONSTRAINT "AiExamTest_sectionId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamTest" DROP CONSTRAINT "AiExamTest_subjectId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamQuestion" DROP CONSTRAINT "AiExamQuestion_testId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamRubricCriterion" DROP CONSTRAINT "AiExamRubricCriterion_questionId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamAssignee" DROP CONSTRAINT "AiExamAssignee_testId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamAssignee" DROP CONSTRAINT "AiExamAssignee_studentId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamSubmission" DROP CONSTRAINT "AiExamSubmission_testId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamSubmission" DROP CONSTRAINT "AiExamSubmission_studentId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamAnswer" DROP CONSTRAINT "AiExamAnswer_submissionId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamAnswer" DROP CONSTRAINT "AiExamAnswer_questionId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamEvaluation" DROP CONSTRAINT "AiExamEvaluation_answerId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamEvaluationEvent" DROP CONSTRAINT "AiExamEvaluationEvent_evaluationId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamImprovementPlan" DROP CONSTRAINT "AiExamImprovementPlan_schoolId_fkey";

-- DropForeignKey
ALTER TABLE "AiExamImprovementPlan" DROP CONSTRAINT "AiExamImprovementPlan_studentId_fkey";

-- DropTable
DROP TABLE "AiExamSettings";

-- DropTable
DROP TABLE "AiExamTest";

-- DropTable
DROP TABLE "AiExamQuestion";

-- DropTable
DROP TABLE "AiExamRubricCriterion";

-- DropTable
DROP TABLE "AiExamAssignee";

-- DropTable
DROP TABLE "AiExamSubmission";

-- DropTable
DROP TABLE "AiExamAnswer";

-- DropTable
DROP TABLE "AiExamEvaluation";

-- DropTable
DROP TABLE "AiExamEvaluationEvent";

-- DropTable
DROP TABLE "AiExamImprovementPlan";

