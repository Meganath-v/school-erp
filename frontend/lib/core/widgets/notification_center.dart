import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'status_badge.dart';

class NotificationCenterDialog extends StatefulWidget {
  const NotificationCenterDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const NotificationCenterDialog(),
    );
  }

  @override
  State<NotificationCenterDialog> createState() => _NotificationCenterDialogState();
}

class _NotificationCenterDialogState extends State<NotificationCenterDialog> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  String _selectedFilter = 'ALL'; // 'ALL' or 'UNREAD'

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().dio.get(
        '/notifications',
        queryParameters: {
          'status': _selectedFilter,
          'limit': 50,
        },
      );
      final data = res.data['data'] ?? {};
      setState(() {
        _notifications = data['notifications'] as List? ?? [];
        _unreadCount = data['unreadCount'] ?? 0;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiClient().dio.patch('/notifications/read-all');
      await _fetchNotifications();
    } catch (_) {}
  }

  Future<void> _markOneAsRead(String id) async {
    try {
      await ApiClient().dio.patch('/notifications/$id/read');
      await _fetchNotifications();
    } catch (_) {}
  }

  String _formatTimeAgo(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  BadgeVariant _getPriorityVariant(String? priority) {
    switch (priority) {
      case 'URGENT':
        return BadgeVariant.error;
      case 'HIGH':
        return BadgeVariant.warning;
      case 'NORMAL':
        return BadgeVariant.info;
      default:
        return BadgeVariant.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.only(top: 60, right: 24, bottom: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.lgBorderRadius,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.popover,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Notifications',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (_unreadCount > 0) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryAccent,
                              borderRadius: AppRadius.pillBorderRadius,
                            ),
                            child: Text(
                              '$_unreadCount new',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_unreadCount > 0)
                      TextButton.icon(
                        onPressed: _markAllAsRead,
                        icon: const Icon(Icons.done_all, size: 14),
                        label: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),

              // Filter Tabs (All vs Unread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All Notices', style: TextStyle(fontSize: 11)),
                      selected: _selectedFilter == 'ALL',
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedFilter = 'ALL');
                          _fetchNotifications();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Unread Only ($_unreadCount)', style: const TextStyle(fontSize: 11)),
                      selected: _selectedFilter == 'UNREAD',
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedFilter = 'UNREAD');
                          _fetchNotifications();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // Notification List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _notifications.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xxl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_none, size: 40, color: AppColors.textSubtle),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    _selectedFilter == 'UNREAD' ? 'No unread notifications' : 'No notifications on file',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Institutional alerts and deadlines will appear here.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSubtle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _notifications.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final n = _notifications[index];
                              final isUnread = n['status'] == 'UNREAD';
                              final title = n['title'] ?? 'Notification';
                              final body = n['body'] ?? '';
                              final channel = n['channel'] ?? 'IN_APP';
                              final priority = n['priority'] ?? 'NORMAL';
                              final timeAgo = _formatTimeAgo(n['createdAt']);

                              return InkWell(
                                onTap: isUnread ? () => _markOneAsRead(n['id']) : null,
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  color: isUnread ? AppColors.primaryAccentSubtle.withValues(alpha: 0.35) : Colors.white,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isUnread
                                              ? AppColors.primaryAccent.withValues(alpha: 0.12)
                                              : AppColors.surfaceVariant,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          priority == 'URGENT'
                                              ? Icons.warning_amber_rounded
                                              : (priority == 'HIGH' ? Icons.priority_high : Icons.notifications),
                                          size: 16,
                                          color: priority == 'URGENT'
                                              ? AppColors.error
                                              : (isUnread ? AppColors.primaryAccent : AppColors.textMuted),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                                                      color: AppColors.textDark,
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (priority != 'NORMAL' && priority != 'LOW') ...[
                                                      StatusBadge(
                                                        label: priority,
                                                        isSmall: true,
                                                        variant: _getPriorityVariant(priority),
                                                      ),
                                                      const SizedBox(width: 4),
                                                    ],
                                                    StatusBadge(
                                                      label: channel,
                                                      isSmall: true,
                                                      variant: BadgeVariant.neutral,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              body,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppColors.textMedium,
                                              ),
                                            ),
                                            if (timeAgo.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                timeAgo,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // Footer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _fetchNotifications,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
