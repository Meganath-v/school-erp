import { BadRequestException, Body, Controller, Delete, Get, NotFoundException, Param, Post, Put, Query, UseGuards, ServiceUnavailableException } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { ACADEMIC_STAFF, Roles, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { Actor, AiExamAccessService } from './ai-exam-access.service';
import { AiExamTestsService } from './ai-exam-tests.service';
import { AiExamStudentService } from './ai-exam-student.service';
import { AiExamAnalyticsService, AnalyticsFilter } from './ai-exam-analytics.service';
import { AiEvaluationService } from './ai-evaluation.service';
import { AiExamSettingsDto, AssignAiTestDto, EvaluateDto, OverrideMarksDto, SaveAiQuestionsDto, SaveAiTestDto, RescheduleAiTestDto, SaveAnswersDto, SubmitAnswersDto } from './ai-exam.dto';
import { AiNotConfiguredError, describeProvider } from './ai/ai-provider';

const optInt = (v?: string) => (v && /^\d+$/.test(v) ? Number(v) : undefined);
const filters = (q: Record<string, string | undefined>): AnalyticsFilter => ({
  classId: q.classId || undefined,
  sectionId: q.sectionId || undefined,
  subjectId: q.subjectId || undefined,
  testId: q.testId || undefined,
  academicYearId: q.academicYearId || undefined,
  from: q.from || undefined,
  to: q.to || undefined,
});

// ======================================================================== teachers

@ApiTags('AI Examination')
@ApiBearerAuth()
@Controller('ai-exams')
@UseGuards(JwtAuthGuard)
@Roles(...ACADEMIC_STAFF)
export class AiExamController {
  constructor(
    private tests: AiExamTestsService,
    private analytics: AiExamAnalyticsService,
  ) {}

  @ApiOperation({ summary: 'Classes 10-12, sections and subjects you can create tests for' })
  @Get('options')
  async options(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor) {
    return { data: await this.tests.options(schoolId, user) };
  }

  @ApiOperation({ summary: 'Teacher dashboard' })
  @Get('dashboard')
  async dashboard(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor) {
    return { data: await this.tests.dashboard(schoolId, user) };
  }

  @ApiOperation({ summary: 'Class / subject analytics (filters: classId, sectionId, subjectId, testId, academicYearId, from, to)' })
  @Get('analytics')
  async classAnalytics(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Query() q: Record<string, string>) {
    return { data: await this.analytics.classAnalytics(schoolId, user, filters(q)) };
  }

  @ApiOperation({ summary: 'One student\'s performance in your tests' })
  @Get('analytics/students/:studentId')
  async student(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('studentId') studentId: string) {
    return { data: await this.analytics.studentDrilldown(schoolId, user, studentId) };
  }

  @ApiOperation({ summary: 'Students of a class/section you teach (for assigning individual students)' })
  @Get('candidates')
  async candidates(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Query('classId') classId: string, @Query('sectionId') sectionId?: string) {
    if (!classId) throw new BadRequestException('classId is required');
    return { data: await this.tests.candidates(schoolId, user, classId, sectionId || undefined) };
  }

  @ApiOperation({ summary: 'Review an evaluation: set the marks (reason required)' })
  @Put('evaluations/:evaluationId/override')
  async override(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('evaluationId') id: string, @Body() dto: OverrideMarksDto) {
    return { data: await this.tests.override(schoolId, user, id, dto.marks, dto.reason) };
  }

  @ApiOperation({ summary: 'Accept the AI marks of an evaluation waiting for review' })
  @Post('evaluations/:evaluationId/accept')
  async accept(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('evaluationId') id: string) {
    return { data: await this.tests.accept(schoolId, user, id) };
  }

  @ApiOperation({ summary: 'Tests you manage' })
  @ApiQuery({ name: 'status', required: false })
  @Get()
  async list(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Query() q: Record<string, string>) {
    return this.tests.list(schoolId, user, { status: q.status, classId: q.classId, subjectId: q.subjectId, page: optInt(q.page), pageSize: optInt(q.pageSize) });
  }

  @ApiOperation({ summary: 'Create a test (draft)' })
  @Post()
  async create(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Body() dto: SaveAiTestDto) {
    return { data: await this.tests.create(schoolId, user, dto) };
  }

  @Get(':id')
  async get(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.tests.get(schoolId, user, id) };
  }

  @Put(':id')
  async update(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SaveAiTestDto) {
    return { data: await this.tests.update(schoolId, user, id, dto) };
  }

  @Delete(':id')
  async remove(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.tests.remove(schoolId, user, id) };
  }

  @ApiOperation({ summary: 'Replace the questions, answer keys and rubrics (until a student starts)' })
  @Post(':id/questions')
  async questions(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SaveAiQuestionsDto) {
    return { data: await this.tests.saveQuestions(schoolId, user, id, dto) };
  }

  @Post(':id/assignments')
  async assign(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: AssignAiTestDto) {
    return { data: await this.tests.assign(schoolId, user, id, dto) };
  }

  @Post(':id/publish')
  async publish(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.tests.publish(schoolId, user, id) };
  }

  @ApiOperation({ summary: 'Change start/end time (subject teacher, class teacher of the section, administrators); reopens a closed test' })
  @Post(':id/reschedule')
  async reschedule(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: RescheduleAiTestDto) {
    return { data: await this.tests.reschedule(schoolId, user, id, dto) };
  }

  @Post(':id/close')
  async close(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.tests.close(schoolId, user, id) };
  }

  @Post(':id/archive')
  async archive(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.tests.archive(schoolId, user, id) };
  }

  @ApiOperation({ summary: 'Release results to students (all answers evaluated, test ended)' })
  @Post(':id/publish-results')
  async publishResults(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.tests.publishResults(schoolId, user, id) };
  }

  @Get(':id/submissions')
  async submissions(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Query() q: Record<string, string>) {
    return this.tests.submissions(schoolId, user, id, { status: q.status, page: optInt(q.page), pageSize: optInt(q.pageSize) });
  }

  @Get(':id/submissions/:submissionId')
  async submission(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Param('submissionId') submissionId: string) {
    return { data: await this.tests.submission(schoolId, user, id, submissionId) };
  }

  @Get(':id/analytics')
  async analyticsForTest(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.analytics.testAnalytics(schoolId, user, id) };
  }
}

// ======================================================================== students

@ApiTags('AI Examination (students)')
@ApiBearerAuth()
@Controller('student/ai-exams')
@UseGuards(JwtAuthGuard)
@Roles('STUDENT')
export class StudentAiExamController {
  constructor(
    private student: AiExamStudentService,
    private analytics: AiExamAnalyticsService,
  ) {}

  @ApiOperation({ summary: 'Available, upcoming and completed tests' })
  @Get()
  async list(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string) {
    return { data: await this.student.list(schoolId, userId) };
  }

  @Get('performance')
  async performance(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string) {
    return { data: await this.analytics.myPerformance(schoolId, userId) };
  }

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Get('improvement-plan')
  async plan(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string, @Query('refresh') refresh?: string) {
    return { data: await this.analytics.myPlan(schoolId, userId, refresh === '1' || refresh === 'true') };
  }

  @Get(':id')
  async get(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string, @Param('id') id: string) {
    return { data: await this.student.get(schoolId, userId, id) };
  }

  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post(':id/start')
  async start(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string, @Param('id') id: string) {
    return { data: await this.student.start(schoolId, userId, id) };
  }

  @ApiOperation({ summary: 'Autosave answers' })
  @Put(':id/answers')
  async save(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string, @Param('id') id: string, @Body() dto: SaveAnswersDto) {
    return { data: await this.student.saveAnswers(schoolId, userId, id, dto) };
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post(':id/submit')
  async submit(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string, @Param('id') id: string, @Body() dto: SubmitAnswersDto) {
    return { data: await this.student.submit(schoolId, userId, id, dto?.answers?.length ? { answers: dto.answers } : undefined) };
  }

  @Get(':id/result')
  async result(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string, @Param('id') id: string) {
    return { data: await this.student.result(schoolId, userId, id) };
  }
}

// ======================================================================== evaluation

@ApiTags('AI Evaluation')
@ApiBearerAuth()
@Controller('ai-evaluation')
@UseGuards(JwtAuthGuard)
@Roles(...ACADEMIC_STAFF)
export class AiEvaluationController {
  constructor(
    private evaluation: AiEvaluationService,
    private tests: AiExamTestsService,
    private access: AiExamAccessService,
    private prisma: PrismaService,
  ) {}

  @ApiOperation({ summary: 'AI provider status (no secrets)' })
  @Get('config')
  config() {
    return { data: describeProvider() };
  }

  @ApiOperation({ summary: 'Run (or retry) AI evaluation for a submission or a whole test' })
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('evaluate')
  async evaluate(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Body() dto: EvaluateDto) {
    let testId = dto.testId;
    if (dto.submissionId) {
      const sub = await this.prisma.aiExamSubmission.findFirst({ where: { id: dto.submissionId, schoolId }, select: { testId: true } });
      if (!sub) throw new NotFoundException('Submission not found');
      testId = sub.testId;
    }
    if (!testId) throw new BadRequestException('Give submissionId or testId');
    await this.access.manageableTest(schoolId, user, testId);
    try {
      const r = await this.evaluation.requeue({ answer: { submission: { testId, schoolId, ...(dto.submissionId && { id: dto.submissionId }), status: 'SUBMITTED' } } }, user.userId);
      return { data: r };
    } catch (e) {
      if (e instanceof AiNotConfiguredError) throw new ServiceUnavailableException(e.message);
      throw e;
    }
  }

  @Get('status/:submissionId')
  async status(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('submissionId') submissionId: string) {
    const sub = await this.prisma.aiExamSubmission.findFirst({ where: { id: submissionId, schoolId }, select: { testId: true, evaluationStatus: true, score: true, maxScore: true } });
    if (!sub) throw new NotFoundException('Submission not found');
    await this.access.manageableTest(schoolId, user, sub.testId);
    const byStatus = await this.prisma.aiExamEvaluation.groupBy({ by: ['status'], where: { answer: { submissionId } }, _count: true });
    return { data: { submissionId, evaluationStatus: sub.evaluationStatus, score: sub.score, maxScore: sub.maxScore, answers: Object.fromEntries(byStatus.map((b) => [b.status, b._count])) } };
  }
}

// ======================================================================== administrators

@ApiTags('AI Examination (admin)')
@ApiBearerAuth()
@Controller('admin/ai-exams')
@UseGuards(JwtAuthGuard)
@Roles(...SCHOOL_ADMINS)
export class AdminAiExamController {
  constructor(
    private analytics: AiExamAnalyticsService,
    private tests: AiExamTestsService,
  ) {}

  @Get('overview')
  async overview(@CurrentSchoolId() schoolId: string) {
    return { data: await this.analytics.adminOverview(schoolId) };
  }

  @Get('analytics')
  async analyticsAll(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Query() q: Record<string, string>) {
    return { data: await this.analytics.classAnalytics(schoolId, user, filters(q)) };
  }

  @ApiOperation({ summary: 'Monitor tests across Classes 10-12' })
  @Get('tests')
  async monitor(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Query() q: Record<string, string>) {
    return this.tests.list(schoolId, user, { status: q.status, classId: q.classId, subjectId: q.subjectId, page: optInt(q.page), pageSize: optInt(q.pageSize) });
  }

  @Put('settings')
  async settings(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Body() dto: AiExamSettingsDto) {
    return { data: await this.analytics.saveSettings(schoolId, user, dto) };
  }
}

