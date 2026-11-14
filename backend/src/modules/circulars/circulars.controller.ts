import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { CircularsService } from './circulars.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateCircularDto, AcknowledgeCircularDto } from './circulars.dto';

@ApiTags('School Circulars & Parent Acknowledgments')
@ApiBearerAuth()
@Controller('circulars')
@UseGuards(JwtAuthGuard)
export class CircularsController {
  constructor(private circularsService: CircularsService) {}

  @Get()
  @ApiOperation({ summary: 'List published circulars matching the caller role and class filters' })
  @ApiQuery({ name: 'classId', required: false, description: 'Class UUID' })
  @ApiResponse({ status: 200, description: 'List of circulars' })
  async getCirculars(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @Query('classId') classId?: string,
  ) {
    const data = await this.circularsService.getCirculars(schoolId, userId, role, classId);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Post()
  @ApiOperation({ summary: 'Publish a new school circular with role and target scope validation' })
  @ApiResponse({ status: 201, description: 'Circular published successfully' })
  async createCircular(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('name') userName: string,
    @CurrentUser('role') role: string,
    @Body() body: CreateCircularDto,
  ) {
    const data = await this.circularsService.createCircular(
      schoolId,
      { userId, name: userName || 'Staff Member', role },
      body,
    );
    return { data };
  }

  @Post(':id/acknowledge')
  @ApiOperation({ summary: 'Acknowledge reading a circular' })
  @ApiParam({ name: 'id', description: 'Circular UUID' })
  @ApiResponse({ status: 200, description: 'Acknowledgment registered' })
  async acknowledgeCircular(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('name') userName: string,
    @CurrentUser('role') role: string,
    @Param('id') id: string,
    @Body() body: AcknowledgeCircularDto,
  ) {
    const data = await this.circularsService.acknowledgeCircular(
      schoolId,
      userId,
      userName || 'User',
      role,
      id,
      body.remarks,
    );
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Get(':id/acknowledgements')
  @ApiOperation({ summary: 'View list of users who acknowledged this circular' })
  @ApiParam({ name: 'id', description: 'Circular UUID' })
  @ApiResponse({ status: 200, description: 'List of acknowledgments' })
  async getAcknowledgements(
    @CurrentSchoolId() schoolId: string,
    @Param('id') id: string,
  ) {
    const data = await this.circularsService.getAcknowledgements(schoolId, id);
    return { data };
  }
}
