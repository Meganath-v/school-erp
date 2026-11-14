import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { AnnouncementsService } from './announcements.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('announcements')
@UseGuards(JwtAuthGuard)
export class AnnouncementsController {
  constructor(private announcementsService: AnnouncementsService) {}

  @Get()
  async getAnnouncements(@CurrentSchoolId() schoolId: string, @CurrentUser('role') role: string) {
    const data = await this.announcementsService.getAnnouncements(schoolId, role);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Post()
  async createAnnouncement(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @CurrentUser('name') authorName: string,
    @Body() body: any,
  ) {
    const data = await this.announcementsService.createAnnouncement(schoolId, body, {
      userId,
      role,
      name: authorName,
    });
    return { data };
  }
}
