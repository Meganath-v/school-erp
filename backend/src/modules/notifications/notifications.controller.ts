import { Controller, Get, Patch, Param, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, SCHOOL_ADMINS, ALL_SCHOOL_ROLES } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { UpdateNotificationPreferencesDto, GetNotificationsQueryDto } from './notifications.dto';

@ApiTags('In-App Notifications, History & Preference Control')
@ApiBearerAuth()
@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private notificationsService: NotificationsService) {}

  @Roles(...ALL_SCHOOL_ROLES)
  @Get()
  @ApiOperation({ summary: 'Get current user notifications with status, priority, search and pagination filters' })
  @ApiResponse({ status: 200, description: 'List of notifications with unread counter and pagination' })
  async getNotifications(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Query() query: GetNotificationsQueryDto,
  ) {
    const data = await this.notificationsService.getNotifications(schoolId, userId, query);
    return { data };
  }

  @Roles(...ALL_SCHOOL_ROLES)
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

  @Roles(...ALL_SCHOOL_ROLES)
  @Patch('read-all')
  @ApiOperation({ summary: 'Mark all unread notifications as read' })
  @ApiResponse({ status: 200, description: 'All notifications marked as read' })
  async markAllAsRead(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string) {
    const data = await this.notificationsService.markAllAsRead(schoolId, userId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Get('delivery-logs')
  @ApiOperation({ summary: 'Inspect notification delivery logs across channels with retry counts and errors' })
  @ApiQuery({ name: 'limit', required: false })
  @ApiQuery({ name: 'recipientId', required: false })
  @ApiResponse({ status: 200, description: 'List of delivery logs' })
  async getDeliveryLogs(
    @CurrentSchoolId() schoolId: string,
    @Query('recipientId') recipientId?: string,
    @Query('limit') limit?: number,
  ) {
    const data = await this.notificationsService.getDeliveryLogs(schoolId, recipientId, limit);
    return { data };
  }
}

@ApiTags('In-App Notifications, History & Preference Control')
@ApiBearerAuth()
@Controller('notification-preferences')
@UseGuards(JwtAuthGuard)
export class NotificationPreferencesController {
  constructor(private notificationsService: NotificationsService) {}

  @Roles(...ALL_SCHOOL_ROLES)
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
