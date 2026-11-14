import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { TimetableService } from './timetable.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateTimetableEntryDto, TimetableFilterDto } from './timetable.dto';

@ApiTags('Timetable & Schedule Scheduling')
@ApiBearerAuth()
@Controller('timetable')
@UseGuards(JwtAuthGuard)
export class TimetableController {
  constructor(private timetableService: TimetableService) {}

  @Get('entries')
  @ApiOperation({ summary: 'Get timetable schedule slots filtered by section, staff or class' })
  @ApiResponse({ status: 200, description: 'Timetable slots retrieved successfully' })
  async getEntries(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @Query() query: TimetableFilterDto,
  ) {
    const data = await this.timetableService.getEntries(schoolId, {
      sectionId: query.sectionId,
      staffId: query.staffId,
      classId: query.classId,
      userId,
      role,
    });
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Post('entries')
  @ApiOperation({ summary: 'Schedule a new timetable slot with teacher/room conflict detection' })
  @ApiResponse({ status: 201, description: 'Timetable slot created successfully' })
  async createEntry(@CurrentSchoolId() schoolId: string, @Body() body: CreateTimetableEntryDto) {
    const data = await this.timetableService.createEntry(schoolId, body);
    return { data };
  }
}
