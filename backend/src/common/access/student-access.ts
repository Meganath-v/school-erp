import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export const STAFF_ROLES = ['SCHOOL_ADMIN', 'PRINCIPAL', 'OFFICE', 'CLASS_TEACHER', 'SUBJECT_TEACHER'];

/** Student IDs the given parent user is a guardian of, within a school. */
export async function getLinkedStudentIds(prisma: PrismaService, schoolId: string, userId: string): Promise<string[]> {
  const links = await prisma.studentGuardian.findMany({
    where: { guardian: { schoolId, userId }, student: { schoolId } },
    select: { studentId: true },
  });
  return [...new Set(links.map((l) => l.studentId))];
}

/**
 * Throws unless the student belongs to the school and the caller may see them:
 * staff of the school, or a parent linked to the student as a guardian.
 */
export async function assertStudentAccess(
  prisma: PrismaService,
  schoolId: string,
  user: { userId: string; role: string },
  studentId: string,
): Promise<void> {
  const student = await prisma.student.findFirst({ where: { id: studentId, schoolId }, select: { id: true } });
  if (!student) {
    throw new NotFoundException('Student not found');
  }
  if (STAFF_ROLES.includes(user.role)) return;
  if (user.role === 'PARENT') {
    const ids = await getLinkedStudentIds(prisma, schoolId, user.userId);
    if (ids.includes(studentId)) return;
  }
  if (user.role === 'STUDENT') {
    const studentUserRecord = await prisma.student.findFirst({
      where: { id: studentId, schoolId, userId: user.userId },
      select: { id: true },
    });
    if (studentUserRecord) return;
  }
  throw new ForbiddenException('You are not authorized to access records for this student');
}
