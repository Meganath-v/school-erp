import { Controller, Get, Patch, Param, Body, UseGuards } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private notificationsService: NotificationsService) {}

  @Get()
  async getNotifications(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string) {
    const data = await this.notificationsService.getNotifications(schoolId, userId);
    return { data };
  }

  @Patch(':id/read')
  async markAsRead(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    const data = await this.notificationsService.markAsRead(schoolId, userId, id);
    return { data };
  }

  @Patch('read-all')
  async markAllAsRead(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string) {
    const data = await this.notificationsService.markAllAsRead(schoolId, userId);
    return { data };
  }
}

@Controller('notification-preferences')
@UseGuards(JwtAuthGuard)
export class NotificationPreferencesController {
  constructor(private notificationsService: NotificationsService) {}

  @Patch()
  async updatePreferences(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Body() body: any,
  ) {
    const data = await this.notificationsService.updatePreferences(schoolId, userId, body);
    return { data };
  }
}
