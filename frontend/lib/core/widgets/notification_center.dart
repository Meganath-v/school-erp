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

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().dio.get('/notifications');
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.only(top: 60, right: 24, bottom: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
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
                      TextButton(
                        onPressed: _markAllAsRead,
                        child: const Text('Mark all read'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
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
                                  Icon(Icons.notifications_none, size: 36, color: AppColors.textSubtle),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'No notifications',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted,
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

                              return InkWell(
                                onTap: isUnread ? () => _markOneAsRead(n['id']) : null,
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  color: isUnread ? AppColors.primaryAccentSubtle.withValues(alpha: 0.4) : Colors.white,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isUnread ? AppColors.primaryAccent.withValues(alpha: 0.12) : AppColors.surfaceVariant,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.notifications,
                                          size: 16,
                                          color: isUnread ? AppColors.primaryAccent : AppColors.textMuted,
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
                                                StatusBadge(
                                                  label: channel,
                                                  isSmall: true,
                                                  variant: BadgeVariant.neutral,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
