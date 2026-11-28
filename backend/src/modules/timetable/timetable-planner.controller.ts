import { Body, Controller, Delete, Get, Param, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { ALL_STAFF, OFFICE_STAFF, Roles, TEACHERS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { TimetablePlannerService } from './timetable-planner.service';
import type { ScheduleActor } from './schedule-access.service';
import { DateQueryDto, SaveTimetablePeriodsDto, SetClassSlotDto, SetSubstitutionDto, SlotQueryDto, SubstitutionQueryDto } from './timetable.dto';

@ApiTags('Timetable & Schedule Scheduling')
@ApiBearerAuth()
@Controller('timetable')
@UseGuards(JwtAuthGuard)
export class TimetablePlannerController {
  constructor(private planner: TimetablePlannerService) {}

  @Roles(...ALL_STAFF)
  @Get('periods')
  @ApiOperation({ summary: 'Bell schedule: the periods (and times) of each school day' })
  async periods(@CurrentSchoolId() schoolId: string) {
    return { data: await this.planner.getPeriods(schoolId) };
  }

  @Roles(...OFFICE_STAFF)
  @Put('periods')
  @ApiOperation({ summary: 'Office: replace the bell schedule' })
  async savePeriods(@CurrentSchoolId() schoolId: string, @CurrentUser() actor: ScheduleActor, @Body() body: SaveTimetablePeriodsDto) {
    return { data: await this.planner.savePeriods(schoolId, actor, body) };
  }

  @Roles(...ALL_STAFF)
  @Get('class/:sectionId')
  @ApiOperation({ summary: "A section's weekly timetable with the subjects and teachers filled in" })
  async classTimetable(@CurrentSchoolId() schoolId: string, @CurrentUser() actor: ScheduleActor, @Param('sectionId') sectionId: string) {
    return { data: await this.planner.getClassTimetable(schoolId, actor, sectionId) };
  }

  @Roles(...OFFICE_STAFF, 'CLASS_TEACHER')
  @Put('class/:sectionId/slot')
  @ApiOperation({ summary: 'Class teacher / office: set the subject and teacher (username or email) for a period' })
  async setSlot(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() actor: ScheduleActor,
    @Param('sectionId') sectionId: string,
    @Body() body: SetClassSlotDto,
  ) {
    return { data: await this.planner.setSlot(schoolId, actor, sectionId, body) };
  }

  @Roles(...OFFICE_STAFF, 'CLASS_TEACHER')
  @Delete('class/:sectionId/slot')
  @ApiOperation({ summary: 'Class teacher / office: clear a period' })
  async clearSlot(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() actor: ScheduleActor,
    @Param('sectionId') sectionId: string,
    @Query() q: SlotQueryDto,
  ) {
    return { data: await this.planner.clearSlot(schoolId, actor, sectionId, q.dayOfWeek, q.periodNumber) };
  }

  @Roles(...ALL_STAFF)
  @Get('daily/:sectionId')
  @ApiOperation({ summary: "A section's periods on a date, with substitutions and attendance status" })
  async daily(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() actor: ScheduleActor,
    @Param('sectionId') sectionId: string,
    @Query() q: DateQueryDto,
  ) {
    return { data: await this.planner.getDaily(schoolId, actor, sectionId, q.date) };
  }

  @Roles(...OFFICE_STAFF, 'CLASS_TEACHER')
  @Put('daily/:sectionId/substitution')
  @ApiOperation({ summary: 'Class teacher / office: another teacher takes a period on a date' })
  async substitute(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() actor: ScheduleActor,
    @Param('sectionId') sectionId: string,
    @Body() body: SetSubstitutionDto,
  ) {
    return { data: await this.planner.setSubstitution(schoolId, actor, sectionId, body) };
  }

  @Roles(...OFFICE_STAFF, 'CLASS_TEACHER')
  @Delete('daily/:sectionId/substitution')
  @ApiOperation({ summary: 'Class teacher / office: undo a substitution' })
  async clearSubstitution(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() actor: ScheduleActor,
    @Param('sectionId') sectionId: string,
    @Query() q: SubstitutionQueryDto,
  ) {
    return { data: await this.planner.clearSubstitution(schoolId, actor, sectionId, q.date, q.periodNumber) };
  }

  @Roles(...TEACHERS, 'PRINCIPAL', 'SCHOOL_ADMIN')
  @Get('my-day')
  @ApiOperation({ summary: "The signed-in teacher's periods on a date, including substitutions" })
  async myDay(@CurrentSchoolId() schoolId: string, @CurrentUser() actor: ScheduleActor, @Query() q: DateQueryDto) {
    return { data: await this.planner.getMyDay(schoolId, actor, q.date) };
  }
}
