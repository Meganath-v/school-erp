import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { LeaveService } from './leave.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('leave-requests')
@UseGuards(JwtAuthGuard)
export class LeaveController {
  constructor(private leaveService: LeaveService) {}

  @Get()
  async getLeaveRequests(@CurrentSchoolId() schoolId: string, @Query('studentId') studentId?: string) {
    const data = await this.leaveService.getLeaveRequests(schoolId, { studentId });
    return { data };
  }

  @Get('inbox')
  async getLeaveInbox(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
  ) {
    const data = await this.leaveService.getLeaveInbox(schoolId, { userId, role });
    return { data };
  }

  @Post()
  async createLeaveRequest(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('name') applicantName: string,
    @Body() body: any,
  ) {
    const data = await this.leaveService.createLeaveRequest(schoolId, {
      ...body,
      applicantName: body.applicantName || applicantName,
    });
    return { data };
  }

  @Post(':id/decision')
  async decideLeave(
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('name') userName: string,
    @Body() body: any,
  ) {
    const data = await this.leaveService.decideLeave(id, {
      ...body,
      decidedBy: body.decidedBy || userName,
      actorId: userId,
    });
    return { data };
  }
}
