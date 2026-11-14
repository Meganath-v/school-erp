import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
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

  @Roles(...SCHOOL_ADMINS, ...PLATFORM_ADMINS)
  @Get('audit-logs')
  @ApiOperation({ summary: 'Query immutable tenant audit log trail' })
  @ApiResponse({ status: 200, description: 'List of audit log records' })
  async getAuditLogs(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getAuditLogs(schoolId);
    return { data };
  }
}
