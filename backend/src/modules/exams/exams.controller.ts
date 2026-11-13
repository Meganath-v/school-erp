import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ExamsService } from './exams.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ACADEMIC_STAFF, ALL_STAFF, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('exams')
@UseGuards(JwtAuthGuard)
export class ExamsController {
  constructor(private examsService: ExamsService) {}

  @Roles(...ALL_STAFF)
  @Get()
  async getExams(@CurrentSchoolId() schoolId: string) {
    const data = await this.examsService.getExams(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Post()
  async createExam(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.examsService.createExam(schoolId, body);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Post(':id/subjects')
  async addExamSubject(@CurrentSchoolId() schoolId: string, @Param('id') examId: string, @Body() body: any) {
    const data = await this.examsService.addExamSubject(schoolId, examId, body);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Get('subjects/:subjectId/details')
  async getExamSubjectDetails(@CurrentSchoolId() schoolId: string, @Param('subjectId') subjectId: string) {
    const data = await this.examsService.getExamSubjectDetails(schoolId, subjectId);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Post('subjects/:subjectId/marks')
  async enterMarks(
    @CurrentSchoolId() schoolId: string,
    @Param('subjectId') subjectId: string,
    @Body() body: { marks: any[] },
  ) {
    const data = await this.examsService.enterMarks(schoolId, subjectId, body?.marks);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Get('subjects/:subjectId/template')
  async exportTemplate(@CurrentSchoolId() schoolId: string, @Param('subjectId') subjectId: string) {
    const data = await this.examsService.exportTemplate(schoolId, subjectId);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Post('subjects/:subjectId/import')
  async importMarks(
    @CurrentSchoolId() schoolId: string,
    @Param('subjectId') subjectId: string,
    @Body() body: { rows: any[] },
  ) {
    const data = await this.examsService.importMarksFromData(schoolId, subjectId, body?.rows);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Get(':id/classes/:classId/broadsheet')
  async getClassBroadsheet(
    @CurrentSchoolId() schoolId: string,
    @Param('id') examId: string,
    @Param('classId') classId: string,
  ) {
    const data = await this.examsService.getClassBroadsheet(schoolId, examId, classId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Post(':id/publish')
  async publishExam(
    @CurrentSchoolId() schoolId: string,
    @Param('id') examId: string,
    @CurrentUser('name') userName: string,
    @CurrentUser('userId') userId: string,
  ) {
    const data = await this.examsService.publishExam(examId, schoolId, userName, userId);
    return { data };
  }
}
