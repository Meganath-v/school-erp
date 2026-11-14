import { Controller, Get, Post, Patch, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { SchoolsService } from './schools.service';
import {
  UpdateSchoolDto,
  CreateAcademicYearDto,
  CreateAcademicTermDto,
  CreateCampusDto,
  CreateClassDto,
  CreateSectionDto,
  CreateSubjectDto,
} from './schools.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';

@ApiTags('School Institutional Configuration')
@ApiBearerAuth()
@Controller('schools')
@UseGuards(JwtAuthGuard)
export class SchoolsController {
  constructor(private schoolsService: SchoolsService) {}

  @ApiOperation({ summary: 'Get current school tenant profile and active subscription' })
  @ApiResponse({ status: 200, description: 'School profile retrieved' })
  @Get('current')
  async getCurrentSchool(@CurrentSchoolId() schoolId: string) {
    const data = await this.schoolsService.getCurrentSchool(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Update school tenant settings (name, address, currency, timezone)' })
  @ApiResponse({ status: 200, description: 'School profile updated' })
  @Patch('current')
  async updateSchool(@CurrentSchoolId() schoolId: string, @Body() body: UpdateSchoolDto) {
    const data = await this.schoolsService.updateSchool(schoolId, body);
    return { data };
  }

  // Campuses
  @ApiOperation({ summary: 'List campuses / branches configured for this institution' })
  @ApiResponse({ status: 200, description: 'Campuses list' })
  @Get('campuses')
  async getCampuses(@CurrentSchoolId() schoolId: string) {
    const data = await this.schoolsService.getCampuses(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Create a new campus or physical branch' })
  @ApiResponse({ status: 201, description: 'Campus created' })
  @Post('campuses')
  async createCampus(@CurrentSchoolId() schoolId: string, @Body() body: CreateCampusDto) {
    const data = await this.schoolsService.createCampus(schoolId, body);
    return { data };
  }

  // Academic Years & Terms
  @ApiOperation({ summary: 'List academic years configured for this school' })
  @ApiResponse({ status: 200, description: 'Academic years retrieved' })
  @Get('academic-years')
  async getAcademicYears(@CurrentSchoolId() schoolId: string) {
    const data = await this.schoolsService.getAcademicYears(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Create new academic year session (atomic isCurrent update)' })
  @ApiResponse({ status: 201, description: 'Academic year session created' })
  @Post('academic-years')
  async createAcademicYear(@CurrentSchoolId() schoolId: string, @Body() body: CreateAcademicYearDto) {
    const data = await this.schoolsService.createAcademicYear(schoolId, body);
    return { data };
  }

  @ApiOperation({ summary: 'List academic terms / semesters' })
  @ApiResponse({ status: 200, description: 'Academic terms retrieved' })
  @Get('academic-terms')
  async getAcademicTerms(
    @CurrentSchoolId() schoolId: string,
    @Query('academicYearId') academicYearId?: string,
  ) {
    const data = await this.schoolsService.getAcademicTerms(schoolId, academicYearId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Create new academic term or semester' })
  @ApiResponse({ status: 201, description: 'Academic term created' })
  @Post('academic-terms')
  async createAcademicTerm(@CurrentSchoolId() schoolId: string, @Body() body: CreateAcademicTermDto) {
    const data = await this.schoolsService.createAcademicTerm(schoolId, body);
    return { data };
  }

  // Classes & Sections
  @ApiOperation({ summary: 'List academic classes, sections, and curriculum subjects' })
  @ApiResponse({ status: 200, description: 'Classes and sections hierarchy' })
  @Get('classes')
  async getClasses(@CurrentSchoolId() schoolId: string) {
    const data = await this.schoolsService.getClasses(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Create a new class or grade level' })
  @ApiResponse({ status: 201, description: 'Class created' })
  @Post('classes')
  async createClass(@CurrentSchoolId() schoolId: string, @Body() body: CreateClassDto) {
    const data = await this.schoolsService.createClass(schoolId, body);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Create a section classroom inside a class' })
  @ApiResponse({ status: 201, description: 'Section created' })
  @Post('sections')
  async createSection(@CurrentSchoolId() schoolId: string, @Body() body: CreateSectionDto) {
    const data = await this.schoolsService.createSection(schoolId, body);
    return { data };
  }

  // Subjects
  @ApiOperation({ summary: 'List curriculum courses / subjects' })
  @ApiResponse({ status: 200, description: 'Subjects list' })
  @Get('subjects')
  async getSubjects(@CurrentSchoolId() schoolId: string) {
    const data = await this.schoolsService.getSubjects(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @ApiOperation({ summary: 'Create a new curriculum subject' })
  @ApiResponse({ status: 201, description: 'Subject created' })
  @Post('subjects')
  async createSubject(@CurrentSchoolId() schoolId: string, @Body() body: CreateSubjectDto) {
    const data = await this.schoolsService.createSubject(schoolId, body);
    return { data };
  }
}
