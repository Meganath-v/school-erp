import { Module } from '@nestjs/common';
import { ReportsService } from './reports.service';
import { ReportsController, AuditLogsController } from './reports.controller';

@Module({
  providers: [ReportsService],
  controllers: [ReportsController, AuditLogsController],
  exports: [ReportsService],
})
export class ReportsModule {}
