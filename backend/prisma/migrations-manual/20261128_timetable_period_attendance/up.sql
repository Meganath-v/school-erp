-- AlterTable
ALTER TABLE "TeacherAssignment" ADD COLUMN     "source" TEXT;

-- CreateTable
CREATE TABLE "TimetablePeriod" (
    "id" TEXT NOT NULL,
    "schoolId" TEXT NOT NULL,
    "academicYearId" TEXT NOT NULL,
    "dayOfWeek" INTEGER NOT NULL,
    "periodNumber" INTEGER NOT NULL,
    "startTime" TEXT NOT NULL,
    "endTime" TEXT NOT NULL,
    "label" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TimetablePeriod_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PeriodSubstitution" (
    "id" TEXT NOT NULL,
    "schoolId" TEXT NOT NULL,
    "sectionId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "periodNumber" INTEGER NOT NULL,
    "staffId" TEXT NOT NULL,
    "subjectId" TEXT,
    "originalStaffId" TEXT,
    "reason" TEXT,
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PeriodSubstitution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PeriodAttendance" (
    "id" TEXT NOT NULL,
    "schoolId" TEXT NOT NULL,
    "sectionId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "periodNumber" INTEGER NOT NULL,
    "subjectId" TEXT,
    "staffId" TEXT NOT NULL,
    "markedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PeriodAttendance_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PeriodAttendanceRecord" (
    "id" TEXT NOT NULL,
    "periodAttendanceId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "remarks" TEXT,

    CONSTRAINT "PeriodAttendanceRecord_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "TimetablePeriod_schoolId_idx" ON "TimetablePeriod"("schoolId");

-- CreateIndex
CREATE UNIQUE INDEX "TimetablePeriod_schoolId_academicYearId_dayOfWeek_periodNum_key" ON "TimetablePeriod"("schoolId", "academicYearId", "dayOfWeek", "periodNumber");

-- CreateIndex
CREATE INDEX "PeriodSubstitution_schoolId_idx" ON "PeriodSubstitution"("schoolId");

-- CreateIndex
CREATE INDEX "PeriodSubstitution_staffId_date_idx" ON "PeriodSubstitution"("staffId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "PeriodSubstitution_sectionId_date_periodNumber_key" ON "PeriodSubstitution"("sectionId", "date", "periodNumber");

-- CreateIndex
CREATE INDEX "PeriodAttendance_schoolId_idx" ON "PeriodAttendance"("schoolId");

-- CreateIndex
CREATE INDEX "PeriodAttendance_staffId_date_idx" ON "PeriodAttendance"("staffId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "PeriodAttendance_sectionId_date_periodNumber_key" ON "PeriodAttendance"("sectionId", "date", "periodNumber");

-- CreateIndex
CREATE INDEX "PeriodAttendanceRecord_studentId_idx" ON "PeriodAttendanceRecord"("studentId");

-- CreateIndex
CREATE UNIQUE INDEX "PeriodAttendanceRecord_periodAttendanceId_studentId_key" ON "PeriodAttendanceRecord"("periodAttendanceId", "studentId");

-- AddForeignKey
ALTER TABLE "TimetablePeriod" ADD CONSTRAINT "TimetablePeriod_schoolId_fkey" FOREIGN KEY ("schoolId") REFERENCES "School"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TimetablePeriod" ADD CONSTRAINT "TimetablePeriod_academicYearId_fkey" FOREIGN KEY ("academicYearId") REFERENCES "AcademicYear"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PeriodSubstitution" ADD CONSTRAINT "PeriodSubstitution_schoolId_fkey" FOREIGN KEY ("schoolId") REFERENCES "School"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PeriodSubstitution" ADD CONSTRAINT "PeriodSubstitution_sectionId_fkey" FOREIGN KEY ("sectionId") REFERENCES "Section"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PeriodSubstitution" ADD CONSTRAINT "PeriodSubstitution_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "Staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PeriodSubstitution" ADD CONSTRAINT "PeriodSubstitution_subjectId_fkey" FOREIGN KEY ("subjectId") REFERENCES "Subject"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PeriodAttendance" ADD CONSTRAINT "PeriodAttendance_schoolId_fkey" FOREIGN KEY ("schoolId") REFERENCES "School"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PeriodAttendance" ADD CONSTRAINT "PeriodAttendance_sectionId_fkey" FOREIGN KEY ("sectionId") REFERENCES "Section"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PeriodAttendance" ADD CONSTRAINT "PeriodAttendance_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "Staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PeriodAttendance" ADD CONSTRAINT "PeriodAttendance_subjectId_fkey" FOREIGN KEY ("subjectId") REFERENCES "Subject"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PeriodAttendanceRecord" ADD CONSTRAINT "PeriodAttendanceRecord_periodAttendanceId_fkey" FOREIGN KEY ("periodAttendanceId") REFERENCES "PeriodAttendance"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PeriodAttendanceRecord" ADD CONSTRAINT "PeriodAttendanceRecord_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

┌─────────────────────────────────────────────────────────┐
│  Update available 6.4.1 -> 8.0.0-rc.36                  │
│                                                         │
│  This is a major update - please follow the guide at    │
│  https://pris.ly/d/major-version-upgrade                │
│                                                         │
│  Run the following to update                            │
│    npm i --save-dev prisma@latest                       │
│    npm i @prisma/client@latest                          │
└─────────────────────────────────────────────────────────┘
