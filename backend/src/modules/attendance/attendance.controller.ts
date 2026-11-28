import { Controller, Get, Post, Patch, Param, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery, ApiParam } from '@nestjs/swagger';
import { AttendanceService } from './attendance.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ACADEMIC_STAFF, ALL_STAFF, OFFICE_STAFF, TEACHERS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { SaveAttendanceDto, AttendanceFilterDto, CorrectAttendanceRecordDto, SavePeriodAttendanceDto, PeriodAttendanceQueryDto } from './attendance.dto';
import { PeriodAttendanceService } from './period-attendance.service';
import type { ScheduleActor } from '../timetable/schedule-access.service';

@ApiTags('Attendance Sessions & Roster Marking')
@ApiBearerAuth()
@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceController {
  constructor(private attendanceService: AttendanceService, private periodAttendance: PeriodAttendanceService) {}

  @Roles(...ALL_STAFF)
  @Get('today')
  @ApiOperation({ summary: 'Get current day section roster with past attendance rates & condonation risk warnings' })
  @ApiQuery({ name: 'sectionId', required: false, description: 'Section UUID' })
  @ApiResponse({ status: 200, description: 'Today attendance roster' })
  async getTodayAttendance(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() actor: ScheduleActor,
    @Query('sectionId') sectionId?: string,
  ) {
    const data = await this.attendanceService.getTodayAttendance(schoolId, sectionId, actor);
    return { data };
  }

  @Roles(...OFFICE_STAFF, ...TEACHERS)
  @Post('sessions')
  @ApiOperation({ summary: 'Atomically commit daily section attendance session and student records' })
  @ApiResponse({ status: 201, description: 'Attendance session recorded successfully' })
  async saveAttendance(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() actor: ScheduleActor,
    @Body() body: SaveAttendanceDto,
  ) {
    const data = await this.attendanceService.saveAttendance(
      schoolId,
      { ...body, markedBy: actor.name },
      actor,
    );
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Get('reports')
  @ApiOperation({ summary: 'Get aggregated section attendance rate reports' })
  @ApiQuery({ name: 'sectionId', required: false, description: 'Section UUID' })
  @ApiResponse({ status: 200, description: 'Attendance reports' })
  async getReports(@CurrentSchoolId() schoolId: string, @Query('sectionId') sectionId?: string) {
    const data = await this.attendanceService.getAttendanceReports(schoolId, sectionId);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Get('matrix')
  @ApiOperation({ summary: 'Get monthly student-by-day attendance grid/matrix' })
  @ApiResponse({ status: 200, description: 'Monthly attendance matrix' })
  async getAttendanceMatrix(
    @CurrentSchoolId() schoolId: string,
    @Query() query: AttendanceFilterDto,
  ) {
    const data = await this.attendanceService.getAttendanceMatrix(
      schoolId,
      query.sectionId,
      query.month,
      query.year,
    );
    return { data };
  }

  @Roles(...OFFICE_STAFF, ...TEACHERS)
  @Patch('records/:id/correction')
  @ApiOperation({ summary: 'Correct an existing attendance record with reason and audit trail' })
  @ApiParam({ name: 'id', description: 'AttendanceRecord UUID' })
  @ApiResponse({ status: 200, description: 'Attendance record corrected successfully' })
  async correctRecord(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser() actor: ScheduleActor,
    @Param('id') id: string,
    @Body() body: CorrectAttendanceRecordDto,
  ) {
    const data = await this.attendanceService.correctAttendanceRecord(
      schoolId,
      id,
      body,
      { id: actor.userId, name: actor.name || 'Staff' },
      actor,
    );
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Get('periods')
  @ApiOperation({ summary: 'Roster and status for one period of a section on a date' })
  async getPeriod(@CurrentSchoolId() schoolId: string, @CurrentUser() actor: ScheduleActor, @Query() q: PeriodAttendanceQueryDto) {
    const data = await this.periodAttendance.get(schoolId, actor, q.sectionId, q.date, q.periodNumber);
    return { data };
  }

  @Roles(...OFFICE_STAFF, ...TEACHERS)
  @Post('periods')
  @ApiOperation({ summary: 'Take period attendance (the period teacher, on the day) or correct it (office)' })
  async savePeriod(@CurrentSchoolId() schoolId: string, @CurrentUser() actor: ScheduleActor, @Body() body: SavePeriodAttendanceDto) {
    const data = await this.periodAttendance.save(schoolId, actor, body);
    return { data };
  }
}
