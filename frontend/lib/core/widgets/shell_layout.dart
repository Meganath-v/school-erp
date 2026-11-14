import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_typography.dart';
import '../auth/auth_provider.dart';
import '../theme/app_theme.dart';
import 'notification_center.dart';
import 'status_badge.dart';

class NavigationDestinationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int? badgeCount;

  const NavigationDestinationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount,
  });
}

class ShellLayout extends ConsumerStatefulWidget {
  final Widget child;
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;

  const ShellLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  ConsumerState<ShellLayout> createState() => _ShellLayoutState();
}

class _ShellLayoutState extends ConsumerState<ShellLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final isTablet = width >= 768 && width < 1024;
    final isMobile = width < 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: _buildTopAppBar(context, authState, isDesktop, isTablet, isMobile),
      drawer: !isDesktop ? _buildDrawer(context, authState) : null,
      bottomNavigationBar: (isMobile && widget.destinations.length <= 4)
          ? _buildBottomNavBar()
          : null,
      body: Row(
        children: [
          if (isDesktop) _buildDesktopSidebar(context, authState),
          if (isTablet && !_isSidebarCollapsed) _buildTabletRail(context, authState),
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(
    BuildContext context,
    AuthState authState,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final school = authState.activeSchool;
    final user = authState.user;
    final memberships = authState.memberships;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      automaticallyImplyLeading: !isDesktop,
      leading: !isDesktop
          ? IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textDark, size: 22),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            )
          : null,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
      titleSpacing: isDesktop ? 20 : 0,
      title: Row(
        children: [
          if (isDesktop) ...[
            // Collapse / Expand Sidebar Toggle
            IconButton(
              icon: const Icon(Icons.menu_open, size: 20, color: AppColors.textMuted),
              tooltip: 'Toggle Sidebar',
              onPressed: () {
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
              },
            ),
            const SizedBox(width: 8),
          ],
          // Active Module / Breadcrumb Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.destinations[widget.selectedIndex].label,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccentSubtle,
                        borderRadius: AppRadius.smBorderRadius,
                        border: Border.all(color: AppColors.infoBorder),
                      ),
                      child: Text(
                        'AY 2026-27 • Term 1',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isMobile)
                  Text(
                    '${school?.name ?? "Institution"} • Linways-Grade ERP Workspace',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Multi-Tenant School Switcher
        if (memberships.length > 1)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              tooltip: 'Switch Institutional Campus',
              onSelected: (schoolId) {
                ref.read(authProvider.notifier).switchSchool(schoolId);
              },
              itemBuilder: (context) {
                return memberships.map((m) {
                  final isCurrent = m.schoolId == school?.id;
                  return PopupMenuItem<String>(
                    value: m.schoolId,
                    child: Row(
                      children: [
                        Icon(
                          isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isCurrent ? AppColors.primaryAccent : AppColors.textMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.schoolName,
                                style: GoogleFonts.inter(
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                '${m.schoolCode} • ${m.role}',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: AppRadius.smBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apartment_outlined, size: 16, color: AppColors.textDark),
                    if (!isMobile) ...[
                      const SizedBox(width: 6),
                      Text(
                        school?.code ?? 'Campus',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                    const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),

        // Notification Center Trigger
        IconButton(
          tooltip: 'Institutional Notifications',
          icon: const Icon(Icons.notifications_none_outlined, size: 20, color: AppColors.textDark),
          onPressed: () {
            NotificationCenterDialog.show(context);
          },
        ),

        const SizedBox(width: 4),

        // User Profile & Role Popover
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: PopupMenuButton<String>(
            tooltip: 'User Account & Security',
            onSelected: (val) {
              if (val == 'LOGOUT') {
                ref.read(authProvider.notifier).logout();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.name ?? 'Account User',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    Text(
                      user?.email ?? '',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    StatusBadge(
                      label: authState.activeRole ?? 'GUEST',
                      isSmall: true,
                      variant: BadgeVariant.info,
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'LOGOUT',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 16, color: AppColors.error),
                    const SizedBox(width: 10),
                    Text(
                      'Sign Out of Workstation',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.smBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    Text(
                      user?.name ?? 'User',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textMuted),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, AuthState authState) {
    final school = authState.activeSchool;
    final user = authState.user;

    return Container(
      width: _isSidebarCollapsed ? 72 : 256,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Institutional Logo & Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent,
                    borderRadius: AppRadius.mdBorderRadius,
                  ),
                  child: const Center(
                    child: Icon(Icons.school, color: Colors.white, size: 20),
                  ),
                ),
                if (!_isSidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          school?.name ?? 'School ERP',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          school?.code != null ? 'Campus ID: ${school!.code}' : 'Enterprise Edition',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Role Navigation List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              itemCount: widget.destinations.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = widget.destinations[index];
                final isSelected = widget.selectedIndex == index;

                return InkWell(
                  onTap: () => widget.onDestinationSelected(index),
                  borderRadius: AppRadius.mdBorderRadius,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isSidebarCollapsed ? 8 : 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                      borderRadius: AppRadius.mdBorderRadius,
                      border: isSelected ? Border.all(color: const Color(0xFF334155), width: 1) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          size: 18,
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        ),
                        if (!_isSidebarCollapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.badgeCount != null && item.badgeCount! > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: AppRadius.pillBorderRadius,
                              ),
                              child: Text(
                                '${item.badgeCount}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // User Footer Profile Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primaryAccent,
                  child: Text(
                    (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_isSidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          authState.activeRole ?? 'GUEST',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 16, color: Color(0xFF94A3B8)),
                    tooltip: 'Sign Out',
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletRail(BuildContext context, AuthState authState) {
    return NavigationRail(
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      labelType: NavigationRailLabelType.selected,
      backgroundColor: Colors.white,
      destinations: widget.destinations.map((d) {
        return NavigationRailDestination(
          icon: Icon(d.icon, size: 20),
          selectedIcon: Icon(d.selectedIcon, size: 20),
          label: Text(d.label, style: GoogleFonts.inter(fontSize: 11)),
        );
      }).toList(),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthState authState) {
    final school = authState.activeSchool;

    return Drawer(
      backgroundColor: AppColors.primary,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent,
                    borderRadius: AppRadius.mdBorderRadius,
                  ),
                  child: const Center(
                    child: Icon(Icons.school, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        school?.name ?? 'School ERP',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        school?.code ?? 'Institutional Edition',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: widget.destinations.length,
              itemBuilder: (context, index) {
                final item = widget.destinations[index];
                final isSelected = widget.selectedIndex == index;

                return ListTile(
                  leading: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  title: Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDestinationSelected(index);
                  },
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error, size: 20),
            title: Text(
              'Sign Out',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
            ),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return NavigationBar(
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      backgroundColor: Colors.white,
      elevation: 3,
      destinations: widget.destinations.map((d) {
        return NavigationDestination(
          icon: Icon(d.icon, size: 20),
          selectedIcon: Icon(d.selectedIcon, size: 20),
          label: d.label,
        );
      }).toList(),
    );
  }
}
