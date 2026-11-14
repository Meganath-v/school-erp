import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateSchoolDto, CreateSubscriptionPlanDto } from './platform.dto';
import * as bcrypt from 'bcryptjs';
import { randomBytes } from 'crypto';

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

  async createPlan(dto: CreateSubscriptionPlanDto) {
    const existing = await this.prisma.subscriptionPlan.findUnique({
      where: { code: dto.code.toUpperCase() },
    });
    if (existing) {
      throw new BadRequestException('A subscription plan with this code already exists');
    }
    return this.prisma.subscriptionPlan.create({
      data: {
        code: dto.code.toUpperCase(),
        name: dto.name,
        priceMinor: dto.priceMinor || 0,
        currency: dto.currency || 'INR',
        billingInterval: dto.billingInterval || 'YEARLY',
        studentLimit: dto.studentLimit || 500,
        staffLimit: dto.staffLimit || 50,
        trialDays: dto.trialDays || 30,
      },
    });
  }

  async updateSchoolStatus(schoolId: string, status: 'ACTIVE' | 'SUSPENDED' | 'TRIAL') {
    const school = await this.prisma.school.findUnique({ where: { id: schoolId } });
    if (!school) {
      throw new NotFoundException('School tenant not found');
    }
    return this.prisma.school.update({
      where: { id: schoolId },
      data: { status },
    });
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

    // One-time random password for a newly created admin; returned once so it can be handed over securely.
    const temporaryPassword = randomBytes(12).toString('base64url');
    const passwordHash = await bcrypt.hash(temporaryPassword, 10);

    const { school, createdNewUser } = await this.prisma.$transaction(async (tx) => {
      // Create school, admin user, membership, and initial subscription in transaction
      const school = await tx.school.create({
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
      let user = await tx.user.findUnique({
        where: { email: dto.adminEmail },
      });

      let createdNewUser = false;
      if (!user) {
        createdNewUser = true;
        user = await tx.user.create({
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
      await tx.userSchoolMembership.create({
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
        await tx.subscription.create({
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
      await tx.academicYear.create({
        data: {
          schoolId: school.id,
          name: '2026-2027',
          startDate: new Date('2026-06-01'),
          endDate: new Date('2027-04-30'),
          isCurrent: true,
          status: 'ACTIVE',
        },
      });

      return { school, createdNewUser };
    });

    return {
      ...school,
      adminCredentials: createdNewUser
        ? { email: dto.adminEmail, temporaryPassword, note: 'Shown once. Share securely and change after first sign-in.' }
        : { email: dto.adminEmail, note: 'Existing user was granted SCHOOL_ADMIN; their password is unchanged.' },
    };
  }
}
