import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { TenantDiscoveryModule } from './modules/tenant-discovery/tenant-discovery.module';
import { PlatformModule } from './modules/platform/platform.module';
import { SchoolsModule } from './modules/schools/schools.module';
import { StudentsModule } from './modules/students/students.module';
import { StaffModule } from './modules/staff/staff.module';
import { AttendanceModule } from './modules/attendance/attendance.module';
import { TimetableModule } from './modules/timetable/timetable.module';
import { AssignmentsModule } from './modules/assignments/assignments.module';
import { ExamsModule } from './modules/exams/exams.module';
import { FeesModule } from './modules/fees/fees.module';
import { LeaveModule } from './modules/leave/leave.module';
import { AnnouncementsModule } from './modules/announcements/announcements.module';
import { ReportsModule } from './modules/reports/reports.module';
import { AcademicsModule } from './modules/academics/academics.module';
import { ParentModule } from './modules/parent/parent.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { RemindersModule } from './modules/reminders/reminders.module';
import { TasksModule } from './modules/tasks/tasks.module';
import { FeedbackModule } from './modules/feedback/feedback.module';
import { CircularsModule } from './modules/circulars/circulars.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', '../.env'],
    }),
    // Global rate limit (per IP); stricter limits are set on /auth/login and /auth/refresh.
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 300 }]),
    PrismaModule,
    AuthModule,
    TenantDiscoveryModule,
    PlatformModule,
    SchoolsModule,
    StudentsModule,
    StaffModule,
    AttendanceModule,
    TimetableModule,
    AssignmentsModule,
    ExamsModule,
    FeesModule,
    LeaveModule,
    AnnouncementsModule,
    ReportsModule,
    AcademicsModule,
    ParentModule,
    NotificationsModule,
    RemindersModule,
    TasksModule,
    FeedbackModule,
    CircularsModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
