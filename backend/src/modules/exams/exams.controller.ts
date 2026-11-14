import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { ExamsService } from './exams.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ACADEMIC_STAFF, ALL_STAFF, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateExamDto, AddExamSubjectDto, EnterMarksDto, ImportMarksDto } from './exams.dto';

@ApiTags('Examinations, Marks & Grade Broadsheets')
@ApiBearerAuth()
@Controller('exams')
@UseGuards(JwtAuthGuard)
export class ExamsController {
  constructor(private examsService: ExamsService) {}

  @Roles(...ALL_STAFF)
  @Get()
  @ApiOperation({ summary: 'List all examinations scheduled or published for this school' })
  @ApiResponse({ status: 200, description: 'List of exams' })
  async getExams(@CurrentSchoolId() schoolId: string) {
    const data = await this.examsService.getExams(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Post()
  @ApiOperation({ summary: 'Create and schedule a new examination series' })
  @ApiResponse({ status: 201, description: 'Exam created successfully' })
  async createExam(@CurrentSchoolId() schoolId: string, @Body() body: CreateExamDto) {
    const data = await this.examsService.createExam(schoolId, body);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Post(':id/subjects')
  @ApiOperation({ summary: 'Add a subject schedule and max/pass marks configuration to an exam' })
  @ApiParam({ name: 'id', description: 'Exam UUID' })
  @ApiResponse({ status: 201, description: 'Subject added to exam' })
  async addExamSubject(@CurrentSchoolId() schoolId: string, @Param('id') examId: string, @Body() body: AddExamSubjectDto) {
    const data = await this.examsService.addExamSubject(schoolId, examId, body);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Get('subjects/:subjectId/details')
  @ApiOperation({ summary: 'Get subject details, enrolled class roster, and entered marks' })
  @ApiParam({ name: 'subjectId', description: 'ExamSubject UUID' })
  @ApiResponse({ status: 200, description: 'Exam subject details and marks entries' })
  async getExamSubjectDetails(@CurrentSchoolId() schoolId: string, @Param('subjectId') subjectId: string) {
    const data = await this.examsService.getExamSubjectDetails(schoolId, subjectId);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Post('subjects/:subjectId/marks')
  @ApiOperation({ summary: 'Atomically enter and persist marks for students enrolled in this exam subject' })
  @ApiParam({ name: 'subjectId', description: 'ExamSubject UUID' })
  @ApiResponse({ status: 201, description: 'Marks recorded successfully' })
  async enterMarks(
    @CurrentSchoolId() schoolId: string,
    @Param('subjectId') subjectId: string,
    @Body() body: EnterMarksDto,
  ) {
    const data = await this.examsService.enterMarks(schoolId, subjectId, body.marks);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Get('subjects/:subjectId/template')
  @ApiOperation({ summary: 'Export CSV marks entry template with enrolled student admission numbers' })
  @ApiParam({ name: 'subjectId', description: 'ExamSubject UUID' })
  @ApiResponse({ status: 200, description: 'Template data with student rosters' })
  async exportTemplate(@CurrentSchoolId() schoolId: string, @Param('subjectId') subjectId: string) {
    const data = await this.examsService.exportTemplate(schoolId, subjectId);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Post('subjects/:subjectId/import')
  @ApiOperation({ summary: 'Bulk import marks from parsed spreadsheet rows' })
  @ApiParam({ name: 'subjectId', description: 'ExamSubject UUID' })
  @ApiResponse({ status: 201, description: 'Marks imported successfully' })
  async importMarks(
    @CurrentSchoolId() schoolId: string,
    @Param('subjectId') subjectId: string,
    @Body() body: ImportMarksDto,
  ) {
    const data = await this.examsService.importMarksFromData(schoolId, subjectId, body.rows);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Get(':id/classes/:classId/broadsheet')
  @ApiOperation({ summary: 'Generate class broadsheet with subject-wise marks, ranks, and percentages' })
  @ApiParam({ name: 'id', description: 'Exam UUID' })
  @ApiParam({ name: 'classId', description: 'Class UUID' })
  @ApiResponse({ status: 200, description: 'Broadsheet data' })
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
  @ApiOperation({ summary: 'Publish exam results to parents and generate audit event' })
  @ApiParam({ name: 'id', description: 'Exam UUID' })
  @ApiResponse({ status: 200, description: 'Exam results published' })
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
