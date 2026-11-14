import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

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
            content: Text('Exam results approved and published to Parent Portal!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadPrincipalData();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to publish exam results'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _decideLeave(String leaveId, String decision) async {
    try {
      await ApiClient().dio.post('/leave-requests/$leaveId/decision', data: {
        'decision': decision,
        'remarks': 'Processed by Principal Office',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave request $decision successfully'),
            backgroundColor: decision == 'APPROVED' ? AppTheme.success : AppTheme.warning,
          ),
        );
        _loadPrincipalData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update leave status: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Broadcast Notice'),
        content: const Text('Are you sure you want to delete this notice?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient().dio.delete('/announcements/$id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement deleted successfully'), backgroundColor: AppTheme.success),
          );
          _loadPrincipalData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete announcement: $e'), backgroundColor: AppTheme.error),
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
            title: Text('Publish School Announcement', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Notice Title')),
                  const SizedBox(height: 12),
                  TextField(controller: contentCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notice Content / Description')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: targetRole,
                          decoration: const InputDecoration(labelText: 'Target Audience'),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Entire Campus (All)')),
                            DropdownMenuItem(value: 'PARENT', child: Text('Parents Only')),
                            DropdownMenuItem(value: 'TEACHER', child: Text('Faculty Only')),
                          ],
                          onChanged: (val) => setDialogState(() => targetRole = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement broadcasted successfully!'), backgroundColor: AppTheme.success));
                      _loadPrincipalData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to broadcast: $e'), backgroundColor: AppTheme.error));
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text('Unable to load principal oversight data', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPrincipalData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = _overview?['stats'] ?? {};

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textMuted,
                  indicatorColor: AppTheme.primary,
                  tabs: const [
                    Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Executive Overview'),
                    Tab(icon: Icon(Icons.verified_outlined, size: 18), text: 'Approvals & Moderation'),
                    Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'Campus Notices'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Overview',
                onPressed: _loadPrincipalData,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const Divider(height: 1),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Academic & Institutional Oversight', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildKpiCard('Total Enrollment', '${stats['totalStudents'] ?? 0}', Icons.people, AppTheme.primary),
                const SizedBox(width: 16),
                _buildKpiCard('Active Faculty', '${stats['totalStaff'] ?? 0}', Icons.badge, AppTheme.secondary),
                const SizedBox(width: 16),
                _buildKpiCard('Today Attendance', attendanceStr, Icons.check_circle, todayRate != null ? AppTheme.success : AppTheme.textMuted),
                const SizedBox(width: 16),
                _buildKpiCard('Pending Leaves', '${_leaveRequests.where((l) => l['status'] == 'PENDING').length}', Icons.event_busy, AppTheme.warning),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Institutional Audit Trail', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    if ((_overview?['recentAuditLogs'] as List? ?? []).isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No system audit events recorded yet.'),
                      )
                    else
                      ...((_overview?['recentAuditLogs'] as List? ?? []).map((l) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.success),
                              const SizedBox(width: 10),
                              Text('${l['action']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text('by ${l['actorName'] ?? 'Staff'} • ${l['timestamp']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            ],
                          ),
                        );
                      }).toList()),
                  ],
                ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Examination Publication Section
            Text('Examination Publication Moderation', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_exams.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No examinations scheduled or submitted for moderation')),
                ),
              )
            else
              ..._exams.map((ex) {
                final isPublished = ex['status'] == 'PUBLISHED';
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.school, color: AppTheme.primary, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ex['name'], style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('Term: ${ex['term']} • Academic Year: ${ex['academicYear']}', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
                              const SizedBox(height: 4),
                              Text('Subjects Tested: ${(ex['subjects'] as List? ?? []).length}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        if (!isPublished)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                            onPressed: () => _publishExam(ex['id']),
                            icon: const Icon(Icons.verified, size: 16),
                            label: const Text('Approve & Publish Results'),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Row(
                              children: [
                                Icon(Icons.check, size: 14, color: AppTheme.success),
                                SizedBox(width: 4),
                                Text('PUBLISHED TO PARENTS', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),

            const SizedBox(height: 28),
            // Student & Staff Leave Moderation Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pending Leave Applications (${pendingLeaves.length})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Real-time leave authorization', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            if (pendingLeaves.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No pending leave requests awaiting approval')),
                ),
              )
            else
              ...pendingLeaves.map((l) {
                final student = l['student'] ?? {};
                final sName = student['fullName'] ?? '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFFEF3C7),
                          child: Icon(Icons.event_busy, color: Colors.amber, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sName.isNotEmpty ? sName : 'Student Leave', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text('Reason: ${l['reason'] ?? 'Medical / Personal'}', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                              const SizedBox(height: 2),
                              Text('Dates: ${l['startDate']?.toString().split('T')[0]} to ${l['endDate']?.toString().split('T')[0]}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                              onPressed: () => _decideLeave(l['id'], 'APPROVED'),
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Approve', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                              onPressed: () => _decideLeave(l['id'], 'REJECTED'),
                              icon: const Icon(Icons.close, size: 14),
                              label: const Text('Reject', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('School-Wide Official Broadcasts (${allNotices.length})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showNewAnnouncementDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Compose Broadcast'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search broadcasts by title or content...',
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (val) => setState(() => _noticeSearchQuery = val),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.campaign_outlined, size: 48, color: AppTheme.border),
                        const SizedBox(height: 12),
                        Text(
                          _noticeSearchQuery.isNotEmpty ? 'No notices match "$_noticeSearchQuery"' : 'No official announcements issued yet',
                          style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final n = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(n['title'] ?? 'Notice', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      if (n['priority'] == 'URGENT')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('URGENT', style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text('Target: ${n['targetRole'] ?? 'ALL'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary)),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                                        tooltip: 'Delete Announcement',
                                        onPressed: () => _deleteAnnouncement(n['id']),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(n['content'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                              const SizedBox(height: 6),
                              Text('Issued by: ${n['authorName'] ?? 'Principal'} • ${n['publishedAt']?.toString().split('T')[0]}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            ],
          ),
        ),
      ),
    );
  }
}
