import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { assertStudentAccess } from '../../common/access/student-access';

@Injectable()
export class StudentsService {
  constructor(private prisma: PrismaService) {}

  async getStudents(schoolId: string, query: { classId?: string; sectionId?: string; search?: string; userId?: string; role?: string }) {
    const where: any = { schoolId };

    // If role is PARENT, restrict to linked children
    if (query.role === 'PARENT' && query.userId) {
      const guardian = await this.prisma.guardian.findFirst({
        where: { schoolId, userId: query.userId },
      });
      if (!guardian) {
        return [];
      }
      where.studentGuardians = {
        some: { guardianId: guardian.id },
      };
    } else if (query.role === 'STUDENT' && query.userId) {
      where.userId = query.userId;
    } else {
      if (query.classId || query.sectionId) {
        where.enrollments = {
          some: {
            status: 'ACTIVE',
            ...(query.classId ? { classId: query.classId } : {}),
            ...(query.sectionId ? { sectionId: query.sectionId } : {}),
          },
        };
      }
      if (query.search) {
        where.OR = [
          { firstName: { contains: query.search } },
          { lastName: { contains: query.search } },
          { admissionNo: { contains: query.search } },
        ];
      }
    }

    const students = await this.prisma.student.findMany({
      where,
      include: {
        enrollments: {
          where: { status: 'ACTIVE' },
          include: {
            class: true,
            section: true,
          },
        },
        studentGuardians: {
          include: {
            guardian: true,
          },
        },
      },
      orderBy: { firstName: 'asc' },
    });

    return students.map((s) => ({
      id: s.id,
      schoolId: s.schoolId,
      admissionNo: s.admissionNo,
      firstName: s.firstName,
      lastName: s.lastName,
      fullName: `${s.firstName} ${s.lastName}`,
      gender: s.gender,
      dob: s.dob,
      bloodGroup: s.bloodGroup,
      address: s.address,
      status: s.status,
      currentClass: s.enrollments[0]?.class?.name || 'Unassigned',
      currentSection: s.enrollments[0]?.section?.name || 'Unassigned',
      classId: s.enrollments[0]?.classId,
      sectionId: s.enrollments[0]?.sectionId,
      rollNo: s.enrollments[0]?.rollNo,
      guardians: s.studentGuardians.map((sg) => ({
        name: sg.guardian.name,
        relation: sg.relationship,
        phone: sg.guardian.phone,
        email: sg.guardian.email,
        isPrimary: sg.isPrimary,
      })),
    }));
  }

  async getStudentById(schoolId: string, id: string, user: { userId: string; role: string }) {
    await assertStudentAccess(this.prisma, schoolId, user, id);
    const student = await this.prisma.student.findFirst({
      where: { id, schoolId },
      include: {
        enrollments: {
          include: {
            class: true,
            section: true,
            academicYear: true,
          },
        },
        studentGuardians: {
          include: { guardian: true },
        },
        attendanceRecords: {
          include: { session: true },
          orderBy: { session: { date: 'desc' } },
          take: 30,
        },
        marks: {
          // Parents only see results once the exam has been published.
          where: user.role === 'PARENT' ? { examSubject: { exam: { status: 'PUBLISHED' } } } : undefined,
          include: {
            examSubject: {
              include: {
                subject: true,
                exam: true,
              },
            },
          },
        },
        invoices: {
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!student) {
      throw new NotFoundException('Student not found in this school');
    }

    const totalAttendance = student.attendanceRecords.length;
    const presentAttendance = student.attendanceRecords.filter((r) => r.status === 'PRESENT').length;
    const attendancePercentage = totalAttendance > 0 ? Math.round((presentAttendance / totalAttendance) * 100) : 100;

    return {
      ...student,
      fullName: `${student.firstName} ${student.lastName}`,
      attendancePercentage,
    };
  }

  async createStudentAdmission(schoolId: string, data: any) {
    // Generate admission number if not provided
    const count = await this.prisma.student.count({ where: { schoolId } });
    const admissionNo = data.admissionNo || `ADM-2026-${String(count + 1).padStart(3, '0')}`;

    const student = await this.prisma.student.create({
      data: {
        schoolId,
        admissionNo,
        firstName: data.firstName,
        lastName: data.lastName,
        dob: new Date(data.dob || '2012-01-01'),
        gender: data.gender || 'OTHER',
        bloodGroup: data.bloodGroup,
        address: data.address,
        emergencyContact: data.emergencyContact || data.guardianPhone,
        status: 'ACTIVE',
      },
    });

    // Create Enrollment if class & section provided
    if (data.classId && data.sectionId) {
      const activeYear = await this.prisma.academicYear.findFirst({
        where: { schoolId, isCurrent: true },
      });
      if (activeYear) {
        await this.prisma.enrollment.create({
          data: {
            schoolId,
            studentId: student.id,
            academicYearId: activeYear.id,
            classId: data.classId,
            sectionId: data.sectionId,
            rollNo: data.rollNo || count + 1,
            status: 'ACTIVE',
          },
        });
      }
    }

    // Create Guardian and link
    if (data.guardianName && data.guardianPhone) {
      const guardian = await this.prisma.guardian.create({
        data: {
          schoolId,
          name: data.guardianName,
          relation: data.guardianRelation || 'FATHER',
          phone: data.guardianPhone,
          email: data.guardianEmail,
        },
      });

      await this.prisma.studentGuardian.create({
        data: {
          studentId: student.id,
          guardianId: guardian.id,
          relationship: data.guardianRelation || 'FATHER',
          isPrimary: true,
          canAccessPortal: true,
        },
      });
    }

    return student;
  }

  async getReportCard(schoolId: string, studentId: string, user: { userId: string; role: string }) {
    await assertStudentAccess(this.prisma, schoolId, user, studentId);
    const student = await this.prisma.student.findFirst({
      where: { id: studentId, schoolId },
      include: {
        enrollments: {
          where: { status: 'ACTIVE' },
          include: { class: true, section: true, academicYear: true },
        },
        marks: {
          // Parents only see results once the exam has been published.
          where: user.role === 'PARENT' ? { examSubject: { exam: { status: 'PUBLISHED' } } } : undefined,
          include: {
            examSubject: {
              include: {
                subject: true,
                exam: true,
              },
            },
          },
        },
        attendanceRecords: true,
      },
    });

    if (!student) {
      throw new NotFoundException('Student not found');
    }

    const marksByExam: { [key: string]: any } = {};
    for (const m of student.marks) {
      const examName = m.examSubject.exam.name;
      if (!marksByExam[examName]) {
        marksByExam[examName] = {
          examName,
          term: m.examSubject.exam.term,
          status: m.examSubject.exam.status,
          subjects: [],
          totalMarksObtained: 0,
          totalMaxMarks: 0,
        };
      }
      marksByExam[examName].subjects.push({
        subjectName: m.examSubject.subject.name,
        subjectCode: m.examSubject.subject.code,
        marksObtained: m.marksObtained,
        maxMarks: m.examSubject.maxMarks,
        passMarks: m.examSubject.passMarks,
        remarks: m.remarks,
      });
      marksByExam[examName].totalMarksObtained += m.marksObtained || 0;
      marksByExam[examName].totalMaxMarks += m.examSubject.maxMarks;
    }

    const totalAttendance = student.attendanceRecords.length;
    const presentAttendance = student.attendanceRecords.filter((r) => r.status === 'PRESENT').length;
    const attendancePercentage = totalAttendance > 0 ? Math.round((presentAttendance / totalAttendance) * 100) : 100;

    return {
      student: {
        id: student.id,
        admissionNo: student.admissionNo,
        fullName: `${student.firstName} ${student.lastName}`,
        dob: student.dob,
        class: student.enrollments[0]?.class?.name || 'N/A',
        section: student.enrollments[0]?.section?.name || 'N/A',
        rollNo: student.enrollments[0]?.rollNo || 'N/A',
        academicYear: student.enrollments[0]?.academicYear?.name || '2026-2027',
      },
      attendancePercentage,
      totalWorkingDays: totalAttendance || 65,
      daysPresent: presentAttendance || 62,
      exams: Object.values(marksByExam),
    };
  }

  async getStudentMe(schoolId: string, userId: string) {
    const student = await this.prisma.student.findFirst({
      where: { schoolId, userId },
      include: {
        enrollments: {
          where: { status: 'ACTIVE' },
          include: {
            class: true,
            section: true,
            academicYear: true,
          },
        },
        studentGuardians: {
          include: { guardian: true },
        },
      },
    });

    if (!student) {
      throw new NotFoundException('Student profile not found for this user');
    }

    return {
      id: student.id,
      admissionNo: student.admissionNo,
      firstName: student.firstName,
      lastName: student.lastName,
      fullName: `${student.firstName} ${student.lastName}`,
      dob: student.dob,
      gender: student.gender,
      bloodGroup: student.bloodGroup,
      address: student.address,
      className: student.enrollments[0]?.class?.name || 'Grade 10',
      sectionName: student.enrollments[0]?.section?.name || 'Section A',
      classId: student.enrollments[0]?.classId,
      sectionId: student.enrollments[0]?.sectionId,
      rollNo: student.enrollments[0]?.rollNo,
      guardians: student.studentGuardians.map((sg) => ({
        name: sg.guardian.name,
        relation: sg.relationship,
        phone: sg.guardian.phone,
      })),
    };
  }
}
