import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ExamsService {
  constructor(private prisma: PrismaService) {}

  async getExams(schoolId: string) {
    const exams = await this.prisma.exam.findMany({
      where: { schoolId },
      include: {
        academicYear: true,
        subjects: {
          include: {
            class: true,
            subject: true,
            marks: {
              include: { student: true },
            },
          },
        },
      },
      orderBy: { startDate: 'desc' },
    });

    return exams.map((e) => ({
      id: e.id,
      name: e.name,
      term: e.term,
      startDate: e.startDate,
      endDate: e.endDate,
      status: e.status,
      academicYear: e.academicYear.name,
      subjects: e.subjects.map((s) => ({
        id: s.id,
        className: s.class.name,
        classId: s.classId,
        subjectName: s.subject.name,
        subjectId: s.subjectId,
        examDate: s.examDate,
        maxMarks: s.maxMarks,
        passMarks: s.passMarks,
        marksEntered: s.marks.length,
        marks: s.marks.map((m) => ({
          studentId: m.studentId,
          studentName: `${m.student.firstName} ${m.student.lastName}`,
          admissionNo: m.student.admissionNo,
          marksObtained: m.marksObtained,
          isAbsent: m.isAbsent,
          remarks: m.remarks,
        })),
      })),
    }));
  }

  async createExam(schoolId: string, data: any) {
    const activeYear = await this.prisma.academicYear.findFirst({
      where: { schoolId, isCurrent: true },
    });

    return this.prisma.exam.create({
      data: {
        schoolId,
        academicYearId: data.academicYearId || activeYear?.id,
        name: data.name,
        term: data.term || 'TERM_1',
        startDate: new Date(data.startDate),
        endDate: new Date(data.endDate),
        status: 'SCHEDULED',
      },
    });
  }

  async addExamSubject(examId: string, data: any) {
    return this.prisma.examSubject.create({
      data: {
        examId,
        classId: data.classId,
        subjectId: data.subjectId,
        examDate: new Date(data.examDate),
        maxMarks: data.maxMarks || 100,
        passMarks: data.passMarks || 40,
      },
    });
  }

  async getExamSubjectDetails(examSubjectId: string) {
    const examSubject = await this.prisma.examSubject.findUnique({
      where: { id: examSubjectId },
      include: {
        exam: true,
        class: true,
        subject: true,
        marks: {
          include: { student: true },
        },
      },
    });

    if (!examSubject) {
      throw new NotFoundException('Exam subject not found');
    }

    // Fetch all active students enrolled in this class
    const enrollments = await this.prisma.enrollment.findMany({
      where: {
        classId: examSubject.classId,
        status: 'ACTIVE',
      },
      include: {
        student: true,
        section: true,
      },
      orderBy: [
        { section: { name: 'asc' } },
        { rollNo: 'asc' },
        { student: { lastName: 'asc' } },
      ],
    });

    const marksMap = new Map<string, any>();
    for (const m of examSubject.marks) {
      marksMap.set(m.studentId, m);
    }

    const studentRoster = enrollments.map((enr) => {
      const existingMark = marksMap.get(enr.studentId);
      const marksObtained = existingMark?.marksObtained ?? null;
      const isAbsent = existingMark?.isAbsent ?? false;
      const pass = marksObtained !== null && marksObtained >= examSubject.passMarks;

      let grade = 'F';
      if (marksObtained !== null && !isAbsent) {
        const pct = (marksObtained / examSubject.maxMarks) * 100;
        if (pct >= 90) grade = 'A+';
        else if (pct >= 80) grade = 'A';
        else if (pct >= 70) grade = 'B';
        else if (pct >= 60) grade = 'C';
        else if (pct >= 40) grade = 'D';
        else grade = 'F';
      }

      return {
        studentId: enr.student.id,
        admissionNo: enr.student.admissionNo,
        rollNo: enr.rollNo,
        studentName: `${enr.student.firstName} ${enr.student.lastName}`,
        sectionName: enr.section.name,
        marksObtained,
        isAbsent,
        remarks: existingMark?.remarks || '',
        passed: isAbsent ? false : pass,
        grade: isAbsent ? 'ABSENT' : (marksObtained !== null ? grade : '-'),
      };
    });

    // Summary Statistics
    const scoredMarks = studentRoster
      .filter((s) => s.marksObtained !== null && !s.isAbsent)
      .map((s) => s.marksObtained as number);

    const totalStudents = studentRoster.length;
    const enteredCount = studentRoster.filter((s) => s.marksObtained !== null || s.isAbsent).length;
    const absentCount = studentRoster.filter((s) => s.isAbsent).length;
    const passCount = studentRoster.filter((s) => s.passed).length;
    const failCount = scoredMarks.length - passCount;
    const average = scoredMarks.length > 0 ? Number((scoredMarks.reduce((a, b) => a + b, 0) / scoredMarks.length).toFixed(1)) : 0;
    const highest = scoredMarks.length > 0 ? Math.max(...scoredMarks) : 0;
    const lowest = scoredMarks.length > 0 ? Math.min(...scoredMarks) : 0;

    return {
      examSubject: {
        id: examSubject.id,
        examName: examSubject.exam.name,
        term: examSubject.exam.term,
        className: examSubject.class.name,
        subjectName: examSubject.subject.name,
        examDate: examSubject.examDate,
        maxMarks: examSubject.maxMarks,
        passMarks: examSubject.passMarks,
        status: examSubject.exam.status,
      },
      stats: {
        totalStudents,
        enteredCount,
        absentCount,
        passCount,
        failCount,
        passPercentage: totalStudents > 0 ? Number(((passCount / totalStudents) * 100).toFixed(1)) : 0,
        average,
        highest,
        lowest,
      },
      students: studentRoster,
    };
  }

  async enterMarks(
    examSubjectId: string,
    marks: { studentId: string; marksObtained: number; isAbsent?: boolean; remarks?: string }[],
  ) {
    const examSubject = await this.prisma.examSubject.findUnique({
      where: { id: examSubjectId },
    });

    if (!examSubject) {
      throw new NotFoundException('Exam subject not found');
    }

    for (const m of marks) {
      // Validate marksObtained range
      const isAbsent = !!m.isAbsent;
      let score: number | null = m.marksObtained;

      if (isAbsent) {
        score = null;
      } else if (score !== null && (score < 0 || score > examSubject.maxMarks)) {
        throw new BadRequestException(
          `Marks obtained (${score}) cannot be negative or exceed maximum marks (${examSubject.maxMarks}).`,
        );
      }

      await this.prisma.mark.upsert({
        where: {
          examSubjectId_studentId: {
            examSubjectId,
            studentId: m.studentId,
          },
        },
        update: {
          marksObtained: score,
          isAbsent,
          remarks: m.remarks,
        },
        create: {
          examSubjectId,
          studentId: m.studentId,
          marksObtained: score,
          isAbsent,
          remarks: m.remarks,
        },
      });
    }

    return { message: 'Marks updated successfully', count: marks.length };
  }

  /**
   * Generates a template schema for Excel/CSV export and downloads
   */
  async exportTemplate(examSubjectId: string) {
    const details = await this.getExamSubjectDetails(examSubjectId);

    const headers = [
      'Admission No',
      'Roll No',
      'Student Name',
      'Section',
      'Max Marks',
      'Pass Marks',
      'Marks Obtained',
      'Is Absent (Y/N)',
      'Remarks',
    ];

    const rows = details.students.map((s) => [
      s.admissionNo,
      s.rollNo ?? '',
      s.studentName,
      s.sectionName,
      details.examSubject.maxMarks,
      details.examSubject.passMarks,
      s.marksObtained ?? '',
      s.isAbsent ? 'Y' : 'N',
      s.remarks || '',
    ]);

    // Build CSV string
    const csvLines = [headers.join(',')];
    for (const r of rows) {
      csvLines.push(r.map((val) => `"${String(val).replace(/"/g, '""')}"`).join(','));
    }
    const csvContent = csvLines.join('\n');

    return {
      filename: `${details.examSubject.className}_${details.examSubject.subjectName}_Marks_Template.csv`,
      csvContent,
      headers,
      rows,
      examSubject: details.examSubject,
    };
  }

  /**
   * Bulk imports marks from structured row data (parsed from Excel or CSV)
   */
  async importMarksFromData(
    examSubjectId: string,
    rows: Array<{
      admissionNo?: string;
      studentId?: string;
      marksObtained?: any;
      isAbsent?: any;
      remarks?: string;
    }>,
  ) {
    const examSubject = await this.prisma.examSubject.findUnique({
      where: { id: examSubjectId },
    });

    if (!examSubject) {
      throw new NotFoundException('Exam subject not found');
    }

    // Map all admission numbers to student IDs
    const students = await this.prisma.student.findMany({
      where: {
        enrollments: {
          some: { classId: examSubject.classId, status: 'ACTIVE' },
        },
      },
      select: { id: true, admissionNo: true, firstName: true, lastName: true },
    });

    const admissionMap = new Map<string, string>();
    for (const s of students) {
      admissionMap.set(s.admissionNo.trim().toUpperCase(), s.id);
    }

    const errors: Array<{ row: number; error: string; data: any }> = [];
    const validBatch: Array<{ studentId: string; marksObtained: number | null; isAbsent: boolean; remarks?: string }> = [];

    let rowIndex = 1;
    for (const r of rows) {
      rowIndex++;
      const adm = String(r.admissionNo || '').trim().toUpperCase();
      let studentId = r.studentId;

      if (!studentId && adm) {
        studentId = admissionMap.get(adm);
      }

      if (!studentId) {
        errors.push({
          row: rowIndex,
          error: `Student with Admission No "${r.admissionNo}" not found in this class.`,
          data: r,
        });
        continue;
      }

      const isAbsentStr = String(r.isAbsent || '').trim().toUpperCase();
      const isAbsent = isAbsentStr === 'Y' || isAbsentStr === 'YES' || isAbsentStr === 'TRUE' || isAbsentStr === '1';

      let marksObtained: number | null = null;
      if (!isAbsent && r.marksObtained !== undefined && r.marksObtained !== null && r.marksObtained !== '') {
        const parsed = Number(r.marksObtained);
        if (isNaN(parsed)) {
          errors.push({
            row: rowIndex,
            error: `Invalid mark value "${r.marksObtained}". Must be numeric.`,
            data: r,
          });
          continue;
        }
        if (parsed < 0 || parsed > examSubject.maxMarks) {
          errors.push({
            row: rowIndex,
            error: `Mark ${parsed} is out of allowable range (0 to ${examSubject.maxMarks}).`,
            data: r,
          });
          continue;
        }
        marksObtained = parsed;
      }

      validBatch.push({
        studentId,
        marksObtained,
        isAbsent,
        remarks: r.remarks ? String(r.remarks).trim() : undefined,
      });
    }

    // Execute bulk upserts for all valid records
    for (const item of validBatch) {
      await this.prisma.mark.upsert({
        where: {
          examSubjectId_studentId: {
            examSubjectId,
            studentId: item.studentId,
          },
        },
        update: {
          marksObtained: item.marksObtained,
          isAbsent: item.isAbsent,
          remarks: item.remarks,
        },
        create: {
          examSubjectId,
          studentId: item.studentId,
          marksObtained: item.marksObtained,
          isAbsent: item.isAbsent,
          remarks: item.remarks,
        },
      });
    }

    return {
      message: `Import completed: ${validBatch.length} marks saved successfully.`,
      successCount: validBatch.length,
      errorCount: errors.length,
      errors,
    };
  }

  /**
   * Generates a consolidated class broadsheet across all subjects for a class
   */
  async getClassBroadsheet(schoolId: string, examId: string, classId: string) {
    const exam = await this.prisma.exam.findUnique({
      where: { id: examId },
    });

    if (!exam) {
      throw new NotFoundException('Exam not found');
    }

    const examSubjects = await this.prisma.examSubject.findMany({
      where: { examId, classId },
      include: { subject: true },
      orderBy: { subject: { name: 'asc' } },
    });

    const enrollments = await this.prisma.enrollment.findMany({
      where: { classId, status: 'ACTIVE' },
      include: {
        student: true,
        section: true,
      },
      orderBy: [{ rollNo: 'asc' }, { student: { lastName: 'asc' } }],
    });

    const subjectIds = examSubjects.map((es) => es.id);
    const marks = await this.prisma.mark.findMany({
      where: { examSubjectId: { in: subjectIds } },
    });

    const markMap = new Map<string, any>();
    for (const m of marks) {
      markMap.set(`${m.examSubjectId}_${m.studentId}`, m);
    }

    const maxTotalPossible = examSubjects.reduce((sum, es) => sum + es.maxMarks, 0);

    const rows = enrollments.map((enr) => {
      let totalObtained = 0;
      let hasFailedAny = false;
      let subjectsCounted = 0;

      const subjectMarks: Record<string, any> = {};

      for (const es of examSubjects) {
        const m = markMap.get(`${es.id}_${enr.studentId}`);
        const score = m?.marksObtained ?? null;
        const isAbsent = m?.isAbsent ?? false;

        subjectMarks[es.subject.name] = {
          marksObtained: score,
          isAbsent,
          maxMarks: es.maxMarks,
          passMarks: es.passMarks,
          passed: !isAbsent && score !== null && score >= es.passMarks,
        };

        if (score !== null && !isAbsent) {
          totalObtained += score;
          subjectsCounted++;
          if (score < es.passMarks) hasFailedAny = true;
        } else if (isAbsent) {
          hasFailedAny = true;
        }
      }

      const percentage = maxTotalPossible > 0 ? Number(((totalObtained / maxTotalPossible) * 100).toFixed(1)) : 0;

      let grade = 'F';
      if (!hasFailedAny && subjectsCounted === examSubjects.length) {
        if (percentage >= 90) grade = 'A+';
        else if (percentage >= 80) grade = 'A';
        else if (percentage >= 70) grade = 'B';
        else if (percentage >= 60) grade = 'C';
        else grade = 'D';
      }

      return {
        studentId: enr.student.id,
        admissionNo: enr.student.admissionNo,
        rollNo: enr.rollNo,
        studentName: `${enr.student.firstName} ${enr.student.lastName}`,
        sectionName: enr.section.name,
        subjectMarks,
        totalObtained,
        maxTotalPossible,
        percentage,
        grade,
        result: hasFailedAny ? 'FAIL' : 'PASS',
      };
    });

    // Rank calculation for passed students
    rows.sort((a, b) => b.totalObtained - a.totalObtained);
    let currentRank = 1;
    const rankedRows = rows.map((r, idx) => {
      let rank: number | string = '-';
      if (r.result === 'PASS') {
        rank = currentRank++;
      }
      return { ...r, rank };
    });

    return {
      examName: exam.name,
      term: exam.term,
      subjects: examSubjects.map((es) => ({
        id: es.id,
        name: es.subject.name,
        maxMarks: es.maxMarks,
        passMarks: es.passMarks,
      })),
      broadsheet: rankedRows,
    };
  }

  async publishExam(examId: string, schoolId: string, userName?: string) {
    const exam = await this.prisma.exam.update({
      where: { id: examId },
      data: { status: 'PUBLISHED' },
    });

    await this.prisma.auditLog.create({
      data: {
        schoolId,
        actorId: userName || 'Principal',
        actorName: userName || 'Principal',
        action: 'MARKS_PUBLISHED',
        entity: 'Exam',
        entityId: examId,
        details: JSON.stringify({ examName: exam.name }),
      },
    });

    return exam;
  }
}
