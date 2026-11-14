import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { StaffService } from './staff.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF, SCHOOL_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';
import { CreateStaffDto, CreateAssignmentDto } from './staff.dto';

@ApiTags('Staff & Teacher Management')
@ApiBearerAuth()
@Controller('staff')
@UseGuards(JwtAuthGuard)
export class StaffController {
  constructor(private staffService: StaffService) {}

  @Roles(...ALL_STAFF)
  @Get()
  @ApiOperation({ summary: 'List all staff members and their active class/subject assignments' })
  @ApiResponse({ status: 200, description: 'List of staff members retrieved successfully' })
  async getStaff(@CurrentSchoolId() schoolId: string) {
    const data = await this.staffService.getStaff(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Post()
  @ApiOperation({ summary: 'Onboard a new staff member' })
  @ApiResponse({ status: 201, description: 'Staff member onboarded successfully' })
  async createStaff(@CurrentSchoolId() schoolId: string, @Body() body: CreateStaffDto) {
    const data = await this.staffService.createStaff(schoolId, body);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Get('assignments')
  @ApiOperation({ summary: 'Get all teacher-to-class/section/subject assignments' })
  @ApiResponse({ status: 200, description: 'Teacher assignments retrieved successfully' })
  async getAssignments(@CurrentSchoolId() schoolId: string) {
    const data = await this.staffService.getAssignments(schoolId);
    return { data };
  }

  @Roles(...SCHOOL_ADMINS)
  @Post('assignments')
  @ApiOperation({ summary: 'Assign a staff member as Class Teacher or Subject Teacher' })
  @ApiResponse({ status: 201, description: 'Assignment created successfully' })
  async createAssignment(@CurrentSchoolId() schoolId: string, @Body() body: CreateAssignmentDto) {
    const data = await this.staffService.createAssignment(schoolId, body);
    return { data };
  }
}
