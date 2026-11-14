import { Controller, Get, Post, Patch, Param, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery, ApiParam } from '@nestjs/swagger';
import { AttendanceService } from './attendance.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ACADEMIC_STAFF, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { SaveAttendanceDto, AttendanceFilterDto, CorrectAttendanceRecordDto } from './attendance.dto';

@ApiTags('Attendance Sessions & Roster Marking')
@ApiBearerAuth()
@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceController {
  constructor(private attendanceService: AttendanceService) {}

  @Roles(...ALL_STAFF)
  @Get('today')
  @ApiOperation({ summary: 'Get current day section roster with past attendance rates & condonation risk warnings' })
  @ApiQuery({ name: 'sectionId', required: false, description: 'Section UUID' })
  @ApiResponse({ status: 200, description: 'Today attendance roster' })
  async getTodayAttendance(@CurrentSchoolId() schoolId: string, @Query('sectionId') sectionId?: string) {
    const data = await this.attendanceService.getTodayAttendance(schoolId, sectionId);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @Post('sessions')
  @ApiOperation({ summary: 'Atomically commit daily section attendance session and student records' })
  @ApiResponse({ status: 201, description: 'Attendance session recorded successfully' })
  async saveAttendance(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('name') userName: string,
    @Body() body: SaveAttendanceDto,
  ) {
    const data = await this.attendanceService.saveAttendance(schoolId, {
      ...body,
      markedBy: userName,
    });
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

  @Roles(...ACADEMIC_STAFF)
  @Patch('records/:id/correction')
  @ApiOperation({ summary: 'Correct an existing attendance record with reason and audit trail' })
  @ApiParam({ name: 'id', description: 'AttendanceRecord UUID' })
  @ApiResponse({ status: 200, description: 'Attendance record corrected successfully' })
  async correctRecord(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('name') userName: string,
    @Param('id') id: string,
    @Body() body: CorrectAttendanceRecordDto,
  ) {
    const data = await this.attendanceService.correctAttendanceRecord(
      schoolId,
      id,
      body,
      { id: userId, name: userName || 'Staff' },
    );
    return { data };
  }
}
