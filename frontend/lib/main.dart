import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/shell_layout.dart';
import 'features/school_discovery/presentation/discovery_screen.dart';
import 'features/platform_admin/presentation/platform_dashboard_screen.dart';
import 'features/school_admin/presentation/school_admin_dashboard.dart';
import 'features/principal/presentation/principal_dashboard.dart';
import 'features/class_teacher/presentation/teacher_dashboard.dart';
import 'features/subject_teacher/presentation/subject_teacher_dashboard.dart';
import 'features/parent/presentation/parent_portal_screen.dart';
import 'features/office/presentation/office_dashboard.dart';
import 'features/student/presentation/student_portal_screen.dart';
import 'features/audit/presentation/audit_logs_screen.dart';
import 'features/students/presentation/student_management_screen.dart';
import 'features/staff/presentation/staff_management_screen.dart';
import 'features/attendance/presentation/attendance_management_screen.dart';
import 'features/examination/presentation/examination_management_screen.dart';
import 'features/fees/presentation/fee_management_screen.dart';
import 'features/timetable/presentation/timetable_management_screen.dart';
import 'features/circulars/presentation/circular_management_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SchoolErpApp()));
}

class SchoolErpApp extends ConsumerWidget {
  const SchoolErpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Multi-Tenant School ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: authState.isAuthenticated ? const AppShellScreen() : const DiscoveryScreen(),
    );
  }
}

class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.activeRole ?? 'SCHOOL_ADMIN';

    final List<NavigationDestinationItem> destinations;
    final List<Widget> pages;

    switch (role) {
      case 'PLATFORM_OWNER':
        destinations = const [
          NavigationDestinationItem(
            label: 'Platform Control Plane',
            icon: Icons.domain_outlined,
            selectedIcon: Icons.domain,
          ),
          NavigationDestinationItem(
            label: 'System Audit Logs',
            icon: Icons.history_outlined,
            selectedIcon: Icons.history,
          ),
        ];
        pages = const [
          PlatformDashboardScreen(),
          AuditLogsScreen(),
        ];
        break;

      case 'PRINCIPAL':
        destinations = const [
          NavigationDestinationItem(
            label: 'Executive Cockpit',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          NavigationDestinationItem(
            label: 'Attendance Register',
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check,
          ),
          NavigationDestinationItem(
            label: 'Examinations & Results',
            icon: Icons.grade_outlined,
            selectedIcon: Icons.grade,
          ),
          NavigationDestinationItem(
            label: 'Master Timetable',
            icon: Icons.schedule_outlined,
            selectedIcon: Icons.schedule,
          ),
          NavigationDestinationItem(
            label: 'School Circulars',
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign,
          ),
          NavigationDestinationItem(
            label: 'Compliance Audit',
            icon: Icons.history_outlined,
            selectedIcon: Icons.history,
          ),
        ];
        pages = const [
          PrincipalDashboard(),
          AttendanceManagementScreen(),
          ExaminationManagementScreen(),
          TimetableManagementScreen(),
          CircularManagementScreen(),
          AuditLogsScreen(),
        ];
        break;

      case 'CLASS_TEACHER':
        destinations = const [
          NavigationDestinationItem(
            label: 'Class Attendance & Roster',
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check,
          ),
          NavigationDestinationItem(
            label: 'Attendance Register',
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
          ),
          NavigationDestinationItem(
            label: 'Marks & Broadsheet',
            icon: Icons.grade_outlined,
            selectedIcon: Icons.grade,
          ),
          NavigationDestinationItem(
            label: 'Class Timetable',
            icon: Icons.schedule_outlined,
            selectedIcon: Icons.schedule,
          ),
          NavigationDestinationItem(
            label: 'Notices & Circulars',
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign,
          ),
        ];
        pages = const [
          ClassTeacherDashboard(),
          AttendanceManagementScreen(),
          ExaminationManagementScreen(),
          TimetableManagementScreen(),
          CircularManagementScreen(),
        ];
        break;

      case 'SUBJECT_TEACHER':
        destinations = const [
          NavigationDestinationItem(
            label: 'Schedule & Homework',
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment,
          ),
          NavigationDestinationItem(
            label: 'Period Attendance',
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check,
          ),
          NavigationDestinationItem(
            label: 'Marks Entry',
            icon: Icons.grade_outlined,
            selectedIcon: Icons.grade,
          ),
          NavigationDestinationItem(
            label: 'Faculty Timetable',
            icon: Icons.schedule_outlined,
            selectedIcon: Icons.schedule,
          ),
        ];
        pages = const [
          SubjectTeacherDashboard(),
          AttendanceManagementScreen(),
          ExaminationManagementScreen(),
          TimetableManagementScreen(),
        ];
        break;

      case 'PARENT':
        destinations = const [
          NavigationDestinationItem(
            label: 'Parent & Ward Portal',
            icon: Icons.family_restroom_outlined,
            selectedIcon: Icons.family_restroom,
          ),
        ];
        pages = const [
          ParentPortalScreen(),
        ];
        break;

      case 'OFFICE':
        destinations = const [
          NavigationDestinationItem(
            label: 'Office Operations',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          NavigationDestinationItem(
            label: 'Fee Billing & Receipts',
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
          ),
          NavigationDestinationItem(
            label: 'Admissions & Students',
            icon: Icons.school_outlined,
            selectedIcon: Icons.school,
          ),
          NavigationDestinationItem(
            label: 'Circulars & Notices',
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign,
          ),
          NavigationDestinationItem(
            label: 'Audit Records',
            icon: Icons.history_outlined,
            selectedIcon: Icons.history,
          ),
        ];
        pages = const [
          OfficeDashboard(),
          FeeManagementScreen(),
          StudentManagementScreen(),
          CircularManagementScreen(),
          AuditLogsScreen(),
        ];
        break;

      case 'STUDENT':
        destinations = const [
          NavigationDestinationItem(
            label: 'Student Academic Portal',
            icon: Icons.school_outlined,
            selectedIcon: Icons.school,
          ),
        ];
        pages = const [
          StudentPortalScreen(),
        ];
        break;

      case 'SCHOOL_ADMIN':
      default:
        destinations = const [
          NavigationDestinationItem(
            label: 'Campus Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          NavigationDestinationItem(
            label: 'Learners Directory',
            icon: Icons.school_outlined,
            selectedIcon: Icons.school,
          ),
          NavigationDestinationItem(
            label: 'Faculty & Staff',
            icon: Icons.badge_outlined,
            selectedIcon: Icons.badge,
          ),
          NavigationDestinationItem(
            label: 'Attendance Register',
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check,
          ),
          NavigationDestinationItem(
            label: 'Examinations & Results',
            icon: Icons.grade_outlined,
            selectedIcon: Icons.grade,
          ),
          NavigationDestinationItem(
            label: 'Fee Billing & Ledger',
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
          ),
          NavigationDestinationItem(
            label: 'Master Timetable',
            icon: Icons.schedule_outlined,
            selectedIcon: Icons.schedule,
          ),
          NavigationDestinationItem(
            label: 'Notices & Circulars',
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign,
          ),
          NavigationDestinationItem(
            label: 'System Audit Logs',
            icon: Icons.history_outlined,
            selectedIcon: Icons.history,
          ),
        ];
        pages = const [
          SchoolAdminDashboard(),
          StudentManagementScreen(),
          StaffManagementScreen(),
          AttendanceManagementScreen(),
          ExaminationManagementScreen(),
          FeeManagementScreen(),
          TimetableManagementScreen(),
          CircularManagementScreen(),
          AuditLogsScreen(),
        ];
        break;
    }

    final safeIndex = _selectedIndex < pages.length ? _selectedIndex : 0;

    return ShellLayout(
      selectedIndex: safeIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
      destinations: destinations,
      child: pages[safeIndex],
    );
  }
}
