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

  Map<String, dynamic>? _overview;
  List<dynamic> _exams = [];
  List<dynamic> _leaveRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPrincipalData();
  }

  Future<void> _loadPrincipalData() async {
    setState(() => _isLoading = true);
    try {
      final overviewRes = await ApiClient().dio.get('/reports/overview');
      final examsRes = await ApiClient().dio.get('/exams');
      final leaveRes = await ApiClient().dio.get('/leave-requests');

      setState(() {
        _overview = overviewRes.data['data'];
        _exams = examsRes.data['data'] ?? [];
        _leaveRequests = leaveRes.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _publishExam(String examId) async {
    try {
      await ApiClient().dio.post('/exams/$examId/publish');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exam results approved and published to Parent Portal!'),
          backgroundColor: AppTheme.success,
        ),
      );
      _loadPrincipalData();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to publish exam results'), backgroundColor: AppTheme.error),
      );
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
                  if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;
                  await ApiClient().dio.post('/announcements', data: {
                    'title': titleCtrl.text.trim(),
                    'content': contentCtrl.text.trim(),
                    'targetRole': targetRole,
                    'priority': priority,
                    'authorName': 'Principal Office',
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement broadcasted successfully!')));
                    _loadPrincipalData();
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

    final stats = _overview?['stats'] ?? {};

    return Column(
      children: [
        Container(
          color: Colors.white,
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
    return SingleChildScrollView(
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
              _buildKpiCard('Today Attendance', '${stats['todayAttendanceRate'] ?? 0}%', Icons.check_circle, AppTheme.success),
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
    );
  }

  Widget _buildApprovalsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Examination Publication Moderation', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _exams.length,
              itemBuilder: (context, index) {
                final ex = _exams[index];
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
                              Text('Subjects Tested: ${(ex['subjects'] as List).length}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticesTab() {
    final notices = _overview?['recentAnnouncements'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('School-Wide Official Broadcasts (${notices.length})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showNewAnnouncementDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Compose Broadcast'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: notices.length,
              itemBuilder: (context, index) {
                final n = notices[index];
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
                            Text(n['title'], style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Target: ${n['targetRole']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(n['content'], style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
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
