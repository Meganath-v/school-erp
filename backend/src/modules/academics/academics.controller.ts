import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { AcademicsService } from './academics.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('academics')
@UseGuards(JwtAuthGuard)
export class AcademicsController {
  constructor(private academicsService: AcademicsService) {}

  @Get('lesson-plans')
  async getLessonPlans(
    @CurrentSchoolId() schoolId: string,
    @Query('classId') classId?: string,
    @Query('subjectId') subjectId?: string,
    @Query('teacherId') teacherId?: string,
  ) {
    const data = await this.academicsService.getLessonPlans(schoolId, { classId, subjectId, teacherId });
    return { data };
  }

  @Post('lesson-plans')
  async createLessonPlan(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.academicsService.createLessonPlan(schoolId, body);
    return { data };
  }

  @Patch('lesson-plans/:id/progress')
  async updateProgress(@Param('id') id: string, @Body() body: { conductedHours: number; status?: string }) {
    const data = await this.academicsService.updateLessonProgress(id, body);
    return { data };
  }

  @Get('teaching-diaries')
  async getTeachingDiaries(
    @CurrentSchoolId() schoolId: string,
    @Query('classId') classId?: string,
    @Query('subjectId') subjectId?: string,
    @Query('teacherId') teacherId?: string,
  ) {
    const data = await this.academicsService.getTeachingDiaries(schoolId, { classId, subjectId, teacherId });
    return { data };
  }

  @Post('teaching-diaries')
  async createTeachingDiary(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('name') userName: string,
    @Body() body: any,
  ) {
    const data = await this.academicsService.createTeachingDiary(schoolId, body);
    return { data };
  }

  @Get('course-materials')
  async getCourseMaterials(@CurrentSchoolId() schoolId: string, @Query('subjectId') subjectId?: string) {
    const data = await this.academicsService.getCourseMaterials(schoolId, subjectId);
    return { data };
  }

  @Post('course-materials')
  async createCourseMaterial(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('name') userName: string,
    @Body() body: any,
  ) {
    const data = await this.academicsService.createCourseMaterial(schoolId, { ...body, uploadedBy: userName });
    return { data };
  }

  @Get('attendance-analytics')
  async getAttendanceAnalytics(@CurrentSchoolId() schoolId: string) {
    const data = await this.academicsService.getAttendanceShortageAnalytics(schoolId);
    return { data };
  }
}
