import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/roles.dart';
import 'core/navigation/role_navigation.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/mobile_shell.dart';
import 'core/widgets/shell_layout.dart';
import 'core/widgets/omni_search_dialog.dart';
import 'features/auth/presentation/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SchoolErpApp()));
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

class SchoolErpApp extends ConsumerWidget {
  const SchoolErpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leaving the authenticated area closes every pushed route (dialogs, sheets,
    // detail pages) so nothing from the old session stays reachable with Back.
    ref.listen<AuthStatus>(authProvider.select((s) => s.status), (prev, next) {
      if (prev == AuthStatus.authenticated && next != AuthStatus.authenticated) {
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });

    final auth = ref.watch(authProvider);

    final Widget home;
    switch (auth.status) {
      case AuthStatus.restoring:
        home = const SplashScreen();
      case AuthStatus.unauthenticated:
        home = const LoginScreen();
      case AuthStatus.authenticated:
        // A new key per user/school/role rebuilds the shell from scratch.
        home = AppShellScreen(key: ValueKey('${auth.user?.id}|${auth.activeSchool?.id}|${auth.activeRole}'));
    }

    return MaterialApp(
      title: 'Ark-ERP',
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: home),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.primaryAccent, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.school, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 24),
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(height: 12),
          Semantics(liveRegion: true, child: const Text('Restoring your session...')),
        ]),
      ),
    );
  }
}

/// Shown when the account's role has no screens in this app.
class NoAccessScreen extends ConsumerWidget {
  final String? role;
  const NoAccessScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text('No access in this app', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Your account (${AppRoles.label(role)}) has no screens in Ark-ERP mobile. '
                'Contact your school administrator if you think this is wrong.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
                style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
              ),
            ]),
          ),
        ),
      ),
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
  final List<int> _history = [0];

  void _navigateToIndex(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _history.add(index);
      _selectedIndex = index;
    });
  }

  void _navigateBack() {
    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _selectedIndex = _history.last;
      });
    }
  }

  void _handleSearchResult(OmniSearchResult result, RoleNavigation nav) {
    final t = result.routeTarget.toUpperCase();
    const map = {
      'STUDENT': 'students',
      'STAFF': 'staff',
      'ATTENDANCE': 'attendance',
      'EXAM': 'exams',
      'FEE': 'fees',
      'INVOICE': 'fees',
      'RECEIPT': 'fees',
      'TIMETABLE': 'timetable',
      'CIRCULAR': 'circulars',
      'REPORT': 'reports',
      'ANALYTIC': 'reports',
      'DEFAULTER': 'reports',
      'STRENGTH': 'reports',
      'EXPORT': 'reports',
    };
    for (final e in map.entries) {
      final idx = nav.indexOf(e.value);
      if (t.contains(e.key) && idx >= 0) {
        _navigateToIndex(idx);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final nav = RoleNavigation.forRole(authState.activeRole);
    if (nav == null) return NoAccessScreen(role: authState.activeRole);

    // Phones get a dedicated layout instead of a shrunken desktop shell.
    if (MediaQuery.of(context).size.width < 768) {
      return MobileShell(navigation: nav);
    }

    final destinations = [
      for (final s in nav.sections)
        NavigationDestinationItem(label: s.label, icon: s.icon, selectedIcon: s.selectedIcon),
    ];
    final safeIndex = _selectedIndex < nav.sections.length ? _selectedIndex : 0;
    final schoolName = authState.activeSchool?.name ?? '';

    return ShellLayout(
      selectedIndex: safeIndex,
      onDestinationSelected: _navigateToIndex,
      destinations: destinations,
      canNavigateBack: _history.length > 1,
      onBack: _navigateBack,
      breadcrumbs: [if (schoolName.isNotEmpty) schoolName, 'Ark-ERP', nav.sections[safeIndex].label],
      onSearchNavigate: (res) => _handleSearchResult(res, nav),
      child: Builder(builder: nav.sections[safeIndex].builder),
    );
  }
}
