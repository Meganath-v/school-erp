import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { assertStudentAccess } from '../../common/access/student-access';

@Injectable()
export class AssignmentsService {
  constructor(private prisma: PrismaService) {}

  async getAssignments(schoolId: string, query: { classId?: string; sectionId?: string; teacherId?: string }) {
    const where: any = { schoolId };
    if (query.classId) where.classId = query.classId;
    if (query.sectionId) where.sectionId = query.sectionId;
    if (query.teacherId) where.teacherId = query.teacherId;

    const assignments = await this.prisma.assignment.findMany({
      where,
      include: {
        subject: true,
        teacher: true,
        class: true,
        section: true,
        _count: {
          select: { submissions: true },
        },
      },
      orderBy: { dueDate: 'asc' },
    });

    return assignments.map((a) => ({
      id: a.id,
      title: a.title,
      description: a.description,
      subjectName: a.subject.name,
      teacherName: `${a.teacher.firstName} ${a.teacher.lastName}`,
      className: a.class.name,
      sectionName: a.section.name,
      issueDate: a.issueDate,
      dueDate: a.dueDate,
      maxMarks: a.maxMarks,
      status: a.status,
      submissionsCount: a._count.submissions,
    }));
  }

  async createAssignment(schoolId: string, data: any) {
    return this.prisma.assignment.create({
      data: {
        schoolId,
        classId: data.classId,
        sectionId: data.sectionId,
        subjectId: data.subjectId,
        teacherId: data.teacherId,
        title: data.title,
        description: data.description,
        dueDate: new Date(data.dueDate),
        maxMarks: data.maxMarks || 100,
        status: 'ACTIVE',
      },
    });
  }

  async getSubmissions(schoolId: string, assignmentId: string) {
    const submissions = await this.prisma.submission.findMany({
      where: {
        assignmentId,
        assignment: { schoolId },
      },
      include: {
        student: true,
      },
    });

    return submissions.map((s) => ({
      id: s.id,
      studentId: s.student.id,
      studentName: `${s.student.firstName} ${s.student.lastName}`,
      admissionNo: s.student.admissionNo,
      submittedAt: s.submittedAt,
      status: s.status,
      notes: s.notes,
      marksObtained: s.marksObtained,
      feedback: s.feedback,
    }));
  }

  async submitAssignment(
    schoolId: string,
    user: { userId: string; role: string },
    data: { assignmentId: string; studentId: string; notes?: string; fileUrl?: string },
  ) {
    const assignment = await this.prisma.assignment.findFirst({ where: { id: data.assignmentId, schoolId } });
    if (!assignment) {
      throw new NotFoundException('Assignment not found');
    }
    if (assignment.status !== 'ACTIVE') {
      throw new BadRequestException('This assignment is closed for submissions');
    }
    // The caller must be a guardian of the student, and the student must be in the assignment's section.
    await assertStudentAccess(this.prisma, schoolId, user, data.studentId);
    const enrolled = await this.prisma.enrollment.findFirst({
      where: { schoolId, studentId: data.studentId, sectionId: assignment.sectionId, status: 'ACTIVE' },
    });
    if (!enrolled) {
      throw new BadRequestException('Student is not enrolled in the section this assignment was issued to');
    }
    if (data.fileUrl && !/^https:\/\//i.test(data.fileUrl)) {
      throw new BadRequestException('fileUrl must be an https:// link');
    }

    return this.prisma.submission.upsert({
      where: {
        assignmentId_studentId: {
          assignmentId: data.assignmentId,
          studentId: data.studentId,
        },
      },
      update: {
        submittedAt: new Date(),
        status: 'SUBMITTED',
        notes: data.notes,
        fileUrl: data.fileUrl,
      },
      create: {
        assignmentId: data.assignmentId,
        studentId: data.studentId,
        submittedAt: new Date(),
        status: 'SUBMITTED',
        notes: data.notes,
        fileUrl: data.fileUrl,
      },
    });
  }

  async gradeSubmission(schoolId: string, submissionId: string, data: { marksObtained: number; feedback?: string }) {
    const submission = await this.prisma.submission.findFirst({
      where: { id: submissionId, assignment: { schoolId } },
      include: { assignment: true },
    });
    if (!submission) {
      throw new NotFoundException('Submission not found');
    }
    const marks = Number(data?.marksObtained);
    if (!Number.isInteger(marks) || marks < 0 || marks > submission.assignment.maxMarks) {
      throw new BadRequestException(`marksObtained must be a whole number between 0 and ${submission.assignment.maxMarks}`);
    }

    return this.prisma.submission.update({
      where: { id: submissionId },
      data: {
        marksObtained: marks,
        feedback: data.feedback,
        status: 'REVIEWED',
      },
    });
  }
}
