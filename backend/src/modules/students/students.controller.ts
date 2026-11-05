import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { StudentsService } from './students.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('students')
@UseGuards(JwtAuthGuard)
export class StudentsController {
  constructor(private studentsService: StudentsService) {}

  @Get()
  async getStudents(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @Query('classId') classId?: string,
    @Query('sectionId') sectionId?: string,
    @Query('search') search?: string,
  ) {
    const data = await this.studentsService.getStudents(schoolId, {
      classId,
      sectionId,
      search,
      userId,
      role,
    });
    return { data };
  }

  @Get(':id')
  async getStudentById(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    const data = await this.studentsService.getStudentById(schoolId, id);
    return { data };
  }

  @Post()
  async createStudent(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.studentsService.createStudentAdmission(schoolId, body);
    return { data };
  }

  @Get(':id/report-card')
  async getReportCard(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    const data = await this.studentsService.getReportCard(schoolId, id);
    return { data };
  }
}

@Controller('admissions')
@UseGuards(JwtAuthGuard)
export class AdmissionsController {
  constructor(private studentsService: StudentsService) {}

  @Post()
  async createAdmission(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.studentsService.createStudentAdmission(schoolId, body);
    return { data };
  }
}
