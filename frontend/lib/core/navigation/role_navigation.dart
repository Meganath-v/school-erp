import 'package:flutter/material.dart';
import '../auth/roles.dart';
import '../../features/attendance/presentation/attendance_management_screen.dart';
import '../../features/audit/presentation/audit_logs_screen.dart';
import '../../features/circulars/presentation/circular_management_screen.dart';
import '../../features/class_teacher/presentation/teacher_dashboard.dart';
import '../../features/examination/presentation/examination_management_screen.dart';
import '../../features/fees/presentation/fee_management_screen.dart';
import '../../features/office/presentation/office_dashboard.dart';
import '../../features/parent/presentation/parent_portal_screen.dart';
import '../../features/platform_admin/presentation/platform_dashboard_screen.dart';
import '../../features/principal/presentation/principal_dashboard.dart';
import '../../features/reports/presentation/reports_analytics_screen.dart';
import '../../features/school_admin/presentation/school_admin_dashboard.dart';
import '../../features/staff/presentation/staff_management_screen.dart';
import '../../features/student/presentation/student_portal_screen.dart';
import '../../features/students/presentation/student_management_screen.dart';
import '../../features/subject_teacher/presentation/subject_teacher_dashboard.dart';
import '../../features/timetable/presentation/timetable_management_screen.dart';

/// A screen a role may open. [label] is used in menus and app bars,
/// [shortLabel] in the bottom navigation bar.
class RoleSection {
  final String id;
  final String label;
  final String shortLabel;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;

  const RoleSection({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });
}

class RoleNavigation {
  final String role;

  /// Every section the role can open, in menu order.
  final List<RoleSection> sections;

  /// Ids of up to three sections pinned to the mobile bottom bar (after Home).
  final List<String> primaryIds;

  const RoleNavigation({required this.role, required this.sections, required this.primaryIds});

  List<RoleSection> get primarySections =>
      primaryIds.map((id) => sections.firstWhere((s) => s.id == id)).toList();

  int indexOf(String id) => sections.indexWhere((s) => s.id == id);

  /// Navigation for [role], or `null` for roles the app does not support.
  /// Unknown roles must never fall back to another role's screens.
  static RoleNavigation? forRole(String? role) {
    switch (role) {
      case AppRoles.platformOwner:
        return RoleNavigation(role: role!, primaryIds: const ['schools', 'audit'], sections: [
          _s('schools', 'Schools & Plans', 'Schools', Icons.domain_outlined, Icons.domain, (_) => const PlatformDashboardScreen()),
          _audit,
        ]);
      case AppRoles.schoolAdmin:
        return RoleNavigation(role: role!, primaryIds: const ['students', 'fees', 'attendance'], sections: [
          _s('dashboard', 'Campus Dashboard', 'Dashboard', Icons.dashboard_outlined, Icons.dashboard, (_) => const SchoolAdminDashboard()),
          _reports,
          _students,
          _s('staff', 'Faculty & Staff', 'Staff', Icons.badge_outlined, Icons.badge, (_) => const StaffManagementScreen()),
          _attendance,
          _exams,
          _fees,
          _timetable,
          _circulars,
          _audit,
        ]);
      case AppRoles.principal:
        return RoleNavigation(role: role!, primaryIds: const ['reports', 'attendance', 'exams'], sections: [
          _s('dashboard', 'Principal Dashboard', 'Dashboard', Icons.dashboard_outlined, Icons.dashboard, (_) => const PrincipalDashboard()),
          _reports,
          _attendance,
          _exams,
          _timetable,
          _circulars,
          _audit,
        ]);
      case AppRoles.office:
        return RoleNavigation(role: role!, primaryIds: const ['fees', 'students', 'circulars'], sections: [
          _s('dashboard', 'Office Operations', 'Office', Icons.dashboard_outlined, Icons.dashboard, (_) => const OfficeDashboard()),
          _reports,
          _fees,
          _students,
          _circulars,
          _audit,
        ]);
      case AppRoles.classTeacher:
        return RoleNavigation(role: role!, primaryIds: const ['myclass', 'attendance', 'exams'], sections: [
          _s('myclass', 'My Class', 'My class', Icons.groups_outlined, Icons.groups, (_) => const ClassTeacherDashboard()),
          _attendance,
          _exams,
          _timetable,
          _circulars,
        ]);
      case AppRoles.subjectTeacher:
        return RoleNavigation(role: role!, primaryIds: const ['teaching', 'exams', 'timetable'], sections: [
          _s('teaching', 'Lessons & Homework', 'Teaching', Icons.assignment_outlined, Icons.assignment, (_) => const SubjectTeacherDashboard()),
          _attendance,
          _exams,
          _timetable,
        ]);
      case AppRoles.parent:
        return RoleNavigation(role: role!, primaryIds: const ['portal'], sections: [
          _s('portal', 'Children & Fees', 'Children', Icons.family_restroom_outlined, Icons.family_restroom, (_) => const ParentPortalScreen()),
        ]);
      case AppRoles.student:
        return RoleNavigation(role: role!, primaryIds: const ['portal'], sections: [
          _s('portal', 'My Studies', 'Studies', Icons.menu_book_outlined, Icons.menu_book, (_) => const StudentPortalScreen()),
        ]);
      default:
        return null;
    }
  }

  static RoleSection _s(String id, String label, String shortLabel, IconData icon, IconData selected, WidgetBuilder b) =>
      RoleSection(id: id, label: label, shortLabel: shortLabel, icon: icon, selectedIcon: selected, builder: b);

  static final _reports = _s('reports', 'Reports & Analytics', 'Reports', Icons.analytics_outlined, Icons.analytics, (_) => const ReportsAnalyticsScreen());
  static final _students = _s('students', 'Students & Admissions', 'Students', Icons.school_outlined, Icons.school, (_) => const StudentManagementScreen());
  static final _attendance = _s('attendance', 'Attendance', 'Attendance', Icons.fact_check_outlined, Icons.fact_check, (_) => const AttendanceManagementScreen());
  static final _exams = _s('exams', 'Exams & Marks', 'Marks', Icons.grade_outlined, Icons.grade, (_) => const ExaminationManagementScreen());
  static final _fees = _s('fees', 'Fees & Receipts', 'Fees', Icons.receipt_long_outlined, Icons.receipt_long, (_) => const FeeManagementScreen());
  static final _timetable = _s('timetable', 'Timetable', 'Timetable', Icons.schedule_outlined, Icons.schedule, (_) => const TimetableManagementScreen());
  static final _circulars = _s('circulars', 'Circulars & Notices', 'Notices', Icons.campaign_outlined, Icons.campaign, (_) => const CircularManagementScreen());
  static final _audit = _s('audit', 'Audit Logs', 'Audit', Icons.history_outlined, Icons.history, (_) => const AuditLogsScreen());
}
