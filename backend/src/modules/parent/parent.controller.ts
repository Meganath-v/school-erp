import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ParentService } from './parent.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('parent')
@UseGuards(JwtAuthGuard)
export class ParentController {
  constructor(private parentService: ParentService) {}

  @Get('my-children')
  async getMyChildren(@CurrentUser('userId') userId: string, @CurrentSchoolId() schoolId: string) {
    const data = await this.parentService.getMyChildren(userId, schoolId);
    return { data };
  }

  @Get('children/:studentId/assessments')
  async getChildAssessments(
    @CurrentUser('userId') userId: string,
    @Param('studentId') studentId: string,
    @CurrentSchoolId() schoolId: string,
  ) {
    const data = await this.parentService.getChildAssessments(userId, studentId, schoolId);
    return { data };
  }

  @Get('children/:studentId/fees')
  async getChildFees(
    @CurrentUser('userId') userId: string,
    @Param('studentId') studentId: string,
    @CurrentSchoolId() schoolId: string,
  ) {
    const data = await this.parentService.getChildFees(userId, studentId, schoolId);
    return { data };
  }
}
