import { Controller, Get, Param, Query, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Controller()
export class TenantDiscoveryController {
  constructor(private prisma: PrismaService) {}

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
        status: true,
        timezone: true,
        currency: true,
        address: true,
      },
    });

    if (!school) {
      throw new NotFoundException(`School with code or slug "${code}" was not found`);
    }

    return { data: school };
  }
}
