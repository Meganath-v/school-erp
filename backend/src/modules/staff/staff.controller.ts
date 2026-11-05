import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { StaffService } from './staff.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';

@Controller('staff')
@UseGuards(JwtAuthGuard)
export class StaffController {
  constructor(private staffService: StaffService) {}

  @Get()
  async getStaff(@CurrentSchoolId() schoolId: string) {
    const data = await this.staffService.getStaff(schoolId);
    return { data };
  }

  @Post()
  async createStaff(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.staffService.createStaff(schoolId, body);
    return { data };
  }

  @Get('assignments')
  async getAssignments(@CurrentSchoolId() schoolId: string) {
    const data = await this.staffService.getAssignments(schoolId);
    return { data };
  }

  @Post('assignments')
  async createAssignment(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.staffService.createAssignment(schoolId, body);
    return { data };
  }
}
