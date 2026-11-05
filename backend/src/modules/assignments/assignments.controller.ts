import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { AssignmentsService } from './assignments.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';

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

  @Post()
  async createAssignment(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.assignmentsService.createAssignment(schoolId, body);
    return { data };
  }

  @Get(':id/submissions')
  async getSubmissions(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    const data = await this.assignmentsService.getSubmissions(schoolId, id);
    return { data };
  }

  @Post(':id/submissions')
  async submitAssignment(@Param('id') assignmentId: string, @Body() body: any) {
    const data = await this.assignmentsService.submitAssignment({ ...body, assignmentId });
    return { data };
  }

  @Post('submissions/:id/grade')
  async gradeSubmission(@Param('id') submissionId: string, @Body() body: any) {
    const data = await this.assignmentsService.gradeSubmission(submissionId, body);
    return { data };
  }
}
