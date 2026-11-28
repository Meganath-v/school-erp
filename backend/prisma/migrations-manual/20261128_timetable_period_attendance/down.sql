-- Reverses 20261128_timetable_period_attendance. Removes only what up.sql added.
DROP TABLE IF EXISTS "PeriodAttendanceRecord";
DROP TABLE IF EXISTS "PeriodAttendance";
DROP TABLE IF EXISTS "PeriodSubstitution";
DROP TABLE IF EXISTS "TimetablePeriod";
ALTER TABLE "TeacherAssignment" DROP COLUMN IF EXISTS "source";
