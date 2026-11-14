import { Injectable, UnauthorizedException, BadRequestException, NotFoundException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { LoginDto, SwitchSchoolDto, RefreshTokenDto } from './auth.dto';
import * as bcrypt from 'bcryptjs';
import { ACCESS_TOKEN_TYPE, REFRESH_TOKEN_TYPE } from './jwt.strategy';

type TokenClaims = { sub: string; email: string; schoolId: string; role: string; ver: number };

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
  ) {}

  private issueTokens(claims: TokenClaims) {
    const accessToken = this.jwtService.sign({ ...claims, typ: ACCESS_TOKEN_TYPE }, { expiresIn: '1d' });
    const refreshToken = this.jwtService.sign({ ...claims, typ: REFRESH_TOKEN_TYPE }, { expiresIn: '7d' });
    return { accessToken, refreshToken };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findFirst({
      where: {
        OR: [
          { email: dto.login },
          { username: dto.login },
          { phone: dto.login },
        ],
      },
      include: {
        memberships: {
          where: { status: 'ACTIVE', school: { status: { in: ['ACTIVE', 'TRIAL'] } } },
          orderBy: { createdAt: 'asc' }, // deterministic default school
          include: {
            school: true,
          },
        },
      },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isMatch = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isMatch) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Account suspended');
    }

    if (user.memberships.length === 0) {
      throw new UnauthorizedException('User has no active school memberships');
    }

    // Determine target school
    let activeMembership = user.memberships[0];
    if (dto.schoolCode) {
      const match = user.memberships.find(
        (m) => m.school.code.toLowerCase() === dto.schoolCode?.toLowerCase(),
      );
      if (!match) {
        throw new UnauthorizedException('You do not have an active membership in this school');
      }
      activeMembership = match;
    }

    const { accessToken, refreshToken } = this.issueTokens({
      sub: user.id,
      email: user.email,
      schoolId: activeMembership.schoolId,
      role: activeMembership.defaultRole,
      ver: user.tokenVersion,
    });

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: `${user.firstName} ${user.lastName}`,
        firstName: user.firstName,
        lastName: user.lastName,
        avatarUrl: user.avatarUrl,
        activeRole: activeMembership.defaultRole,
        activeSchool: {
          id: activeMembership.school.id,
          name: activeMembership.school.name,
          code: activeMembership.school.code,
          logoUrl: activeMembership.school.logoUrl,
          currency: activeMembership.school.currency,
        },
        memberships: user.memberships.map((m) => ({
          schoolId: m.school.id,
          schoolName: m.school.name,
          schoolCode: m.school.code,
          role: m.defaultRole,
        })),
      },
    };
  }

  async getMe(userId: string, currentSchoolId?: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        memberships: {
          include: {
            school: true,
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const activeSchoolId = currentSchoolId || user.memberships[0]?.schoolId;
    const activeMembership = user.memberships.find((m) => m.schoolId === activeSchoolId) || user.memberships[0];

    return {
      id: user.id,
      email: user.email,
      name: `${user.firstName} ${user.lastName}`,
      firstName: user.firstName,
      lastName: user.lastName,
      avatarUrl: user.avatarUrl,
      activeRole: activeMembership?.defaultRole || 'GUEST',
      activeSchool: activeMembership?.school
        ? {
            id: activeMembership.school.id,
            name: activeMembership.school.name,
            code: activeMembership.school.code,
            logoUrl: activeMembership.school.logoUrl,
            currency: activeMembership.school.currency,
            timezone: activeMembership.school.timezone,
            status: activeMembership.school.status,
          }
        : null,
      memberships: user.memberships.map((m) => ({
        schoolId: m.school.id,
        schoolName: m.school.name,
        schoolCode: m.school.code,
        role: m.defaultRole,
      })),
    };
  }

  async switchSchool(userId: string, dto: SwitchSchoolDto) {
    const membership = await this.prisma.userSchoolMembership.findUnique({
      where: {
        userId_schoolId: {
          userId,
          schoolId: dto.schoolId,
        },
      },
      include: {
        school: true,
        user: true,
      },
    });

    if (!membership || membership.status !== 'ACTIVE' || !['ACTIVE', 'TRIAL'].includes(membership.school.status)) {
      throw new BadRequestException('You do not have a verified membership in this school');
    }

    const { accessToken, refreshToken } = this.issueTokens({
      sub: userId,
      email: membership.user.email,
      schoolId: membership.schoolId,
      role: membership.defaultRole,
      ver: membership.user.tokenVersion,
    });

    return {
      accessToken,
      refreshToken,
      activeSchool: {
        id: membership.school.id,
        name: membership.school.name,
        code: membership.school.code,
        currency: membership.school.currency,
      },
      activeRole: membership.defaultRole,
    };
  }

  async refreshToken(dto: RefreshTokenDto) {
    let decoded: any;
    try {
      decoded = this.jwtService.verify(dto.refreshToken);
    } catch (e) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }
    if (decoded.typ !== REFRESH_TOKEN_TYPE) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    // Re-check the account and membership so suspended users / revoked sessions cannot refresh.
    const membership = await this.prisma.userSchoolMembership.findUnique({
      where: { userId_schoolId: { userId: decoded.sub, schoolId: decoded.schoolId } },
      include: { user: true },
    });
    if (
      !membership ||
      membership.status !== 'ACTIVE' ||
      membership.user.status !== 'ACTIVE' ||
      membership.user.tokenVersion !== decoded.ver
    ) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const { accessToken } = this.issueTokens({
      sub: membership.userId,
      email: membership.user.email,
      schoolId: membership.schoolId,
      role: membership.defaultRole,
      ver: membership.user.tokenVersion,
    });
    return { accessToken };
  }

  /** Revokes every access and refresh token issued to the user so far. */
  async logout(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { tokenVersion: { increment: 1 } },
    });
    return { message: 'Logged out successfully' };
  }
}
