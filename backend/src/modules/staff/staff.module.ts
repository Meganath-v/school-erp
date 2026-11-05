import { Module } from '@nestjs/common';
import { StaffService } from './staff.service';
import { StaffController } from './staff.controller';
import { TeacherController } from './teacher.controller';

@Module({
  providers: [StaffService],
  controllers: [StaffController, TeacherController],
  exports: [StaffService],
})
export class StaffModule {}
