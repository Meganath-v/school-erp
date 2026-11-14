import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { StudentsService } from './students.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, OFFICE_STAFF, ALL_SCHOOL_ROLES } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateStudentAdmissionDto, UpdateStudentDto, GetStudentsFilterDto } from './students.dto';

@ApiTags('Student Lifecycle, Directory & Records')
@ApiBearerAuth()
@Controller('students')
@UseGuards(JwtAuthGuard)
export class StudentsController {
  constructor(private studentsService: StudentsService) {}

  @Roles('STUDENT')
  @Get('me/profile')
  @ApiOperation({ summary: 'Get profile and academic enrollment details of the logged-in student' })
  @ApiResponse({ status: 200, description: 'Student profile payload' })
  async getStudentMe(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
  ) {
    const data = await this.studentsService.getStudentMe(schoolId, userId);
    return { data };
  }

  @Roles(...ALL_SCHOOL_ROLES)
  @Get()
  @ApiOperation({ summary: 'List students with class, section, search and tenant filters' })
  @ApiResponse({ status: 200, description: 'List of students' })
  async getStudents(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @Query() query: GetStudentsFilterDto,
  ) {
    const data = await this.studentsService.getStudents(schoolId, {
      classId: query.classId,
      sectionId: query.sectionId,
      search: query.search,
      userId,
      role,
    });
    return { data };
  }

  @Roles(...ALL_SCHOOL_ROLES)
  @Get(':id')
  @ApiOperation({ summary: 'Get student details, enrollments, attendance summary, and marks' })
  @ApiParam({ name: 'id', description: 'Student UUID' })
  @ApiResponse({ status: 200, description: 'Student profile and record history' })
  async getStudentById(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Param('id') id: string) {
    const data = await this.studentsService.getStudentById(schoolId, id, user);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Post()
  @ApiOperation({ summary: 'Admit a new student with optional enrollment and guardian link' })
  @ApiResponse({ status: 201, description: 'Student admitted successfully' })
  async createStudent(@CurrentSchoolId() schoolId: string, @Body() body: CreateStudentAdmissionDto) {
    const data = await this.studentsService.createStudentAdmission(schoolId, body);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Patch(':id')
  @ApiOperation({ summary: 'Update student profile fields' })
  @ApiParam({ name: 'id', description: 'Student UUID' })
  @ApiResponse({ status: 200, description: 'Student updated successfully' })
  async updateStudent(
    @CurrentSchoolId() schoolId: string,
    @Param('id') id: string,
    @Body() body: UpdateStudentDto,
  ) {
    const data = await this.studentsService.updateStudent(schoolId, id, body);
    return { data };
  }

  @Roles(...ALL_SCHOOL_ROLES)
  @Get(':id/report-card')
  @ApiOperation({ summary: 'Generate comprehensive academic report card for a student' })
  @ApiParam({ name: 'id', description: 'Student UUID' })
  @ApiResponse({ status: 200, description: 'Report card data' })
  async getReportCard(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Param('id') id: string) {
    const data = await this.studentsService.getReportCard(schoolId, id, user);
    return { data };
  }
}

@ApiTags('Student Lifecycle, Directory & Records')
@ApiBearerAuth()
@Controller('admissions')
@UseGuards(JwtAuthGuard)
export class AdmissionsController {
  constructor(private studentsService: StudentsService) {}

  @Roles(...OFFICE_STAFF)
  @Post()
  @ApiOperation({ summary: 'Admit a new student (admissions alias)' })
  @ApiResponse({ status: 201, description: 'Student admitted successfully' })
  async createAdmission(@CurrentSchoolId() schoolId: string, @Body() body: CreateStudentAdmissionDto) {
    const data = await this.studentsService.createStudentAdmission(schoolId, body);
    return { data };
  }
}
