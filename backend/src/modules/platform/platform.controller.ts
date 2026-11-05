import { Controller, Get, Post, Body, UseGuards, ForbiddenException } from '@nestjs/common';
import { PlatformService } from './platform.service';
import { CreateSchoolDto } from './platform.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('platform')
@UseGuards(JwtAuthGuard)
export class PlatformController {
  constructor(private platformService: PlatformService) {}

  private assertSuperAdmin(role: string) {
    if (role !== 'PLATFORM_OWNER' && role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Access restricted to platform administrators');
    }
  }

  @Get('schools')
  async getAllSchools(@CurrentUser('role') role: string) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.getAllSchools();
    return { data };
  }

  @Post('schools')
  async createSchool(@CurrentUser('role') role: string, @Body() dto: CreateSchoolDto) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.createSchool(dto);
    return { data };
  }

  @Get('stats')
  async getStats(@CurrentUser('role') role: string) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.getPlatformStats();
    return { data };
  }

  @Get('plans')
  async getPlans(@CurrentUser('role') role: string) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.getPlans();
    return { data };
  }
}
