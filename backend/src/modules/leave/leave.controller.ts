import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { LeaveService } from './leave.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('leave-requests')
@UseGuards(JwtAuthGuard)
export class LeaveController {
  constructor(private leaveService: LeaveService) {}

  @Roles(...ALL_STAFF, 'PARENT', 'STUDENT')
  @Get()
  async getLeaveRequests(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @Query('studentId') studentId?: string,
  ) {
    const data = await this.leaveService.getLeaveRequests(schoolId, { studentId, userId, role });
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Get('inbox')
  async getLeaveInbox(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
  ) {
    const data = await this.leaveService.getLeaveInbox(schoolId, { userId, role });
    return { data };
  }

  @Roles(...ALL_STAFF, 'PARENT', 'STUDENT')
  @Post()
  async createLeaveRequest(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() user: any,
    @Body() body: any,
  ) {
    const data = await this.leaveService.createLeaveRequest(schoolId, user, {
      studentId: body?.studentId,
      startDate: body?.startDate,
      endDate: body?.endDate,
      reason: body?.reason,
      applicantName: user.name,
    });
    return { data };
  }

  @Roles('CLASS_TEACHER', ...SCHOOL_ADMINS)
  @Post(':id/decision')
  async decideLeave(
    @CurrentSchoolId() schoolId: string,
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('name') userName: string,
    @Body() body: any,
  ) {
    // Who decided is always the authenticated caller, never a client-supplied name.
    const data = await this.leaveService.decideLeave(schoolId, id, {
      status: body?.status,
      remarks: body?.remarks,
      decidedBy: userName,
      actorId: userId,
    });
    return { data };
  }
}
