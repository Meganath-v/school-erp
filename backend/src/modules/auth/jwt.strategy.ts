import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../prisma/prisma.service';

const MIN_SECRET_LENGTH = 32;
const KNOWN_LEAKED_SECRETS = [
  'school_erp_secure_jwt_secret_key_2026_antigravity',
  'super_secret_jwt_key_change_in_production_min_32_characters',
];

/**
 * Reads the JWT signing secret from the environment. Called lazily (after ConfigModule
 * has loaded .env) and refuses to start with a missing, short, or publicly known secret.
 */
export function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < MIN_SECRET_LENGTH) {
    throw new Error(
      `JWT_SECRET must be set to a random value of at least ${MIN_SECRET_LENGTH} characters ` +
        '(e.g. `openssl rand -base64 48`).',
    );
  }
  if (KNOWN_LEAKED_SECRETS.includes(secret)) {
    throw new Error('JWT_SECRET is set to a value published in this repository. Generate a new secret.');
  }
  return secret;
}

export const ACCESS_TOKEN_TYPE = 'access';
export const REFRESH_TOKEN_TYPE = 'refresh';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: getJwtSecret(),
    });
  }

  async validate(payload: any) {
    // Refresh tokens (or tokens minted before this change) are not valid for API access.
    if (payload.typ !== ACCESS_TOKEN_TYPE) {
      throw new UnauthorizedException('Invalid access token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: {
        memberships: {
          where: { status: 'ACTIVE' },
          include: {
            school: true,
          },
        },
      },
    });

    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('User account is invalid or suspended');
    }

    // Tokens issued before the last logout are revoked.
    if (payload.ver !== user.tokenVersion) {
      throw new UnauthorizedException('Session has been revoked. Please sign in again.');
    }

    // The token's school is only honoured while the user still has an ACTIVE membership there.
    const activeMembership = user.memberships.find((m) => m.schoolId === payload.schoolId);

    // If the school is suspended and caller is not a platform superadmin, immediately reject
    const isPlatformAdmin =
      activeMembership?.defaultRole === 'PLATFORM_OWNER' || activeMembership?.defaultRole === 'SUPER_ADMIN';
    if (activeMembership && activeMembership.school && activeMembership.school.status === 'SUSPENDED' && !isPlatformAdmin) {
      throw new UnauthorizedException('School account has been suspended by the platform administrator');
    }

    return {
      userId: user.id,
      email: user.email,
      name: `${user.firstName} ${user.lastName}`,
      schoolId: activeMembership ? activeMembership.schoolId : null,
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
