import { BadRequestException, ConflictException, ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ScheduleAccessService, ScheduleActor } from './schedule-access.service';
import { DAY_NAMES, dayOfWeekOf, minutes, parseDateOnly, TIME_RE } from './schedule.util';

const STAFF_WITH_USER = { include: { user: { select: { email: true, username: true } } } } as const;

type Tx = any;

/** Transactions here run a handful of queries; allow for a slow database connection. */
export const LONG_TX = { maxWait: 10_000, timeout: 30_000 };

/**
 * Bell schedule (office), class timetables (class teacher fills subject + teacher),
 * one-day substitutions and each teacher's periods for a day.
 */
@Injectable()
export class TimetablePlannerService {
  constructor(private prisma: PrismaService, private access: ScheduleAccessService) {}

  private async currentYear(schoolId: string) {
    const year = await this.prisma.academicYear.findFirst({ where: { schoolId, isCurrent: true } });
    if (!year) throw new BadRequestException('No current academic year is set for this school');
    return year;
  }

  private dateOrToday(actor: ScheduleActor, text?: string) {
    const value = text || this.access.today(actor);
    if (!parseDateOnly(value)) throw new BadRequestException('Date must be YYYY-MM-DD');
    return value;
  }

  // ---------------------------------------------------------------- bell schedule

  async getPeriods(schoolId: string) {
    const year = await this.currentYear(schoolId);
    const periods = await this.prisma.timetablePeriod.findMany({
      where: { schoolId, academicYearId: year.id },
      orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
    });
    return {
      academicYear: { id: year.id, name: year.name },
      periods: periods.map((p) => this.periodView(p)),
    };
  }

  private periodView(p: { dayOfWeek: number; periodNumber: number; startTime: string; endTime: string; label: string | null }) {
    return { dayOfWeek: p.dayOfWeek, periodNumber: p.periodNumber, startTime: p.startTime, endTime: p.endTime, label: p.label };
  }

  async savePeriods(
    schoolId: string,
    actor: ScheduleActor,
    body: { periods: { dayOfWeek: number; periodNumber: number; startTime: string; endTime: string; label?: string }[]; removeAssignedSlots?: boolean },
  ) {
    const year = await this.currentYear(schoolId);
    const byDay = new Map<number, typeof body.periods>();
    for (const p of body.periods) {
      if (!TIME_RE.test(p.startTime) || !TIME_RE.test(p.endTime)) throw new BadRequestException('Times must be HH:mm');
      if (minutes(p.endTime) <= minutes(p.startTime)) {
        throw new BadRequestException(`${DAY_NAMES[p.dayOfWeek]} period ${p.periodNumber}: end time must be after the start time`);
      }
      byDay.set(p.dayOfWeek, [...(byDay.get(p.dayOfWeek) ?? []), p]);
    }
    for (const [day, list] of byDay) {
      const numbers = new Set<number>();
      for (const p of list) {
        if (numbers.has(p.periodNumber)) throw new BadRequestException(`${DAY_NAMES[day]} has period ${p.periodNumber} twice`);
        numbers.add(p.periodNumber);
      }
      const sorted = [...list].sort((a, b) => minutes(a.startTime) - minutes(b.startTime));
      for (let i = 1; i < sorted.length; i++) {
        if (minutes(sorted[i].startTime) < minutes(sorted[i - 1].endTime)) {
          throw new BadRequestException(`${DAY_NAMES[day]}: period ${sorted[i - 1].periodNumber} and period ${sorted[i].periodNumber} overlap`);
        }
      }
    }

    const existing = await this.prisma.timetablePeriod.findMany({ where: { schoolId, academicYearId: year.id } });
    const key = (d: number, n: number) => `${d}:${n}`;
    const keep = new Set(body.periods.map((p) => key(p.dayOfWeek, p.periodNumber)));
    const removed = existing.filter((p) => !keep.has(key(p.dayOfWeek, p.periodNumber)));
    const removedWhere = removed.map((p) => ({ dayOfWeek: p.dayOfWeek, periodNumber: p.periodNumber }));
    const assignedInRemoved = removedWhere.length
      ? await this.prisma.timetableEntry.count({ where: { schoolId, academicYearId: year.id, OR: removedWhere } })
      : 0;
    if (assignedInRemoved > 0 && !body.removeAssignedSlots) {
      throw new ConflictException(
        `${assignedInRemoved} class timetable slot(s) use the periods you removed. Save again with "remove assigned slots" to clear them.`,
      );
    }

    await this.prisma.$transaction(async (tx: Tx) => {
      if (removedWhere.length) {
        const affected = await tx.timetableEntry.findMany({
          where: { schoolId, academicYearId: year.id, OR: removedWhere },
          select: { sectionId: true },
        });
        await tx.timetableEntry.deleteMany({ where: { schoolId, academicYearId: year.id, OR: removedWhere } });
        await tx.timetablePeriod.deleteMany({ where: { id: { in: removed.map((p) => p.id) } } });
        const sectionIds: string[] = [...new Set<string>(affected.map((a: { sectionId: string }) => a.sectionId))];
        await this.syncAssignments(tx, schoolId, sectionIds);
      }
      // Batched writes: one delete + one insert for the schedule (nothing references period rows by id).
      await tx.timetablePeriod.deleteMany({ where: { schoolId, academicYearId: year.id } });
      await tx.timetablePeriod.createMany({
        data: body.periods.map((p) => ({
          schoolId, academicYearId: year.id, dayOfWeek: p.dayOfWeek, periodNumber: p.periodNumber,
          startTime: p.startTime, endTime: p.endTime, label: p.label?.trim() || null,
        })),
      });
      // Class timetable slots follow the bell schedule's times (only where the times changed).
      const old = new Map(existing.map((p) => [key(p.dayOfWeek, p.periodNumber), p]));
      for (const p of body.periods) {
        const before = old.get(key(p.dayOfWeek, p.periodNumber));
        if (before && before.startTime === p.startTime && before.endTime === p.endTime) continue;
        await tx.timetableEntry.updateMany({
          where: { schoolId, academicYearId: year.id, dayOfWeek: p.dayOfWeek, periodNumber: p.periodNumber },
          data: { startTime: p.startTime, endTime: p.endTime },
        });
      }
    }, LONG_TX);

    await this.access.log(schoolId, actor, 'TIMETABLE_PERIODS_SAVED', 'TimetablePeriod', year.id, {
      periods: body.periods.length,
      removed: removed.length,
      clearedSlots: assignedInRemoved,
    });
    return this.getPeriods(schoolId);
  }

  // ---------------------------------------------------------------- class timetable

  async getClassTimetable(schoolId: string, actor: ScheduleActor, sectionId: string) {
    await this.access.assertCanViewSection(schoolId, actor, sectionId);
    const section = await this.access.section(schoolId, sectionId);
    const year = await this.currentYear(schoolId);
    const [periods, entries, classSubjects, canEdit] = await Promise.all([
      this.prisma.timetablePeriod.findMany({ where: { schoolId, academicYearId: year.id }, orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }] }),
      this.prisma.timetableEntry.findMany({
        where: { schoolId, academicYearId: year.id, sectionId },
        include: { subject: true, staff: STAFF_WITH_USER },
      }),
      this.prisma.classSubject.findMany({ where: { schoolId, classId: section.classId }, include: { subject: true } }),
      this.access.canEditSection(schoolId, actor, sectionId),
    ]);
    const subjects = classSubjects.length
      ? classSubjects.map((c) => c.subject)
      : await this.prisma.subject.findMany({ where: { schoolId }, orderBy: { name: 'asc' } });
    const periodKeys = new Set(periods.map((p) => `${p.dayOfWeek}:${p.periodNumber}`));
    return {
      section: { id: section.id, name: section.name, classId: section.classId, className: section.class.name },
      canEdit,
      periods: periods.map((p) => this.periodView(p)),
      entries: entries
        .sort((a, b) => a.dayOfWeek - b.dayOfWeek || a.periodNumber - b.periodNumber)
        .map((e) => ({
          id: e.id,
          dayOfWeek: e.dayOfWeek,
          periodNumber: e.periodNumber,
          startTime: e.startTime,
          endTime: e.endTime,
          subject: { id: e.subject.id, name: e.subject.name, code: e.subject.code },
          teacher: this.access.teacherView(e.staff),
          outsideSchedule: !periodKeys.has(`${e.dayOfWeek}:${e.periodNumber}`),
        })),
      subjects: subjects
        .map((s) => ({ id: s.id, name: s.name, code: s.code }))
        .sort((a, b) => a.name.localeCompare(b.name)),
    };
  }

  async setSlot(
    schoolId: string,
    actor: ScheduleActor,
    sectionId: string,
    body: { dayOfWeek: number; periodNumber: number; subjectId: string; teacher: string; room?: string },
  ) {
    await this.access.assertCanEditSection(schoolId, actor, sectionId);
    const section = await this.access.section(schoolId, sectionId);
    const year = await this.currentYear(schoolId);
    const period = await this.prisma.timetablePeriod.findUnique({
      where: { schoolId_academicYearId_dayOfWeek_periodNumber: { schoolId, academicYearId: year.id, dayOfWeek: body.dayOfWeek, periodNumber: body.periodNumber } },
    });
    if (!period) throw new BadRequestException(`${DAY_NAMES[body.dayOfWeek] ?? 'That day'} has no period ${body.periodNumber} in the bell schedule`);

    const subject = await this.prisma.subject.findFirst({ where: { id: body.subjectId, schoolId } });
    if (!subject) throw new BadRequestException('Subject not found');
    const classSubjects = await this.prisma.classSubject.findMany({ where: { schoolId, classId: section.classId }, select: { subjectId: true } });
    if (classSubjects.length && !classSubjects.some((c) => c.subjectId === subject.id)) {
      throw new BadRequestException(`${subject.name} is not a subject of ${section.class.name}`);
    }

    const { staff } = await this.access.resolveTeacher(schoolId, body.teacher);
    const clash = await this.prisma.timetableEntry.findFirst({
      where: { schoolId, academicYearId: year.id, staffId: staff.id, dayOfWeek: body.dayOfWeek, periodNumber: body.periodNumber, NOT: { sectionId } },
      include: { section: { include: { class: true } } },
    });
    if (clash) {
      throw new ConflictException(
        `${staff.firstName} ${staff.lastName} already teaches ${clash.section.class.name} ${clash.section.name} in ${DAY_NAMES[body.dayOfWeek]} period ${body.periodNumber}`,
      );
    }

    const slot = { schoolId_academicYearId_sectionId_dayOfWeek_periodNumber: { schoolId, academicYearId: year.id, sectionId, dayOfWeek: body.dayOfWeek, periodNumber: body.periodNumber } };
    const before = await this.prisma.timetableEntry.findUnique({ where: slot });
    const entry = await this.prisma.$transaction(async (tx: Tx) => {
      const saved = await tx.timetableEntry.upsert({
        where: slot,
        update: { subjectId: subject.id, staffId: staff.id, startTime: period.startTime, endTime: period.endTime, room: body.room ?? undefined },
        create: {
          schoolId, academicYearId: year.id, classId: section.classId, sectionId,
          subjectId: subject.id, staffId: staff.id, dayOfWeek: body.dayOfWeek, periodNumber: body.periodNumber,
          startTime: period.startTime, endTime: period.endTime, room: body.room || section.room || null,
        },
      });
      await this.ensureAssignment(tx, schoolId, staff.id, section.classId, sectionId, subject.id);
      await this.syncAssignments(tx, schoolId, [sectionId]);
      return saved;
    }, LONG_TX);

    await this.access.log(schoolId, actor, 'TIMETABLE_SLOT_SET', 'TimetableEntry', entry.id, {
      sectionId, dayOfWeek: body.dayOfWeek, periodNumber: body.periodNumber,
      subjectId: subject.id, staffId: staff.id,
      previous: before ? { subjectId: before.subjectId, staffId: before.staffId } : null,
    });
    return this.getClassTimetable(schoolId, actor, sectionId);
  }

  async clearSlot(schoolId: string, actor: ScheduleActor, sectionId: string, dayOfWeek: number, periodNumber: number) {
    await this.access.assertCanEditSection(schoolId, actor, sectionId);
    const year = await this.currentYear(schoolId);
    const entry = await this.prisma.timetableEntry.findFirst({ where: { schoolId, academicYearId: year.id, sectionId, dayOfWeek, periodNumber } });
    if (entry) {
      await this.prisma.$transaction(async (tx: Tx) => {
        await tx.timetableEntry.delete({ where: { id: entry.id } });
        await this.syncAssignments(tx, schoolId, [sectionId]);
      }, LONG_TX);
      await this.access.log(schoolId, actor, 'TIMETABLE_SLOT_CLEARED', 'TimetableEntry', entry.id, {
        sectionId, dayOfWeek, periodNumber, subjectId: entry.subjectId, staffId: entry.staffId,
      });
    }
    return this.getClassTimetable(schoolId, actor, sectionId);
  }

  /** Gives the teacher access to the subject's modules for this section (unless an admin already did). */
  private async ensureAssignment(tx: Tx, schoolId: string, staffId: string, classId: string, sectionId: string, subjectId: string) {
    const existing = await tx.teacherAssignment.findFirst({ where: { schoolId, staffId, sectionId, subjectId } });
    if (!existing) {
      await tx.teacherAssignment.create({ data: { schoolId, staffId, classId, sectionId, subjectId, isClassTeacher: false, source: 'TIMETABLE' } });
    }
  }

  /** Removes timetable-created access when the teacher no longer teaches that subject in the section. */
  private async syncAssignments(tx: Tx, schoolId: string, sectionIds: string[]) {
    if (!sectionIds.length) return;
    const generated = await tx.teacherAssignment.findMany({
      where: { schoolId, source: 'TIMETABLE', isClassTeacher: false, sectionId: { in: sectionIds } },
    });
    for (const a of generated) {
      const stillTeaches = await tx.timetableEntry.count({
        where: { schoolId, staffId: a.staffId, sectionId: a.sectionId, subjectId: a.subjectId ?? undefined },
      });
      if (!stillTeaches) await tx.teacherAssignment.delete({ where: { id: a.id } });
    }
  }

  // ---------------------------------------------------------------- daily periods & substitutions

  /** The period a section has on a date: the timetable slot, any substitution, and who teaches it. */
  async effectivePeriod(schoolId: string, sectionId: string, dateText: string, periodNumber: number) {
    const year = await this.currentYear(schoolId);
    const dayOfWeek = dayOfWeekOf(dateText);
    const date = parseDateOnly(dateText)!;
    const [period, entry, substitution] = await Promise.all([
      this.prisma.timetablePeriod.findUnique({
        where: { schoolId_academicYearId_dayOfWeek_periodNumber: { schoolId, academicYearId: year.id, dayOfWeek, periodNumber } },
      }),
      this.prisma.timetableEntry.findFirst({
        where: { schoolId, academicYearId: year.id, sectionId, dayOfWeek, periodNumber },
        include: { subject: true, staff: STAFF_WITH_USER },
      }),
      this.prisma.periodSubstitution.findUnique({
        where: { sectionId_date_periodNumber: { sectionId, date, periodNumber } },
        include: { subject: true, staff: STAFF_WITH_USER },
      }),
    ]);
    const staff = substitution?.staff ?? entry?.staff ?? null;
    const subject = substitution?.subject ?? entry?.subject ?? null;
    return { period, entry, substitution, staff, subject, dayOfWeek, date };
  }

  async getDaily(schoolId: string, actor: ScheduleActor, sectionId: string, dateText?: string) {
    await this.access.assertCanViewSection(schoolId, actor, sectionId);
    const section = await this.access.section(schoolId, sectionId);
    const year = await this.currentYear(schoolId);
    const dateValue = this.dateOrToday(actor, dateText);
    const date = parseDateOnly(dateValue)!;
    const dayOfWeek = dayOfWeekOf(dateValue);
    const today = this.access.today(actor);
    const [periods, entries, substitutions, taken, me, canEditSection] = await Promise.all([
      this.prisma.timetablePeriod.findMany({ where: { schoolId, academicYearId: year.id, dayOfWeek }, orderBy: { startTime: 'asc' } }),
      this.prisma.timetableEntry.findMany({
        where: { schoolId, academicYearId: year.id, sectionId, dayOfWeek },
        include: { subject: true, staff: STAFF_WITH_USER },
      }),
      this.prisma.periodSubstitution.findMany({ where: { schoolId, sectionId, date }, include: { subject: true, staff: STAFF_WITH_USER } }),
      this.prisma.periodAttendance.findMany({ where: { schoolId, sectionId, date }, select: { periodNumber: true, staffId: true } }),
      this.access.staffOf(schoolId, actor.userId),
      this.access.canEditSection(schoolId, actor, sectionId),
    ]);
    const editable = canEditSection && dateValue >= today;
    return {
      section: { id: section.id, name: section.name, className: section.class.name },
      date: dateValue,
      dayOfWeek,
      dayName: DAY_NAMES[dayOfWeek],
      isToday: dateValue === today,
      canEdit: editable,
      periods: periods.map((p) => {
        const entry = entries.find((e) => e.periodNumber === p.periodNumber) ?? null;
        const sub = substitutions.find((s) => s.periodNumber === p.periodNumber) ?? null;
        const effectiveStaff = sub?.staff ?? entry?.staff ?? null;
        const effectiveSubject = sub?.subject ?? entry?.subject ?? null;
        const attendanceTaken = taken.some((t) => t.periodNumber === p.periodNumber);
        return {
          ...this.periodView(p),
          subject: entry ? { id: entry.subject.id, name: entry.subject.name } : null,
          teacher: this.access.teacherView(entry?.staff ?? null),
          substitution: sub
            ? { id: sub.id, teacher: this.access.teacherView(sub.staff), subject: sub.subject ? { id: sub.subject.id, name: sub.subject.name } : null, reason: sub.reason }
            : null,
          effectiveTeacher: this.access.teacherView(effectiveStaff),
          effectiveSubject: effectiveSubject ? { id: effectiveSubject.id, name: effectiveSubject.name } : null,
          attendanceTaken,
          canTakeAttendance: !!effectiveStaff && dateValue === today && !!me && effectiveStaff.id === me.id,
          canChange: editable && !attendanceTaken,
        };
      }),
    };
  }

  async setSubstitution(
    schoolId: string,
    actor: ScheduleActor,
    sectionId: string,
    body: { date: string; periodNumber: number; teacher: string; subjectId?: string; reason?: string },
  ) {
    await this.access.assertCanEditSection(schoolId, actor, sectionId);
    const dateValue = this.dateOrToday(actor, body.date);
    if (dateValue < this.access.today(actor)) throw new ForbiddenException('Past days cannot be changed');
    const eff = await this.effectivePeriod(schoolId, sectionId, dateValue, body.periodNumber);
    if (!eff.period) throw new BadRequestException(`${DAY_NAMES[eff.dayOfWeek]} has no period ${body.periodNumber}`);
    await this.assertNoAttendance(schoolId, sectionId, eff.date, body.periodNumber);

    const { staff } = await this.access.resolveTeacher(schoolId, body.teacher);
    let subjectId = body.subjectId || eff.entry?.subjectId || null;
    if (subjectId) {
      const subject = await this.prisma.subject.findFirst({ where: { id: subjectId, schoolId } });
      if (!subject) throw new BadRequestException('Subject not found');
    }
    if (!subjectId) throw new BadRequestException('This period has no timetable subject. Choose the subject for the day.');
    if (eff.entry && eff.entry.staffId === staff.id && subjectId === eff.entry.subjectId) {
      throw new BadRequestException(`${staff.firstName} ${staff.lastName} already takes this period in the timetable`);
    }
    await this.assertTeacherFree(schoolId, staff, sectionId, eff.dayOfWeek, eff.date, body.periodNumber);

    const saved = await this.prisma.periodSubstitution.upsert({
      where: { sectionId_date_periodNumber: { sectionId, date: eff.date, periodNumber: body.periodNumber } },
      update: { staffId: staff.id, subjectId, reason: body.reason?.trim() || null, originalStaffId: eff.entry?.staffId ?? null, createdById: actor.userId },
      create: {
        schoolId, sectionId, date: eff.date, periodNumber: body.periodNumber, staffId: staff.id, subjectId,
        originalStaffId: eff.entry?.staffId ?? null, reason: body.reason?.trim() || null, createdById: actor.userId,
      },
    });
    await this.access.log(schoolId, actor, 'PERIOD_SUBSTITUTED', 'PeriodSubstitution', saved.id, {
      sectionId, date: dateValue, periodNumber: body.periodNumber,
      from: eff.entry?.staffId ?? null, to: staff.id, subjectId, reason: body.reason ?? null,
    });
    return this.getDaily(schoolId, actor, sectionId, dateValue);
  }

  async clearSubstitution(schoolId: string, actor: ScheduleActor, sectionId: string, dateText: string, periodNumber: number) {
    await this.access.assertCanEditSection(schoolId, actor, sectionId);
    const dateValue = this.dateOrToday(actor, dateText);
    if (dateValue < this.access.today(actor)) throw new ForbiddenException('Past days cannot be changed');
    const date = parseDateOnly(dateValue)!;
    const sub = await this.prisma.periodSubstitution.findUnique({ where: { sectionId_date_periodNumber: { sectionId, date, periodNumber } } });
    if (sub) {
      await this.assertNoAttendance(schoolId, sectionId, date, periodNumber);
      await this.prisma.periodSubstitution.delete({ where: { id: sub.id } });
      await this.access.log(schoolId, actor, 'PERIOD_SUBSTITUTION_REMOVED', 'PeriodSubstitution', sub.id, {
        sectionId, date: dateValue, periodNumber, staffId: sub.staffId,
      });
    }
    return this.getDaily(schoolId, actor, sectionId, dateValue);
  }

  private async assertNoAttendance(schoolId: string, sectionId: string, date: Date, periodNumber: number) {
    const taken = await this.prisma.periodAttendance.findUnique({ where: { sectionId_date_periodNumber: { sectionId, date, periodNumber } } });
    if (taken && taken.schoolId === schoolId) {
      throw new ConflictException('Attendance has already been taken for this period, so its teacher cannot be changed');
    }
  }

  /** The substitute must not be teaching another section at the same time that day. */
  private async assertTeacherFree(
    schoolId: string,
    staff: { id: string; firstName: string; lastName: string },
    sectionId: string,
    dayOfWeek: number,
    date: Date,
    periodNumber: number,
  ) {
    const year = await this.currentYear(schoolId);
    const otherSub = await this.prisma.periodSubstitution.findFirst({
      where: { schoolId, staffId: staff.id, date, periodNumber, NOT: { sectionId } },
      include: { section: { include: { class: true } } },
    });
    if (otherSub) {
      throw new ConflictException(`${staff.firstName} ${staff.lastName} is already covering ${otherSub.section.class.name} ${otherSub.section.name} in period ${periodNumber}`);
    }
    const own = await this.prisma.timetableEntry.findFirst({
      where: { schoolId, academicYearId: year.id, staffId: staff.id, dayOfWeek, periodNumber, NOT: { sectionId } },
      include: { section: { include: { class: true } } },
    });
    if (own) {
      const handedOver = await this.prisma.periodSubstitution.findUnique({
        where: { sectionId_date_periodNumber: { sectionId: own.sectionId, date, periodNumber } },
      });
      if (!handedOver || handedOver.staffId === staff.id) {
        throw new ConflictException(`${staff.firstName} ${staff.lastName} teaches ${own.section.class.name} ${own.section.name} in period ${periodNumber}`);
      }
    }
  }

  // ---------------------------------------------------------------- a teacher's day

  async getMyDay(schoolId: string, actor: ScheduleActor, dateText?: string) {
    const dateValue = this.dateOrToday(actor, dateText);
    const date = parseDateOnly(dateValue)!;
    const dayOfWeek = dayOfWeekOf(dateValue);
    const today = this.access.today(actor);
    const me = await this.access.staffOf(schoolId, actor.userId);
    const base = { date: dateValue, dayOfWeek, dayName: DAY_NAMES[dayOfWeek], isToday: dateValue === today };
    if (!me) return { ...base, periods: [] };
    const year = await this.currentYear(schoolId);

    const [mine, coveringFor, periods] = await Promise.all([
      this.prisma.timetableEntry.findMany({
        where: { schoolId, academicYearId: year.id, staffId: me.id, dayOfWeek },
        include: { subject: true, section: { include: { class: true } } },
      }),
      this.prisma.periodSubstitution.findMany({
        where: { schoolId, staffId: me.id, date },
        include: { subject: true, section: { include: { class: true } } },
      }),
      this.prisma.timetablePeriod.findMany({ where: { schoolId, academicYearId: year.id, dayOfWeek } }),
    ]);
    const handedAway = mine.length
      ? await this.prisma.periodSubstitution.findMany({
          where: { schoolId, date, OR: mine.map((e) => ({ sectionId: e.sectionId, periodNumber: e.periodNumber })) },
          include: { staff: STAFF_WITH_USER },
        })
      : [];
    const sectionIds = [...new Set([...mine.map((e) => e.sectionId), ...coveringFor.map((s) => s.sectionId)])];
    const taken = sectionIds.length
      ? await this.prisma.periodAttendance.findMany({ where: { schoolId, date, sectionId: { in: sectionIds } }, select: { sectionId: true, periodNumber: true } })
      : [];
    const isTaken = (sectionId: string, n: number) => taken.some((t) => t.sectionId === sectionId && t.periodNumber === n);
    const time = (n: number, fallback: { startTime: string; endTime: string }) => {
      const p = periods.find((x) => x.periodNumber === n);
      return { startTime: p?.startTime ?? fallback.startTime, endTime: p?.endTime ?? fallback.endTime };
    };

    const list = [
      ...mine.map((e) => {
        const away = handedAway.find((h) => h.sectionId === e.sectionId && h.periodNumber === e.periodNumber && h.staffId !== me.id);
        return {
          sectionId: e.sectionId,
          className: e.section.class.name,
          sectionName: e.section.name,
          periodNumber: e.periodNumber,
          ...time(e.periodNumber, e),
          subject: { id: e.subject.id, name: e.subject.name },
          isSubstitution: false,
          handedOverTo: away ? this.access.teacherView(away.staff) : null,
          attendanceTaken: isTaken(e.sectionId, e.periodNumber),
          canTakeAttendance: !away && dateValue === today,
        };
      }),
      ...coveringFor
        .filter((s) => !mine.some((e) => e.sectionId === s.sectionId && e.periodNumber === s.periodNumber))
        .map((s) => ({
          sectionId: s.sectionId,
          className: s.section.class.name,
          sectionName: s.section.name,
          periodNumber: s.periodNumber,
          ...time(s.periodNumber, { startTime: '', endTime: '' }),
          subject: s.subject ? { id: s.subject.id, name: s.subject.name } : null,
          isSubstitution: true,
          handedOverTo: null,
          attendanceTaken: isTaken(s.sectionId, s.periodNumber),
          canTakeAttendance: dateValue === today,
        })),
    ].sort((a, b) => (a.startTime || '99').localeCompare(b.startTime || '99') || a.periodNumber - b.periodNumber);

    return { ...base, periods: list };
  }
}
