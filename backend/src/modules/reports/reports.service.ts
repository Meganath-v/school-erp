import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ReportFilterDto, ExportReportDto } from './reports.dto';
import * as XLSX from 'xlsx';

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  async getOverview(schoolId: string) {
    const totalStudents = await this.prisma.student.count({ where: { schoolId, status: 'ACTIVE' } });
    const totalStaff = await this.prisma.staff.count({ where: { schoolId, status: 'ACTIVE' } });
    const totalClasses = await this.prisma.class.count({ where: { schoolId } });
    const totalSections = await this.prisma.section.count({ where: { schoolId } });

    // Invoices sum
    const invoices = await this.prisma.invoice.findMany({
      where: { schoolId },
      select: { amountMinor: true, paidAmountMinor: true, dueAmountMinor: true, status: true },
    });

    const totalInvoiced = invoices.reduce((acc, curr) => acc + curr.amountMinor, 0) / 100;
    const totalCollected = invoices.reduce((acc, curr) => acc + curr.paidAmountMinor, 0) / 100;
    const totalDue = invoices.reduce((acc, curr) => acc + curr.dueAmountMinor, 0) / 100;
    const pendingInvoicesCount = invoices.filter((i) => i.status === 'PENDING' || i.status === 'PARTIALLY_PAID').length;

    // Today Attendance
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todaySessions = await this.prisma.attendanceSession.findMany({
      where: { schoolId, date: today },
      include: { records: true },
    });

    let totalAttendanceRecords = 0;
    let presentAttendanceRecords = 0;
    for (const s of todaySessions) {
      totalAttendanceRecords += s.records.length;
      presentAttendanceRecords += s.records.filter((r) => r.status === 'PRESENT').length;
    }

    const isAttendanceMarkedToday = totalAttendanceRecords > 0;
    const todayAttendanceRate = isAttendanceMarkedToday
      ? Math.round((presentAttendanceRecords / totalAttendanceRecords) * 100)
      : null;

    // Today Fee Collections
    const todayPayments = await this.prisma.payment.findMany({
      where: { schoolId, status: 'SUCCESS', createdAt: { gte: today } },
      select: { amountMinor: true },
    });
    const todayFeeCollected = todayPayments.reduce((acc, curr) => acc + curr.amountMinor, 0) / 100;

    // Recent Receipts
    const recentReceiptsData = await this.prisma.payment.findMany({
      where: { schoolId, status: 'SUCCESS' },
      include: {
        invoice: {
          include: {
            student: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 6,
    });
    const recentReceipts = recentReceiptsData.map((p) => ({
      id: p.id,
      receiptNo: p.receiptNo,
      amount: p.amountMinor / 100,
      method: p.method,
      studentName: p.invoice?.student ? `${p.invoice.student.firstName} ${p.invoice.student.lastName}` : 'Enrolled Student',
      admissionNo: p.invoice?.student?.admissionNo,
      invoiceNo: p.invoice?.invoiceNo,
      createdAt: p.createdAt,
    }));

    // Pending administrative work (pending leaves + pending tasks)
    const pendingLeavesCount = await this.prisma.leaveRequest.count({
      where: { schoolId, status: 'PENDING' },
    });
    const pendingTasksCount = await this.prisma.task.count({
      where: { schoolId, status: 'PENDING' },
    });

    // Exams status
    const publishedExamsCount = await this.prisma.exam.count({
      where: { schoolId, status: 'PUBLISHED' },
    });
    const draftExamsCount = await this.prisma.exam.count({
      where: { schoolId, status: 'DRAFT' },
    });

    // Timetable Workload
    const totalWeeklyPeriods = await this.prisma.timetableEntry.count({
      where: { schoolId },
    });

    // Recent announcements
    const recentAnnouncements = await this.prisma.announcement.findMany({
      where: { schoolId },
      orderBy: { publishedAt: 'desc' },
      take: 4,
    });

    // Recent audit events
    const recentAuditLogs = await this.prisma.auditLog.findMany({
      where: { schoolId },
      orderBy: { timestamp: 'desc' },
      take: 5,
    });

    return {
      stats: {
        totalStudents,
        totalStaff,
        totalClasses,
        totalSections,
        todayAttendanceRate,
        isAttendanceMarkedToday,
        totalInvoiced,
        totalCollected,
        totalDue,
        todayFeeCollected,
        pendingInvoicesCount,
        pendingLeavesCount,
        pendingTasksCount,
        pendingAdminWork: pendingLeavesCount + pendingTasksCount,
        publishedExamsCount,
        draftExamsCount,
        totalWeeklyPeriods,
      },
      recentReceipts,
      recentAnnouncements,
      recentAuditLogs,
    };
  }

  async getAuditLogs(schoolId?: string) {
    return this.prisma.auditLog.findMany({
      where: schoolId ? { schoolId } : {},
      orderBy: { timestamp: 'desc' },
      take: 50,
    });
  }

  // =========================================================================
  // 1. STUDENT STRENGTH REPORT
  // =========================================================================
  async getStudentStrengthReport(schoolId: string, filter?: ReportFilterDto) {
    const where: any = { schoolId };
    if (filter?.status && filter.status !== 'ALL') {
      where.status = filter.status;
    }

    if (filter?.classId || filter?.sectionId) {
      where.enrollments = {
        some: {
          status: 'ACTIVE',
          ...(filter.classId ? { classId: filter.classId } : {}),
          ...(filter.sectionId ? { sectionId: filter.sectionId } : {}),
        },
      };
    }

    const students = await this.prisma.student.findMany({
      where,
      include: {
        enrollments: {
          where: { status: 'ACTIVE' },
          include: { class: true, section: true },
        },
      },
      orderBy: [{ firstName: 'asc' }],
    });

    const totalStudents = students.length;
    const active = students.filter((s) => s.status === 'ACTIVE').length;
    const alumni = students.filter((s) => s.status === 'ALUMNI').length;
    const transferred = students.filter((s) => s.status === 'TRANSFERRED').length;

    const male = students.filter((s) => s.gender === 'MALE').length;
    const female = students.filter((s) => s.gender === 'FEMALE').length;
    const other = students.filter((s) => s.gender !== 'MALE' && s.gender !== 'FEMALE').length;

    // Class and Section Breakdown matrix
    const classMap = new Map<string, { className: string; male: number; female: number; total: number; sections: Map<string, { sectionName: string; male: number; female: number; total: number }> }>();

    for (const s of students) {
      const enr = s.enrollments[0];
      const cName = enr?.class?.name || 'Unassigned';
      const sName = enr?.section?.name || 'General';

      if (!classMap.has(cName)) {
        classMap.set(cName, { className: cName, male: 0, female: 0, total: 0, sections: new Map() });
      }
      const cItem = classMap.get(cName)!;
      cItem.total++;
      if (s.gender === 'MALE') cItem.male++;
      else if (s.gender === 'FEMALE') cItem.female++;

      if (!cItem.sections.has(sName)) {
        cItem.sections.set(sName, { sectionName: sName, male: 0, female: 0, total: 0 });
      }
      const secItem = cItem.sections.get(sName)!;
      secItem.total++;
      if (s.gender === 'MALE') secItem.male++;
      else if (s.gender === 'FEMALE') secItem.female++;
    }

    const rows: any[] = [];
    classMap.forEach((c) => {
      c.sections.forEach((sec) => {
        rows.push({
          className: c.className,
          sectionName: sec.sectionName,
          male: sec.male,
          female: sec.female,
          totalStrength: sec.total,
        });
      });
    });

    const classes = Array.from(classMap.entries()).map(([cName, c]) => ({
      classId: cName,
      className: cName,
      studentCount: c.total,
      total: c.total,
      male: c.male,
      female: c.female,
      other: c.total - (c.male + c.female),
      sections: Array.from(c.sections.entries()).map(([secName, sec]) => ({
        sectionName: secName,
        total: sec.total,
        count: sec.total,
        male: sec.male,
        female: sec.female,
      })),
    }));

    return {
      totalStudents,
      statusBreakdown: { active, alumni, transferred },
      genderBreakdown: { male, female, other },
      classDistribution: classes,
      classes,
      summary: {
        totalStudents,
        active,
        alumni,
        transferred,
        male,
        female,
        other,
      },
      rows,
    };
  }

  // =========================================================================
  // 2. ADMISSION STATISTICS REPORT
  // =========================================================================
  async getAdmissionStatisticsReport(schoolId: string, filter?: ReportFilterDto) {
    const where: any = { schoolId };
    if (filter?.classId) {
      where.enrollments = {
        some: { classId: filter.classId, status: 'ACTIVE' },
      };
    }
    if (filter?.startDate || filter?.endDate) {
      where.createdAt = {};
      if (filter.startDate) where.createdAt.gte = new Date(filter.startDate);
      if (filter.endDate) where.createdAt.lte = new Date(filter.endDate + 'T23:59:59.999Z');
    }

    const students = await this.prisma.student.findMany({
      where,
      include: {
        enrollments: {
          where: { status: 'ACTIVE' },
          include: { class: true, section: true },
        },
        studentGuardians: {
          include: { guardian: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const rows = students.map((s) => ({
      admissionNo: s.admissionNo,
      fullName: `${s.firstName} ${s.lastName}`,
      className: s.enrollments[0]?.class?.name || 'Unassigned',
      sectionName: s.enrollments[0]?.section?.name || 'Unassigned',
      gender: s.gender,
      dob: s.dob ? new Date(s.dob).toLocaleDateString() : 'N/A',
      admissionDate: new Date(s.createdAt).toLocaleDateString(),
      guardianName: s.studentGuardians[0]?.guardian?.name || 'N/A',
      guardianPhone: s.studentGuardians[0]?.guardian?.phone || 'N/A',
      status: s.status,
    }));

    return {
      summary: {
        totalAdmissions: students.length,
        activeAdmissions: students.filter((s) => s.status === 'ACTIVE').length,
        transferredOut: students.filter((s) => s.status === 'TRANSFERRED').length,
      },
      rows,
    };
  }

  // =========================================================================
  // 3. STAFF DIRECTORY REPORT
  // =========================================================================
  async getStaffDirectoryReport(schoolId: string, filter?: ReportFilterDto) {
    const where: any = { schoolId };
    if (filter?.department && filter.department !== 'ALL') {
      where.department = filter.department;
    }
    if (filter?.status && filter.status !== 'ALL') {
      where.status = filter.status;
    }
    if (filter?.search && filter.search.trim()) {
      const s = filter.search.trim();
      where.OR = [
        { firstName: { contains: s, mode: 'insensitive' } },
        { lastName: { contains: s, mode: 'insensitive' } },
        { email: { contains: s, mode: 'insensitive' } },
        { department: { contains: s, mode: 'insensitive' } },
        { designation: { contains: s, mode: 'insensitive' } },
      ];
    }

    const staffList = await this.prisma.staff.findMany({
      where,
      include: {
        teacherAssignments: {
          include: { class: true, section: true, subject: true },
        },
      },
      orderBy: { firstName: 'asc' },
    });

    const rows = staffList.map((st) => {
      const subjects = Array.from(new Set(st.teacherAssignments.map((a) => a.subject?.name).filter(Boolean))).join(', ') || 'General';
      const classes = Array.from(new Set(st.teacherAssignments.map((a) => `${a.class.name}-${a.section.name}`))).join(', ') || 'None';

      return {
        employeeNo: st.employeeNo,
        fullName: `${st.firstName} ${st.lastName}`,
        department: st.department,
        designation: st.designation,
        email: st.email,
        phone: st.phone,
        joiningDate: new Date(st.joiningDate).toLocaleDateString(),
        assignedClasses: classes,
        assignedSubjects: subjects,
        status: st.status,
      };
    });

    const departments: Record<string, number> = {};
    for (const st of staffList) {
      departments[st.department] = (departments[st.department] || 0) + 1;
    }

    return {
      summary: {
        totalStaff: staffList.length,
        activeFaculty: staffList.filter((s) => s.status === 'ACTIVE').length,
        departments,
      },
      rows,
    };
  }

  // =========================================================================
  // 4. ATTENDANCE SUMMARY REPORT
  // =========================================================================
  async getAttendanceSummaryReport(schoolId: string, filter?: ReportFilterDto) {
    const sessionWhere: any = { schoolId };
    if (filter?.classId) sessionWhere.classId = filter.classId;
    if (filter?.sectionId) sessionWhere.sectionId = filter.sectionId;
    if (filter?.startDate || filter?.endDate) {
      sessionWhere.date = {};
      if (filter.startDate) sessionWhere.date.gte = new Date(filter.startDate);
      if (filter.endDate) sessionWhere.date.lte = new Date(filter.endDate + 'T23:59:59.999Z');
    }

    const sessions = await this.prisma.attendanceSession.findMany({
      where: sessionWhere,
      include: {
        section: {
          include: { class: true },
        },
        records: true,
      },
      orderBy: { date: 'desc' },
    });

    const classSectionMap = new Map<string, { className: string; sectionName: string; sessionsCount: number; present: number; absent: number; totalRecords: number }>();

    let grandTotalSessions = 0;
    let grandPresent = 0;
    let grandAbsent = 0;

    for (const sess of sessions) {
      grandTotalSessions++;
      const cName = sess.section?.class?.name || 'Unassigned';
      const sName = sess.section?.name || 'General';
      const key = `${cName} - ${sName}`;
      if (!classSectionMap.has(key)) {
        classSectionMap.set(key, {
          className: cName,
          sectionName: sName,
          sessionsCount: 0,
          present: 0,
          absent: 0,
          totalRecords: 0,
        });
      }
      const entry = classSectionMap.get(key)!;
      entry.sessionsCount++;

      for (const rec of sess.records) {
        entry.totalRecords++;
        if (rec.status === 'PRESENT' || rec.status === 'LATE' || rec.status === 'EXCUSED') {
          entry.present++;
          grandPresent++;
        } else {
          entry.absent++;
          grandAbsent++;
        }
      }
    }

    const rows = Array.from(classSectionMap.values()).map((item) => {
      const rate = item.totalRecords > 0 ? Math.round((item.present / item.totalRecords) * 100) : 100;
      return {
        className: item.className,
        sectionName: item.sectionName,
        sessionsConducted: item.sessionsCount,
        totalRecords: item.totalRecords,
        presentRecords: item.present,
        absentRecords: item.absent,
        attendanceRate: rate,
      };
    });

    const totalRecords = grandPresent + grandAbsent;
    const overallRate = totalRecords > 0 ? Math.round((grandPresent / totalRecords) * 100) : 100;

    return {
      condonationThreshold: 75,
      overallRate,
      conductedSessions: grandTotalSessions,
      summary: {
        totalSessionsConducted: grandTotalSessions,
        totalRecordsLogged: totalRecords,
        presentRecords: grandPresent,
        absentRecords: grandAbsent,
        overallAttendanceRate: overallRate,
        condonationThreshold: 75,
      },
      rows,
    };
  }

  // =========================================================================
  // 5. ATTENDANCE DEFAULTERS REPORT (< 75% CONDONATION THRESHOLD)
  // =========================================================================
  async getAttendanceDefaultersReport(schoolId: string, filter?: ReportFilterDto) {
    const threshold = filter?.threshold ? Number(filter.threshold) : 75;

    const studentWhere: any = { schoolId, status: 'ACTIVE' };
    if (filter?.classId || filter?.sectionId) {
      studentWhere.enrollments = {
        some: {
          status: 'ACTIVE',
          ...(filter.classId ? { classId: filter.classId } : {}),
          ...(filter.sectionId ? { sectionId: filter.sectionId } : {}),
        },
      };
    }

    const students = await this.prisma.student.findMany({
      where: studentWhere,
      include: {
        enrollments: {
          where: { status: 'ACTIVE' },
          include: { class: true, section: true },
        },
        studentGuardians: {
          include: { guardian: true },
        },
        attendanceRecords: {
          include: { session: true },
        },
      },
    });

    const rows: any[] = [];
    let evaluatedStudents = 0;

    for (const s of students) {
      let filteredRecords = s.attendanceRecords;
      if (filter?.startDate) {
        filteredRecords = filteredRecords.filter((r) => new Date(r.session.date) >= new Date(filter.startDate!));
      }
      if (filter?.endDate) {
        filteredRecords = filteredRecords.filter((r) => new Date(r.session.date) <= new Date(filter.endDate! + 'T23:59:59.999Z'));
      }

      const total = filteredRecords.length;
      if (total >= 3) {
        evaluatedStudents++;
        const present = filteredRecords.filter((r) => r.status === 'PRESENT' || r.status === 'LATE' || r.status === 'EXCUSED').length;
        const rate = Math.round((present / total) * 100);

        if (rate < threshold) {
          const deficit = Math.max(1, Math.ceil((threshold * total) / 100) - present);
          rows.push({
            admissionNo: s.admissionNo,
            fullName: `${s.firstName} ${s.lastName}`,
            className: s.enrollments[0]?.class?.name || 'Unassigned',
            sectionName: s.enrollments[0]?.section?.name || 'Unassigned',
            totalSessions: total,
            attendedSessions: present,
            attendanceRate: rate,
            deficitSessions: deficit,
            guardianName: s.studentGuardians[0]?.guardian?.name || 'N/A',
            guardianPhone: s.studentGuardians[0]?.guardian?.phone || 'N/A',
          });
        }
      }
    }

    return {
      summary: {
        threshold,
        totalStudentsEvaluated: evaluatedStudents,
        defaulterCount: rows.length,
        defaulterPercentage: evaluatedStudents > 0 ? Math.round((rows.length / evaluatedStudents) * 100) : 0,
      },
      rows: rows.sort((a, b) => a.attendanceRate - b.attendanceRate),
    };
  }

  // =========================================================================
  // 6. EXAMINATION PERFORMANCE REPORT
  // =========================================================================
  async getExamPerformanceReport(schoolId: string, filter?: ReportFilterDto) {
    const exams = await this.prisma.exam.findMany({
      where: {
        schoolId,
        ...(filter?.examId ? { id: filter.examId } : {}),
      },
      include: {
        subjects: {
          include: {
            subject: true,
            class: true,
            marks: true,
          },
        },
      },
      orderBy: { startDate: 'desc' },
    });

    if (exams.length === 0) {
      return { summary: { totalExams: 0, candidatesEvaluated: 0, overallPassRate: 0 }, rows: [] };
    }

    const selectedExam = filter?.examId ? exams.find((e) => e.id === filter.examId) || exams[0] : exams[0];

    const rows: any[] = [];
    let totalExamCandidates = 0;
    let totalExamPassed = 0;

    for (const es of selectedExam.subjects) {
      if (filter?.classId && es.classId !== filter.classId) continue;
      if (filter?.subjectId && es.subjectId !== filter.subjectId) continue;

      const marks = es.marks;
      const candidates = marks.length;
      totalExamCandidates += candidates;

      const passed = marks.filter((m) => !m.isAbsent && (m.marksObtained || 0) >= es.passMarks).length;
      totalExamPassed += passed;

      const scores = marks.filter((m) => !m.isAbsent && m.marksObtained !== null).map((m) => m.marksObtained!);
      const highest = scores.length > 0 ? Math.max(...scores) : 0;
      const lowest = scores.length > 0 ? Math.min(...scores) : 0;
      const average = scores.length > 0 ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length) : 0;
      const passRate = candidates > 0 ? Math.round((passed / candidates) * 100) : 0;

      rows.push({
        examName: selectedExam.name,
        className: es.class.name,
        subjectName: es.subject.name,
        maxMarks: es.maxMarks,
        passMarks: es.passMarks,
        candidatesAppeared: candidates,
        passedCandidates: passed,
        failedCandidates: candidates - passed,
        highestScore: highest,
        lowestScore: lowest,
        averageScore: average,
        passRate,
      });
    }

    const overallPassRate = totalExamCandidates > 0 ? Math.round((totalExamPassed / totalExamCandidates) * 100) : 0;

    return {
      summary: {
        examName: selectedExam.name,
        term: selectedExam.term,
        totalSubjectsEvaluated: rows.length,
        totalCandidates: totalExamCandidates,
        totalPassed: totalExamPassed,
        overallPassRate,
      },
      rows,
    };
  }

  // =========================================================================
  // 7. CLASS BROADSHEET REPORT
  // =========================================================================
  async getClassBroadsheetReport(schoolId: string, filter?: ReportFilterDto) {
    const exams = await this.prisma.exam.findMany({
      where: { schoolId },
      orderBy: { startDate: 'desc' },
      include: {
        subjects: { include: { subject: true, class: true } },
      },
    });

    if (exams.length === 0) {
      return { summary: { totalCandidates: 0, passed: 0, failed: 0 }, subjects: [], rows: [] };
    }

    const selectedExam = filter?.examId ? exams.find((e) => e.id === filter.examId) || exams[0] : exams[0];

    const markWhere: any = {
      examSubject: { examId: selectedExam.id },
    };
    if (filter?.classId) markWhere.examSubject.classId = filter.classId;

    const marks = await this.prisma.mark.findMany({
      where: markWhere,
      include: {
        student: {
          include: {
            enrollments: {
              where: { status: 'ACTIVE' },
              include: { class: true, section: true },
            },
          },
        },
        examSubject: { include: { subject: true, class: true } },
      },
    });

    const studentMap = new Map<string, { admissionNo: string; studentName: string; className: string; sectionName: string; subjects: Record<string, number | string>; totalObtained: number; totalMax: number; allPassed: boolean }>();

    const distinctSubjects = new Set<string>();

    for (const m of marks) {
      distinctSubjects.add(m.examSubject.subject.name);
      if (!studentMap.has(m.studentId)) {
        studentMap.set(m.studentId, {
          admissionNo: m.student.admissionNo,
          studentName: `${m.student.firstName} ${m.student.lastName}`,
          className: m.student.enrollments[0]?.class?.name || 'N/A',
          sectionName: m.student.enrollments[0]?.section?.name || 'N/A',
          subjects: {},
          totalObtained: 0,
          totalMax: 0,
          allPassed: true,
        });
      }
      const entry = studentMap.get(m.studentId)!;
      const subName = m.examSubject.subject.name;
      const val = m.isAbsent ? 'AB' : (m.marksObtained ?? 0);
      entry.subjects[subName] = val;
      if (!m.isAbsent) {
        entry.totalObtained += m.marksObtained || 0;
        if ((m.marksObtained || 0) < m.examSubject.passMarks) {
          entry.allPassed = false;
        }
      } else {
        entry.allPassed = false;
      }
      entry.totalMax += m.examSubject.maxMarks;
    }

    const rows = Array.from(studentMap.values()).map((s) => {
      const percentage = s.totalMax > 0 ? Math.round((s.totalObtained / s.totalMax) * 100) : 0;
      return {
        admissionNo: s.admissionNo,
        studentName: s.studentName,
        className: s.className,
        sectionName: s.sectionName,
        ...s.subjects,
        totalObtained: s.totalObtained,
        totalMax: s.totalMax,
        percentage,
        result: s.allPassed ? 'PASS' : 'FAIL',
      };
    }).sort((a, b) => b.percentage - a.percentage);

    rows.forEach((r, idx) => {
      (r as any).rank = idx + 1;
    });

    const passedCount = rows.filter((r) => r.result === 'PASS').length;

    return {
      summary: {
        examName: selectedExam.name,
        term: selectedExam.term,
        totalCandidates: rows.length,
        passed: passedCount,
        failed: rows.length - passedCount,
        passPercentage: rows.length > 0 ? Math.round((passedCount / rows.length) * 100) : 0,
      },
      subjectColumns: Array.from(distinctSubjects),
      rows,
    };
  }

  // =========================================================================
  // 8. STUDENT REPORT CARD
  // =========================================================================
  async getStudentReportCard(schoolId: string, studentId: string, filter?: ReportFilterDto) {
    const student = await this.prisma.student.findFirst({
      where: { id: studentId, schoolId },
      include: {
        enrollments: {
          where: { status: 'ACTIVE' },
          include: { class: true, section: true },
        },
        studentGuardians: {
          include: { guardian: true },
        },
      },
    });

    if (!student) {
      throw new NotFoundException(`Student ${studentId} not found`);
    }

    const marks = await this.prisma.mark.findMany({
      where: {
        studentId,
        ...(filter?.examId ? { examSubject: { examId: filter.examId } } : {}),
      },
      include: {
        examSubject: {
          include: { subject: true, exam: true },
        },
      },
    });

    let totalObtained = 0;
    let totalMax = 0;
    let allPassed = true;

    const subjects = marks.map((m) => {
      const obtained = m.isAbsent ? 0 : m.marksObtained || 0;
      const isPass = !m.isAbsent && obtained >= m.examSubject.passMarks;
      if (!isPass) allPassed = false;
      totalObtained += obtained;
      totalMax += m.examSubject.maxMarks;

      const pct = m.examSubject.maxMarks > 0 ? Math.round((obtained / m.examSubject.maxMarks) * 100) : 0;
      let grade = 'F';
      if (pct >= 90) grade = 'A+';
      else if (pct >= 80) grade = 'A';
      else if (pct >= 70) grade = 'B';
      else if (pct >= 60) grade = 'C';
      else if (pct >= 40) grade = 'D';

      return {
        subjectName: m.examSubject.subject.name,
        subjectCode: m.examSubject.subject.code,
        examName: m.examSubject.exam.name,
        marksObtained: m.isAbsent ? 'Absent' : obtained,
        maxMarks: m.examSubject.maxMarks,
        passMarks: m.examSubject.passMarks,
        percentage: pct,
        grade,
        result: isPass ? 'PASS' : 'FAIL',
      };
    });

    const percentage = totalMax > 0 ? Math.round((totalObtained / totalMax) * 100) : 0;

    return {
      student: {
        id: student.id,
        admissionNo: student.admissionNo,
        fullName: `${student.firstName} ${student.lastName}`,
        className: student.enrollments[0]?.class?.name || 'N/A',
        sectionName: student.enrollments[0]?.section?.name || 'N/A',
        guardianName: student.studentGuardians[0]?.guardian?.name || 'N/A',
        guardianPhone: student.studentGuardians[0]?.guardian?.phone || 'N/A',
      },
      summary: {
        totalObtained,
        totalMax,
        percentage,
        overallResult: subjects.length > 0 && allPassed ? 'PASS' : (subjects.length === 0 ? 'NO_MARKS' : 'FAIL'),
      },
      subjects,
    };
  }

  // =========================================================================
  // 9. FEE COLLECTION REPORT
  // =========================================================================
  async getFeeCollectionReport(schoolId: string, filter?: ReportFilterDto) {
    const where: any = { schoolId, status: 'SUCCESS' };

    if (filter?.category && filter.category !== 'ALL') {
      where.invoice = { category: filter.category };
    }

    if (filter?.startDate || filter?.endDate) {
      where.createdAt = {};
      if (filter.startDate) where.createdAt.gte = new Date(filter.startDate);
      if (filter.endDate) where.createdAt.lte = new Date(filter.endDate + 'T23:59:59.999Z');
    }

    const payments = await this.prisma.payment.findMany({
      where,
      include: {
        invoice: {
          include: {
            student: {
              include: {
                enrollments: {
                  where: { status: 'ACTIVE' },
                  include: { class: true, section: true },
                },
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    let totalCollected = 0;
    const byMethod: Record<string, number> = { CASH: 0, CHEQUE: 0, BANK_TRANSFER: 0, UPI: 0 };
    const byCategory: Record<string, number> = { SCHOOL: 0, HOSTEL: 0, TRANSPORT: 0 };

    const rows = payments.map((p) => {
      const amt = p.amountMinor / 100;
      totalCollected += amt;
      byMethod[p.method] = (byMethod[p.method] || 0) + amt;

      const cat = p.invoice?.category || 'SCHOOL';
      byCategory[cat] = (byCategory[cat] || 0) + amt;

      return {
        receiptNo: p.receiptNo,
        paymentDate: new Date(p.createdAt).toLocaleDateString(),
        studentName: p.invoice?.student ? `${p.invoice.student.firstName} ${p.invoice.student.lastName}` : 'N/A',
        admissionNo: p.invoice?.student?.admissionNo || 'N/A',
        className: p.invoice?.student?.enrollments[0]?.class?.name || 'N/A',
        sectionName: p.invoice?.student?.enrollments[0]?.section?.name || 'N/A',
        invoiceNo: p.invoice?.invoiceNo || 'N/A',
        category: cat,
        method: p.method,
        amount: amt,
      };
    });

    const categories: Record<string, { invoiced: number; collected: number; due: number }> = {
      SCHOOL: { invoiced: 0, collected: byCategory['SCHOOL'] || 0, due: 0 },
      HOSTEL: { invoiced: 0, collected: byCategory['HOSTEL'] || 0, due: 0 },
      TRANSPORT: { invoiced: 0, collected: byCategory['TRANSPORT'] || 0, due: 0 },
    };

    return {
      totalCollected,
      receiptsCount: payments.length,
      paymentModeBreakdown: byMethod,
      categories,
      summary: {
        totalReceiptsCount: payments.length,
        totalCollectedAmount: totalCollected,
        byMethod,
        byCategory,
        categories,
      },
      rows,
    };
  }

  // =========================================================================
  // 10. OUTSTANDING FEE BALANCES REPORT
  // =========================================================================
  async getOutstandingFeesReport(schoolId: string, filter?: ReportFilterDto) {
    const where: any = { schoolId, dueAmountMinor: { gt: 0 } };

    if (filter?.category && filter.category !== 'ALL') {
      where.category = filter.category;
    }

    if (filter?.classId || filter?.sectionId) {
      where.student = {
        enrollments: {
          some: {
            status: 'ACTIVE',
            ...(filter.classId ? { classId: filter.classId } : {}),
            ...(filter.sectionId ? { sectionId: filter.sectionId } : {}),
          },
        },
      };
    }

    const invoices = await this.prisma.invoice.findMany({
      where,
      include: {
        student: {
          include: {
            enrollments: {
              where: { status: 'ACTIVE' },
              include: { class: true, section: true },
            },
            studentGuardians: { include: { guardian: true } },
          },
        },
      },
      orderBy: { dueAmountMinor: 'desc' },
    });

    let totalOutstanding = 0;
    let totalBilled = 0;
    let totalCollected = 0;

    const rows = invoices.map((inv) => {
      const billed = inv.amountMinor / 100;
      const paid = inv.paidAmountMinor / 100;
      const due = inv.dueAmountMinor / 100;

      totalBilled += billed;
      totalCollected += paid;
      totalOutstanding += due;

      return {
        invoiceNo: inv.invoiceNo,
        studentName: `${inv.student.firstName} ${inv.student.lastName}`,
        admissionNo: inv.student.admissionNo,
        className: inv.student.enrollments[0]?.class?.name || 'N/A',
        sectionName: inv.student.enrollments[0]?.section?.name || 'N/A',
        category: inv.category,
        totalBilled: billed,
        totalPaid: paid,
        balanceDue: due,
        dueDate: new Date(inv.dueDate).toLocaleDateString(),
        guardianPhone: inv.student.studentGuardians[0]?.guardian?.phone || 'N/A',
        status: inv.status,
      };
    });

    return {
      summary: {
        totalOutstandingCount: invoices.length,
        totalBilled,
        totalCollected,
        totalOutstandingDue: totalOutstanding,
      },
      rows,
    };
  }

  // =========================================================================
  // 11. TEACHER WORKLOAD REPORT
  // =========================================================================
  async getTeacherWorkloadReport(schoolId: string, filter?: ReportFilterDto) {
    const where: any = { schoolId, status: 'ACTIVE' };
    if (filter?.department && filter.department !== 'ALL') {
      where.department = filter.department;
    }
    if (filter?.staffId) {
      where.id = filter.staffId;
    }

    const staffList = await this.prisma.staff.findMany({
      where,
      include: {
        teacherAssignments: {
          include: { class: true, section: true, subject: true },
        },
        timetableEntries: true,
      },
    });

    let grandWeeklyPeriods = 0;

    const rows = staffList.map((st) => {
      const subjects = Array.from(new Set(st.teacherAssignments.map((a) => a.subject?.name).filter(Boolean))).join(', ') || 'None';
      const classes = Array.from(new Set(st.teacherAssignments.map((a) => `${a.class.name} (${a.section.name})`))).join(', ') || 'None';
      const periods = st.timetableEntries.length;
      grandWeeklyPeriods += periods;

      return {
        employeeNo: st.employeeNo,
        fullName: `${st.firstName} ${st.lastName}`,
        department: st.department,
        designation: st.designation,
        assignedClasses: classes,
        assignedSubjects: subjects,
        totalWeeklyPeriods: periods,
        isClassTeacher: st.teacherAssignments.some((a) => a.isClassTeacher) ? 'YES' : 'NO',
      };
    }).sort((a, b) => b.totalWeeklyPeriods - a.totalWeeklyPeriods);

    const avgPeriods = staffList.length > 0 ? Math.round(grandWeeklyPeriods / staffList.length) : 0;

    return {
      summary: {
        totalFacultyEvaluated: staffList.length,
        grandTotalWeeklyPeriods: grandWeeklyPeriods,
        averagePeriodsPerFaculty: avgPeriods,
      },
      rows,
    };
  }

  // =========================================================================
  // 12. ASSIGNMENT PERFORMANCE REPORT
  // =========================================================================
  async getAssignmentPerformanceReport(schoolId: string, filter?: ReportFilterDto) {
    const where: any = { schoolId };
    if (filter?.classId) where.classId = filter.classId;
    if (filter?.sectionId) where.sectionId = filter.sectionId;
    if (filter?.subjectId) where.subjectId = filter.subjectId;

    const assignments = await this.prisma.assignment.findMany({
      where,
      include: {
        subject: true,
        class: true,
        section: true,
        submissions: true,
      },
      orderBy: { dueDate: 'desc' },
    });

    let totalSubmissionsSum = 0;
    let totalEnrolledSum = 0;

    const rows: any[] = [];

    for (const a of assignments) {
      const totalEnrolled = await this.prisma.enrollment.count({
        where: { classId: a.classId, sectionId: a.sectionId, status: 'ACTIVE' },
      });

      const submissionsCount = a.submissions.length;
      totalSubmissionsSum += submissionsCount;
      totalEnrolledSum += totalEnrolled;

      const subRate = totalEnrolled > 0 ? Math.round((submissionsCount / totalEnrolled) * 100) : 0;
      const graded = a.submissions.filter((s) => s.marksObtained !== null);
      const avgScore = graded.length > 0
        ? Math.round(graded.reduce((acc, curr) => acc + (curr.marksObtained || 0), 0) / graded.length)
        : null;

      rows.push({
        title: a.title,
        subjectName: a.subject.name,
        className: a.class.name,
        sectionName: a.section.name,
        dueDate: new Date(a.dueDate).toLocaleDateString(),
        maxMarks: a.maxMarks,
        totalEnrolled,
        submissionsReceived: submissionsCount,
        submissionRate: subRate,
        gradedSubmissions: graded.length,
        averageMarks: avgScore !== null ? avgScore : 'Ungraded',
        status: a.status,
      });
    }

    const overallRate = totalEnrolledSum > 0 ? Math.round((totalSubmissionsSum / totalEnrolledSum) * 100) : 0;

    return {
      summary: {
        totalAssignmentsEvaluated: assignments.length,
        totalExpectedSubmissions: totalEnrolledSum,
        totalReceivedSubmissions: totalSubmissionsSum,
        overallSubmissionRate: overallRate,
      },
      rows,
    };
  }

  // =========================================================================
  // 13. FEEDBACK RESOLUTION REPORT
  // =========================================================================
  async getFeedbackReport(schoolId: string, filter?: ReportFilterDto) {
    const where: any = { schoolId };
    if (filter?.category && filter.category !== 'ALL') where.category = filter.category;
    if (filter?.status && filter.status !== 'ALL') where.status = filter.status;
    if (filter?.startDate || filter?.endDate) {
      where.createdAt = {};
      if (filter.startDate) where.createdAt.gte = new Date(filter.startDate);
      if (filter.endDate) where.createdAt.lte = new Date(filter.endDate + 'T23:59:59.999Z');
    }

    const feedbacks = await this.prisma.feedback.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        submitter: { select: { firstName: true, lastName: true } },
      },
    });

    const total = feedbacks.length;
    const resolved = feedbacks.filter((f) => f.status === 'RESOLVED').length;
    const underReview = feedbacks.filter((f) => f.status === 'UNDER_REVIEW').length;
    const submitted = feedbacks.filter((f) => f.status === 'SUBMITTED').length;

    const ratedFeedbacks = feedbacks.filter((f) => f.rating !== null && f.rating !== undefined);
    const averageRating = ratedFeedbacks.length > 0
      ? Number((ratedFeedbacks.reduce((acc, curr) => acc + (curr.rating || 0), 0) / ratedFeedbacks.length).toFixed(1))
      : null;

    const byCategory: Record<string, number> = {};
    for (const f of feedbacks) {
      byCategory[f.category] = (byCategory[f.category] || 0) + 1;
    }

    const rows = feedbacks.map((f) => ({
      feedbackId: f.id.substring(0, 8),
      date: new Date(f.createdAt).toLocaleDateString(),
      category: f.category,
      title: f.title,
      submitterName: f.isAnonymous ? 'Anonymous' : `${f.submitter.firstName} ${f.submitter.lastName}`,
      rating: f.rating ? `${f.rating} ★` : 'N/A',
      status: f.status,
      respondedBy: f.respondedByName || 'Pending',
    }));

    const resRate = total > 0 ? Math.round((resolved / total) * 100) : 0;

    return {
      totalFeedbacks: total,
      averageRating: averageRating ?? 0,
      resolutionRate: resRate,
      byCategory,
      summary: {
        totalFeedbacks: total,
        resolvedCount: resolved,
        underReviewCount: underReview,
        pendingCount: submitted,
        resolutionRate: resRate,
        averageRating,
        byCategory,
      },
      rows,
    };
  }

  // =========================================================================
  // UNIVERSAL EXPORT ENGINE (EXCEL & CSV)
  // =========================================================================
  async exportReport(schoolId: string, query: ExportReportDto) {
    let reportData: { summary?: any; rows?: any[] } = {};

    const normalizedType = (query.reportType || '').toLowerCase().replace(/_/g, '-');

    switch (normalizedType) {
      case 'student-strength':
        reportData = await this.getStudentStrengthReport(schoolId, query);
        break;
      case 'admissions':
        reportData = await this.getAdmissionStatisticsReport(schoolId, query);
        break;
      case 'staff-directory':
        reportData = await this.getStaffDirectoryReport(schoolId, query);
        break;
      case 'attendance-summary':
        reportData = await this.getAttendanceSummaryReport(schoolId, query);
        break;
      case 'attendance-defaulters':
        reportData = await this.getAttendanceDefaultersReport(schoolId, query);
        break;
      case 'exam-performance':
        reportData = await this.getExamPerformanceReport(schoolId, query);
        break;
      case 'class-broadsheet':
        reportData = await this.getClassBroadsheetReport(schoolId, query);
        break;
      case 'student-report-card':
        reportData = await this.getStudentReportCard(schoolId, query.studentId || '', query);
        break;
      case 'fee-collections':
        reportData = await this.getFeeCollectionReport(schoolId, query);
        break;
      case 'outstanding-fees':
        reportData = await this.getOutstandingFeesReport(schoolId, query);
        break;
      case 'teacher-workload':
        reportData = await this.getTeacherWorkloadReport(schoolId, query);
        break;
      case 'assignment-performance':
        reportData = await this.getAssignmentPerformanceReport(schoolId, query);
        break;
      case 'feedback-resolution':
        reportData = await this.getFeedbackReport(schoolId, query);
        break;
      default:
        throw new NotFoundException(`Unknown report type: ${query.reportType}`);
    }

    const rows = reportData.rows || [];
    const format = query.format === 'csv' ? 'csv' : 'excel';

    const worksheet = XLSX.utils.json_to_sheet(rows.length > 0 ? rows : [{ Status: 'No records found matching filters' }]);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Report');

    const buffer = XLSX.write(workbook, {
      type: 'buffer',
      bookType: format === 'csv' ? 'csv' : 'xlsx',
    });

    const timestamp = new Date().toISOString().split('T')[0];
    const filename = `${query.reportType}_${timestamp}.${format === 'csv' ? 'csv' : 'xlsx'}`;
    const mimeType = format === 'csv' ? 'text/csv' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

    return {
      buffer,
      filename,
      mimeType,
      summary: reportData.summary,
    };
  }
}
