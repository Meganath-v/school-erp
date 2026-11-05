import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { AttendanceService } from './attendance.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceController {
  constructor(private attendanceService: AttendanceService) {}

  @Get('today')
  async getTodayAttendance(@CurrentSchoolId() schoolId: string, @Query('sectionId') sectionId?: string) {
    const data = await this.attendanceService.getTodayAttendance(schoolId, sectionId);
    return { data };
  }

  @Post('sessions')
  async saveAttendance(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('name') userName: string,
    @Body() body: any,
  ) {
    const data = await this.attendanceService.saveAttendance(schoolId, {
      ...body,
      markedBy: userName,
    });
    return { data };
  }

  @Get('reports')
  async getReports(@CurrentSchoolId() schoolId: string, @Query('sectionId') sectionId?: string) {
    const data = await this.attendanceService.getAttendanceReports(schoolId, sectionId);
    return { data };
  }
}
