import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { ReportsService } from './reports.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, OFFICE_STAFF, PLATFORM_ADMINS, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';

@ApiTags('Institutional Reports & Audit Logs')
@ApiBearerAuth()
@Controller()
@UseGuards(JwtAuthGuard)
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Roles(...OFFICE_STAFF)
  @Get('reports/overview')
  @ApiOperation({ summary: 'School-level executive overview: counts, invoice totals, today attendance rate, recent events' })
  @ApiResponse({ status: 200, description: 'Aggregated institutional overview' })
  async getOverview(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getOverview(schoolId);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('reports/students')
  @ApiOperation({ summary: 'Student demographic breakdown, status distribution, and class-wise roll counts' })
  @ApiResponse({ status: 200, description: 'Student report data' })
  async getStudentReport(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getStudentReport(schoolId);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('reports/attendance')
  @ApiOperation({ summary: 'Cumulative attendance rates and condonation shortage (<75%) deficiency report' })
  @ApiQuery({ name: 'sectionId', required: false })
  @ApiResponse({ status: 200, description: 'Attendance deficiency report' })
  async getAttendanceReport(
    @CurrentSchoolId() schoolId: string,
    @Query('sectionId') sectionId?: string,
  ) {
    const data = await this.reportsService.getAttendanceReport(schoolId, sectionId);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('reports/examinations')
  @ApiOperation({ summary: 'Consolidated class broadsheet, pass/fail status, percentages, and student rankings' })
  @ApiQuery({ name: 'examId', required: false })
  @ApiResponse({ status: 200, description: 'Examination performance report' })
  async getExamReport(
    @CurrentSchoolId() schoolId: string,
    @Query('examId') examId?: string,
  ) {
    const data = await this.reportsService.getExamReport(schoolId, examId);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('reports/fees')
  @ApiOperation({ summary: 'Fee collection analytics across SCHOOL, HOSTEL, and TRANSPORT categories and defaulters' })
  @ApiResponse({ status: 200, description: 'Financial fee report' })
  async getFeeReport(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getFeeReport(schoolId);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('reports/teacher-workload')
  @ApiOperation({ summary: 'Faculty weekly teaching workload, periods per week, and assigned courses' })
  @ApiResponse({ status: 200, description: 'Teacher workload report' })
  async getTeacherWorkloadReport(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getTeacherWorkloadReport(schoolId);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('reports/feedback')
  @ApiOperation({ summary: 'Feedback resolution metrics, category distributions, and sentiment ratings' })
  @ApiResponse({ status: 200, description: 'Feedback report' })
  async getFeedbackReport(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getFeedbackReport(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS, ...PLATFORM_ADMINS)
  @Get('audit-logs')
  @ApiOperation({ summary: 'Query immutable tenant audit log trail' })
  @ApiResponse({ status: 200, description: 'List of audit log records' })
  async getAuditLogs(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getAuditLogs(schoolId);
    return { data };
  }
}
