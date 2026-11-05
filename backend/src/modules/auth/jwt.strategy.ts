import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../prisma/prisma.service';

export const JWT_SECRET = process.env.JWT_SECRET || 'school_erp_secure_jwt_secret_key_2026_antigravity';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: JWT_SECRET,
    });
  }

  async validate(payload: any) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: {
        memberships: {
          include: {
            school: true,
          },
        },
      },
    });

    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('User account is invalid or suspended');
    }

    const activeSchoolId = payload.schoolId || user.memberships[0]?.schoolId;
    const activeMembership = user.memberships.find((m) => m.schoolId === activeSchoolId);

    return {
      userId: user.id,
      email: user.email,
      name: `${user.firstName} ${user.lastName}`,
      schoolId: activeSchoolId,
      role: activeMembership ? activeMembership.defaultRole : 'GUEST',
      activeSchool: activeMembership?.school || null,
      memberships: user.memberships.map((m) => ({
        schoolId: m.schoolId,
        schoolName: m.school.name,
        schoolCode: m.school.code,
        role: m.defaultRole,
      })),
    };
  }
}
