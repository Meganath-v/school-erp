import { Module } from '@nestjs/common';
import { TimetableService } from './timetable.service';
import { TimetableController } from './timetable.controller';
import { TimetablePlannerController } from './timetable-planner.controller';
import { TimetablePlannerService } from './timetable-planner.service';
import { ScheduleAccessService } from './schedule-access.service';

@Module({
  providers: [TimetableService, TimetablePlannerService, ScheduleAccessService],
  controllers: [TimetableController, TimetablePlannerController],
  exports: [TimetableService, TimetablePlannerService, ScheduleAccessService],
})
export class TimetableModule {}
