import { Injectable, ExecutionContext, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { ROLES_KEY, ALLOW_NO_MEMBERSHIP_KEY } from '../decorators/roles.decorator';

/**
 * Authenticates the bearer token, then enforces:
 *  - the user has an ACTIVE membership in the school carried by the token
 *    (unless the route is marked @AllowNoMembership), and
 *  - the membership role is one of the route's @Roles (when declared).
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private reflector: Reflector) {
    super();
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const authenticated = (await super.canActivate(context)) as boolean;
    if (!authenticated) return false;

    const user = context.switchToHttp().getRequest().user;
    const targets = [context.getHandler(), context.getClass()];

    const allowNoMembership = this.reflector.getAllAndOverride<boolean>(ALLOW_NO_MEMBERSHIP_KEY, targets);
    if (!allowNoMembership && (!user.schoolId || user.role === 'GUEST')) {
      throw new ForbiddenException('You do not have an active membership in this school');
    }

    const roles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, targets);
    if (roles && roles.length > 0 && !roles.includes(user.role)) {
      throw new ForbiddenException('Your role is not permitted to perform this action');
    }

    return true;
  }

  handleRequest(err: any, user: any) {
    if (err || !user) {
      throw err || new UnauthorizedException('Authentication required');
    }
    return user;
  }
}
