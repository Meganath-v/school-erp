-- CreateTable
CREATE TABLE "AiExamSettings" (
    "id" TEXT NOT NULL,
    "schoolId" TEXT NOT NULL,
    "autoEvaluate" BOOLEAN NOT NULL DEFAULT true,
    "reviewConfidence" DOUBLE PRECISION NOT NULL DEFAULT 0.6,
    "allowVoice" BOOLEAN NOT NULL DEFAULT true,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiExamSettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiExamTest" (
    "id" TEXT NOT NULL,
    "schoolId" TEXT NOT NULL,
    "academicYearId" TEXT NOT NULL,
    "classId" TEXT NOT NULL,
    "sectionId" TEXT,
    "subjectId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "chapter" TEXT,
    "topics" TEXT[],
    "instructions" TEXT,
    "totalMarks" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "durationMinutes" INTEGER,
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "assignMode" TEXT NOT NULL DEFAULT 'CLASS',
    "autoSubmit" BOOLEAN NOT NULL DEFAULT true,
    "publishedAt" TIMESTAMP(3),
    "resultsPublishedAt" TIMESTAMP(3),
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiExamTest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiExamQuestion" (
    "id" TEXT NOT NULL,
    "testId" TEXT NOT NULL,
    "orderIndex" INTEGER NOT NULL DEFAULT 0,
    "type" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "imageUrl" TEXT,
    "marks" DOUBLE PRECISION NOT NULL,
    "chapter" TEXT,
    "topic" TEXT,
    "difficulty" TEXT NOT NULL DEFAULT 'MEDIUM',
    "options" JSONB,
    "correctOption" INTEGER,
    "answerKey" TEXT,
    "acceptableAnswers" TEXT[],
    "keywords" TEXT[],
    "concepts" TEXT[],
    "explanation" TEXT,
    "partialCredit" TEXT,
    "tolerance" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiExamQuestion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiExamRubricCriterion" (
    "id" TEXT NOT NULL,
    "questionId" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "marks" DOUBLE PRECISION NOT NULL,
    "orderIndex" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "AiExamRubricCriterion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiExamAssignee" (
    "id" TEXT NOT NULL,
    "testId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,

    CONSTRAINT "AiExamAssignee_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiExamSubmission" (
    "id" TEXT NOT NULL,
    "schoolId" TEXT NOT NULL,
    "testId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'IN_PROGRESS',
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deadline" TIMESTAMP(3),
    "submittedAt" TIMESTAMP(3),
    "autoSubmitted" BOOLEAN NOT NULL DEFAULT false,
    "late" BOOLEAN NOT NULL DEFAULT false,
    "evaluationStatus" TEXT NOT NULL DEFAULT 'NOT_SUBMITTED',
    "score" DOUBLE PRECISION,
    "maxScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "lastSavedAt" TIMESTAMP(3),

    CONSTRAINT "AiExamSubmission_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiExamAnswer" (
    "id" TEXT NOT NULL,
    "submissionId" TEXT NOT NULL,
    "questionId" TEXT NOT NULL,
    "text" TEXT NOT NULL DEFAULT '',
    "choice" INTEGER,
    "inputMethod" TEXT NOT NULL DEFAULT 'TYPED',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiExamAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiExamEvaluation" (
    "id" TEXT NOT NULL,
    "answerId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "method" TEXT,
    "maxMarks" DOUBLE PRECISION NOT NULL,
    "aiMarks" DOUBLE PRECISION,
    "teacherMarks" DOUBLE PRECISION,
    "finalMarks" DOUBLE PRECISION,
    "feedback" JSONB,
    "criteria" JSONB,
    "confidence" DOUBLE PRECISION,
    "reviewReasons" TEXT[],
    "overrideReason" TEXT,
    "reviewedById" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "provider" TEXT,
    "model" TEXT,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lastError" TEXT,
    "claimedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiExamEvaluation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiExamEvaluationEvent" (
    "id" TEXT NOT NULL,
    "evaluationId" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "marks" DOUBLE PRECISION,
    "details" JSONB,
    "actorId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AiExamEvaluationEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiExamImprovementPlan" (
    "id" TEXT NOT NULL,
    "schoolId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "plan" JSONB NOT NULL,
    "basedOn" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AiExamImprovementPlan_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AiExamSettings_schoolId_key" ON "AiExamSettings"("schoolId");

-- CreateIndex
CREATE INDEX "AiExamTest_schoolId_classId_subjectId_idx" ON "AiExamTest"("schoolId", "classId", "subjectId");

-- CreateIndex
CREATE INDEX "AiExamTest_schoolId_status_idx" ON "AiExamTest"("schoolId", "status");

-- CreateIndex
CREATE INDEX "AiExamQuestion_testId_idx" ON "AiExamQuestion"("testId");

-- CreateIndex
CREATE INDEX "AiExamRubricCriterion_questionId_idx" ON "AiExamRubricCriterion"("questionId");

-- CreateIndex
CREATE INDEX "AiExamAssignee_studentId_idx" ON "AiExamAssignee"("studentId");

-- CreateIndex
CREATE UNIQUE INDEX "AiExamAssignee_testId_studentId_key" ON "AiExamAssignee"("testId", "studentId");

-- CreateIndex
CREATE INDEX "AiExamSubmission_schoolId_studentId_idx" ON "AiExamSubmission"("schoolId", "studentId");

-- CreateIndex
CREATE UNIQUE INDEX "AiExamSubmission_testId_studentId_key" ON "AiExamSubmission"("testId", "studentId");

-- CreateIndex
CREATE INDEX "AiExamAnswer_questionId_idx" ON "AiExamAnswer"("questionId");

-- CreateIndex
CREATE UNIQUE INDEX "AiExamAnswer_submissionId_questionId_key" ON "AiExamAnswer"("submissionId", "questionId");

-- CreateIndex
CREATE UNIQUE INDEX "AiExamEvaluation_answerId_key" ON "AiExamEvaluation"("answerId");

-- CreateIndex
CREATE INDEX "AiExamEvaluation_status_idx" ON "AiExamEvaluation"("status");

-- CreateIndex
CREATE INDEX "AiExamEvaluationEvent_evaluationId_idx" ON "AiExamEvaluationEvent"("evaluationId");

-- CreateIndex
CREATE INDEX "AiExamImprovementPlan_studentId_createdAt_idx" ON "AiExamImprovementPlan"("studentId", "createdAt");

-- AddForeignKey
ALTER TABLE "AiExamSettings" ADD CONSTRAINT "AiExamSettings_schoolId_fkey" FOREIGN KEY ("schoolId") REFERENCES "School"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamTest" ADD CONSTRAINT "AiExamTest_schoolId_fkey" FOREIGN KEY ("schoolId") REFERENCES "School"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamTest" ADD CONSTRAINT "AiExamTest_academicYearId_fkey" FOREIGN KEY ("academicYearId") REFERENCES "AcademicYear"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamTest" ADD CONSTRAINT "AiExamTest_classId_fkey" FOREIGN KEY ("classId") REFERENCES "Class"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamTest" ADD CONSTRAINT "AiExamTest_sectionId_fkey" FOREIGN KEY ("sectionId") REFERENCES "Section"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamTest" ADD CONSTRAINT "AiExamTest_subjectId_fkey" FOREIGN KEY ("subjectId") REFERENCES "Subject"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamQuestion" ADD CONSTRAINT "AiExamQuestion_testId_fkey" FOREIGN KEY ("testId") REFERENCES "AiExamTest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamRubricCriterion" ADD CONSTRAINT "AiExamRubricCriterion_questionId_fkey" FOREIGN KEY ("questionId") REFERENCES "AiExamQuestion"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamAssignee" ADD CONSTRAINT "AiExamAssignee_testId_fkey" FOREIGN KEY ("testId") REFERENCES "AiExamTest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamAssignee" ADD CONSTRAINT "AiExamAssignee_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamSubmission" ADD CONSTRAINT "AiExamSubmission_testId_fkey" FOREIGN KEY ("testId") REFERENCES "AiExamTest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamSubmission" ADD CONSTRAINT "AiExamSubmission_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamAnswer" ADD CONSTRAINT "AiExamAnswer_submissionId_fkey" FOREIGN KEY ("submissionId") REFERENCES "AiExamSubmission"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamAnswer" ADD CONSTRAINT "AiExamAnswer_questionId_fkey" FOREIGN KEY ("questionId") REFERENCES "AiExamQuestion"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamEvaluation" ADD CONSTRAINT "AiExamEvaluation_answerId_fkey" FOREIGN KEY ("answerId") REFERENCES "AiExamAnswer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamEvaluationEvent" ADD CONSTRAINT "AiExamEvaluationEvent_evaluationId_fkey" FOREIGN KEY ("evaluationId") REFERENCES "AiExamEvaluation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamImprovementPlan" ADD CONSTRAINT "AiExamImprovementPlan_schoolId_fkey" FOREIGN KEY ("schoolId") REFERENCES "School"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AiExamImprovementPlan" ADD CONSTRAINT "AiExamImprovementPlan_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

