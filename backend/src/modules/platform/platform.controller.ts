import { Controller, Get, Post, Body, UseGuards, ForbiddenException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { PlatformService } from './platform.service';
import { CreateSchoolDto } from './platform.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, PLATFORM_ADMINS } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Platform Superadmin Control Plane')
@ApiBearerAuth()
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
  @ApiOperation({ summary: 'List all provisioned school tenants across the SaaS platform' })
  @ApiResponse({ status: 200, description: 'Tenants directory retrieved' })
  @Get('schools')
  async getAllSchools(@CurrentUser('role') role: string) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.getAllSchools();
    return { data };
  }

  @Roles(...PLATFORM_ADMINS)
  @ApiOperation({ summary: 'Provision new multi-tenant school with admin account and subscription' })
  @ApiResponse({ status: 201, description: 'School provisioned and admin credentials generated' })
  @Post('schools')
  async createSchool(@CurrentUser('role') role: string, @Body() dto: CreateSchoolDto) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.createSchool(dto);
    return { data };
  }

  @Roles(...PLATFORM_ADMINS)
  @ApiOperation({ summary: 'Platform-wide metrics (total schools, students, ARR minor, faculty)' })
  @ApiResponse({ status: 200, description: 'SaaS metrics retrieved' })
  @Get('stats')
  async getStats(@CurrentUser('role') role: string) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.getPlatformStats();
    return { data };
  }

  @Roles(...PLATFORM_ADMINS)
  @ApiOperation({ summary: 'List SaaS subscription tier plans' })
  @ApiResponse({ status: 200, description: 'Subscription plans retrieved' })
  @Get('plans')
  async getPlans(@CurrentUser('role') role: string) {
    this.assertSuperAdmin(role);
    const data = await this.platformService.getPlans();
    return { data };
  }
}
