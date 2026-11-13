import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { RemindersService } from './reminders.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('reminders')
@UseGuards(JwtAuthGuard)
export class RemindersController {
  constructor(private remindersService: RemindersService) {}

  @Get()
  async getReminders(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Query('category') category?: string,
  ) {
    const data = await this.remindersService.getReminders(schoolId, userId, category);
    return { data };
  }

  @Post()
  async createReminder(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Body() body: any,
  ) {
    const data = await this.remindersService.createReminder(schoolId, userId, body);
    return { data };
  }

  @Patch(':id/status')
  async updateStatus(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body('status') status: string,
  ) {
    const data = await this.remindersService.updateReminderStatus(schoolId, userId, id, status);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Post('trigger-automated')
  async triggerAutomated(@CurrentSchoolId() schoolId: string) {
    const data = await this.remindersService.triggerAutomatedReminders(schoolId);
    return { data };
  }
}

