import { Body, Controller, Delete, Get, Param, ParseFloatPipe, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { ACADEMIC_STAFF, Roles } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Actor, InternalAssessmentService } from './internal-assessment.service';
import { QuizzesService } from './quizzes.service';
import { SaveManualMarksDto, SaveQuizDto, SaveSchemeDto, SetQuizQuestionsDto, SubmitQuizDto } from './internal-assessment.dto';

@ApiTags('Internal Assessment')
@ApiBearerAuth()
@Controller('internal-assessment')
@UseGuards(JwtAuthGuard)
@Roles(...ACADEMIC_STAFF)
export class InternalAssessmentController {
  constructor(private service: InternalAssessmentService) {}

  @ApiOperation({ summary: 'Internal mark schemes of a subject' })
  @Get('subjects/:subjectId/schemes')
  async list(@CurrentSchoolId() schoolId: string, @Param('subjectId') subjectId: string) {
    return { data: await this.service.listSchemes(schoolId, subjectId) };
  }

  @ApiOperation({ summary: 'Create an internal mark scheme' })
  @Post('subjects/:subjectId/schemes')
  async create(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('subjectId') subjectId: string, @Body() dto: SaveSchemeDto) {
    return { data: await this.service.createScheme(schoolId, subjectId, dto, user) };
  }

  @ApiOperation({ summary: 'Update an internal mark scheme (components with an id keep their manual marks)' })
  @Put('schemes/:id')
  async update(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SaveSchemeDto) {
    return { data: await this.service.updateScheme(schoolId, id, dto, user) };
  }

  @ApiOperation({ summary: 'Delete an internal mark scheme' })
  @Delete('schemes/:id')
  async remove(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.service.deleteScheme(schoolId, id, user) };
  }

  @ApiOperation({ summary: 'Internal mark sheet for a class' })
  @ApiQuery({ name: 'classId', required: false })
  @Get('schemes/:id/sheet')
  async sheet(@CurrentSchoolId() schoolId: string, @Param('id') id: string, @Query('classId') classId?: string) {
    return { data: await this.service.sheet(schoolId, id, classId) };
  }

  @ApiOperation({ summary: 'Enter marks for a manual component (e.g. class participation)' })
  @Put('components/:id/manual-marks')
  async manual(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SaveManualMarksDto) {
    return { data: await this.service.saveManualMarks(schoolId, id, dto, user) };
  }

  @ApiOperation({ summary: 'Students below a threshold on an exam subject or an internal mark scheme' })
  @ApiQuery({ name: 'examSubjectId', required: false })
  @ApiQuery({ name: 'schemeId', required: false })
  @ApiQuery({ name: 'classId', required: false })
  @ApiQuery({ name: 'threshold', required: false })
  @Get('weak-students')
  async weak(
    @CurrentSchoolId() schoolId: string,
    @Query('examSubjectId') examSubjectId?: string,
    @Query('schemeId') schemeId?: string,
    @Query('classId') classId?: string,
    @Query('threshold', new ParseFloatPipe({ optional: true })) threshold?: number,
  ) {
    return { data: await this.service.weakStudents(schoolId, { examSubjectId, schemeId, classId, threshold }) };
  }
}

@ApiTags('Quizzes')
@ApiBearerAuth()
@Controller('quizzes')
@UseGuards(JwtAuthGuard)
export class QuizzesController {
  constructor(private service: QuizzesService) {}

  // ---------------- students (declared first so /mine is not read as an id)

  @Roles('STUDENT')
  @ApiOperation({ summary: 'Quizzes for the signed-in student' })
  @Get('mine')
  async mine(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string) {
    return { data: await this.service.myQuizzes(schoolId, userId) };
  }

  @Roles('STUDENT')
  @ApiOperation({ summary: 'Start or resume a quiz (questions without answers)' })
  @Post(':id/start')
  async start(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string, @Param('id') id: string) {
    return { data: await this.service.start(schoolId, userId, id) };
  }

  @Roles('STUDENT')
  @ApiOperation({ summary: 'Submit answers; graded immediately' })
  @Post(':id/submit')
  async submit(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string, @Param('id') id: string, @Body() dto: SubmitQuizDto) {
    return { data: await this.service.submit(schoolId, userId, id, dto.answers) };
  }

  // ---------------- staff

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Quizzes of a subject' })
  @Get()
  async list(@CurrentSchoolId() schoolId: string, @Query('subjectId') subjectId: string) {
    return { data: await this.service.list(schoolId, subjectId) };
  }

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Create a quiz (draft)' })
  @Post()
  async create(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Body() dto: SaveQuizDto) {
    return { data: await this.service.create(schoolId, dto, user) };
  }

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Quiz with its questions and answers (staff)' })
  @Get(':id')
  async get(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    return { data: await this.service.get(schoolId, id) };
  }

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Update quiz details' })
  @Put(':id')
  async update(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SaveQuizDto) {
    return { data: await this.service.update(schoolId, id, dto, user) };
  }

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Set quiz questions (multiple-choice questions from the bank)' })
  @Put(':id/questions')
  async questions(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SetQuizQuestionsDto) {
    return { data: await this.service.setQuestions(schoolId, id, dto, user) };
  }

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Publish a quiz to students' })
  @Post(':id/publish')
  async publish(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.service.setStatus(schoolId, id, 'PUBLISHED', user) };
  }

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Close a quiz' })
  @Post(':id/close')
  async close(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.service.setStatus(schoolId, id, 'CLOSED', user) };
  }

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Delete a quiz and its attempts' })
  @Delete(':id')
  async remove(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.service.remove(schoolId, id, user) };
  }

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Quiz results by student' })
  @Get(':id/results')
  async results(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    return { data: await this.service.results(schoolId, id) };
  }
}
