import { Body, Controller, Delete, Get, Param, Patch, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { ACADEMIC_STAFF, Roles, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Actor, OutcomesService } from './outcomes.service';
import {
  CreateOutcomeForSubjectDto,
  CreateProgramDto,
  CreateProgramOutcomeDto,
  CreateQuestionDto,
  SaveAttainmentRuleDto,
  SaveIndirectDto,
  SaveMappingDto,
  SavePaperDto,
  SaveQuestionMarksDto,
  SetAssessmentTypeDto,
  SetProgramClassesDto,
  UpdateCourseOutcomeDto,
  UpdateProgramDto,
  UpdateProgramOutcomeDto,
  UpdateQuestionDto,
} from './outcomes.dto';

/**
 * Outcome-based education: programs and their outcomes, course outcomes and CO-PO
 * mapping, the question bank, question papers, question-wise marks and attainment.
 * Read access: academic staff. Programs/school defaults: school admins. Subject-level
 * changes: school admins, or teachers assigned to that subject.
 */
@ApiTags('Outcome-Based Education')
@ApiBearerAuth()
@Controller('outcomes')
@UseGuards(JwtAuthGuard)
@Roles(...ACADEMIC_STAFF)
export class OutcomesController {
  constructor(private service: OutcomesService) {}

  // ------------------------------------------------------------ programs

  @ApiOperation({ summary: 'List programs with their outcomes (PO/PSO/PEO) and classes' })
  @Get('programs')
  async listPrograms(@CurrentSchoolId() schoolId: string) {
    return { data: await this.service.listPrograms(schoolId) };
  }

  @ApiOperation({ summary: 'Get one program with its outcomes' })
  @Get('programs/:id')
  async getProgram(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    return { data: await this.service.getProgram(schoolId, id) };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Create a program' })
  @Post('programs')
  async createProgram(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Body() dto: CreateProgramDto) {
    return { data: await this.service.createProgram(schoolId, dto, user) };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Update a program' })
  @Patch('programs/:id')
  async updateProgram(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: UpdateProgramDto) {
    return { data: await this.service.updateProgram(schoolId, id, dto, user) };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Delete a program and its outcomes (classes are kept, unlinked)' })
  @Delete('programs/:id')
  async deleteProgram(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.service.deleteProgram(schoolId, id, user) };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Set which classes belong to a program (replaces the list)' })
  @Put('programs/:id/classes')
  async setProgramClasses(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SetProgramClassesDto) {
    return { data: await this.service.setProgramClasses(schoolId, id, dto.classIds, user) };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Add a PO / PSO / PEO to a program' })
  @Post('programs/:id/outcomes')
  async createProgramOutcome(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: CreateProgramOutcomeDto) {
    return { data: await this.service.createProgramOutcome(schoolId, id, dto, user) };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Update a program outcome' })
  @Patch('program-outcomes/:id')
  async updateProgramOutcome(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: UpdateProgramOutcomeDto) {
    return { data: await this.service.updateProgramOutcome(schoolId, id, dto, user) };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Delete a program outcome (its CO mappings are removed)' })
  @Delete('program-outcomes/:id')
  async deleteProgramOutcome(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.service.deleteProgramOutcome(schoolId, id, user) };
  }

  @ApiOperation({ summary: 'Program-level PO attainment averaged over its courses' })
  @Get('programs/:id/attainment')
  async programAttainment(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    return { data: await this.service.programAttainment(schoolId, id) };
  }

  // ------------------------------------------------------------ school default rule

  @ApiOperation({ summary: 'School-wide default attainment rule' })
  @Get('attainment-rule')
  async getSchoolRule(@CurrentSchoolId() schoolId: string) {
    return { data: await this.service.getRule(schoolId) };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Save the school-wide default attainment rule' })
  @Put('attainment-rule')
  async saveSchoolRule(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Body() dto: SaveAttainmentRuleDto) {
    return { data: await this.service.saveRule(schoolId, null, dto, user) };
  }

  // ------------------------------------------------------------ subjects

  @ApiOperation({ summary: 'Subjects the caller can see, with outcome and question counts' })
  @Get('subjects')
  async listSubjects(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor) {
    return { data: await this.service.listSubjects(schoolId, user) };
  }

  @ApiOperation({ summary: 'Course outcomes of a subject' })
  @Get('subjects/:subjectId/course-outcomes')
  async listCourseOutcomes(@CurrentSchoolId() schoolId: string, @Param('subjectId') subjectId: string) {
    return { data: await this.service.listCourseOutcomes(schoolId, subjectId) };
  }

  @ApiOperation({ summary: 'Add a course outcome to a subject' })
  @Post('subjects/:subjectId/course-outcomes')
  async createCourseOutcome(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('subjectId') subjectId: string, @Body() dto: CreateOutcomeForSubjectDto) {
    return { data: await this.service.createCourseOutcome(schoolId, subjectId, dto, user) };
  }

  @ApiOperation({ summary: 'Update a course outcome' })
  @Patch('course-outcomes/:id')
  async updateCourseOutcome(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: UpdateCourseOutcomeDto) {
    return { data: await this.service.updateCourseOutcome(schoolId, id, dto, user) };
  }

  @ApiOperation({ summary: 'Delete a course outcome (questions stay, unmapped)' })
  @Delete('course-outcomes/:id')
  async deleteCourseOutcome(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.service.deleteCourseOutcome(schoolId, id, user) };
  }

  @ApiOperation({ summary: 'CO × PO correlation matrix for a subject' })
  @ApiQuery({ name: 'programId', required: false })
  @Get('subjects/:subjectId/mapping')
  async getMapping(@CurrentSchoolId() schoolId: string, @Param('subjectId') subjectId: string, @Query('programId') programId?: string) {
    return { data: await this.service.getMapping(schoolId, subjectId, programId) };
  }

  @ApiOperation({ summary: 'Save CO-PO correlations (strength 0 removes a link)' })
  @Put('subjects/:subjectId/mapping')
  async saveMapping(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('subjectId') subjectId: string, @Body() dto: SaveMappingDto) {
    return { data: await this.service.saveMapping(schoolId, subjectId, dto, user) };
  }

  @ApiOperation({ summary: 'Save course exit survey (indirect) levels per course outcome' })
  @Put('subjects/:subjectId/indirect')
  async saveIndirect(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('subjectId') subjectId: string, @Body() dto: SaveIndirectDto) {
    return { data: await this.service.saveIndirect(schoolId, subjectId, dto, user) };
  }

  @ApiOperation({ summary: 'Effective attainment rule for a subject' })
  @Get('subjects/:subjectId/attainment-rule')
  async getSubjectRule(@CurrentSchoolId() schoolId: string, @Param('subjectId') subjectId: string) {
    return { data: await this.service.getRule(schoolId, subjectId) };
  }

  @ApiOperation({ summary: 'Save a subject-specific attainment rule' })
  @Put('subjects/:subjectId/attainment-rule')
  async saveSubjectRule(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('subjectId') subjectId: string, @Body() dto: SaveAttainmentRuleDto) {
    return { data: await this.service.saveRule(schoolId, subjectId, dto, user) };
  }

  @ApiOperation({ summary: 'Remove the subject rule (falls back to the school default)' })
  @Delete('subjects/:subjectId/attainment-rule')
  async deleteSubjectRule(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('subjectId') subjectId: string) {
    return { data: await this.service.deleteSubjectRule(schoolId, subjectId, user) };
  }

  @ApiOperation({ summary: 'CO and PO attainment report for a subject' })
  @ApiQuery({ name: 'classId', required: false })
  @ApiQuery({ name: 'programId', required: false })
  @Get('subjects/:subjectId/attainment')
  async subjectAttainment(
    @CurrentSchoolId() schoolId: string,
    @Param('subjectId') subjectId: string,
    @Query('classId') classId?: string,
    @Query('programId') programId?: string,
  ) {
    return { data: await this.service.subjectAttainment(schoolId, subjectId, { classId, programId }) };
  }

  // ------------------------------------------------------------ question bank

  @ApiOperation({ summary: 'Question bank of a subject' })
  @ApiQuery({ name: 'courseOutcomeId', required: false })
  @ApiQuery({ name: 'bloomLevel', required: false })
  @ApiQuery({ name: 'search', required: false })
  @Get('subjects/:subjectId/questions')
  async listQuestions(
    @CurrentSchoolId() schoolId: string,
    @Param('subjectId') subjectId: string,
    @Query('courseOutcomeId') courseOutcomeId?: string,
    @Query('bloomLevel') bloomLevel?: string,
    @Query('search') search?: string,
  ) {
    return { data: await this.service.listQuestions(schoolId, subjectId, { courseOutcomeId, bloomLevel, search }) };
  }

  @ApiOperation({ summary: 'Add a question to the bank' })
  @Post('subjects/:subjectId/questions')
  async createQuestion(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('subjectId') subjectId: string, @Body() dto: CreateQuestionDto) {
    return { data: await this.service.createQuestion(schoolId, subjectId, dto, user) };
  }

  @ApiOperation({ summary: 'Update a bank question' })
  @Patch('questions/:id')
  async updateQuestion(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: UpdateQuestionDto) {
    return { data: await this.service.updateQuestion(schoolId, id, dto, user) };
  }

  @ApiOperation({ summary: 'Delete a bank question (refused while used in a paper)' })
  @Delete('questions/:id')
  async deleteQuestion(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.service.deleteQuestion(schoolId, id, user) };
  }

  // ------------------------------------------------------------ assessments & papers

  @ApiOperation({ summary: 'Exam subjects and assignments of a subject that can carry a question paper' })
  @Get('subjects/:subjectId/assessments')
  async listAssessments(@CurrentSchoolId() schoolId: string, @Param('subjectId') subjectId: string) {
    return { data: await this.service.listAssessments(schoolId, subjectId) };
  }

  @ApiOperation({ summary: 'Mark an exam subject as internal or external assessment' })
  @Patch('exam-subjects/:id/assessment-type')
  async setAssessmentType(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SetAssessmentTypeDto) {
    return { data: await this.service.setAssessmentType(schoolId, id, dto.assessmentType, user) };
  }

  @ApiOperation({ summary: 'Question paper of an exam subject' })
  @Get('exam-subjects/:id/paper')
  async getExamPaper(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    return { data: await this.service.getPaper(schoolId, { kind: 'exam', examSubjectId: id }) };
  }

  @ApiOperation({ summary: 'Create or replace the question paper of an exam subject' })
  @Put('exam-subjects/:id/paper')
  async saveExamPaper(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SavePaperDto) {
    return { data: await this.service.savePaper(schoolId, { kind: 'exam', examSubjectId: id }, dto, user) };
  }

  @ApiOperation({ summary: 'Delete the question paper of an exam subject' })
  @Delete('exam-subjects/:id/paper')
  async deleteExamPaper(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.service.deletePaper(schoolId, { kind: 'exam', examSubjectId: id }, user) };
  }

  @ApiOperation({ summary: 'Question-wise marks roster for an exam subject' })
  @Get('exam-subjects/:id/marks')
  async getExamMarks(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    return { data: await this.service.getPaperMarks(schoolId, { kind: 'exam', examSubjectId: id }) };
  }

  @ApiOperation({ summary: 'Save question-wise marks for an exam subject (totals sync to exam marks)' })
  @Put('exam-subjects/:id/marks')
  async saveExamMarks(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SaveQuestionMarksDto) {
    return { data: await this.service.saveMarks(schoolId, { kind: 'exam', examSubjectId: id }, dto, user) };
  }

  @ApiOperation({ summary: 'Question paper of an assignment' })
  @Get('assignments/:id/paper')
  async getAssignmentPaper(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    return { data: await this.service.getPaper(schoolId, { kind: 'assignment', assignmentId: id }) };
  }

  @ApiOperation({ summary: 'Create or replace the question paper of an assignment' })
  @Put('assignments/:id/paper')
  async saveAssignmentPaper(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SavePaperDto) {
    return { data: await this.service.savePaper(schoolId, { kind: 'assignment', assignmentId: id }, dto, user) };
  }

  @ApiOperation({ summary: 'Delete the question paper of an assignment' })
  @Delete('assignments/:id/paper')
  async deleteAssignmentPaper(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string) {
    return { data: await this.service.deletePaper(schoolId, { kind: 'assignment', assignmentId: id }, user) };
  }

  @ApiOperation({ summary: 'Question-wise marks roster for an assignment' })
  @Get('assignments/:id/marks')
  async getAssignmentMarks(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    return { data: await this.service.getPaperMarks(schoolId, { kind: 'assignment', assignmentId: id }) };
  }

  @ApiOperation({ summary: 'Save question-wise marks for an assignment (totals sync to submissions)' })
  @Put('assignments/:id/marks')
  async saveAssignmentMarks(@CurrentSchoolId() schoolId: string, @CurrentUser() user: Actor, @Param('id') id: string, @Body() dto: SaveQuestionMarksDto) {
    return { data: await this.service.saveMarks(schoolId, { kind: 'assignment', assignmentId: id }, dto, user) };
  }
}
