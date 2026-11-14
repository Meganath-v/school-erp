import { Controller, Get, Patch, Param, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { UpdateNotificationPreferencesDto } from './notifications.dto';

@ApiTags('In-App Notifications & Preference Control')
@ApiBearerAuth()
@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private notificationsService: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'Get current user notifications in this school' })
  @ApiResponse({ status: 200, description: 'List of notifications' })
  async getNotifications(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string) {
    const data = await this.notificationsService.getNotifications(schoolId, userId);
    return { data };
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark a single notification as read' })
  @ApiParam({ name: 'id', description: 'Notification UUID' })
  @ApiResponse({ status: 200, description: 'Notification marked as read' })
  async markAsRead(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    const data = await this.notificationsService.markAsRead(schoolId, userId, id);
    return { data };
  }

  @Patch('read-all')
  @ApiOperation({ summary: 'Mark all unread notifications as read' })
  @ApiResponse({ status: 200, description: 'All notifications marked as read' })
  async markAllAsRead(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string) {
    const data = await this.notificationsService.markAllAsRead(schoolId, userId);
    return { data };
  }
}

@ApiTags('In-App Notifications & Preference Control')
@ApiBearerAuth()
@Controller('notification-preferences')
@UseGuards(JwtAuthGuard)
export class NotificationPreferencesController {
  constructor(private notificationsService: NotificationsService) {}

  @Patch()
  @ApiOperation({ summary: 'Update channel-level notification preferences for the authenticated user' })
  @ApiResponse({ status: 200, description: 'Preferences updated' })
  async updatePreferences(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Body() body: UpdateNotificationPreferencesDto,
  ) {
    const data = await this.notificationsService.updatePreferences(schoolId, userId, body);
    return { data };
  }
}
