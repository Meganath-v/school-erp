import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class ClassTeacherDashboard extends ConsumerStatefulWidget {
  const ClassTeacherDashboard({super.key});

  @override
  ConsumerState<ClassTeacherDashboard> createState() => _ClassTeacherDashboardState();
}

class _ClassTeacherDashboardState extends ConsumerState<ClassTeacherDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;

  String? _sectionId;
  String _sectionName = 'Section A';
  String _className = 'Grade 10';
  List<dynamic> _students = [];
  Map<String, String> _attendanceMap = {};
  List<dynamic> _leaveRequests = [];
  List<dynamic> _assignments = [];
  List<dynamic> _circulars = [];
  String _searchQuery = '';
  bool _filterShortageOnly = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTeacherData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ApiClient().dio.get('/attendance/today'),
        ApiClient().dio.get('/leave-requests'),
        ApiClient().dio.get('/assignments'),
        ApiClient().dio.get('/circulars'),
      ]);

      final attData = results[0].data['data'];
      final studentsList = attData['students'] as List? ?? [];

      _sectionId = attData['section']?['id'];
      _sectionName = attData['section']?['name'] ?? 'Section A';
      _className = attData['section']?['className'] ?? 'Grade 10';

      final Map<String, String> newMap = {};
      for (final s in studentsList) {
        newMap[s['studentId']] = s['status'] ?? 'PRESENT';
      }

      setState(() {
        _students = studentsList;
        _attendanceMap = newMap;
        _leaveRequests = results[1].data['data'] ?? [];
        _assignments = results[2].data['data'] as List? ?? [];
        _circulars = results[3].data as List? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _markAllPresent() {
    setState(() {
      for (final s in _students) {
        _attendanceMap[s['studentId']] = 'PRESENT';
      }
    });
  }

  Future<void> _submitAttendance() async {
    if (_sectionId == null) return;
    setState(() => _isSaving = true);

    try {
      final records = _attendanceMap.entries.map((e) {
        return {
          'studentId': e.key,
          'status': e.value,
        };
      }).toList();

      await ApiClient().dio.post('/attendance/sessions', data: {
        'sectionId': _sectionId,
        'records': records,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance submitted and locked successfully! Notifications queued for parents.'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadTeacherData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit attendance'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _decideLeave(String id, String status) async {
    try {
      await ApiClient().dio.post('/leave-requests/$id/decision', data: {
        'status': status,
        'remarks': status == 'APPROVED' ? 'Approved by Class Teacher' : 'Rejected due to academic schedule',
      });
      _loadTeacherData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave request $status successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update leave: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading classroom roster and attendance sessions...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Unable to Load Roster',
        message: _errorMessage,
        onRetry: _loadTeacherData,
      );
    }

    final presentCount = _attendanceMap.values.where((v) => v == 'PRESENT').length;
    final absentCount = _attendanceMap.values.where((v) => v == 'ABSENT').length;
    final lateCount = _attendanceMap.values.where((v) => v == 'LATE').length;

    return Column(
      children: [
        // Tab Header
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
                    Tab(icon: Icon(Icons.fact_check_outlined, size: 18), text: 'Daily Class Attendance'),
                    Tab(icon: Icon(Icons.event_busy_outlined, size: 18), text: 'Student Leave Applications'),
                    Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'Class Assignments'),
                    Tab(icon: Icon(Icons.forum_outlined, size: 18), text: 'Parent Communications'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Roster',
                onPressed: _loadTeacherData,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAttendanceView(presentCount, absentCount, lateCount),
              _buildLeaveRequestsView(),
              _buildAssignmentsView(),
              _buildCircularsView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceView(int present, int absent, int late) {
    final filteredStudents = _students.where((s) {
      if (_filterShortageOnly && (s['isShortageRisk'] != true && (s['attendancePercentage'] ?? 100) >= 75)) {
        return false;
      }
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (s['fullName'] ?? '').toString().toLowerCase();
      final adm = (s['admissionNo'] ?? '').toString().toLowerCase();
      return name.contains(q) || adm.contains(q);
    }).toList();

    final total = _students.length;
    final attendanceRate = total > 0 ? ((present / total) * 100).toStringAsFixed(1) : '0';
    final shortageCount = _students.where((s) => s['isShortageRisk'] == true || (s['attendancePercentage'] ?? 100) < 75).length;
    final pendingLeaves = _leaveRequests.where((l) => l['status'] == 'PENDING').length;

    return RefreshIndicator(
      onRefresh: _loadTeacherData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Classroom', 'Class Teacher', 'Daily Session'],
              title: 'Class Attendance: $_className - $_sectionName',
              subtitle: 'Assigned Classroom • Academic Year 2026-2027 • Mark attendance and manage class learners.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _markAllPresent,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark All Present'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitAttendance,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_clock, size: 16),
                  label: const Text('Submit & Lock Attendance'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Summary Metric Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1000;
                final cards = [
                  MetricCard(
                    title: 'Assigned Roster',
                    value: '$total Students',
                    icon: Icons.groups_outlined,
                    subtitle: 'Grade: $_className - $_sectionName',
                    color: AppColors.primary,
                    onTap: () => setState(() {
                      _searchQuery = '';
                      _filterShortageOnly = false;
                    }),
                  ),
                  MetricCard(
                    title: "Today's Attendance",
                    value: '$present Present',
                    icon: Icons.check_circle_outline,
                    subtitle: 'Today • Morning Session ($absent Absent)',
                    color: AppColors.success,
                  ),
                  MetricCard(
                    title: 'Attendance Rate',
                    value: '$attendanceRate%',
                    icon: Icons.analytics_outlined,
                    subtitle: 'Daily Presence Ratio',
                    color: AppColors.secondary,
                  ),
                  MetricCard(
                    title: 'Below Condonation (<75%)',
                    value: '$shortageCount Defaulters',
                    icon: Icons.warning_amber_outlined,
                    subtitle: _filterShortageOnly ? 'Filtered: Tap to Show All' : 'Condonation Shortage Risk',
                    color: shortageCount > 0 ? AppColors.error : AppColors.success,
                    onTap: () => setState(() => _filterShortageOnly = !_filterShortageOnly),
                  ),
                  MetricCard(
                    title: 'Pending Leaves',
                    value: '$pendingLeaves Requests',
                    icon: Icons.event_busy_outlined,
                    subtitle: 'Awaiting Class Teacher',
                    color: pendingLeaves > 0 ? AppColors.warning : AppColors.success,
                    onTap: () => _tabController.animateTo(1),
                  ),
                  MetricCard(
                    title: 'Class Assignments',
                    value: '${_assignments.length} Tasks',
                    icon: Icons.assignment_outlined,
                    subtitle: 'Homework & Curricula',
                    color: AppColors.accent,
                    onTap: () => _tabController.animateTo(2),
                  ),
                  MetricCard(
                    title: 'Parent Notices',
                    value: '${_circulars.length} Broadcasts',
                    icon: Icons.forum_outlined,
                    subtitle: 'Communications to Guardians',
                    color: AppColors.info,
                    onTap: () => _tabController.animateTo(3),
                  ),
                ];

                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: cards.map((c) {
                    final width = isDesktop
                        ? (constraints.maxWidth - 3 * AppSpacing.md) / 4
                        : (constraints.maxWidth - AppSpacing.md) / 2;
                    return SizedBox(width: width, child: c);
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),

            SearchFilterBar(
              searchHint: 'Search student by name or admission number...',
              searchQuery: _searchQuery,
              onSearchChanged: (val) => setState(() => _searchQuery = val),
              totalCount: filteredStudents.length,
              countLabel: 'Students Listed',
            ),
            const SizedBox(height: AppSpacing.lg),

            if (filteredStudents.isEmpty)
              EmptyStateView(
                icon: Icons.people_outline,
                title: _searchQuery.isNotEmpty ? 'No Matching Students' : 'No Students Enrolled',
                description: _searchQuery.isNotEmpty ? 'No student matches "$_searchQuery".' : 'No students found in this assigned classroom.',
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: AppShadows.subtle,
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredStudents.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.borderLight),
                  itemBuilder: (context, index) {
                    final s = filteredStudents[index];
                    final studentId = s['studentId'];
                    final currentStatus = _attendanceMap[studentId] ?? 'PRESENT';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primarySubtle,
                            child: Text(
                              '${s['rollNo'] ?? index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(s['fullName'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    if (s['isShortageRisk'] == true) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      StatusBadge(
                                        label: '⚠️ Shortage Risk (${s['attendancePercentage']}%)',
                                        variant: BadgeVariant.error,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Admission ID: ${s['admissionNo'] ?? 'N/A'}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          // Status Buttons
                          Row(
                            children: [
                              _buildStatusToggle(
                                studentId: studentId,
                                label: 'Present',
                                statusKey: 'PRESENT',
                                currentStatus: currentStatus,
                                activeColor: AppColors.success,
                                icon: Icons.check,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _buildStatusToggle(
                                studentId: studentId,
                                label: 'Absent',
                                statusKey: 'ABSENT',
                                currentStatus: currentStatus,
                                activeColor: AppColors.error,
                                icon: Icons.close,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _buildStatusToggle(
                                studentId: studentId,
                                label: 'Late',
                                statusKey: 'LATE',
                                currentStatus: currentStatus,
                                activeColor: AppColors.warning,
                                icon: Icons.schedule,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusToggle({
    required String studentId,
    required String label,
    required String statusKey,
    required String currentStatus,
    required Color activeColor,
    required IconData icon,
  }) {
    final isSelected = currentStatus == statusKey;

    return InkWell(
      onTap: () {
        setState(() {
          _attendanceMap[studentId] = statusKey;
        });
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.surfaceMuted,
          border: Border.all(color: isSelected ? activeColor : AppColors.borderLight),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestsView() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Classroom', 'Leave Requests'],
            title: 'Assigned Student Leave Applications',
            subtitle: 'Review medical and personal leave requests submitted by guardians for this section.',
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: _leaveRequests.isEmpty
                ? const EmptyStateView(
                    icon: Icons.event_available_outlined,
                    title: 'No Pending Leave Requests',
                    description: 'All submitted student leave requests for your section have been reviewed.',
                  )
                : ListView.builder(
                    itemCount: _leaveRequests.length,
                    itemBuilder: (context, index) {
                      final l = _leaveRequests[index];
                      final student = l['student'] ?? {};
                      final sName = student['fullName'] ?? '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim();
                      final dates = '${l['startDate']?.toString().split('T')[0]} to ${l['endDate']?.toString().split('T')[0]}';
                      final status = l['status'] ?? 'PENDING';

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
                              child: const Icon(Icons.event_note, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(sName.isNotEmpty ? sName : 'Student Leave', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(width: AppSpacing.sm),
                                      StatusBadge.fromStatus(status),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Reason: ${l['reason'] ?? 'Personal'}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text('Duration: $dates', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            if (status == 'PENDING')
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Classroom', 'Academic Curriculum', 'Assignments'],
            title: 'Class Homework & Coursework',
            subtitle: 'Assignments assigned to learners in $_className - $_sectionName.',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_assignments.isEmpty)
            const EmptyStateView(
              icon: Icons.assignment_outlined,
              title: 'No Active Class Assignments',
              description: 'Subject teachers have not posted any pending coursework for this section yet.',
            )
          else
            ..._assignments.map((a) {
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
                    const CircleAvatar(
                      backgroundColor: AppColors.primarySubtle,
                      child: Icon(Icons.assignment, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(a['title'] ?? 'Assignment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: AppSpacing.sm),
                              StatusBadge.fromStatus(a['status'] ?? 'PUBLISHED'),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('${a['description'] ?? 'No description'} • Max Marks: ${a['maxMarks'] ?? 100}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text('Due Date: ${a['dueDate'] ?? 'Open'}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCircularsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Classroom', 'Guardian Engagement', 'Parent Communications'],
            title: 'Parent Notices & Circular Communications',
            subtitle: 'Administrative notices and communications dispatched to guardians and learners.',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_circulars.isEmpty)
            const EmptyStateView(
              icon: Icons.forum_outlined,
              title: 'No Parent Communications',
              description: 'No administrative circulars have been broadcasted to parents yet.',
            )
          else
            ..._circulars.map((c) {
              final isUrgent = c['priority'] == 'URGENT';
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: isUrgent ? AppColors.errorSubtle : AppColors.secondarySubtle,
                      child: Icon(isUrgent ? Icons.error_outline : Icons.campaign_outlined, color: isUrgent ? AppColors.error : AppColors.secondary, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(c['title'] ?? 'Notice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              StatusBadge(
                                label: c['priority'] ?? 'STANDARD',
                                variant: isUrgent ? BadgeVariant.error : BadgeVariant.info,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(c['content'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          Text('Target: ${c['targetAudience']} • Dispatched: ${c['createdAt'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
