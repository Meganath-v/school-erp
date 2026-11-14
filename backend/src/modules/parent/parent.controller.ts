import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { ParentService } from './parent.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Parent Portal & Ward Progress')
@ApiBearerAuth()
@Controller('parent')
@UseGuards(JwtAuthGuard)
export class ParentController {
  constructor(private parentService: ParentService) {}

  @Roles('PARENT')
  @Get('my-children')
  @ApiOperation({ summary: 'Get list of wards linked to the logged-in parent with active enrollment & attendance' })
  @ApiResponse({ status: 200, description: 'List of linked children' })
  async getMyChildren(@CurrentUser('userId') userId: string, @CurrentSchoolId() schoolId: string) {
    const data = await this.parentService.getMyChildren(userId, schoolId);
    return { data };
  }

  @Roles('PARENT')
  @Get('children/:studentId/assessments')
  @ApiOperation({ summary: 'Get published examination marks, grades, and remarks for a specific ward' })
  @ApiParam({ name: 'studentId', description: 'Student UUID' })
  @ApiResponse({ status: 200, description: 'Ward assessment and marks payload' })
  async getChildAssessments(
    @CurrentUser('userId') userId: string,
    @Param('studentId') studentId: string,
    @CurrentSchoolId() schoolId: string,
  ) {
    const data = await this.parentService.getChildAssessments(userId, studentId, schoolId);
    return { data };
  }

  @Roles('PARENT')
  @Get('children/:studentId/fees')
  @ApiOperation({ summary: 'Get fee invoices, payment history, and pending balances for a specific ward' })
  @ApiParam({ name: 'studentId', description: 'Student UUID' })
  @ApiResponse({ status: 200, description: 'Ward fee invoice history' })
  async getChildFees(
    @CurrentUser('userId') userId: string,
    @Param('studentId') studentId: string,
    @CurrentSchoolId() schoolId: string,
  ) {
    const data = await this.parentService.getChildFees(userId, studentId, schoolId);
    return { data };
  }
}
