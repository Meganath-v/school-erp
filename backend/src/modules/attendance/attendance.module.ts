import { Module } from '@nestjs/common';
import { AttendanceService } from './attendance.service';
import { AttendanceController } from './attendance.controller';
import { PeriodAttendanceService } from './period-attendance.service';
import { TimetableModule } from '../timetable/timetable.module';

@Module({
  imports: [TimetableModule],
  providers: [AttendanceService, PeriodAttendanceService],
  controllers: [AttendanceController],
  exports: [AttendanceService],
})
export class AttendanceModule {}
