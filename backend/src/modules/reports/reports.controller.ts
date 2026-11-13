import { Controller, Get, UseGuards } from '@nestjs/common';
import { ReportsService } from './reports.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, OFFICE_STAFF, PLATFORM_ADMINS, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';

@Controller()
@UseGuards(JwtAuthGuard)
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Roles(...OFFICE_STAFF)
  @Get('reports/overview')
  async getOverview(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getOverview(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS, ...PLATFORM_ADMINS)
  @Get('audit-logs')
  async getAuditLogs(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getAuditLogs(schoolId);
    return { data };
  }
}
