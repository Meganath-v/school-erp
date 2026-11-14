import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class PrincipalDashboard extends ConsumerStatefulWidget {
  const PrincipalDashboard({super.key});

  @override
  ConsumerState<PrincipalDashboard> createState() => _PrincipalDashboardState();
}

class _PrincipalDashboardState extends ConsumerState<PrincipalDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _overview;
  List<dynamic> _exams = [];
  List<dynamic> _leaveRequests = [];
  String _noticeSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPrincipalData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrincipalData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient().dio.get('/reports/overview').then((r) => r.data['data'] as Map<String, dynamic>?).catchError((_) => null),
        ApiClient().dio.get('/exams').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/leave-requests').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
      ]);

      setState(() {
        _overview = results[0] as Map<String, dynamic>?;
        _exams = results[1] as List<dynamic>;
        _leaveRequests = results[2] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _publishExam(String examId) async {
    try {
      await ApiClient().dio.post('/exams/$examId/publish');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam marks approved and officially published to Parent & Student Portals!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadPrincipalData();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to publish examination results'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _decideLeave(String leaveId, String decision) async {
    try {
      await ApiClient().dio.post('/leave-requests/$leaveId/decision', data: {
        'decision': decision,
        'remarks': 'Principal executive decision',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave application $decision successfully'),
            backgroundColor: decision == 'APPROVED' ? AppColors.success : AppColors.warning,
          ),
        );
        _loadPrincipalData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update leave status: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Campus Notice'),
        content: const Text('Are you sure you want to permanently revoke this official broadcast?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke Notice'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient().dio.delete('/announcements/$id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement successfully revoked'), backgroundColor: AppColors.success),
          );
          _loadPrincipalData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to revoke announcement: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _showNewAnnouncementDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String targetRole = 'ALL';
    String priority = 'NORMAL';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Broadcast Official Notice'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notice Heading',
                      hintText: 'e.g. Schedule of Term Examination Moderation',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Broadcast Body',
                      hintText: 'Enter formal notification details...',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: targetRole,
                          decoration: const InputDecoration(labelText: 'Target Audience'),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Entire Campus (All)')),
                            DropdownMenuItem(value: 'PARENT', child: Text('Parents Only')),
                            DropdownMenuItem(value: 'TEACHER', child: Text('Academic Faculty Only')),
                          ],
                          onChanged: (val) => setDialogState(() => targetRole = val!),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: priority,
                          decoration: const InputDecoration(labelText: 'Priority Level'),
                          items: const [
                            DropdownMenuItem(value: 'NORMAL', child: Text('Normal Priority')),
                            DropdownMenuItem(value: 'URGENT', child: Text('Urgent Notification')),
                          ],
                          onChanged: (val) => setDialogState(() => priority = val!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) return;
                  try {
                    await ApiClient().dio.post('/announcements', data: {
                      'title': titleCtrl.text.trim(),
                      'content': contentCtrl.text.trim(),
                      'targetRole': targetRole,
                      'priority': priority,
                      'authorName': 'Principal Office',
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notice broadcasted successfully!'), backgroundColor: AppColors.success),
                      );
                      _loadPrincipalData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to broadcast: $e'), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: const Text('Broadcast Notice'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading institutional oversight and moderation telemetry...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Executive Oversight Unavailable',
        message: _errorMessage,
        onRetry: _loadPrincipalData,
      );
    }

    final stats = _overview?['stats'] ?? {};

    return Column(
      children: [
        // Top Tab Navigation Bar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Executive Overview'),
                    Tab(icon: Icon(Icons.verified_outlined, size: 18), text: 'Approvals & Moderation'),
                    Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'Campus Notices'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Oversight Data',
                onPressed: _loadPrincipalData,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(stats),
              _buildApprovalsTab(),
              _buildNoticesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> stats) {
    final todayRate = stats['todayAttendanceRate'];
    final attendanceStr = todayRate != null ? '$todayRate%' : 'Not Marked';

    return RefreshIndicator(
      onRefresh: _loadPrincipalData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Principal Office', 'Executive Oversight'],
              title: 'Institutional Oversight & Governance',
              subtitle: 'Academic compliance monitoring, attendance fulfillment, and institutional operations.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _loadPrincipalData,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Executive KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                final cards = [
                  MetricCard(
                    title: 'Total Enrollment',
                    value: '${stats['totalStudents'] ?? 0}',
                    icon: Icons.people_outline,
                    subtitle: 'Active matriculated students',
                    color: AppColors.primary,
                  ),
                  MetricCard(
                    title: 'Academic Faculty',
                    value: '${stats['totalStaff'] ?? 0}',
                    icon: Icons.badge_outlined,
                    subtitle: 'Teaching & support staff',
                    color: AppColors.secondary,
                  ),
                  MetricCard(
                    title: 'Today Attendance',
                    value: attendanceStr,
                    icon: Icons.check_circle_outline,
                    subtitle: 'Campus-wide presence',
                    color: todayRate != null ? AppColors.success : AppColors.textMuted,
                  ),
                  MetricCard(
                    title: 'Pending Leaves',
                    value: '${_leaveRequests.where((l) => l['status'] == 'PENDING').length}',
                    icon: Icons.event_busy_outlined,
                    subtitle: 'Awaiting moderation',
                    color: AppColors.warning,
                  ),
                ];

                if (isDesktop) {
                  return Row(
                    children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: AppSpacing.md), child: c))).toList(),
                  );
                } else {
                  return Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: cards.map((c) => SizedBox(width: (constraints.maxWidth - AppSpacing.md) / 2, child: c)).toList(),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Recent Audit Events
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: AppShadows.subtle,
              ),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_toggle_off, color: AppColors.primary, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Recent Institutional Audit Trail',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if ((_overview?['recentAuditLogs'] as List? ?? []).isEmpty)
                    const Text('No recent system audit events logged.', style: TextStyle(color: AppColors.textSecondary))
                  else
                    ...((_overview?['recentAuditLogs'] as List? ?? []).map((l) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              '${l['action']}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'by ${l['actorName'] ?? 'Staff'} • ${l['timestamp']}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalsTab() {
    final pendingLeaves = _leaveRequests.where((l) => l['status'] == 'PENDING').toList();

    return RefreshIndicator(
      onRefresh: _loadPrincipalData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Principal Office', 'Moderation & Approvals'],
              title: 'Academic Approvals & Moderation',
              subtitle: 'Final authorization of examination marks publication and student leave approvals.',
            ),
            const SizedBox(height: AppSpacing.xl),

            // Examination Publication Section
            Text(
              'Examination Publication Moderation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_exams.isEmpty)
              const EmptyStateView(
                icon: Icons.assignment_turned_in_outlined,
                title: 'No Examinations Awaiting Moderation',
                description: 'All scheduled terms are either in draft or already published.',
              )
            else
              ..._exams.map((ex) {
                final isPublished = ex['status'] == 'PUBLISHED';
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: AppShadows.subtle,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.school_outlined, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  ex['name'] ?? 'Term Exam',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                StatusBadge.fromStatus(isPublished ? 'PUBLISHED' : 'PENDING'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Term: ${ex['term']} • Academic Year: ${ex['academicYear']}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Subjects Evaluated: ${(ex['subjects'] as List? ?? []).length} modules',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      if (!isPublished)
                        ElevatedButton.icon(
                          onPressed: () => _publishExam(ex['id']),
                          icon: const Icon(Icons.verified_outlined, size: 16),
                          label: const Text('Approve & Publish Results'),
                        )
                      else
                        const StatusBadge(label: 'PUBLISHED TO PARENTS', variant: BadgeVariant.success),
                    ],
                  ),
                );
              }).toList(),

            const SizedBox(height: AppSpacing.xxl),

            // Student Leave Moderation Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Student Leave Applications (${pendingLeaves.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('Real-time authorization', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (pendingLeaves.isEmpty)
              const EmptyStateView(
                icon: Icons.event_available_outlined,
                title: 'No Pending Leave Requests',
                description: 'All submitted student and faculty leave requests have been addressed.',
              )
            else
              ...pendingLeaves.map((l) {
                final student = l['student'] ?? {};
                final sName = student['fullName'] ?? '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim();
                final dates = '${l['startDate']?.toString().split('T')[0]} to ${l['endDate']?.toString().split('T')[0]}';

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: AppShadows.subtle,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.warningSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.event_busy_outlined, color: AppColors.warning, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sName.isNotEmpty ? sName : 'Student Leave Application',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Reason: ${l['reason'] ?? 'Medical / Family emergency'}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Duration: $dates',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                            onPressed: () => _decideLeave(l['id'], 'APPROVED'),
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Approve'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                            onPressed: () => _decideLeave(l['id'], 'REJECTED'),
                            icon: const Icon(Icons.close, size: 14),
                            label: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticesTab() {
    final allNotices = _overview?['recentAnnouncements'] as List? ?? [];
    final filtered = _noticeSearchQuery.isEmpty
        ? allNotices
        : allNotices.where((n) {
            final q = _noticeSearchQuery.toLowerCase();
            final title = (n['title'] ?? '').toString().toLowerCase();
            final content = (n['content'] ?? '').toString().toLowerCase();
            return title.contains(q) || content.contains(q);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Principal Office', 'Official Broadcasts'],
            title: 'School-Wide Official Broadcasts',
            subtitle: 'Formal institutional announcements dispatched to students, parents, and faculty.',
            actions: [
              ElevatedButton.icon(
                onPressed: _showNewAnnouncementDialog,
                icon: const Icon(Icons.campaign, size: 16),
                label: const Text('Broadcast Notice'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SearchFilterBar(
            searchHint: 'Search official notices by title or content...',
            searchQuery: _noticeSearchQuery,
            onSearchChanged: (val) => setState(() => _noticeSearchQuery = val),
            totalCount: filtered.length,
            countLabel: 'Notices Broadcasted',
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: filtered.isEmpty
                ? EmptyStateView(
                    icon: Icons.campaign_outlined,
                    title: _noticeSearchQuery.isNotEmpty ? 'No Matching Broadcasts' : 'No Official Notices Issued',
                    description: _noticeSearchQuery.isNotEmpty
                        ? 'No announcements match your search.'
                        : 'Broadcast your first campus announcement using the button above.',
                    actionLabel: _noticeSearchQuery.isNotEmpty ? 'Clear Search' : 'Broadcast Notice',
                    onAction: _noticeSearchQuery.isNotEmpty ? () => setState(() => _noticeSearchQuery = '') : _showNewAnnouncementDialog,
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final n = filtered[index];
                      final isUrgent = n['priority'] == 'URGENT';

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.borderLight),
                          boxShadow: AppShadows.subtle,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      n['title'] ?? 'Official Notice',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    if (isUrgent)
                                      const StatusBadge(label: 'URGENT', variant: BadgeVariant.error)
                                    else
                                      const StatusBadge(label: 'OFFICIAL', variant: BadgeVariant.info),
                                  ],
                                ),
                                Row(
                                  children: [
                                    StatusBadge(
                                      label: 'Audience: ${n['targetRole'] ?? 'ALL'}',
                                      variant: BadgeVariant.neutral,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                      tooltip: 'Revoke Notice',
                                      onPressed: () => _deleteAnnouncement(n['id']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              n['content'] ?? '',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
