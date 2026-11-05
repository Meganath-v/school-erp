import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ParentService {
  constructor(private prisma: PrismaService) {}

  async verifyParentChildLink(userId: string, studentId: string, schoolId: string): Promise<boolean> {
    const guardian = await this.prisma.guardian.findFirst({
      where: {
        userId,
        schoolId,
        students: {
          some: { studentId },
        },
      },
    });
    return !!guardian;
  }

  async getMyChildren(userId: string, schoolId: string) {
    const guardians = await this.prisma.guardian.findMany({
      where: { userId, schoolId },
      include: {
        students: {
          include: {
            student: {
              include: {
                school: true,
                enrollments: {
                  where: { status: 'ACTIVE' },
                  include: { class: true, section: true, academicYear: true },
                },
                attendanceRecords: true,
              },
            },
          },
        },
      },
    });

    const children: any[] = [];
    const seenStudentIds = new Set<string>();

    for (const g of guardians) {
      for (const sg of g.students) {
        const s = sg.student;
        if (seenStudentIds.has(s.id)) continue;
        seenStudentIds.add(s.id);

        const totalSessions = s.attendanceRecords.length;
        const presentSessions = s.attendanceRecords.filter(
          (r) => r.status === 'PRESENT' || r.status === 'EXCUSED' || r.status === 'LATE',
        ).length;
        const attendancePct = totalSessions > 0 ? Math.round((presentSessions / totalSessions) * 100) : 95;

        children.push({
          id: s.id,
          admissionNo: s.admissionNo,
          firstName: s.firstName,
          lastName: s.lastName,
          fullName: `${s.firstName} ${s.lastName}`,
          dob: s.dob,
          gender: s.gender,
          bloodGroup: s.bloodGroup,
          relationship: sg.relationship,
          isPrimaryGuardian: sg.isPrimary,
          canAccessPortal: sg.canAccessPortal,
          schoolId: s.schoolId,
          schoolName: s.school.name,
          currentClass: s.enrollments[0]?.class?.name || 'Grade 10',
          currentSection: s.enrollments[0]?.section?.name || 'Section A',
          classId: s.enrollments[0]?.classId,
          sectionId: s.enrollments[0]?.sectionId,
          academicYear: s.enrollments[0]?.academicYear?.name || '2026-2027',
          attendancePercentage: attendancePct,
          isAttendanceRisk: attendancePct < 75,
        });
      }
    }

    return children;
  }

  async getChildAssessments(userId: string, studentId: string, schoolId: string) {
    const isLinked = await this.verifyParentChildLink(userId, studentId, schoolId);
    if (!isLinked) {
      throw new ForbiddenException('Access denied: You are not authorized to view records for this student (PAR-02).');
    }

    // Published assessments only (ASM-02)
    const marks = await this.prisma.mark.findMany({
      where: {
        studentId,
        examSubject: {
          exam: {
            schoolId,
            status: 'PUBLISHED',
          },
        },
      },
      include: {
        examSubject: {
          include: {
            exam: true,
            subject: true,
            class: true,
          },
        },
      },
      orderBy: { examSubject: { examDate: 'desc' } },
    });

    return marks.map((m) => ({
      id: m.id,
      examId: m.examSubject.exam.id,
      examName: m.examSubject.exam.name,
      term: m.examSubject.exam.term,
      subjectId: m.examSubject.subject.id,
      subjectName: m.examSubject.subject.name,
      subjectCode: m.examSubject.subject.code,
      examDate: m.examSubject.examDate,
      maxMarks: m.examSubject.maxMarks,
      passMarks: m.examSubject.passMarks,
      marksObtained: m.marksObtained,
      isAbsent: m.isAbsent,
      percentage: m.marksObtained != null ? Math.round((m.marksObtained / m.examSubject.maxMarks) * 100) : 0,
      grade: this.calculateGrade(m.marksObtained != null ? (m.marksObtained / m.examSubject.maxMarks) * 100 : 0),
      remarks: m.remarks,
      publishedAt: m.examSubject.exam.endDate,
    }));
  }

  async getChildFees(userId: string, studentId: string, schoolId: string) {
    const isLinked = await this.verifyParentChildLink(userId, studentId, schoolId);
    if (!isLinked) {
      throw new ForbiddenException('Access denied: You are not authorized to view fees for this student (FEE-02).');
    }

    const invoices = await this.prisma.invoice.findMany({
      where: { schoolId, studentId },
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
      orderBy: { createdAt: 'desc' },
    });

    const formattedInvoices = invoices.map((inv) => ({
      id: inv.id,
      invoiceNo: inv.invoiceNo,
      title: inv.title,
      category: inv.category || 'SCHOOL', // SCHOOL, HOSTEL, TRANSPORT
      studentId: inv.studentId,
      studentName: `${inv.student.firstName} ${inv.student.lastName}`,
      admissionNo: inv.student.admissionNo,
      className: inv.student.enrollments[0]?.class?.name || 'Grade 10',
      sectionName: inv.student.enrollments[0]?.section?.name || 'Section A',
      amount: inv.amountMinor / 100,
      paidAmount: inv.paidAmountMinor / 100,
      dueAmount: inv.dueAmountMinor / 100,
      dueDate: inv.dueDate,
      status: inv.status,
      payments: inv.payments.map((p) => ({
        id: p.id,
        receiptNo: p.receiptNo,
        amount: p.amountMinor / 100,
        method: p.method,
        status: p.status,
        date: p.createdAt,
        transactionRef: p.transactionRef,
      })),
    }));

    // Group by Category (Section 7)
    const schoolFees = formattedInvoices.filter((i) => i.category === 'SCHOOL');
    const hostelFees = formattedInvoices.filter((i) => i.category === 'HOSTEL');
    const transportFees = formattedInvoices.filter((i) => i.category === 'TRANSPORT');

    const computeSummary = (list: typeof formattedInvoices) => ({
      totalAmount: list.reduce((sum, item) => sum + item.amount, 0),
      totalPaid: list.reduce((sum, item) => sum + item.paidAmount, 0),
      totalDue: list.reduce((sum, item) => sum + item.dueAmount, 0),
      invoiceCount: list.length,
      hasPending: list.some((item) => item.status !== 'PAID'),
    });

    return {
      summary: {
        overall: computeSummary(formattedInvoices),
        school: computeSummary(schoolFees),
        hostel: computeSummary(hostelFees),
        transport: computeSummary(transportFees),
      },
      categories: {
        school: schoolFees,
        hostel: hostelFees,
        transport: transportFees,
      },
      allInvoices: formattedInvoices,
    };
  }

  private calculateGrade(pct: number): string {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 35) return 'D';
    return 'F';
  }
}
