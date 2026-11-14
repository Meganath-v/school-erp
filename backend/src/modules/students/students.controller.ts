import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { StudentsService } from './students.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF, OFFICE_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('students')
@UseGuards(JwtAuthGuard)
export class StudentsController {
  constructor(private studentsService: StudentsService) {}

  @Roles(...ALL_STAFF, 'PARENT')
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

  @Roles(...ALL_STAFF, 'PARENT')
  @Get(':id')
  async getStudentById(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Param('id') id: string) {
    const data = await this.studentsService.getStudentById(schoolId, id, user);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Post()
  async createStudent(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.studentsService.createStudentAdmission(schoolId, body);
    return { data };
  }

  @Roles(...ALL_STAFF, 'PARENT')
  @Get(':id/report-card')
  async getReportCard(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Param('id') id: string) {
    const data = await this.studentsService.getReportCard(schoolId, id, user);
    return { data };
  }
}

@Controller('admissions')
@UseGuards(JwtAuthGuard)
export class AdmissionsController {
  constructor(private studentsService: StudentsService) {}

  @Roles(...OFFICE_STAFF)
  @Post()
  async createAdmission(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.studentsService.createStudentAdmission(schoolId, body);
    return { data };
  }
}
