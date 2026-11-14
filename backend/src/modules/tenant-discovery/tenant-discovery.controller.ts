import { Controller, Get, Param, Query, NotFoundException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';
import { PrismaService } from '../../prisma/prisma.service';

@ApiTags('Tenant Discovery & School Resolution')
@Controller()
export class TenantDiscoveryController {
  constructor(private prisma: PrismaService) {}

  @ApiOperation({ summary: 'Public discovery: search active school tenants by name, code, or city' })
  @ApiQuery({ name: 'query', required: false, description: 'Search term (school name, code, or slug)' })
  @ApiResponse({ status: 200, description: 'Matching active school tenants' })
  @Get('tenant-discovery')
  async searchTenants(@Query('query') query?: string) {
    const where = query
      ? {
          OR: [
            { name: { contains: query } },
            { code: { contains: query } },
            { slug: { contains: query } },
          ],
          status: 'ACTIVE',
        }
      : { status: 'ACTIVE' };

    const schools = await this.prisma.school.findMany({
      where,
      select: {
        id: true,
        code: true,
        name: true,
        slug: true,
        logoUrl: true,
        status: true,
        timezone: true,
        currency: true,
        address: true,
      },
      take: 20,
    });

    return { data: schools };
  }

  @ApiOperation({ summary: 'Resolve school tenant by code or subdomain slug' })
  @ApiResponse({ status: 200, description: 'Resolved tenant profile' })
  @ApiResponse({ status: 404, description: 'School tenant not found' })
  @Get('tenants/resolve/:code')
  async resolveTenant(@Param('code') code: string) {
    const school = await this.prisma.school.findFirst({
      where: {
        OR: [{ code: code.toUpperCase() }, { slug: code.toLowerCase() }],
        status: 'ACTIVE',
      },
      select: {
        id: true,
        code: true,
        name: true,
        slug: true,
        logoUrl: true,
        address: true,
        timezone: true,
        currency: true,
      },
    });

    if (!school) {
      throw new NotFoundException(`School with code or slug "${code}" not found`);
    }

    return { data: school };
  }
}
