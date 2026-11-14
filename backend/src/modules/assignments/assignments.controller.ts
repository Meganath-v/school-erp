import { Controller, Get, Post, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { AssignmentsService } from './assignments.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ACADEMIC_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('assignments')
@UseGuards(JwtAuthGuard)
export class AssignmentsController {
  constructor(private assignmentsService: AssignmentsService) {}

  @Get()
  async getAssignments(
    @CurrentSchoolId() schoolId: string,
    @Query('classId') classId?: string,
    @Query('sectionId') sectionId?: string,
    @Query('teacherId') teacherId?: string,
  ) {
    const data = await this.assignmentsService.getAssignments(schoolId, { classId, sectionId, teacherId });
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Post()
  async createAssignment(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Body() body: any) {
    const data = await this.assignmentsService.createAssignment(schoolId, body, user);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Get(':id/submissions')
  async getSubmissions(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    const data = await this.assignmentsService.getSubmissions(schoolId, id);
    return { data };
  }

  @Roles('PARENT', 'STUDENT')
  @Post(':id/submissions')
  async submitAssignment(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() user: any,
    @Param('id') assignmentId: string,
    @Body() body: any,
  ) {
    const data = await this.assignmentsService.submitAssignment(schoolId, user, {
      assignmentId,
      studentId: body?.studentId,
      notes: body?.notes,
      fileUrl: body?.fileUrl,
    });
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Post('submissions/:id/grade')
  async gradeSubmission(@CurrentSchoolId() schoolId: string, @Param('id') submissionId: string, @Body() body: any) {
    const data = await this.assignmentsService.gradeSubmission(schoolId, submissionId, body);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Delete(':id')
  async deleteAssignment(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    const data = await this.assignmentsService.deleteAssignment(schoolId, id);
    return { data };
  }
}
