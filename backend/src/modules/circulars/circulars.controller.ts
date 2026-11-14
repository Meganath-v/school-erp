import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { CircularsService } from './circulars.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('circulars')
@UseGuards(JwtAuthGuard)
export class CircularsController {
  constructor(private circularsService: CircularsService) {}

  @Get()
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
  async createCircular(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('name') userName: string,
    @CurrentUser('role') role: string,
    @Body() body: any,
  ) {
    const data = await this.circularsService.createCircular(
      schoolId,
      { userId, name: userName || 'Staff Member', role },
      body,
    );
    return { data };
  }

  @Post(':id/acknowledge')
  async acknowledgeCircular(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('name') userName: string,
    @CurrentUser('role') role: string,
    @Param('id') id: string,
    @Body('remarks') remarks?: string,
  ) {
    const data = await this.circularsService.acknowledgeCircular(
      schoolId,
      userId,
      userName || 'User',
      role,
      id,
      remarks,
    );
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Get(':id/acknowledgements')
  async getAcknowledgements(
    @CurrentSchoolId() schoolId: string,
    @Param('id') id: string,
  ) {
    const data = await this.circularsService.getAcknowledgements(schoolId, id);
    return { data };
  }
}

