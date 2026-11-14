import { Body, Controller, Get, Param, Post, Query, Res, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { Response } from 'express';
import { ReportsService } from './reports.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, OFFICE_STAFF, PLATFORM_ADMINS, SCHOOL_ADMINS, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';
import { ReportFilterDto, ExportReportDto } from './reports.dto';

@ApiTags('Institutional Reports & Analytics Suite')
@ApiBearerAuth()
@Controller('reports')
@UseGuards(JwtAuthGuard)
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Roles(...OFFICE_STAFF)
  @Get('overview')
  @ApiOperation({ summary: 'Executive summary telemetry: totals, attendance, fees, receipts' })
  async getOverview(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getOverview(schoolId);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('students')
  @ApiOperation({ summary: '1. Student Demographics & Class Distribution' })
  async getStudentReport(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getStudentStrengthReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('student-strength')
  @ApiOperation({ summary: '1. Student Strength & Gender Distribution by Class/Section' })
  async getStudentStrength(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getStudentStrengthReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('admissions')
  @ApiOperation({ summary: '2. Admission Statistics & Enrollment Intake' })
  async getAdmissionStatistics(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getAdmissionStatisticsReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('staff-directory')
  @ApiOperation({ summary: '3. Faculty & Staff Directory Breakdown' })
  async getStaffDirectory(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getStaffDirectoryReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('attendance')
  @ApiOperation({ summary: '4. Attendance Rate Summary by Class & Section' })
  async getAttendanceReport(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getAttendanceSummaryReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('attendance-summary')
  @ApiOperation({ summary: '4. Attendance Rate Summary by Class & Section' })
  async getAttendanceSummary(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getAttendanceSummaryReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('attendance-defaulters')
  @ApiOperation({ summary: '5. Attendance Defaulters (< 75% Condonation Threshold)' })
  async getAttendanceDefaulters(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getAttendanceDefaultersReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('examinations')
  @ApiOperation({ summary: '6. Examination Performance Analytics' })
  async getExamReport(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const perfData = await this.reportsService.getExamPerformanceReport(schoolId, query);
    const broadsheetData = await this.reportsService.getClassBroadsheetReport(schoolId, query);
    return {
      data: {
        ...perfData,
        broadsheet: broadsheetData.rows || [],
      },
    };
  }

  @Roles(...OFFICE_STAFF)
  @Get('exam-performance')
  @ApiOperation({ summary: '6. Examination Performance Analytics' })
  async getExamPerformance(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getExamPerformanceReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('class-broadsheet')
  @ApiOperation({ summary: '7. Class Broadsheet Multi-Subject Mark Matrix & Ranks' })
  async getClassBroadsheet(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getClassBroadsheetReport(schoolId, query);
    return { data };
  }

  @Roles(...ALL_STAFF, 'PARENT', 'STUDENT')
  @Get('report-card/:studentId')
  @ApiOperation({ summary: '8. Student Report Card with Subject Marks & Grade Scale' })
  @ApiParam({ name: 'studentId', description: 'Student UUID' })
  async getStudentReportCard(
    @CurrentSchoolId() schoolId: string,
    @Param('studentId') studentId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getStudentReportCard(schoolId, studentId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('fees')
  @ApiOperation({ summary: '9. Fee Collection & Serialized Receipts' })
  async getFeeReport(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getFeeCollectionReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('fee-collections')
  @ApiOperation({ summary: '9. Fee Collection Ledger by Payment Instrument & Category' })
  async getFeeCollections(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getFeeCollectionReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('outstanding-fees')
  @ApiOperation({ summary: '10. Outstanding Balances & Defaulters Ledger' })
  async getOutstandingFees(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getOutstandingFeesReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('teacher-workload')
  @ApiOperation({ summary: '11. Teacher Workload & Weekly Periods Allocation' })
  async getTeacherWorkload(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getTeacherWorkloadReport(schoolId, query);
    return { data: data.rows };
  }

  @Roles(...OFFICE_STAFF)
  @Get('assignment-performance')
  @ApiOperation({ summary: '12. Assignment Submission Rates & Average Grades' })
  async getAssignmentPerformance(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getAssignmentPerformanceReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('feedback')
  @ApiOperation({ summary: '13. Feedback Resolution & Satisfaction Ratings' })
  async getFeedback(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getFeedbackReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('feedback-resolution')
  @ApiOperation({ summary: '13. Feedback Resolution & Satisfaction Ratings' })
  async getFeedbackResolution(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ReportFilterDto,
  ) {
    const data = await this.reportsService.getFeedbackReport(schoolId, query);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Get('export')
  @ApiOperation({ summary: 'Export any institutional report as Excel (.xlsx) or CSV (.csv) with matching totals' })
  async exportReport(
    @CurrentSchoolId() schoolId: string,
    @Query() query: ExportReportDto,
    @Res() res: Response,
  ) {
    const fileResult = await this.reportsService.exportReport(schoolId, query);
    res.setHeader('Content-Type', fileResult.mimeType);
    res.setHeader('Content-Disposition', `attachment; filename="${fileResult.filename}"`);
    res.setHeader('Content-Length', fileResult.buffer.length);
    res.end(fileResult.buffer);
  }

  @Roles(...OFFICE_STAFF)
  @Post('export')
  @ApiOperation({ summary: 'Export any institutional report via POST payload' })
  async exportReportPost(
    @CurrentSchoolId() schoolId: string,
    @Body() body: ExportReportDto,
    @Res() res: Response,
  ) {
    const fileResult = await this.reportsService.exportReport(schoolId, body);
    res.setHeader('Content-Type', fileResult.mimeType);
    res.setHeader('Content-Disposition', `attachment; filename="${fileResult.filename}"`);
    res.setHeader('Content-Length', fileResult.buffer.length);
    res.end(fileResult.buffer);
  }
}

@ApiTags('Institutional Reports & Audit Logs')
@ApiBearerAuth()
@Controller('audit-logs')
@UseGuards(JwtAuthGuard)
export class AuditLogsController {
  constructor(private reportsService: ReportsService) {}

  @Roles(...SCHOOL_ADMINS, ...PLATFORM_ADMINS)
  @Get()
  @ApiOperation({ summary: 'Query immutable tenant audit log trail' })
  @ApiResponse({ status: 200, description: 'List of audit log records' })
  async getAuditLogs(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getAuditLogs(schoolId);
    return { data };
  }
}
