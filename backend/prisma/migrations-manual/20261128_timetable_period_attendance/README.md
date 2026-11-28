# 20261128 – Bell schedule, daily substitutions, period attendance

Additive only: four new tables and one nullable column. No existing data is changed.

| Object | Purpose |
|---|---|
| `TimetablePeriod` | The school day's periods and times (set by the office) |
| `PeriodSubstitution` | One-day change of the teacher for a section's period |
| `PeriodAttendance`, `PeriodAttendanceRecord` | Attendance taken for one period on one date |
| `TeacherAssignment.source` | `TIMETABLE` when the class timetable created the assignment; `NULL` for admin-made ones |

Apply: `npx prisma db push` (or run `up.sql`), then re-run `prisma/supabase-lockdown.sql`.
Revert: run `down.sql`.
