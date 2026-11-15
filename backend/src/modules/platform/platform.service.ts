import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { clearAuthCache, invalidateAuthUser } from '../../common/auth-cache';
import { CreateSchoolDto, CreateSubscriptionPlanDto, ResetSchoolAdminPasswordDto } from './platform.dto';
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
    const suspendedSchools = await this.prisma.school.count({ where: { status: 'SUSPENDED' } });
    const totalStudents = await this.prisma.student.count();
    const totalStaff = await this.prisma.staff.count();
    const totalClasses = await this.prisma.class.count();
    const plans = await this.prisma.subscriptionPlan.findMany();
    const subscriptions = await this.prisma.subscription.findMany({
      include: { plan: true },
      take: 10,
      orderBy: { startsAt: 'desc' },
    });

    return {
      totalSchools,
      activeSchools,
      suspendedSchools,
      totalStudents,
      totalStaff,
      totalClasses,
      plansAvailable: plans.length,
      estimatedArrMinor: 1499900 * activeSchools,
      subscriptions: subscriptions.map((sub) => ({
        id: sub.id,
        planName: sub.plan.name,
        planCode: sub.plan.code,
        status: sub.status,
        schoolId: sub.schoolId,
        endsAt: sub.endsAt,
      })),
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

  async updateSchoolStatus(schoolId: string, status: 'ACTIVE' | 'SUSPENDED' | 'TRIAL', actor?: { userId?: string; name?: string }) {
    const school = await this.prisma.school.findUnique({ where: { id: schoolId } });
    if (!school) {
      throw new NotFoundException('School tenant not found');
    }
    const updated = await this.prisma.school.update({
      where: { id: schoolId },
      data: { status },
    });
    clearAuthCache();

    await this.prisma.auditLog.create({
      data: {
        schoolId,
        actorId: actor?.userId || 'PLATFORM_SUPERADMIN',
        actorName: actor?.name || 'Platform Administrator',
        action: 'TENANT_STATUS_CHANGED',
        entity: 'School',
        entityId: schoolId,
        details: JSON.stringify({ previousStatus: school.status, newStatus: status }),
      },
    });

    return updated;
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

    // Use the password chosen by the platform owner, or a one-time random password that is returned once.
    const chosenPassword = dto.adminPassword;
    const temporaryPassword = chosenPassword ? null : randomBytes(12).toString('base64url');
    const passwordHash = await bcrypt.hash(chosenPassword ?? temporaryPassword!, 10);

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

      // Audit Log for Tenant Creation
      await tx.auditLog.create({
        data: {
          schoolId: school.id,
          actorId: 'PLATFORM_SUPERADMIN',
          actorName: 'Platform Administrator',
          action: 'TENANT_CREATED',
          entity: 'School',
          entityId: school.id,
          details: JSON.stringify({ name: school.name, code: school.code, adminEmail: dto.adminEmail }),
        },
      });

      // Audit Log for Role Assignment
      await tx.auditLog.create({
        data: {
          schoolId: school.id,
          actorId: 'PLATFORM_SUPERADMIN',
          actorName: 'Platform Administrator',
          action: 'ROLE_PERMISSION_CHANGED',
          entity: 'UserSchoolMembership',
          entityId: user.id,
          details: JSON.stringify({ email: user.email, role: 'SCHOOL_ADMIN', context: 'Initial tenant admin provisioning' }),
        },
      });

      return { school, createdNewUser };
    });

    return {
      ...school,
      adminCredentials: !createdNewUser
        ? { email: dto.adminEmail, note: 'Existing user was granted SCHOOL_ADMIN; their password is unchanged.' }
        : chosenPassword
          ? { email: dto.adminEmail, passwordSet: true, note: 'The admin can sign in with the password you entered.' }
          : { email: dto.adminEmail, temporaryPassword, note: 'Shown once. Share securely and change after first sign-in.' },
    };
  }

  /** School admins of a school (used by the platform console to pick whom to reset). */
  async getSchoolAdmins(schoolId: string) {
    const school = await this.prisma.school.findUnique({ where: { id: schoolId }, select: { id: true } });
    if (!school) throw new NotFoundException('School not found');
    const memberships = await this.prisma.userSchoolMembership.findMany({
      where: { schoolId, defaultRole: 'SCHOOL_ADMIN' },
      include: { user: { select: { id: true, email: true, firstName: true, lastName: true, status: true } } },
      orderBy: { createdAt: 'asc' },
    });
    return memberships.map((m) => ({
      userId: m.user.id,
      email: m.user.email,
      name: `${m.user.firstName} ${m.user.lastName}`.trim(),
      userStatus: m.user.status,
      membershipStatus: m.status,
    }));
  }

  /**
   * Sets a new password for a school's admin (chosen, or a one-time temporary one),
   * signs that user out on every device and records an audit entry.
   */
  async resetSchoolAdminPassword(
    schoolId: string,
    dto: ResetSchoolAdminPasswordDto,
    actor?: { userId?: string; name?: string },
  ) {
    const school = await this.prisma.school.findUnique({ where: { id: schoolId }, select: { id: true, code: true } });
    if (!school) throw new NotFoundException('School not found');

    const admins = await this.prisma.userSchoolMembership.findMany({
      where: { schoolId, defaultRole: 'SCHOOL_ADMIN' },
      include: { user: true },
    });
    const matches = dto.email
      ? admins.filter((m) => m.user.email.toLowerCase() === dto.email!.toLowerCase())
      : admins;

    if (matches.length === 0) {
      throw new NotFoundException(
        dto.email ? `No school admin with email ${dto.email} in this school` : 'This school has no school admin account',
      );
    }
    if (matches.length > 1) {
      throw new BadRequestException(
        `This school has ${matches.length} admins (${matches.map((m) => m.user.email).join(', ')}). Specify which email to reset.`,
      );
    }

    const user = matches[0].user;
    const temporaryPassword = dto.newPassword ? null : randomBytes(12).toString('base64url');
    const passwordHash = await bcrypt.hash(dto.newPassword ?? temporaryPassword!, 10);

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: user.id },
        data: { passwordHash, tokenVersion: { increment: 1 } },
      }),
      this.prisma.auditLog.create({
        data: {
          schoolId,
          actorId: actor?.userId || 'PLATFORM_SUPERADMIN',
          actorName: actor?.name || 'Platform Administrator',
          action: 'PASSWORD_RESET',
          entity: 'User',
          entityId: user.id,
          details: JSON.stringify({
            email: user.email,
            schoolCode: school.code,
            mode: dto.newPassword ? 'SET_BY_PLATFORM' : 'TEMPORARY_GENERATED',
          }),
        },
      }),
    ]);
    invalidateAuthUser(user.id);

    return dto.newPassword
      ? { email: user.email, passwordSet: true, note: 'Password updated. Existing sessions for this user were signed out.' }
      : {
          email: user.email,
          temporaryPassword,
          note: 'Shown once. Share securely and change after first sign-in. Existing sessions were signed out.',
        };
  }

  async updateMembershipRole(
    schoolId: string,
    membershipId: string,
    role: string,
    actor?: { userId?: string; name?: string },
  ) {
    const membership = await this.prisma.userSchoolMembership.findFirst({
      where: { id: membershipId, schoolId },
      include: { user: true },
    });
    if (!membership) {
      throw new NotFoundException('Membership not found');
    }
    const oldRole = membership.defaultRole;
    const updated = await this.prisma.userSchoolMembership.update({
      where: { id: membershipId },
      data: { defaultRole: role },
    });
    invalidateAuthUser(updated.userId);

    await this.prisma.auditLog.create({
      data: {
        schoolId,
        actorId: actor?.userId || 'ADMIN',
        actorName: actor?.name || 'Administrator',
        action: 'ROLE_PERMISSION_CHANGED',
        entity: 'UserSchoolMembership',
        entityId: membershipId,
        details: JSON.stringify({
          userId: membership.userId,
          email: membership.user?.email,
          previousRole: oldRole,
          newRole: role,
        }),
      },
    });

    return updated;
  }
}
