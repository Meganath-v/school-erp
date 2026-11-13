import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ExamsService } from './exams.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('exams')
@UseGuards(JwtAuthGuard)
export class ExamsController {
  constructor(private examsService: ExamsService) {}

  @Get()
  async getExams(@CurrentSchoolId() schoolId: string) {
    const data = await this.examsService.getExams(schoolId);
    return { data };
  }

  @Post()
  async createExam(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.examsService.createExam(schoolId, body);
    return { data };
  }

  @Post(':id/subjects')
  async addExamSubject(@Param('id') examId: string, @Body() body: any) {
    const data = await this.examsService.addExamSubject(examId, body);
    return { data };
  }

  @Get('subjects/:subjectId/details')
  async getExamSubjectDetails(@Param('subjectId') subjectId: string) {
    const data = await this.examsService.getExamSubjectDetails(subjectId);
    return { data };
  }

  @Post('subjects/:subjectId/marks')
  async enterMarks(@Param('subjectId') subjectId: string, @Body() body: { marks: any[] }) {
    const data = await this.examsService.enterMarks(subjectId, body.marks);
    return { data };
  }

  @Get('subjects/:subjectId/template')
  async exportTemplate(@Param('subjectId') subjectId: string) {
    const data = await this.examsService.exportTemplate(subjectId);
    return { data };
  }

  @Post('subjects/:subjectId/import')
  async importMarks(
    @Param('subjectId') subjectId: string,
    @Body() body: { rows: any[] },
  ) {
    const data = await this.examsService.importMarksFromData(subjectId, body.rows);
    return { data };
  }

  @Get(':id/classes/:classId/broadsheet')
  async getClassBroadsheet(
    @CurrentSchoolId() schoolId: string,
    @Param('id') examId: string,
    @Param('classId') classId: string,
  ) {
    const data = await this.examsService.getClassBroadsheet(schoolId, examId, classId);
    return { data };
  }

  @Post(':id/publish')
  async publishExam(
    @CurrentSchoolId() schoolId: string,
    @Param('id') examId: string,
    @CurrentUser('name') userName: string,
  ) {
    const data = await this.examsService.publishExam(examId, schoolId, userName);
    return { data };
  }
}
