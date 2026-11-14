import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

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
      select: { amountMinor: true, paidAmountMinor: true, dueAmountMinor: true },
    });

    const totalInvoiced = invoices.reduce((acc, curr) => acc + curr.amountMinor, 0) / 100;
    const totalCollected = invoices.reduce((acc, curr) => acc + curr.paidAmountMinor, 0) / 100;
    const totalDue = invoices.reduce((acc, curr) => acc + curr.dueAmountMinor, 0) / 100;

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
      },
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

  // 1. Student Demographics & Class Distribution Report
  async getStudentReport(schoolId: string) {
    const students = await this.prisma.student.findMany({
      where: { schoolId },
      include: {
        enrollments: {
          where: { status: 'ACTIVE' },
          include: { class: true, section: true },
        },
      },
    });

    const totalStudents = students.length;
    const active = students.filter((s) => s.status === 'ACTIVE').length;
    const alumni = students.filter((s) => s.status === 'ALUMNI').length;
    const transferred = students.filter((s) => s.status === 'TRANSFERRED').length;

    const male = students.filter((s) => s.gender === 'MALE').length;
    const female = students.filter((s) => s.gender === 'FEMALE').length;
    const other = students.filter((s) => s.gender !== 'MALE' && s.gender !== 'FEMALE').length;

    // Distribution by Class
    const classMap = new Map<string, { className: string; studentCount: number; sections: Map<string, number> }>();
    for (const s of students) {
      if (s.status === 'ACTIVE' && s.enrollments.length > 0) {
        const enr = s.enrollments[0];
        const cName = enr.class.name;
        const sName = enr.section.name;
        if (!classMap.has(cName)) {
          classMap.set(cName, { className: cName, studentCount: 0, sections: new Map() });
        }
        const item = classMap.get(cName)!;
        item.studentCount++;
        item.sections.set(sName, (item.sections.get(sName) || 0) + 1);
      }
    }

    const classDistribution = Array.from(classMap.values()).map((c) => ({
      className: c.className,
      studentCount: c.studentCount,
      sections: Array.from(c.sections.entries()).map(([sec, count]) => ({ sectionName: sec, count })),
    }));

    return {
      totalStudents,
      statusBreakdown: { active, alumni, transferred },
      genderBreakdown: { male, female, other },
      classDistribution,
    };
  }

  // 2. Attendance & Condonation Deficiency (<75%) Report
  async getAttendanceReport(schoolId: string, sectionId?: string) {
    const condonationThreshold = Number(process.env.ATTENDANCE_CONDONATION_THRESHOLD || 75);

    const students = await this.prisma.student.findMany({
      where: {
        schoolId,
        status: 'ACTIVE',
        ...(sectionId
          ? {
              enrollments: {
                some: { sectionId, status: 'ACTIVE' },
              },
            }
          : {}),
      },
      include: {
        enrollments: {
          where: { status: 'ACTIVE' },
          include: { class: true, section: true },
        },
        attendanceRecords: true,
      },
    });

    const condonationShortageList: any[] = [];
    let totalPresentSum = 0;
    let totalSessionsSum = 0;

    for (const s of students) {
      const total = s.attendanceRecords.length;
      const present = s.attendanceRecords.filter(
        (r) => r.status === 'PRESENT' || r.status === 'LATE' || r.status === 'HALF_DAY',
      ).reduce((acc, r) => acc + (r.status === 'HALF_DAY' ? 0.5 : 1), 0);

      totalSessionsSum += total;
      totalPresentSum += present;

      const rate = total > 0 ? Math.round((present / total) * 100) : 100;

      if (total > 0 && rate < condonationThreshold) {
        condonationShortageList.push({
          studentId: s.id,
          admissionNo: s.admissionNo,
          fullName: `${s.firstName} ${s.lastName}`,
          className: s.enrollments[0]?.class?.name || 'Unassigned',
          sectionName: s.enrollments[0]?.section?.name || 'Unassigned',
          totalSessions: total,
          attendedSessions: present,
          attendanceRate: rate,
          deficitSessions: Math.ceil((condonationThreshold * total) / 100) - present,
        });
      }
    }

    const overallRate = totalSessionsSum > 0 ? Math.round((totalPresentSum / totalSessionsSum) * 100) : 100;

    return {
      condonationThreshold,
      totalStudentsEvaluated: students.length,
      overallAttendanceRate: overallRate,
      defaulterCount: condonationShortageList.length,
      condonationShortageList: condonationShortageList.sort((a, b) => a.attendanceRate - b.attendanceRate),
    };
  }

  // 3. Examination Performance & Broadsheet Report
  async getExamReport(schoolId: string, examId?: string) {
    const exams = await this.prisma.exam.findMany({
      where: { schoolId },
      orderBy: { startDate: 'desc' },
      include: {
        subjects: {
          include: { subject: true, class: true },
        },
      },
    });

    if (exams.length === 0) {
      return { exams: [], activeExam: null, broadsheet: [] };
    }

    const selectedExam = examId ? exams.find((e) => e.id === examId) || exams[0] : exams[0];

    // Fetch marks for selected exam
    const marks = await this.prisma.mark.findMany({
      where: {
        examSubject: { examId: selectedExam.id },
      },
      include: {
        student: {
          include: {
            enrollments: {
              where: { status: 'ACTIVE' },
              include: { class: true, section: true },
            },
          },
        },
        examSubject: {
          include: { subject: true },
        },
      },
    });

    // Group by student
    const studentMarksMap = new Map<string, { student: any; subjects: any[]; totalObtained: number; totalMax: number }>();
    for (const m of marks) {
      if (!studentMarksMap.has(m.studentId)) {
        studentMarksMap.set(m.studentId, {
          student: {
            id: m.student.id,
            admissionNo: m.student.admissionNo,
            fullName: `${m.student.firstName} ${m.student.lastName}`,
            className: m.student.enrollments[0]?.class?.name || 'N/A',
            sectionName: m.student.enrollments[0]?.section?.name || 'N/A',
          },
          subjects: [],
          totalObtained: 0,
          totalMax: 0,
        });
      }
      const entry = studentMarksMap.get(m.studentId)!;
      entry.subjects.push({
        subjectName: m.examSubject.subject.name,
        subjectCode: m.examSubject.subject.code,
        marksObtained: m.marksObtained,
        maxMarks: m.examSubject.maxMarks,
        passMarks: m.examSubject.passMarks,
        isAbsent: m.isAbsent,
        isPassed: !m.isAbsent && (m.marksObtained || 0) >= m.examSubject.passMarks,
      });
      entry.totalObtained += m.isAbsent ? 0 : m.marksObtained || 0;
      entry.totalMax += m.examSubject.maxMarks;
    }

    const broadsheet = Array.from(studentMarksMap.values()).map((item) => {
      const percentage = item.totalMax > 0 ? Math.round((item.totalObtained / item.totalMax) * 100) : 0;
      const allPassed = item.subjects.every((s) => s.isPassed);
      return {
        ...item.student,
        subjects: item.subjects,
        totalObtained: item.totalObtained,
        totalMax: item.totalMax,
        percentage,
        resultStatus: allPassed ? 'PASS' : 'FAIL',
      };
    }).sort((a, b) => b.percentage - a.percentage);

    // Assign ranks
    broadsheet.forEach((row, idx) => {
      (row as any).rank = idx + 1;
    });

    return {
      exam: {
        id: selectedExam.id,
        name: selectedExam.name,
        term: selectedExam.term,
        status: selectedExam.status,
      },
      availableExams: exams.map((e) => ({ id: e.id, name: e.name, term: e.term, status: e.status })),
      totalCandidates: broadsheet.length,
      passedCandidates: broadsheet.filter((b) => b.resultStatus === 'PASS').length,
      failedCandidates: broadsheet.filter((b) => b.resultStatus === 'FAIL').length,
      broadsheet,
    };
  }

  // 4. Financial & Fee Category Collections Report (SCHOOL, HOSTEL, TRANSPORT)
  async getFeeReport(schoolId: string) {
    const invoices = await this.prisma.invoice.findMany({
      where: { schoolId },
      include: {
        student: {
          include: {
            enrollments: {
              where: { status: 'ACTIVE' },
              include: { class: true, section: true },
            },
          },
        },
        payments: true,
      },
    });

    const categoryStats: Record<string, { invoiced: number; collected: number; due: number }> = {
      SCHOOL: { invoiced: 0, collected: 0, due: 0 },
      HOSTEL: { invoiced: 0, collected: 0, due: 0 },
      TRANSPORT: { invoiced: 0, collected: 0, due: 0 },
    };

    let grandTotalInvoiced = 0;
    let grandTotalCollected = 0;
    let grandTotalDue = 0;

    const defaulters: any[] = [];

    for (const inv of invoices) {
      const cat = inv.category || 'SCHOOL';
      if (!categoryStats[cat]) {
        categoryStats[cat] = { invoiced: 0, collected: 0, due: 0 };
      }

      const invAmount = inv.amountMinor / 100;
      const paidAmount = inv.paidAmountMinor / 100;
      const dueAmount = inv.dueAmountMinor / 100;

      categoryStats[cat].invoiced += invAmount;
      categoryStats[cat].collected += paidAmount;
      categoryStats[cat].due += dueAmount;

      grandTotalInvoiced += invAmount;
      grandTotalCollected += paidAmount;
      grandTotalDue += dueAmount;

      if (inv.dueAmountMinor > 0) {
        defaulters.push({
          studentId: inv.student.id,
          admissionNo: inv.student.admissionNo,
          fullName: `${inv.student.firstName} ${inv.student.lastName}`,
          className: inv.student.enrollments[0]?.class?.name || 'N/A',
          sectionName: inv.student.enrollments[0]?.section?.name || 'N/A',
          invoiceNo: inv.invoiceNo,
          title: inv.title,
          category: inv.category,
          dueDate: inv.dueDate,
          dueAmount,
        });
      }
    }

    // Recent payments with serialized receipt numbers
    const recentPayments = await this.prisma.payment.findMany({
      where: { schoolId },
      orderBy: { createdAt: 'desc' },
      take: 20,
      include: {
        invoice: {
          include: { student: true },
        },
      },
    });

    return {
      grandTotals: {
        invoiced: grandTotalInvoiced,
        collected: grandTotalCollected,
        due: grandTotalDue,
        collectionRate: grandTotalInvoiced > 0 ? Math.round((grandTotalCollected / grandTotalInvoiced) * 100) : 0,
      },
      categories: categoryStats,
      defaulters: defaulters.sort((a, b) => b.dueAmount - a.dueAmount).slice(0, 30),
      recentPayments: recentPayments.map((p) => ({
        id: p.id,
        receiptNo: p.receiptNo,
        amount: p.amountMinor / 100,
        method: p.method,
        createdAt: p.createdAt,
        studentName: `${p.invoice.student.firstName} ${p.invoice.student.lastName}`,
        admissionNo: p.invoice.student.admissionNo,
        invoiceTitle: p.invoice.title,
      })),
    };
  }

  // 5. Faculty Teaching Workload Report
  async getTeacherWorkloadReport(schoolId: string) {
    const staffList = await this.prisma.staff.findMany({
      where: { schoolId, status: 'ACTIVE' },
      include: {
        teacherAssignments: {
          include: { class: true, section: true, subject: true },
        },
        timetableEntries: {
          include: { subject: true, section: { include: { class: true } } },
        },
      },
    });

    return staffList.map((st) => {
      const assignedSubjects = Array.from(new Set(st.teacherAssignments.map((a) => a.subject?.name).filter(Boolean)));
      const assignedClasses = Array.from(
        new Set(st.teacherAssignments.map((a) => `${a.class.name} (${a.section.name})`)),
      );
      const totalWeeklyPeriods = st.timetableEntries.length;

      return {
        staffId: st.id,
        employeeNo: st.employeeNo,
        fullName: `${st.firstName} ${st.lastName}`,
        department: st.department,
        designation: st.designation,
        email: st.email,
        phone: st.phone,
        assignedClasses,
        assignedSubjects,
        totalWeeklyPeriods,
        isClassTeacher: st.teacherAssignments.some((a) => a.isClassTeacher),
      };
    }).sort((a, b) => b.totalWeeklyPeriods - a.totalWeeklyPeriods);
  }

  // 6. Stakeholder Feedback & Sentiment Report
  async getFeedbackReport(schoolId: string) {
    const feedbacks = await this.prisma.feedback.findMany({
      where: { schoolId },
      orderBy: { createdAt: 'desc' },
      include: {
        submitter: {
          select: { firstName: true, lastName: true },
        },
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

    return {
      totalFeedbacks: total,
      averageRating,
      resolutionStatus: { submitted, underReview, resolved },
      byCategory,
      feedbacks: feedbacks.slice(0, 30).map((f) => ({
        id: f.id,
        category: f.category,
        title: f.title,
        content: f.content,
        rating: f.rating,
        status: f.status,
        createdAt: f.createdAt,
        submitterName: f.isAnonymous ? 'Anonymous' : `${f.submitter.firstName} ${f.submitter.lastName}`,
        response: f.response,
        respondedByName: f.respondedByName,
      })),
    };
  }
}
