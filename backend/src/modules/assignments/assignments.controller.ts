import { Controller, Get, Post, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { AssignmentsService } from './assignments.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ACADEMIC_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateAssignmentDto, SubmitAssignmentDto, GradeSubmissionDto, AssignmentFilterDto } from './assignments.dto';

@ApiTags('Assignments & Student Submissions')
@ApiBearerAuth()
@Controller('assignments')
@UseGuards(JwtAuthGuard)
export class AssignmentsController {
  constructor(private assignmentsService: AssignmentsService) {}

  @Get()
  @ApiOperation({ summary: 'List assignments filtered by class, section or teacher' })
  @ApiResponse({ status: 200, description: 'List of assignments' })
  async getAssignments(
    @CurrentSchoolId() schoolId: string,
    @Query() query: AssignmentFilterDto,
  ) {
    const data = await this.assignmentsService.getAssignments(schoolId, {
      classId: query.classId,
      sectionId: query.sectionId,
      teacherId: query.teacherId,
    });
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Post()
  @ApiOperation({ summary: 'Create a new course assignment for a class or section' })
  @ApiResponse({ status: 201, description: 'Assignment created successfully' })
  async createAssignment(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Body() body: CreateAssignmentDto) {
    const data = await this.assignmentsService.createAssignment(schoolId, body, user);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Get(':id/submissions')
  @ApiOperation({ summary: 'Get all student submissions for an assignment' })
  @ApiParam({ name: 'id', description: 'Assignment UUID' })
  @ApiResponse({ status: 200, description: 'List of student submissions' })
  async getSubmissions(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    const data = await this.assignmentsService.getSubmissions(schoolId, id);
    return { data };
  }

  @Roles('PARENT', 'STUDENT')
  @Post(':id/submissions')
  @ApiOperation({ summary: 'Submit an assignment on behalf of a student' })
  @ApiParam({ name: 'id', description: 'Assignment UUID' })
  @ApiResponse({ status: 201, description: 'Assignment submitted successfully' })
  async submitAssignment(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() user: any,
    @Param('id') assignmentId: string,
    @Body() body: SubmitAssignmentDto,
  ) {
    const data = await this.assignmentsService.submitAssignment(schoolId, user, {
      assignmentId,
      studentId: body.studentId,
      notes: body.notes,
      fileUrl: body.fileUrl,
    });
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Post('submissions/:id/grade')
  @ApiOperation({ summary: 'Grade and provide feedback on a student submission' })
  @ApiParam({ name: 'id', description: 'Submission UUID' })
  @ApiResponse({ status: 200, description: 'Submission graded successfully' })
  async gradeSubmission(
    @CurrentSchoolId() schoolId: string,
    @Param('id') submissionId: string,
    @Body() body: GradeSubmissionDto,
  ) {
    const data = await this.assignmentsService.gradeSubmission(schoolId, submissionId, body);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Delete(':id')
  @ApiOperation({ summary: 'Delete or archive an assignment' })
  @ApiParam({ name: 'id', description: 'Assignment UUID' })
  @ApiResponse({ status: 200, description: 'Assignment deleted' })
  async deleteAssignment(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    const data = await this.assignmentsService.deleteAssignment(schoolId, id);
    return { data };
  }
}
