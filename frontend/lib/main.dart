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
import 'features/audit/presentation/audit_logs_screen.dart';

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
            label: 'Executive & Approvals',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          NavigationDestinationItem(
            label: 'Compliance Audit',
            icon: Icons.history_outlined,
            selectedIcon: Icons.history,
          ),
        ];
        pages = const [
          PrincipalDashboard(),
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
        ];
        pages = const [
          ClassTeacherDashboard(),
        ];
        break;

      case 'SUBJECT_TEACHER':
        destinations = const [
          NavigationDestinationItem(
            label: 'Schedule & Homework',
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment,
          ),
        ];
        pages = const [
          SubjectTeacherDashboard(),
        ];
        break;

      case 'PARENT':
        destinations = const [
          NavigationDestinationItem(
            label: 'Parent & Student Portal',
            icon: Icons.family_restroom_outlined,
            selectedIcon: Icons.family_restroom,
          ),
        ];
        pages = const [
          ParentPortalScreen(),
        ];
        break;

      case 'SCHOOL_ADMIN':
      case 'OFFICE':
      default:
        destinations = const [
          NavigationDestinationItem(
            label: 'Campus Administration',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          NavigationDestinationItem(
            label: 'System Audit Logs',
            icon: Icons.history_outlined,
            selectedIcon: Icons.history,
          ),
        ];
        pages = const [
          SchoolAdminDashboard(),
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
