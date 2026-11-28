import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ScheduleAccessService, ScheduleActor } from '../timetable/schedule-access.service';
import { LONG_TX, TimetablePlannerService } from '../timetable/timetable-planner.service';
import { DAY_NAMES, parseDateOnly } from '../timetable/schedule.util';

/**
 * Attendance for one period of one section on one date.
 *  - Only the teacher who takes that period that day (the substitute, if there is one) can take it.
 *  - Teachers can take or change it only on that date.
 *  - Office staff can change it on any past date (audited as a correction).
 */
@Injectable()
export class PeriodAttendanceService {
  constructor(
    private prisma: PrismaService,
    private access: ScheduleAccessService,
    private planner: TimetablePlannerService,
  ) {}

  private async context(schoolId: string, actor: ScheduleActor, sectionId: string, dateText: string, periodNumber: number) {
    if (!parseDateOnly(dateText)) throw new BadRequestException('Date must be YYYY-MM-DD');
    const section = await this.access.section(schoolId, sectionId);
    const eff = await this.planner.effectivePeriod(schoolId, sectionId, dateText, periodNumber);
    if (!eff.period) throw new BadRequestException(`${DAY_NAMES[eff.dayOfWeek]} has no period ${periodNumber}`);
    const today = this.access.today(actor);
    const office = this.access.isOffice(actor);
    const me = office ? null : await this.access.staffOf(schoolId, actor.userId);
    const isPeriodTeacher = !!me && !!eff.staff && eff.staff.id === me.id;

    let canMark = false;
    let reason: string | null = null;
    if (!eff.staff) {
      reason = 'No teacher is assigned to this period';
    } else if (office) {
      canMark = dateText <= today;
      if (!canMark) reason = 'Attendance cannot be taken for a future date';
    } else if (!isPeriodTeacher) {
      reason = `Only ${eff.staff.firstName} ${eff.staff.lastName}, who takes this period, can take its attendance`;
    } else if (dateText !== today) {
      reason = dateText < today
        ? 'Attendance can only be changed on the day. Ask the office to correct it.'
        : 'Attendance can be taken on the day of the period';
    } else {
      canMark = true;
    }
    return { section, eff, today, office, me, isPeriodTeacher, canMark, reason };
  }

  async get(schoolId: string, actor: ScheduleActor, sectionId: string, dateText: string, periodNumber: number) {
    const ctx = await this.context(schoolId, actor, sectionId, dateText, periodNumber);
    if (!ctx.office && !ctx.isPeriodTeacher) {
      const mine = await this.access.classTeacherSection(schoolId, actor.userId);
      if (mine?.sectionId !== sectionId) throw new ForbiddenException('You do not take this period');
    }
    const [enrollments, existing] = await Promise.all([
      this.prisma.enrollment.findMany({
        where: { schoolId, sectionId, status: 'ACTIVE' },
        include: { student: true },
        orderBy: [{ rollNo: 'asc' }, { student: { firstName: 'asc' } }],
      }),
      this.prisma.periodAttendance.findUnique({
        where: { sectionId_date_periodNumber: { sectionId, date: ctx.eff.date, periodNumber } },
        include: { records: true, staff: true },
      }),
    ]);
    const records = new Map((existing?.records ?? []).map((r) => [r.studentId, r]));
    return {
      section: { id: ctx.section.id, name: ctx.section.name, className: ctx.section.class.name },
      date: dateText,
      isToday: dateText === ctx.today,
      periodNumber,
      startTime: ctx.eff.period!.startTime,
      endTime: ctx.eff.period!.endTime,
      subject: ctx.eff.subject ? { id: ctx.eff.subject.id, name: ctx.eff.subject.name } : null,
      teacher: this.access.teacherView(ctx.eff.staff),
      isSubstitution: !!ctx.eff.substitution,
      taken: !!existing,
      updatedAt: existing?.updatedAt ?? null,
      canMark: ctx.canMark,
      reason: ctx.reason,
      students: enrollments.map((e) => ({
        studentId: e.studentId,
        name: `${e.student.firstName} ${e.student.lastName}`,
        admissionNo: e.student.admissionNo,
        rollNo: e.rollNo,
        status: records.get(e.studentId)?.status ?? null,
        remarks: records.get(e.studentId)?.remarks ?? null,
      })),
    };
  }

  async save(
    schoolId: string,
    actor: ScheduleActor,
    body: { sectionId: string; date: string; periodNumber: number; records: { studentId: string; status: string; remarks?: string }[] },
  ) {
    const ctx = await this.context(schoolId, actor, body.sectionId, body.date, body.periodNumber);
    if (!ctx.canMark) throw new ForbiddenException(ctx.reason ?? 'You cannot take attendance for this period');

    const roster = await this.prisma.enrollment.findMany({ where: { schoolId, sectionId: body.sectionId, status: 'ACTIVE' }, select: { studentId: true } });
    const enrolled = new Set(roster.map((r) => r.studentId));
    const seen = new Set<string>();
    for (const r of body.records) {
      if (!enrolled.has(r.studentId)) throw new BadRequestException('A student in the list is not in this section');
      if (seen.has(r.studentId)) throw new BadRequestException('A student appears twice');
      seen.add(r.studentId);
    }

    const where = { sectionId_date_periodNumber: { sectionId: body.sectionId, date: ctx.eff.date, periodNumber: body.periodNumber } };
    const before = await this.prisma.periodAttendance.findUnique({ where, include: { records: true } });
    const saved = await this.prisma.$transaction(async (tx: any) => {
      const pa = await tx.periodAttendance.upsert({
        where,
        update: { markedById: actor.userId, staffId: ctx.eff.staff!.id, subjectId: ctx.eff.subject?.id ?? null },
        create: {
          schoolId, sectionId: body.sectionId, date: ctx.eff.date, periodNumber: body.periodNumber,
          subjectId: ctx.eff.subject?.id ?? null, staffId: ctx.eff.staff!.id, markedById: actor.userId,
        },
      });
      // Batched: replace these students' records in two queries, whatever the class size.
      await tx.periodAttendanceRecord.deleteMany({ where: { periodAttendanceId: pa.id, studentId: { in: body.records.map((r) => r.studentId) } } });
      await tx.periodAttendanceRecord.createMany({
        data: body.records.map((r) => ({ periodAttendanceId: pa.id, studentId: r.studentId, status: r.status, remarks: r.remarks?.trim() || null })),
      });
      return pa;
    }, LONG_TX);

    const previous = new Map((before?.records ?? []).map((r) => [r.studentId, r.status]));
    const changes = body.records
      .filter((r) => previous.has(r.studentId) && previous.get(r.studentId) !== r.status)
      .map((r) => ({ studentId: r.studentId, from: previous.get(r.studentId), to: r.status }));
    // Anything saved after the day (only the office can) is a correction.
    const action = body.date < ctx.today
      ? 'PERIOD_ATTENDANCE_CORRECTED'
      : before
        ? 'PERIOD_ATTENDANCE_MODIFIED'
        : 'PERIOD_ATTENDANCE_MARKED';
    await this.access.log(schoolId, actor, action, 'PeriodAttendance', saved.id, {
      sectionId: body.sectionId,
      date: body.date,
      periodNumber: body.periodNumber,
      staffId: ctx.eff.staff!.id,
      present: body.records.filter((r) => r.status === 'PRESENT').length,
      absent: body.records.filter((r) => r.status === 'ABSENT').length,
      changes,
    });
    return this.get(schoolId, actor, body.sectionId, body.date, body.periodNumber);
  }
}
