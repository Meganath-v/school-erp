import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AcademicsService } from './academics.service';
import {
  CreateLessonPlanDto,
  UpdateLessonPlanProgressDto,
  CreateTeachingDiaryDto,
  CreateCourseMaterialDto,
} from './academics.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ACADEMIC_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Academics, OBE Curriculum & Teaching Diary')
@ApiBearerAuth()
@Controller('academics')
@UseGuards(JwtAuthGuard)
export class AcademicsController {
  constructor(private academicsService: AcademicsService) {}

  @ApiOperation({ summary: 'Get outcome-based education (OBE) course lesson plans and syllabus coverage' })
  @ApiQuery({ name: 'classId', required: false })
  @ApiQuery({ name: 'subjectId', required: false })
  @ApiQuery({ name: 'teacherId', required: false })
  @ApiResponse({ status: 200, description: 'Lesson plans and coverage percentage retrieved' })
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

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Create new course lesson plan unit' })
  @ApiResponse({ status: 201, description: 'Lesson plan unit created' })
  @Post('lesson-plans')
  async createLessonPlan(@CurrentSchoolId() schoolId: string, @Body() body: CreateLessonPlanDto) {
    const data = await this.academicsService.createLessonPlan(schoolId, body);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Update teaching progress / conducted hours for an OBE unit' })
  @ApiResponse({ status: 200, description: 'Progress updated' })
  @Patch('lesson-plans/:id/progress')
  async updateProgress(
    @CurrentSchoolId() schoolId: string,
    @Param('id') id: string,
    @Body() body: UpdateLessonPlanProgressDto,
  ) {
    const data = await this.academicsService.updateLessonProgress(schoolId, id, body);
    return { data };
  }

  @ApiOperation({ summary: 'Get faculty daily teaching diary / course log records' })
  @ApiQuery({ name: 'classId', required: false })
  @ApiQuery({ name: 'subjectId', required: false })
  @ApiQuery({ name: 'teacherId', required: false })
  @ApiResponse({ status: 200, description: 'Teaching diaries retrieved' })
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

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Log daily faculty course diary delivery record' })
  @ApiResponse({ status: 201, description: 'Teaching diary entry recorded' })
  @Post('teaching-diaries')
  async createTeachingDiary(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('name') userName: string,
    @Body() body: CreateTeachingDiaryDto,
  ) {
    const data = await this.academicsService.createTeachingDiary(schoolId, body);
    return { data };
  }

  @ApiOperation({ summary: 'Get course study materials repository' })
  @ApiQuery({ name: 'subjectId', required: false })
  @ApiResponse({ status: 200, description: 'Study materials retrieved' })
  @Get('course-materials')
  async getCourseMaterials(
    @CurrentSchoolId() schoolId: string,
    @Query('subjectId') subjectId?: string,
  ) {
    const data = await this.academicsService.getCourseMaterials(schoolId, subjectId);
    return { data };
  }

  @Roles(...ACADEMIC_STAFF)
  @ApiOperation({ summary: 'Upload and publish new digital study material for students' })
  @ApiResponse({ status: 201, description: 'Course study material published' })
  @Post('course-materials')
  async createCourseMaterial(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('name') userName: string,
    @Body() body: CreateCourseMaterialDto,
  ) {
    const data = await this.academicsService.createCourseMaterial(schoolId, {
      ...body,
      uploadedBy: userName,
    });
    return { data };
  }

  @ApiOperation({ summary: 'Linways Attendance Shortage Analytics (<75% Risk Detector)' })
  @ApiResponse({ status: 200, description: 'Attendance condonation risk analysis' })
  @Get('attendance-analytics')
  async getAttendanceAnalytics(@CurrentSchoolId() schoolId: string) {
    const data = await this.academicsService.getAttendanceShortageAnalytics(schoolId);
    return { data };
  }
}
