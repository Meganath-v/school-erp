import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';
export const ALLOW_NO_MEMBERSHIP_KEY = 'allowNoMembership';

/**
 * Restricts a route (or every route of a controller) to the given membership roles.
 * Routes without @Roles are open to any user with an ACTIVE membership in the current school.
 */
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);

/**
 * Lets an authenticated user reach the route even without an active membership
 * in the school carried by their token (e.g. /auth/me, /auth/switch-school).
 */
export const AllowNoMembership = () => SetMetadata(ALLOW_NO_MEMBERSHIP_KEY, true);

// Common role groups
export const SCHOOL_ADMINS = ['SCHOOL_ADMIN', 'PRINCIPAL'];
export const OFFICE_STAFF = ['SCHOOL_ADMIN', 'PRINCIPAL', 'OFFICE'];
export const TEACHERS = ['CLASS_TEACHER', 'SUBJECT_TEACHER'];
export const ACADEMIC_STAFF = [...SCHOOL_ADMINS, ...TEACHERS];
export const ALL_STAFF = [...OFFICE_STAFF, ...TEACHERS];
export const PLATFORM_ADMINS = ['PLATFORM_OWNER', 'SUPER_ADMIN'];
