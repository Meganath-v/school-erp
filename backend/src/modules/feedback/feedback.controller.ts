import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { FeedbackService } from './feedback.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('feedback')
@UseGuards(JwtAuthGuard)
export class FeedbackController {
  constructor(private feedbackService: FeedbackService) {}

  @Get()
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
  async submitFeedback(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Body() body: any,
  ) {
    const data = await this.feedbackService.submitFeedback(schoolId, userId, body);
    return { data };
  }

  @Post(':id/respond')
  async respondToFeedback(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('name') userName: string,
    @Param('id') id: string,
    @Body('response') response: string,
    @Body('status') status?: string,
  ) {
    const data = await this.feedbackService.respondToFeedback(
      schoolId,
      userId,
      userName || 'School Authority',
      id,
      response,
      status || 'RESOLVED',
    );
    return { data };
  }

  @Patch(':id/status')
  async updateStatus(
    @CurrentSchoolId() schoolId: string,
    @Param('id') id: string,
    @Body('status') status: string,
  ) {
    const data = await this.feedbackService.updateFeedbackStatus(schoolId, id, status);
    return { data };
  }
}

