import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { RemindersService } from './reminders.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF, ALL_SCHOOL_ROLES, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateReminderDto, UpdateReminderStatusDto, TriggerWorkflowDto } from './reminders.dto';

@ApiTags('Automated Reminders, Triggers & Deadlines')
@ApiBearerAuth()
@Controller('reminders')
@UseGuards(JwtAuthGuard)
export class RemindersController {
  constructor(private remindersService: RemindersService) {}

  @Roles(...ALL_SCHOOL_ROLES)
  @Get()
  @ApiOperation({ summary: 'List user reminders with category and status filters' })
  @ApiQuery({ name: 'category', required: false, description: 'Category (e.g. FEE_DUE, ATTENDANCE_LOW, EXAM_MARK_ENTRY, CUSTOM)' })
  @ApiQuery({ name: 'status', required: false, description: 'Status (e.g. PENDING, SENT, COMPLETED, DISMISSED)' })
  @ApiResponse({ status: 200, description: 'List of reminders' })
  async getReminders(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Query('category') category?: string,
    @Query('status') status?: string,
  ) {
    const data = await this.remindersService.getReminders(schoolId, userId, category, status);
    return { data };
  }

  @Roles(...ALL_SCHOOL_ROLES)
  @Post()
  @ApiOperation({ summary: 'Schedule a custom reminder with priority and due date' })
  @ApiResponse({ status: 201, description: 'Reminder scheduled successfully' })
  async createReminder(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Body() body: CreateReminderDto,
  ) {
    const data = await this.remindersService.createReminder(schoolId, userId, body);
    return { data };
  }

  @Roles(...ALL_SCHOOL_ROLES)
  @Patch(':id/status')
  @ApiOperation({ summary: 'Update reminder status (COMPLETED, DISMISSED, etc.)' })
  @ApiParam({ name: 'id', description: 'Reminder UUID' })
  @ApiResponse({ status: 200, description: 'Reminder status updated' })
  async updateStatus(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() body: UpdateReminderStatusDto,
  ) {
    const data = await this.remindersService.updateReminderStatus(schoolId, userId, id, body.status);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Post('trigger-automated')
  @ApiOperation({ summary: 'Trigger backend evaluation engine for all 7 reminder conditions with timezone-aware dedup' })
  @ApiResponse({ status: 200, description: 'Automated reminders triggered and summary returned' })
  async triggerAutomated(
    @CurrentSchoolId() schoolId: string,
    @Body() body?: TriggerWorkflowDto,
  ) {
    const data = await this.remindersService.triggerAutomatedReminders(schoolId, { force: body?.force });
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Get('delivery-logs')
  @ApiOperation({ summary: 'Inspect notification and reminder delivery logs, failure reasons, and attempts' })
  @ApiQuery({ name: 'limit', required: false })
  @ApiResponse({ status: 200, description: 'Delivery audit logs retrieved' })
  async getDeliveryLogs(
    @CurrentSchoolId() schoolId: string,
    @Query('limit') limit?: number,
  ) {
    const data = await this.remindersService.getDeliveryLogs(schoolId, limit ? Number(limit) : 50);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Post('retry-failed')
  @ApiOperation({ summary: 'Retry failed notification delivery attempts with retry counter increment' })
  @ApiResponse({ status: 200, description: 'Failed deliveries retried' })
  async retryFailed(@CurrentSchoolId() schoolId: string) {
    const data = await this.remindersService.retryFailedDeliveries(schoolId);
    return { data };
  }
}
