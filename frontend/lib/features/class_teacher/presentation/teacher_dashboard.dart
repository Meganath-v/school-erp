import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

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
  Map<String, String> _attendanceMap = {}; // studentId -> status (PRESENT, ABSENT, LATE)
  List<dynamic> _leaveRequests = [];
  String _searchQuery = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // 1. Fetch today's attendance session & roster
      final attRes = await ApiClient().dio.get('/attendance/today');
      final attData = attRes.data['data'];
      final studentsList = attData['students'] as List? ?? [];

      _sectionId = attData['section']?['id'];
      _sectionName = attData['section']?['name'] ?? 'Section A';

      final Map<String, String> newMap = {};
      for (final s in studentsList) {
        newMap[s['studentId']] = s['status'] ?? 'PRESENT';
      }

      // 2. Fetch leave requests
      final leaveRes = await ApiClient().dio.get('/leave-requests');

      setState(() {
        _students = studentsList;
        _attendanceMap = newMap;
        _leaveRequests = leaveRes.data['data'] ?? [];
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
            backgroundColor: AppTheme.success,
          ),
        );
        _loadTeacherData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit attendance'), backgroundColor: AppTheme.error),
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
          SnackBar(content: Text('Leave request $status successfully'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update leave: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
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
              Text('Unable to load attendance roster', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadTeacherData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final presentCount = _attendanceMap.values.where((v) => v == 'PRESENT').length;
    final absentCount = _attendanceMap.values.where((v) => v == 'ABSENT').length;
    final lateCount = _attendanceMap.values.where((v) => v == 'LATE').length;

    return Column(
      children: [
        // Tab Header
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.fact_check, size: 18), text: 'Daily Class Attendance'),
              Tab(icon: Icon(Icons.event_busy, size: 18), text: 'Student Leave Requests'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAttendanceView(presentCount, absentCount, lateCount),
              _buildLeaveRequestsView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceView(int present, int absent, int late) {
    final filteredStudents = _students.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (s['fullName'] ?? '').toString().toLowerCase();
      final adm = (s['admissionNo'] ?? '').toString().toLowerCase();
      return name.contains(q) || adm.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadTeacherData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner & Quick Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Attendance: $_className - $_sectionName',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Mark individual attendance status below. Parent alert notifications are automatically dispatched upon submission.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _markAllPresent,
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark All Present'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submitAttendance,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save, size: 16),
                      label: const Text('Submit & Lock Attendance'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Metric Summary Pills
            Row(
              children: [
                _buildPill('Total Roster', '${_students.length}', const Color(0xFFF1F5F9), AppTheme.textDark),
                const SizedBox(width: 12),
                _buildPill('Present', '$present', AppTheme.success.withValues(alpha: 0.12), AppTheme.success),
                const SizedBox(width: 12),
                _buildPill('Absent', '$absent', AppTheme.error.withValues(alpha: 0.12), AppTheme.error),
                const SizedBox(width: 12),
                _buildPill('Late / Tardy', '$late', AppTheme.warning.withValues(alpha: 0.12), AppTheme.warning),
              ],
            ),
            const SizedBox(height: 16),
            // Search Input
            TextField(
              decoration: InputDecoration(
                hintText: 'Search student by name or admission number...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 16),
            // Student Attendance Table
            if (filteredStudents.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      _students.isEmpty ? 'No students enrolled in this section' : 'No students matching "$_searchQuery"',
                      style: GoogleFonts.inter(color: AppTheme.textMuted),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredStudents.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = filteredStudents[index];
                    final studentId = s['studentId'];
                    final currentStatus = _attendanceMap[studentId] ?? 'PRESENT';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                            child: Text(
                              '${s['rollNo'] ?? index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(s['fullName'], style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                                    if (s['isShortageRisk'] == true) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text(
                                          '⚠️ Condonation Risk (${s['attendancePercentage']}%)',
                                          style: const TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text('Admission ID: ${s['admissionNo']}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          // Status Toggle Buttons
                          Row(
                            children: [
                              _buildStatusButton(
                                studentId: studentId,
                                label: 'Present',
                                statusKey: 'PRESENT',
                                currentStatus: currentStatus,
                                color: AppTheme.success,
                                icon: Icons.check,
                              ),
                              const SizedBox(width: 8),
                              _buildStatusButton(
                                studentId: studentId,
                                label: 'Absent',
                                statusKey: 'ABSENT',
                                currentStatus: currentStatus,
                                color: AppTheme.error,
                                icon: Icons.close,
                              ),
                              const SizedBox(width: 8),
                              _buildStatusButton(
                                studentId: studentId,
                                label: 'Late',
                                statusKey: 'LATE',
                                currentStatus: currentStatus,
                                color: AppTheme.warning,
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

  Widget _buildStatusButton({
    required String studentId,
    required String label,
    required String statusKey,
    required String currentStatus,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = currentStatus == statusKey;

    return InkWell(
      onTap: () {
        setState(() {
          _attendanceMap[studentId] = statusKey;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          border: Border.all(color: color, width: isSelected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestsView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Leave Applications Pending Review (${_leaveRequests.length})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_leaveRequests.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No leave applications recorded.')),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _leaveRequests.length,
                itemBuilder: (context, index) {
                  final req = _leaveRequests[index];
                  final isPending = req['status'] == 'PENDING';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.event_note, color: AppTheme.primary, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${req['studentName']} (${req['className']} - ${req['sectionName']})',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text('Applicant: ${req['applicantName']} • Reason: ${req['reason']}',
                                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                                Text('Duration: ${req['startDate']} to ${req['endDate']}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          if (isPending) ...[
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                              onPressed: () => _decideLeave(req['id'], 'REJECTED'),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                              onPressed: () => _decideLeave(req['id'], 'APPROVED'),
                              child: const Text('Approve'),
                            ),
                          ] else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: req['status'] == 'APPROVED' ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                req['status'],
                                style: TextStyle(
                                  color: req['status'] == 'APPROVED' ? AppTheme.success : AppTheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
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

  Widget _buildPill(String title, String val, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$title: ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
          Text(val, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }
}
