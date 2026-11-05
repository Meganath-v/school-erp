import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateSchoolDto } from './platform.dto';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class PlatformService {
  constructor(private prisma: PrismaService) {}

  async getAllSchools() {
    const schools = await this.prisma.school.findMany({
      include: {
        subscriptions: {
          include: {
            plan: true,
          },
          orderBy: { startsAt: 'desc' },
          take: 1,
        },
        _count: {
          select: {
            students: true,
            staff: true,
            classes: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return schools.map((s) => ({
      id: s.id,
      name: s.name,
      code: s.code,
      slug: s.slug,
      status: s.status,
      address: s.address,
      contactEmail: s.contactEmail,
      contactPhone: s.contactPhone,
      studentCount: s._count.students,
      staffCount: s._count.staff,
      classCount: s._count.classes,
      activeSubscription: s.subscriptions[0]
        ? {
            planName: s.subscriptions[0].plan.name,
            status: s.subscriptions[0].status,
            endsAt: s.subscriptions[0].endsAt,
          }
        : null,
      createdAt: s.createdAt,
    }));
  }

  async getPlatformStats() {
    const totalSchools = await this.prisma.school.count();
    const activeSchools = await this.prisma.school.count({ where: { status: 'ACTIVE' } });
    const totalStudents = await this.prisma.student.count();
    const totalStaff = await this.prisma.staff.count();
    const plans = await this.prisma.subscriptionPlan.findMany();

    return {
      totalSchools,
      activeSchools,
      totalStudents,
      totalStaff,
      plansAvailable: plans.length,
      estimatedArrMinor: 1499900 * activeSchools, // Mock ARR calculation based on active plans
    };
  }

  async getPlans() {
    return this.prisma.subscriptionPlan.findMany();
  }

  async createSchool(dto: CreateSchoolDto) {
    const existingCode = await this.prisma.school.findFirst({
      where: {
        OR: [{ code: dto.code.toUpperCase() }, { slug: dto.slug.toLowerCase() }],
      },
    });

    if (existingCode) {
      throw new BadRequestException('A school with this code or slug already exists');
    }

    const defaultPlan = await this.prisma.subscriptionPlan.findFirst({
      where: dto.planCode ? { code: dto.planCode } : { code: 'GROWTH' },
    });

    const passwordHash = await bcrypt.hash('password123', 10);

    // Create school, admin user, membership, and initial subscription in transaction
    const school = await this.prisma.school.create({
      data: {
        name: dto.name,
        code: dto.code.toUpperCase(),
        slug: dto.slug.toLowerCase(),
        address: dto.address,
        contactEmail: dto.contactEmail,
        contactPhone: dto.contactPhone,
        status: 'ACTIVE',
      },
    });

    // Find or create admin user
    let user = await this.prisma.user.findUnique({
      where: { email: dto.adminEmail },
    });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          email: dto.adminEmail,
          firstName: dto.adminFirstName,
          lastName: dto.adminLastName,
          passwordHash,
          status: 'ACTIVE',
        },
      });
    }

    // Assign School Admin membership
    await this.prisma.userSchoolMembership.create({
      data: {
        userId: user.id,
        schoolId: school.id,
        defaultRole: 'SCHOOL_ADMIN',
        status: 'ACTIVE',
      },
    });

    // Create subscription
    if (defaultPlan) {
      const endsAt = new Date();
      endsAt.setFullYear(endsAt.getFullYear() + 1);
      await this.prisma.subscription.create({
        data: {
          schoolId: school.id,
          planId: defaultPlan.id,
          status: 'ACTIVE',
          startsAt: new Date(),
          endsAt,
          providerRef: `SUB_${school.code}_INIT`,
        },
      });
    }

    // Default Academic Year
    await this.prisma.academicYear.create({
      data: {
        schoolId: school.id,
        name: '2026-2027',
        startDate: new Date('2026-06-01'),
        endDate: new Date('2027-04-30'),
        isCurrent: true,
        status: 'ACTIVE',
      },
    });

    return school;
  }
}
