import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AcademicsService {
  constructor(private prisma: PrismaService) {}

  // 1. Course Delivery Plans (OBE Lesson Planning)
  async getLessonPlans(schoolId: string, query: { classId?: string; subjectId?: string; teacherId?: string }) {
    const where: any = { schoolId };
    if (query.classId) where.classId = query.classId;
    if (query.subjectId) where.subjectId = query.subjectId;
    if (query.teacherId) where.teacherId = query.teacherId;

    const plans = await this.prisma.lessonPlan.findMany({
      where,
      include: {
        class: true,
        subject: true,
        teacher: true,
      },
      orderBy: [
        { unitNumber: 'asc' },
        { id: 'asc' },
      ],
    });

    const totalPlannedHours = plans.reduce((acc, curr) => acc + curr.plannedHours, 0);
    const totalConductedHours = plans.reduce((acc, curr) => acc + curr.conductedHours, 0);
    const overallSyllabusCoverage = totalPlannedHours > 0 ? Math.round((totalConductedHours / totalPlannedHours) * 100) : 0;

    return {
      plans: plans.map((p) => ({
        id: p.id,
        unitNumber: p.unitNumber,
        unitTitle: p.unitTitle,
        topic: p.topic,
        learningObjectives: p.learningObjectives,
        plannedHours: p.plannedHours,
        conductedHours: p.conductedHours,
        status: p.status,
        className: p.class.name,
        subjectName: p.subject.name,
        teacherName: `${p.teacher.firstName} ${p.teacher.lastName}`,
        coveragePercent: p.plannedHours > 0 ? Math.min(100, Math.round((p.conductedHours / p.plannedHours) * 100)) : 0,
      })),
      totalPlannedHours,
      totalConductedHours,
      overallSyllabusCoverage,
    };
  }

  async createLessonPlan(schoolId: string, data: any) {
    return this.prisma.lessonPlan.create({
      data: {
        schoolId,
        classId: data.classId,
        subjectId: data.subjectId,
        teacherId: data.teacherId,
        unitNumber: data.unitNumber || 1,
        unitTitle: data.unitTitle,
        topic: data.topic,
        learningObjectives: data.learningObjectives,
        plannedHours: data.plannedHours || 4,
        conductedHours: 0,
        status: 'PENDING',
      },
    });
  }

  async updateLessonProgress(
    schoolId: string,
    id: string,
    data: { conductedHours?: number; actualHours?: number; status?: string },
  ) {
    const plan = await this.prisma.lessonPlan.findFirst({ where: { id, schoolId } });
    if (!plan) {
      throw new NotFoundException('Lesson plan not found');
    }
    const hours = Number(data.conductedHours !== undefined ? data.conductedHours : (data.actualHours || 0));
    if (!Number.isInteger(hours) || hours < 0) {
      throw new BadRequestException('conductedHours must be a non-negative whole number');
    }
    if (data.status && !['PENDING', 'IN_PROGRESS', 'COMPLETED'].includes(data.status)) {
      throw new BadRequestException('Invalid lesson plan status');
    }
    return this.prisma.lessonPlan.update({
      where: { id },
      data: {
        conductedHours: hours,
        status: data.status || (hours > 0 ? 'IN_PROGRESS' : 'PENDING'),
      },
    });
  }

  // 2. Faculty Teaching Diary (Linways Course Log)
  async getTeachingDiaries(schoolId: string, query: { classId?: string; subjectId?: string; teacherId?: string }) {
    const where: any = { schoolId };
    if (query.classId) where.classId = query.classId;
    if (query.subjectId) where.subjectId = query.subjectId;
    if (query.teacherId) where.teacherId = query.teacherId;

    const entries = await this.prisma.teachingDiaryEntry.findMany({
      where,
      include: {
        class: true,
        section: true,
        subject: true,
        teacher: true,
      },
      orderBy: { date: 'desc' },
      take: 30,
    });

    return entries.map((e) => ({
      id: e.id,
      date: e.date,
      periodNumber: e.periodNumber,
      topicTaught: e.topicTaught,
      methodology: e.methodology,
      remarks: e.remarks,
      className: e.class.name,
      sectionName: e.section.name,
      subjectName: e.subject.name,
      teacherName: `${e.teacher.firstName} ${e.teacher.lastName}`,
    }));
  }

  async createTeachingDiary(schoolId: string, data: any) {
    let classId = data.classId;
    let sectionId = data.sectionId;
    let subjectId = data.subjectId;
    let teacherId = data.teacherId;

    if (!classId || !sectionId || !subjectId || !teacherId) {
      const cls = await this.prisma.class.findFirst({
        where: { schoolId },
        include: { sections: true },
      });
      const sub = await this.prisma.subject.findFirst({ where: { schoolId } });
      const staff = await this.prisma.staff.findFirst({ where: { schoolId } });

      if (cls) {
        classId = classId || cls.id;
        sectionId = sectionId || cls.sections[0]?.id;
      }
      if (sub) subjectId = subjectId || sub.id;
      if (staff) teacherId = teacherId || staff.id;
    }

    return this.prisma.teachingDiaryEntry.create({
      data: {
        schoolId,
        classId,
        sectionId,
        subjectId,
        teacherId,
        date: new Date(data.date || Date.now()),
        periodNumber: data.periodNumber || 1,
        topicTaught: data.topicTaught || data.topicCovered || 'Course Topic Session',
        methodology: data.methodology || data.teachingMethod || 'LECTURE',
        remarks: data.remarks || data.homeworkGiven,
      },
    });
  }

  // 3. Digital Course Repository (Learning Materials)
  async getCourseMaterials(schoolId: string, subjectId?: string) {
    const where: any = { schoolId };
    if (subjectId) where.subjectId = subjectId;

    const materials = await this.prisma.courseMaterial.findMany({
      where,
      include: { subject: true },
      orderBy: { createdAt: 'desc' },
    });

    return materials.map((m) => ({
      id: m.id,
      title: m.title,
      unitNumber: m.unitNumber,
      fileType: m.fileType,
      fileUrl: m.fileUrl,
      subjectName: m.subject.name,
      uploadedBy: m.uploadedBy,
      createdAt: m.createdAt,
    }));
  }

  async createCourseMaterial(schoolId: string, data: any) {
    return this.prisma.courseMaterial.create({
      data: {
        schoolId,
        subjectId: data.subjectId,
        title: data.title,
        unitNumber: data.unitNumber || 1,
        fileType: data.fileType || 'PDF',
        fileUrl: data.fileUrl,
        uploadedBy: data.uploadedBy || 'Faculty',
      },
    });
  }

  // 4. Linways Attendance Shortage Analytics (<75% Risk Detector)
  async getAttendanceShortageAnalytics(schoolId: string) {
    const students = await this.prisma.student.findMany({
      where: { schoolId, status: 'ACTIVE' },
      include: {
        enrollments: {
          where: { status: 'ACTIVE' },
          include: { class: true, section: true },
        },
        attendanceRecords: true,
      },
    });

    const atRiskStudents = [];
    const normalStudents = [];

    for (const s of students) {
      const total = s.attendanceRecords.length;
      const present = s.attendanceRecords.filter((r) => r.status === 'PRESENT' || r.status === 'LATE').length;
      const rate = total > 0 ? Math.round((present / total) * 100) : 100;

      const studentData = {
        id: s.id,
        admissionNo: s.admissionNo,
        fullName: `${s.firstName} ${s.lastName}`,
        className: s.enrollments[0]?.class?.name || 'Unassigned',
        sectionName: s.enrollments[0]?.section?.name || 'Unassigned',
        totalSessions: total,
        attendedSessions: present,
        attendanceRate: rate,
        isAtRisk: total > 0 && rate < 75,
      };

      if (rate < 75) {
        atRiskStudents.push(studentData);
      } else {
        normalStudents.push(studentData);
      }
    }

    return {
      atRiskCount: atRiskStudents.length,
      normalCount: normalStudents.length,
      thresholdPercentage: 75,
      atRiskStudents,
    };
  }

  // 5. Outcome-Based Education (OBE) Course Outcomes & Bloom's Taxonomy
  async getCourseOutcomes(schoolId: string, subjectId: string) {
    return this.prisma.courseOutcome.findMany({
      where: { schoolId, subjectId },
      orderBy: { code: 'asc' },
    });
  }

  async createCourseOutcome(schoolId: string, subjectId: string, data: any) {
    const subject = await this.prisma.subject.findFirst({
      where: { id: subjectId, schoolId },
    });
    if (!subject) {
      throw new NotFoundException('Subject not found in this school');
    }

    return this.prisma.courseOutcome.upsert({
      where: {
        subjectId_code: {
          subjectId,
          code: data.code,
        },
      },
      update: {
        description: data.description,
        bloomLevel: data.bloomLevel,
        targetAttainment: data.targetAttainment !== undefined ? data.targetAttainment : 70,
      },
      create: {
        schoolId,
        subjectId,
        code: data.code,
        description: data.description,
        bloomLevel: data.bloomLevel,
        targetAttainment: data.targetAttainment !== undefined ? data.targetAttainment : 70,
      },
    });
  }

  getBloomsTaxonomyLevels() {
    return [
      {
        level: 'REMEMBER',
        name: 'Remembering',
        order: 1,
        cognitiveProcess: 'Recall facts, basic concepts, and retrieval of relevant knowledge',
        actionVerbs: ['define', 'duplicate', 'list', 'memorize', 'recall', 'repeat', 'reproduce', 'state'],
      },
      {
        level: 'UNDERSTAND',
        name: 'Understanding',
        order: 2,
        cognitiveProcess: 'Explain ideas or concepts, interpret, exemplify, classify, summarize',
        actionVerbs: ['classify', 'describe', 'discuss', 'explain', 'identify', 'locate', 'recognize', 'report', 'select', 'translate'],
      },
      {
        level: 'APPLY',
        name: 'Applying',
        order: 3,
        cognitiveProcess: 'Use information in new situations, execute or implement tasks',
        actionVerbs: ['execute', 'implement', 'solve', 'use', 'demonstrate', 'interpret', 'operate', 'schedule', 'sketch'],
      },
      {
        level: 'ANALYZE',
        name: 'Analyzing',
        order: 4,
        cognitiveProcess: 'Draw connections among ideas, differentiate, organize, attribute',
        actionVerbs: ['differentiate', 'organize', 'relate', 'compare', 'contrast', 'distinguish', 'examine', 'experiment', 'question', 'test'],
      },
      {
        level: 'EVALUATE',
        name: 'Evaluating',
        order: 5,
        cognitiveProcess: 'Justify a stand or decision, appraise, argue, defend, critique',
        actionVerbs: ['appraise', 'argue', 'defend', 'judge', 'select', 'support', 'value', 'critique', 'weigh'],
      },
      {
        level: 'CREATE',
        name: 'Creating',
        order: 6,
        cognitiveProcess: 'Produce new or original work, design, assemble, construct, formulate',
        actionVerbs: ['design', 'assemble', 'construct', 'conjecture', 'develop', 'formulate', 'author', 'investigate'],
      },
    ];
  }
}
