import { Controller, Get, Post, Patch, Body, UseGuards } from '@nestjs/common';
import { SchoolsService } from './schools.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';

@Controller('schools')
@UseGuards(JwtAuthGuard)
export class SchoolsController {
  constructor(private schoolsService: SchoolsService) {}

  @Get('current')
  async getCurrentSchool(@CurrentSchoolId() schoolId: string) {
    const data = await this.schoolsService.getCurrentSchool(schoolId);
    return { data };
  }

  @Patch('current')
  async updateSchool(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.schoolsService.updateSchool(schoolId, body);
    return { data };
  }

  @Get('academic-years')
  async getAcademicYears(@CurrentSchoolId() schoolId: string) {
    const data = await this.schoolsService.getAcademicYears(schoolId);
    return { data };
  }

  @Post('academic-years')
  async createAcademicYear(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.schoolsService.createAcademicYear(schoolId, body);
    return { data };
  }

  @Get('classes')
  async getClasses(@CurrentSchoolId() schoolId: string) {
    const data = await this.schoolsService.getClasses(schoolId);
    return { data };
  }

  @Post('classes')
  async createClass(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.schoolsService.createClass(schoolId, body);
    return { data };
  }

  @Post('sections')
  async createSection(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.schoolsService.createSection(schoolId, body);
    return { data };
  }

  @Get('subjects')
  async getSubjects(@CurrentSchoolId() schoolId: string) {
    const data = await this.schoolsService.getSubjects(schoolId);
    return { data };
  }

  @Post('subjects')
  async createSubject(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.schoolsService.createSubject(schoolId, body);
    return { data };
  }
}
