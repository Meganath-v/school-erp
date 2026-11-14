import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { TimetableService } from './timetable.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('timetable')
@UseGuards(JwtAuthGuard)
export class TimetableController {
  constructor(private timetableService: TimetableService) {}

  @Get('entries')
  async getEntries(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @Query('sectionId') sectionId?: string,
    @Query('staffId') staffId?: string,
    @Query('classId') classId?: string,
  ) {
    const data = await this.timetableService.getEntries(schoolId, { sectionId, staffId, classId, userId, role });
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Post('entries')
  async createEntry(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.timetableService.createEntry(schoolId, body);
    return { data };
  }
}
