import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { AttendanceService } from './attendance.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ACADEMIC_STAFF, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceController {
  constructor(private attendanceService: AttendanceService) {}

  @Roles(...ALL_STAFF)
  @Get('today')
  async getTodayAttendance(@CurrentSchoolId() schoolId: string, @Query('sectionId') sectionId?: string) {
    const data = await this.attendanceService.getTodayAttendance(schoolId, sectionId);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
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

  @Roles(...ALL_STAFF)
  @Get('reports')
  async getReports(@CurrentSchoolId() schoolId: string, @Query('sectionId') sectionId?: string) {
    const data = await this.attendanceService.getAttendanceReports(schoolId, sectionId);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Get('matrix')
  async getAttendanceMatrix(
    @CurrentSchoolId() schoolId: string,
    @Query('sectionId') sectionId?: string,
    @Query('month') month?: number,
    @Query('year') year?: number,
  ) {
    const data = await this.attendanceService.getAttendanceMatrix(schoolId, sectionId, month, year);
    return { data };
  }
}
