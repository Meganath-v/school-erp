import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/presentation/role_home_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/roles.dart';
import '../navigation/role_navigation.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../../features/auth/presentation/change_password_dialog.dart';
import 'notification_center.dart';
import 'omni_search_dialog.dart';

/// Phone layout: Home + up to three primary sections in the bottom bar,
/// everything else in the drawer ("More").
class MobileShell extends ConsumerStatefulWidget {
  final RoleNavigation navigation;
  const MobileShell({super.key, required this.navigation});

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  static const _home = 'home';
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _current = _home;
  final Set<String> _visited = {_home};
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final res = await ApiClient().dio.get(
        '/notifications',
        queryParameters: {'limit': 1},
      );
      final count = res.data['data']?['unreadCount'];
      if (mounted && count is int) setState(() => _unread = count);
    } catch (_) {}
  }

  void _open(String id) {
    if (id != _home && widget.navigation.indexOf(id) < 0) return;
    setState(() {
      _current = id;
      _visited.add(id);
    });
  }

  void _openSearchResult(OmniSearchResult result) {
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
    };
    for (final e in map.entries) {
      if (t.contains(e.key) && widget.navigation.indexOf(e.value) >= 0) {
        _open(e.value);
        return;
      }
    }
  }

  String get _title {
    if (_current == _home) {
      return ref.read(authProvider).activeSchool?.name ?? 'Ark-ERP';
    }
    return widget
        .navigation
        .sections[widget.navigation.indexOf(_current)]
        .label;
  }

  List<String> get _barIds => [_home, ...widget.navigation.primaryIds];

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again. Signing out also ends your sessions on other devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).logout();
  }

  void _showAccount() {
    final auth = ref.read(authProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Avatar(name: auth.user?.name ?? '', radius: 24),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.user?.name ?? '',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            auth.user?.email ?? '',
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(AppRoles.label(auth.activeRole)),
                  subtitle: Text(
                    '${auth.activeSchool?.name ?? ''} (${auth.activeSchool?.code ?? ''})',
                  ),
                ),
                if (auth.memberships.length > 1) ...[
                  const Divider(),
                  Text(
                    'Switch school',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final m in auth.memberships)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        m.schoolId == auth.activeSchool?.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.primaryAccent,
                      ),
                      title: Text(m.schoolName),
                      subtitle: Text(
                        '${m.schoolCode} · ${AppRoles.label(m.role)}',
                      ),
                      onTap: m.schoolId == auth.activeSchool?.id
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              final ok = await ref
                                  .read(authProvider.notifier)
                                  .switchSchool(m.schoolId);
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ref.read(authProvider).errorMessage ??
                                          'Could not switch school.',
                                    ),
                                  ),
                                );
                              }
                            },
                    ),
                ],
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final changed = await ChangePasswordDialog.show(context);
                    if (changed == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password changed. Other devices were signed out.')),
                      );
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Server'),
                  subtitle: Text(ApiClient().baseUrl),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmSignOut();
                  },
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Sign out',
                    style: TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final nav = widget.navigation;
    final barIds = _barIds;
    final inBar = barIds.indexOf(_current);
    final selectedIndex = inBar >= 0
        ? inBar
        : barIds.length; // "More" when outside the bar

    final bodies = <Widget>[
      RoleHomeScreen(navigation: nav, onOpenSection: _open),
      for (final s in nav.sections)
        _visited.contains(s.id)
            ? Builder(builder: s.builder)
            : const SizedBox.shrink(),
    ];
    final stackIndex = _current == _home ? 0 : nav.indexOf(_current) + 1;

    return PopScope(
      canPop: _current == _home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(_home);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          scrolledUnderElevation: 1,
          titleSpacing: 0,
          title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () =>
                  OmniSearchDialog.show(context, onNavigate: _openSearchResult),
            ),
            IconButton(
              tooltip: _unread > 0
                  ? '$_unread unread notifications'
                  : 'Notifications',
              icon: Badge(
                isLabelVisible: _unread > 0,
                label: Text('$_unread'),
                child: const Icon(Icons.notifications_none_outlined),
              ),
              onPressed: () async {
                await NotificationCenterDialog.show(context);
                _loadUnread();
              },
            ),
            IconButton(
              tooltip: 'Account',
              icon: _Avatar(name: auth.user?.name ?? '', radius: 15),
              onPressed: _showAccount,
            ),
            const SizedBox(width: 4),
          ],
        ),
        drawer: _buildDrawer(auth),
        // IndexedStack keeps visited tabs alive so switching back does not refetch.
        body: IndexedStack(index: stackIndex, children: bodies),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            if (i == barIds.length) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              _open(barIds[i]);
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            for (final s in nav.primarySections)
              NavigationDestination(
                icon: Icon(s.icon),
                selectedIcon: Icon(s.selectedIcon),
                label: s.shortLabel,
              ),
            const NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(AuthState auth) {
    final nav = widget.navigation;
    Widget item(String id, IconData icon, IconData selectedIcon, String label) {
      final selected = _current == id;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          selected: selected,
          selectedTileColor: AppColors.primaryAccentSubtle,
          selectedColor: AppColors.primaryAccent,
          shape: const StadiumBorder(),
          leading: Icon(selected ? selectedIcon : icon),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            _open(id);
          },
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 16, 12),
              child: Row(
                children: [
                  _Avatar(name: auth.user?.name ?? '', radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.user?.name ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${AppRoles.label(auth.activeRole)} · ${auth.activeSchool?.code ?? ''}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Divider(),
            ),
            item(_home, Icons.home_outlined, Icons.home, 'Home'),
            for (final s in nav.sections)
              item(s.id, s.icon, s.selectedIcon, s.label),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Account'),
                onTap: () {
                  Navigator.pop(context);
                  _showAccount();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmSignOut();
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double radius;
  const _Avatar({required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryAccent,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
