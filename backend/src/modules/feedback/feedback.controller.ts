import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { FeedbackService } from './feedback.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { SubmitFeedbackDto, RespondFeedbackDto, UpdateFeedbackStatusDto } from './feedback.dto';

@ApiTags('Parent & Student Feedback & Grievance Redressal')
@ApiBearerAuth()
@Controller('feedback')
@UseGuards(JwtAuthGuard)
export class FeedbackController {
  constructor(private feedbackService: FeedbackService) {}

  @Get()
  @ApiOperation({ summary: 'List feedback items visible to user (submitters see theirs, staff see school-wide)' })
  @ApiQuery({ name: 'category', required: false })
  @ApiQuery({ name: 'status', required: false })
  @ApiResponse({ status: 200, description: 'List of feedback entries' })
  async getFeedbacks(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @Query('category') category?: string,
    @Query('status') status?: string,
  ) {
    const data = await this.feedbackService.getFeedbacks(schoolId, userId, role, category, status);
    return { data };
  }

  @Post()
  @ApiOperation({ summary: 'Submit feedback, suggestions or grievances' })
  @ApiResponse({ status: 201, description: 'Feedback submitted successfully' })
  async submitFeedback(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Body() body: SubmitFeedbackDto,
  ) {
    const data = await this.feedbackService.submitFeedback(schoolId, userId, body);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Post(':id/respond')
  @ApiOperation({ summary: 'Respond to feedback and update resolution status' })
  @ApiParam({ name: 'id', description: 'Feedback UUID' })
  @ApiResponse({ status: 200, description: 'Response recorded' })
  async respondToFeedback(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('name') userName: string,
    @Param('id') id: string,
    @Body() body: RespondFeedbackDto,
  ) {
    const data = await this.feedbackService.respondToFeedback(
      schoolId,
      userId,
      userName || 'School Authority',
      id,
      body.response,
      body.status || 'RESOLVED',
    );
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Patch(':id/status')
  @ApiOperation({ summary: 'Update triage/resolution status of feedback' })
  @ApiParam({ name: 'id', description: 'Feedback UUID' })
  @ApiResponse({ status: 200, description: 'Status updated' })
  async updateStatus(
    @CurrentSchoolId() schoolId: string,
    @Param('id') id: string,
    @Body() body: UpdateFeedbackStatusDto,
  ) {
    const data = await this.feedbackService.updateFeedbackStatus(schoolId, id, body.status);
    return { data };
  }
}
