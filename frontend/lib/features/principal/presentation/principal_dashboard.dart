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
  Map<String, dynamic>? _examReport;
  List<dynamic> _teacherWorkload = [];
  Map<String, dynamic>? _attendanceReport;
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
        ApiClient().dio.get('/reports/examinations').then((r) => r.data as Map<String, dynamic>?).catchError((_) => null),
        ApiClient().dio.get('/reports/teacher-workload').then((r) => r.data as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/reports/attendance').then((r) => r.data as Map<String, dynamic>?).catchError((_) => null),
      ]);

      setState(() {
        _overview = results[0] as Map<String, dynamic>?;
        _exams = results[1] as List<dynamic>;
        _leaveRequests = results[2] as List<dynamic>;
        _examReport = results[3] as Map<String, dynamic>?;
        _teacherWorkload = results[4] as List<dynamic>;
        _attendanceReport = results[5] as Map<String, dynamic>?;
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

  void _showTeacherWorkloadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Teacher Workload Distribution'),
            StatusBadge(label: '${_teacherWorkload.length} Educators', variant: BadgeVariant.info),
          ],
        ),
        content: SizedBox(
          width: 650,
          height: 420,
          child: _teacherWorkload.isEmpty
              ? const Center(child: Text('No active teacher timetable allocations found.'))
              : ListView.separated(
                  itemCount: _teacherWorkload.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final t = _teacherWorkload[i];
                    final periods = t['weeklyPeriodsCount'] ?? 0;
                    final subjects = (t['assignedSubjects'] as List? ?? []).join(', ');
                    final classes = (t['assignedClasses'] as List? ?? []).join(', ');

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.secondarySubtle,
                        child: Icon(Icons.person, color: AppColors.secondary, size: 18),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t['staffName'] ?? 'Faculty Member', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          StatusBadge(
                            label: '$periods Periods/Wk',
                            variant: periods > 25 ? BadgeVariant.warning : BadgeVariant.success,
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Classes: ${classes.isEmpty ? 'General' : classes} • Subjects: ${subjects.isEmpty ? 'Core' : subjects}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showAttendanceComplianceDialog() {
    final defaulters = (_attendanceReport?['condonationShortageList'] as List? ?? []);
    final overall = _attendanceReport?['overallAttendanceRate'] ?? 100;
    final threshold = _attendanceReport?['condonationThreshold'] ?? 75;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Institutional Attendance Compliance'),
            StatusBadge(label: '$overall% Compliance', variant: BadgeVariant.success),
          ],
        ),
        content: SizedBox(
          width: 650,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Statutory Threshold: $threshold%', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('Defaulters Below Condonation: ${defaulters.length}', style: TextStyle(fontWeight: FontWeight.bold, color: defaulters.isNotEmpty ? AppColors.error : AppColors.success)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: defaulters.isEmpty
                    ? const Center(child: Text('All enrolled students meet the 75% condonation threshold.'))
                    : ListView.separated(
                        itemCount: defaulters.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final d = defaulters[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.warning_amber, color: AppColors.error, size: 20),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${d['fullName']} (${d['admissionNo']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${d['attendanceRate']}% Attended', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            subtitle: Text(
                              'Class: ${d['className']} (${d['sectionName']}) • Deficit: ${d['deficitSessions']} Sessions',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
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
                final isDesktop = constraints.maxWidth >= 1000;
                final totalCand = _examReport?['totalCandidates'] as int? ?? 0;
                final passedCand = _examReport?['passedCandidates'] as int? ?? 0;
                final passRateStr = totalCand > 0 ? '${((passedCand / totalCand) * 100).toStringAsFixed(0)}% Pass' : '100% Pass';

                final publishedCount = _exams.where((e) => e['status'] == 'PUBLISHED').length;
                final draftCount = _exams.where((e) => e['status'] != 'PUBLISHED').length;
                final pendingLeaves = _leaveRequests.where((l) => l['status'] == 'PENDING').length;
                final overallAtt = _attendanceReport?['overallAttendanceRate'] ?? 100;

                final cards = [
                  MetricCard(
                    title: 'Academic Performance',
                    value: passRateStr,
                    icon: Icons.school_outlined,
                    subtitle: 'AY 2026-2027 Broadsheet',
                    color: AppColors.primary,
                    onTap: () => _tabController.animateTo(1),
                  ),
                  MetricCard(
                    title: 'Attendance Compliance',
                    value: '$overallAtt%',
                    icon: Icons.verified_user_outlined,
                    subtitle: 'Today: $attendanceStr (>=75% Threshold)',
                    color: overallAtt >= 75 ? AppColors.success : AppColors.error,
                    onTap: _showAttendanceComplianceDialog,
                  ),
                  MetricCard(
                    title: 'Examination Status',
                    value: '$publishedCount Pub / $draftCount Draft',
                    icon: Icons.assignment_turned_in_outlined,
                    subtitle: 'Moderation Workflow',
                    color: AppColors.accent,
                    onTap: () => _tabController.animateTo(1),
                  ),
                  MetricCard(
                    title: 'Teacher Workload',
                    value: '${stats['totalStaff'] ?? 0} Staff',
                    icon: Icons.badge_outlined,
                    subtitle: '${stats['totalWeeklyPeriods'] ?? 0} Weekly Periods',
                    color: AppColors.secondary,
                    onTap: _showTeacherWorkloadDialog,
                  ),
                  MetricCard(
                    title: 'Pending Approvals',
                    value: '$pendingLeaves Leaves',
                    icon: Icons.pending_actions_outlined,
                    subtitle: 'Awaiting Executive Action',
                    color: pendingLeaves > 0 ? AppColors.warning : AppColors.success,
                    onTap: () => _tabController.animateTo(1),
                  ),
                ];

                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: cards.map((c) {
                    final width = isDesktop
                        ? (constraints.maxWidth - 2 * AppSpacing.md) / 3
                        : (constraints.maxWidth - AppSpacing.md) / 2;
                    return SizedBox(width: width, child: c);
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Class Performance Comparisons Table
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.leaderboard_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Class Academic Performance Comparisons',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      StatusBadge(
                        label: 'Academic Year 2026-2027',
                        variant: BadgeVariant.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Builder(
                    builder: (context) {
                      final broadsheet = _examReport?['broadsheet'] as List? ?? [];
                      if (broadsheet.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Text('No examination broadsheet compiled yet for comparative analysis.', style: TextStyle(color: AppColors.textSecondary)),
                        );
                      }

                      // Group students by class
                      final Map<String, List<dynamic>> classGroups = {};
                      for (final st in broadsheet) {
                        final key = '${st['className']} (${st['sectionName']})';
                        classGroups.putIfAbsent(key, () => []).add(st);
                      }

                      return Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.5),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(2),
                          4: FlexColumnWidth(1.5),
                        },
                        border: TableBorder(
                          horizontalInside: BorderSide(color: AppColors.borderLight.withOpacity(0.5)),
                        ),
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: AppColors.surfaceMuted),
                            children: const [
                              Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Class & Section', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Candidates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Passed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Pass Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Avg Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            ],
                          ),
                          ...classGroups.entries.map((entry) {
                            final group = entry.value;
                            final passed = group.where((s) => s['resultStatus'] == 'PASS').length;
                            final passRate = group.isNotEmpty ? ((passed / group.length) * 100).round() : 0;
                            final totalPct = group.fold<num>(0, (acc, s) => acc + (s['percentage'] ?? 0));
                            final avgPct = group.isNotEmpty ? (totalPct / group.length).toStringAsFixed(1) : '0';

                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('${group.length}', style: const TextStyle(fontSize: 13))),
                                Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('$passed', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13))),
                                Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Row(
                                    children: [
                                      Text('$passRate%', style: TextStyle(fontWeight: FontWeight.bold, color: passRate >= 75 ? AppColors.success : AppColors.error)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: passRate / 100,
                                            minHeight: 6,
                                            backgroundColor: AppColors.borderLight,
                                            valueColor: AlwaysStoppedAnimation(passRate >= 75 ? AppColors.success : AppColors.error),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('$avgPct%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              ],
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
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
