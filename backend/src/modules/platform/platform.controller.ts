import { Controller, Get, Post, Body, UseGuards, ForbiddenException } from '@nestjs/common';
import { PlatformService } from './platform.service';
import { CreateSchoolDto } from './platform.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, PLATFORM_ADMINS } from '../../common/decorators/roles.decorator';
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

  @Roles(...PLATFORM_ADMINS)
  @Get('schools')
  async getAllSchools(@CurrentUser('role') role: string) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.getAllSchools();
    return { data };
  }

  @Roles(...PLATFORM_ADMINS)
  @Post('schools')
  async createSchool(@CurrentUser('role') role: string, @Body() dto: CreateSchoolDto) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.createSchool(dto);
    return { data };
  }

  @Roles(...PLATFORM_ADMINS)
  @Get('stats')
  async getStats(@CurrentUser('role') role: string) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.getPlatformStats();
    return { data };
  }

  @Roles(...PLATFORM_ADMINS)
  @Get('plans')
  async getPlans(@CurrentUser('role') role: string) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.getPlans();
    return { data };
  }
}
