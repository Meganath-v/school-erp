import { Controller, Get, UseGuards } from '@nestjs/common';
import { ReportsService } from './reports.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';

@Controller()
@UseGuards(JwtAuthGuard)
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Get('reports/overview')
  async getOverview(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getOverview(schoolId);
    return { data };
  }

  @Get('audit-logs')
  async getAuditLogs(@CurrentSchoolId() schoolId: string) {
    const data = await this.reportsService.getAuditLogs(schoolId);
    return { data };
  }
}
