import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ACADEMIC_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';

@Controller('teacher')
@UseGuards(JwtAuthGuard)
export class TeacherController {
  constructor(private prisma: PrismaService) {}

  @Roles(...ACADEMIC_STAFF)
  @Get('my-classes')
  async getMyClasses(@CurrentSchoolId() schoolId: string, @CurrentUser('userId') userId: string) {
    const staff = await this.prisma.staff.findFirst({
      where: { schoolId, userId },
      include: {
        teacherAssignments: {
          include: {
            class: true,
            section: true,
            subject: true,
          },
        },
      },
    });

    if (!staff) {
      return {
        data: {
          staffId: null,
          staffName: 'Faculty',
          isClassTeacher: false,
          assignedSections: [],
        },
      };
    }

    const assignedSectionsMap = new Map<string, any>();

    for (const a of staff.teacherAssignments) {
      if (!assignedSectionsMap.has(a.sectionId)) {
        // Fetch students currently enrolled in this section
        const enrollments = await this.prisma.enrollment.findMany({
          where: {
            schoolId,
            sectionId: a.sectionId,
            status: 'ACTIVE',
          },
          include: {
            student: {
              include: {
                attendanceRecords: true,
              },
            },
          },
        });

        const students = enrollments.map((e) => {
          const s = e.student;
          const totalSessions = s.attendanceRecords.length;
          const present = s.attendanceRecords.filter(
            (r) => r.status === 'PRESENT' || r.status === 'EXCUSED' || r.status === 'LATE',
          ).length;
          const attendancePct = totalSessions > 0 ? Math.round((present / totalSessions) * 100) : 95;

          return {
            id: s.id,
            admissionNo: s.admissionNo,
            name: `${s.firstName} ${s.lastName}`,
            gender: s.gender,
            bloodGroup: s.bloodGroup,
            attendancePct,
            isAttendanceRisk: attendancePct < 75,
          };
        });

        assignedSectionsMap.set(a.sectionId, {
          sectionId: a.sectionId,
          sectionName: a.section.name,
          classId: a.classId,
          className: a.class.name,
          isClassTeacher: a.isClassTeacher,
          studentCount: students.length,
          students,
          subjects: [],
        });
      }

      if (a.subject) {
        assignedSectionsMap.get(a.sectionId).subjects.push({
          id: a.subject.id,
          name: a.subject.name,
          code: a.subject.code,
        });
      }
    }

    // Pending leave requests for teacher's section
    const assignedSectionIds = Array.from(assignedSectionsMap.keys());
    const pendingLeaveCount = await this.prisma.leaveRequest.count({
      where: {
        schoolId,
        status: 'PENDING',
        student: {
          enrollments: {
            some: {
              sectionId: { in: assignedSectionIds },
              status: 'ACTIVE',
            },
          },
        },
      },
    });

    return {
      data: {
        staffId: staff.id,
        staffName: `${staff.firstName} ${staff.lastName}`,
        employeeNo: staff.employeeNo,
        designation: staff.designation,
        isClassTeacher: staff.teacherAssignments.some((a) => a.isClassTeacher),
        pendingLeaveCount,
        assignedSections: Array.from(assignedSectionsMap.values()),
      },
    };
  }
}
