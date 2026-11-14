import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { LeaveService } from './leave.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateLeaveRequestDto, DecideLeaveDto } from './leave.dto';

@ApiTags('Student Leave Applications & Approval Workflow')
@ApiBearerAuth()
@Controller('leave-requests')
@UseGuards(JwtAuthGuard)
export class LeaveController {
  constructor(private leaveService: LeaveService) {}

  @Roles(...ALL_STAFF, 'PARENT', 'STUDENT')
  @Get()
  @ApiOperation({ summary: 'List student leave applications with optional student filter' })
  @ApiQuery({ name: 'studentId', required: false, description: 'Student UUID' })
  @ApiResponse({ status: 200, description: 'List of leave applications' })
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
  @ApiOperation({ summary: 'Get pending leave requests pending review for teacher assigned sections' })
  @ApiResponse({ status: 200, description: 'Pending leave inbox' })
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
  @ApiOperation({ summary: 'Submit a new student leave application' })
  @ApiResponse({ status: 201, description: 'Leave request submitted successfully' })
  async createLeaveRequest(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() user: any,
    @Body() body: CreateLeaveRequestDto,
  ) {
    const data = await this.leaveService.createLeaveRequest(schoolId, user, {
      studentId: body.studentId,
      startDate: body.startDate,
      endDate: body.endDate,
      reason: body.reason,
      applicantName: user.name,
    });
    return { data };
  }

  @Roles('CLASS_TEACHER', ...SCHOOL_ADMINS)
  @Post(':id/decision')
  @ApiOperation({ summary: 'Approve or reject a student leave application' })
  @ApiParam({ name: 'id', description: 'LeaveRequest UUID' })
  @ApiResponse({ status: 200, description: 'Leave decision recorded' })
  async decideLeave(
    @CurrentSchoolId() schoolId: string,
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('name') userName: string,
    @Body() body: DecideLeaveDto,
  ) {
    const data = await this.leaveService.decideLeave(schoolId, id, {
      status: body.status,
      remarks: body.remarks,
      decidedBy: userName,
      actorId: userId,
    });
    return { data };
  }
}
