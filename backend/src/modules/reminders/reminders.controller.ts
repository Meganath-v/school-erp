import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { RemindersService } from './reminders.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateReminderDto, UpdateReminderStatusDto } from './reminders.dto';

@ApiTags('Automated Reminders & Deadlines')
@ApiBearerAuth()
@Controller('reminders')
@UseGuards(JwtAuthGuard)
export class RemindersController {
  constructor(private remindersService: RemindersService) {}

  @Get()
  @ApiOperation({ summary: 'List user reminders with optional category filter' })
  @ApiQuery({ name: 'category', required: false })
  @ApiResponse({ status: 200, description: 'List of reminders' })
  async getReminders(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Query('category') category?: string,
  ) {
    const data = await this.remindersService.getReminders(schoolId, userId, category);
    return { data };
  }

  @Post()
  @ApiOperation({ summary: 'Schedule a custom reminder' })
  @ApiResponse({ status: 201, description: 'Reminder scheduled successfully' })
  async createReminder(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Body() body: CreateReminderDto,
  ) {
    const data = await this.remindersService.createReminder(schoolId, userId, body);
    return { data };
  }

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
  @ApiOperation({ summary: 'Trigger automated fee due and attendance threshold reminders' })
  @ApiResponse({ status: 200, description: 'Automated reminders triggered' })
  async triggerAutomated(@CurrentSchoolId() schoolId: string) {
    const data = await this.remindersService.triggerAutomatedReminders(schoolId);
    return { data };
  }
}
