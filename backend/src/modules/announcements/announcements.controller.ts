import { Controller, Get, Post, Delete, Param, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { AnnouncementsService } from './announcements.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateAnnouncementDto } from './announcements.dto';

@ApiTags('School Announcements & Broadcasts')
@ApiBearerAuth()
@Controller('announcements')
@UseGuards(JwtAuthGuard)
export class AnnouncementsController {
  constructor(private announcementsService: AnnouncementsService) {}

  @Get()
  @ApiOperation({ summary: 'List published announcements applicable to the caller role' })
  @ApiResponse({ status: 200, description: 'List of announcements' })
  async getAnnouncements(@CurrentSchoolId() schoolId: string, @CurrentUser('role') role: string) {
    const data = await this.announcementsService.getAnnouncements(schoolId, role);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Post()
  @ApiOperation({ summary: 'Broadcast an announcement with role-level audience verification' })
  @ApiResponse({ status: 201, description: 'Announcement created successfully' })
  async createAnnouncement(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @CurrentUser('name') authorName: string,
    @Body() body: CreateAnnouncementDto,
  ) {
    const data = await this.announcementsService.createAnnouncement(schoolId, body, {
      userId,
      role,
      name: authorName,
    });
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Delete(':id')
  @ApiOperation({ summary: 'Delete or archive an announcement' })
  @ApiParam({ name: 'id', description: 'Announcement UUID' })
  @ApiResponse({ status: 200, description: 'Announcement deleted' })
  async deleteAnnouncement(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    const data = await this.announcementsService.deleteAnnouncement(schoolId, id);
    return { data };
  }
}
