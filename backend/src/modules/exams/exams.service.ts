import { Injectable, NotFoundException } from '@nestjs/common';
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

  async enterMarks(examSubjectId: string, marks: { studentId: string; marksObtained: number; isAbsent?: boolean; remarks?: string }[]) {
    for (const m of marks) {
      await this.prisma.mark.upsert({
        where: {
          examSubjectId_studentId: {
            examSubjectId,
            studentId: m.studentId,
          },
        },
        update: {
          marksObtained: m.marksObtained,
          isAbsent: !!m.isAbsent,
          remarks: m.remarks,
        },
        create: {
          examSubjectId,
          studentId: m.studentId,
          marksObtained: m.marksObtained,
          isAbsent: !!m.isAbsent,
          remarks: m.remarks,
        },
      });
    }

    return { message: 'Marks updated successfully', count: marks.length };
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
