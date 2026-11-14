import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class AttendanceManagementScreen extends ConsumerStatefulWidget {
  const AttendanceManagementScreen({super.key});

  @override
  ConsumerState<AttendanceManagementScreen> createState() => _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState extends ConsumerState<AttendanceManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _classes = [];
  String? _selectedClassId;
  String? _selectedSectionId;
  String _className = 'Grade 10';
  String _sectionName = 'Section A';

  // Daily Marking State
  List<dynamic> _students = [];
  Map<String, String> _dailyAttendanceMap = {};
  bool _isSavingDaily = false;
  String _dailySearchQuery = '';

  // Period Marking State
  int _selectedPeriod = 1;
  String? _selectedSubjectId;
  List<dynamic> _subjects = [];
  Map<String, String> _periodAttendanceMap = {};
  final _periodRemarksCtrl = TextEditingController();
  bool _isSavingPeriod = false;

  // Monthly Register State
  Map<String, dynamic>? _monthlyMatrix;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isLoadingMatrix = false;

  // Defaulter & Student Report State
  Map<String, dynamic>? _defaulterReport;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _periodRemarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient().dio.get('/schools/classes').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/subjects').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/reports/attendance').then((r) => r.data as Map<String, dynamic>?).catchError((_) => null),
      ]);

      _classes = results[0] as List<dynamic>;
      _subjects = results[1] as List<dynamic>;
      _defaulterReport = results[2] as Map<String, dynamic>?;

      if (_classes.isNotEmpty) {
        _selectedClassId = _classes[0]['id'];
        final secs = _classes[0]['sections'] as List? ?? [];
        if (secs.isNotEmpty) {
          _selectedSectionId = secs[0]['id'];
          _className = _classes[0]['name'];
          _sectionName = secs[0]['name'];
        }
      }

      if (_subjects.isNotEmpty) {
        _selectedSubjectId = _subjects[0]['id'];
      }

      await _loadSectionRoster();
      await _loadMonthlyMatrix();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSectionRoster() async {
    try {
      final res = await ApiClient().dio.get('/attendance/today', queryParameters: {
        if (_selectedSectionId != null) 'sectionId': _selectedSectionId,
      });

      final data = res.data['data'];
      final studentsList = data['students'] as List? ?? [];

      final Map<String, String> dMap = {};
      final Map<String, String> pMap = {};
      for (final s in studentsList) {
        dMap[s['studentId']] = s['status'] ?? 'PRESENT';
        pMap[s['studentId']] = 'PRESENT';
      }

      setState(() {
        _students = studentsList;
        _dailyAttendanceMap = dMap;
        _periodAttendanceMap = pMap;
      });
    } catch (_) {}
  }

  Future<void> _loadMonthlyMatrix() async {
    setState(() => _isLoadingMatrix = true);
    try {
      final res = await ApiClient().dio.get('/attendance/matrix', queryParameters: {
        if (_selectedSectionId != null) 'sectionId': _selectedSectionId,
        'month': _selectedMonth,
        'year': _selectedYear,
      });
      setState(() {
        _monthlyMatrix = res.data['data'];
        _isLoadingMatrix = false;
      });
    } catch (_) {
      setState(() => _isLoadingMatrix = false);
    }
  }

  Future<void> _saveDailyAttendance() async {
    if (_selectedSectionId == null) return;
    setState(() => _isSavingDaily = true);

    try {
      final records = _dailyAttendanceMap.entries.map((e) {
        return {
          'studentId': e.key,
          'status': e.value,
        };
      }).toList();

      await ApiClient().dio.post('/attendance/sessions', data: {
        'sectionId': _selectedSectionId,
        'records': records,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily attendance locked and persisted successfully!'), backgroundColor: AppColors.success),
        );
        _loadSectionRoster();
        _loadMonthlyMatrix();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit attendance: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSavingDaily = false);
    }
  }

  Future<void> _savePeriodAttendance() async {
    if (_selectedSectionId == null || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select section and subject')));
      return;
    }

    setState(() => _isSavingPeriod = true);
    try {
      final records = _periodAttendanceMap.entries.map((e) {
        return {
          'studentId': e.key,
          'status': e.value,
        };
      }).toList();

      await ApiClient().dio.post('/attendance/sessions', data: {
        'sectionId': _selectedSectionId,
        'sessionType': 'PERIOD',
        'periodNumber': _selectedPeriod,
        'subjectId': _selectedSubjectId,
        'remarks': _periodRemarksCtrl.text.trim(),
        'records': records,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Period $_selectedPeriod attendance recorded successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to record period attendance: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSavingPeriod = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading institutional attendance registry...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Attendance Unavailable',
        message: _errorMessage,
        onRetry: _loadInitialData,
      );
    }

    return Column(
      children: [
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
                    Tab(icon: Icon(Icons.fact_check_outlined, size: 18), text: 'Attendance Overview & Daily'),
                    Tab(icon: Icon(Icons.timer_outlined, size: 18), text: 'Period-Wise Marking'),
                    Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: 'Monthly Register Grid'),
                    Tab(icon: Icon(Icons.warning_amber_outlined, size: 18), text: 'Defaulter Report & Details'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Roster',
                onPressed: _loadInitialData,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDailyMarkingTab(),
              _buildPeriodMarkingTab(),
              _buildMonthlyRegisterTab(),
              _buildDefaulterReportTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyMarkingTab() {
    final presentCount = _dailyAttendanceMap.values.where((v) => v == 'PRESENT').length;
    final absentCount = _dailyAttendanceMap.values.where((v) => v == 'ABSENT').length;
    final lateCount = _dailyAttendanceMap.values.where((v) => v == 'LATE').length;
    final total = _students.length;
    final rate = total > 0 ? ((presentCount / total) * 100).toStringAsFixed(1) : '0';

    final filtered = _students.where((s) {
      if (_dailySearchQuery.isEmpty) return true;
      final q = _dailySearchQuery.toLowerCase();
      final name = (s['fullName'] ?? '').toString().toLowerCase();
      final adm = (s['admissionNo'] ?? '').toString().toLowerCase();
      return name.contains(q) || adm.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadSectionRoster,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Attendance', 'Daily Session', 'Class Marking'],
              title: 'Daily Attendance Marking: $_className - $_sectionName',
              subtitle: 'Track student daily presence with SMS/app notifications sent upon locking session.',
              actions: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      for (final s in _students) {
                        _dailyAttendanceMap[s['studentId']] = 'PRESENT';
                      }
                    });
                  },
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark All Present'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: _isSavingDaily ? null : _saveDailyAttendance,
                  icon: _isSavingDaily
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_clock, size: 16),
                  label: const Text('Submit & Lock Attendance'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Class and Section Switcher Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(labelText: 'Grade / Class'),
                    items: _classes.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedClassId = val;
                          final c = _classes.firstWhere((item) => item['id'] == val);
                          _className = c['name'];
                          final secs = c['sections'] as List? ?? [];
                          if (secs.isNotEmpty) {
                            _selectedSectionId = secs[0]['id'];
                            _sectionName = secs[0]['name'];
                          }
                        });
                        _loadSectionRoster();
                        _loadMonthlyMatrix();
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSectionId,
                    decoration: const InputDecoration(labelText: 'Section Division'),
                    items: (_selectedClassId != null
                            ? (_classes.firstWhere((c) => c['id'] == _selectedClassId, orElse: () => {'sections': []})['sections'] as List? ?? [])
                            : [])
                        .map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'])))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSectionId = val;
                          final c = _classes.firstWhere((item) => item['id'] == _selectedClassId);
                          final s = (c['sections'] as List).firstWhere((sec) => sec['id'] == val);
                          _sectionName = s['name'];
                        });
                        _loadSectionRoster();
                        _loadMonthlyMatrix();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Telemetry Metric Cards
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Total Learners',
                    value: '$total',
                    icon: Icons.groups_outlined,
                    subtitle: 'Section Roster',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Present Today',
                    value: '$presentCount',
                    icon: Icons.check_circle_outline,
                    subtitle: 'Attending learners',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Absent Learners',
                    value: '$absentCount',
                    icon: Icons.cancel_outlined,
                    subtitle: 'Absence slips',
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Late Arrivals',
                    value: '$lateCount',
                    icon: Icons.schedule_outlined,
                    subtitle: 'Tardy presence',
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Section Fulfillment',
                    value: '$rate%',
                    icon: Icons.analytics_outlined,
                    subtitle: 'Presence ratio',
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            SearchFilterBar(
              searchHint: 'Search student by name or admission number...',
              searchQuery: _dailySearchQuery,
              onSearchChanged: (val) => setState(() => _dailySearchQuery = val),
              totalCount: filtered.length,
              countLabel: 'Learners in Roster',
            ),
            const SizedBox(height: AppSpacing.lg),

            if (filtered.isEmpty)
              const EmptyStateView(
                icon: Icons.people_outline,
                title: 'No Students Found',
                description: 'No students match your search filter in this section.',
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
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.borderLight),
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    final studentId = s['studentId'];
                    final status = _dailyAttendanceMap[studentId] ?? 'PRESENT';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primarySubtle,
                            child: Text('${s['rollNo'] ?? index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(s['fullName'] ?? 'Learner', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    if (s['isShortageRisk'] == true) ...[
                                      const SizedBox(width: 8),
                                      const StatusBadge(label: 'Shortage <75%', variant: BadgeVariant.error),
                                    ],
                                  ],
                                ),
                                Text('Adm No: ${s['admissionNo'] ?? 'N/A'} • Cumulative: ${s['attendancePercentage'] ?? 100}%', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'PRESENT', label: Text('Present'), icon: Icon(Icons.check, size: 14)),
                              ButtonSegment(value: 'ABSENT', label: Text('Absent'), icon: Icon(Icons.close, size: 14)),
                              ButtonSegment(value: 'LATE', label: Text('Late'), icon: Icon(Icons.schedule, size: 14)),
                              ButtonSegment(value: 'HALF_DAY', label: Text('Half Day'), icon: Icon(Icons.timelapse, size: 14)),
                            ],
                            selected: {status},
                            onSelectionChanged: (set) {
                              setState(() => _dailyAttendanceMap[studentId] = set.first);
                            },
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

  Widget _buildPeriodMarkingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Attendance', 'Period Attendance', 'Subject Session'],
            title: 'Subject Period Attendance Marking',
            subtitle: 'Record attendance for specific 1-8 class periods and curriculum subjects.',
            actions: [
              ElevatedButton.icon(
                onPressed: _isSavingPeriod ? null : _savePeriodAttendance,
                icon: _isSavingPeriod
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 16),
                label: const Text('Commit Period Attendance'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: AppShadows.subtle,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Period & Instructional Subject', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedPeriod,
                        decoration: const InputDecoration(labelText: 'Class Period (1 to 8)'),
                        items: [1, 2, 3, 4, 5, 6, 7, 8].map((p) => DropdownMenuItem(value: p, child: Text('Period $p'))).toList(),
                        onChanged: (val) => setState(() => _selectedPeriod = val!),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubjectId,
                        decoration: const InputDecoration(labelText: 'Subject Taught'),
                        items: _subjects.map<DropdownMenuItem<String>>((sub) => DropdownMenuItem(value: sub['id'] as String, child: Text(sub['name']))).toList(),
                        onChanged: (val) => setState(() => _selectedSubjectId = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _periodRemarksCtrl,
                  decoration: const InputDecoration(labelText: 'Session Topic & Remarks', hintText: 'e.g. Chapter 4 Thermodynamics Lecture'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Period Students Table
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
              itemCount: _students.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.borderLight),
              itemBuilder: (context, index) {
                final s = _students[index];
                final studentId = s['studentId'];
                final status = _periodAttendanceMap[studentId] ?? 'PRESENT';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.secondarySubtle,
                        child: Text('${s['rollNo'] ?? index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 12)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(s['fullName'] ?? 'Learner', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'PRESENT', label: Text('Present')),
                          ButtonSegment(value: 'ABSENT', label: Text('Absent')),
                          ButtonSegment(value: 'LATE', label: Text('Late')),
                        ],
                        selected: {status},
                        onSelectionChanged: (set) => setState(() => _periodAttendanceMap[studentId] = set.first),
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

  Widget _buildMonthlyRegisterTab() {
    final matrixData = _monthlyMatrix;
    final students = (matrixData?['students'] as List? ?? []);
    final totalDays = matrixData?['totalDaysInMonth'] ?? 30;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Attendance', 'Monthly Matrix', 'Register Broadsheet'],
            title: 'Monthly Attendance Register: $_className - $_sectionName',
            subtitle: 'Day-by-day continuous attendance grid across all active teaching days.',
            actions: [
              OutlinedButton.icon(
                onPressed: _loadMonthlyMatrix,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Matrix'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Month / Year Picker
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: List.generate(12, (i) => i + 1)
                      .map((m) => DropdownMenuItem(value: m, child: Text('Month $m - ${DateTime(2026, m).toString().split(' ')[0]}')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMonth = val);
                      _loadMonthlyMatrix();
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: [2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedYear = val);
                      _loadMonthlyMatrix();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_isLoadingMatrix)
            const SizedBox(height: 200, child: LoadingStateView(message: 'Generating monthly register matrix...'))
          else if (students.isEmpty)
            const EmptyStateView(
              icon: Icons.calendar_today_outlined,
              title: 'No Register Data',
              description: 'No sessions recorded for the selected month and section.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: AppShadows.subtle,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12,
                  headingRowColor: WidgetStateProperty.all(AppColors.tableHeaderBg),
                  columns: [
                    const DataColumn(label: Text('Roll', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    ...List.generate(totalDays, (d) => DataColumn(label: Text('${d + 1}', style: const TextStyle(fontWeight: FontWeight.bold)))),
                    const DataColumn(label: Text('% Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: students.map<DataRow>((st) {
                    final days = st['days'] as Map<String, dynamic>? ?? {};
                    final rate = st['percentage'] ?? 100;

                    return DataRow(
                      cells: [
                        DataCell(Text('${st['rollNo'] ?? '—'}')),
                        DataCell(Text(st['fullName'] ?? 'Learner', style: const TextStyle(fontWeight: FontWeight.w600))),
                        ...List.generate(totalDays, (d) {
                          final status = days['${d + 1}']?['status'];
                          Color color = Colors.transparent;
                          String text = '—';
                          if (status == 'PRESENT') {
                            color = AppColors.success.withValues(alpha: 0.15);
                            text = 'P';
                          } else if (status == 'ABSENT') {
                            color = AppColors.error.withValues(alpha: 0.15);
                            text = 'A';
                          } else if (status == 'LATE') {
                            color = AppColors.warning.withValues(alpha: 0.15);
                            text = 'L';
                          } else if (status == 'HALF_DAY') {
                            color = AppColors.info.withValues(alpha: 0.15);
                            text = 'H';
                          }
                          return DataCell(
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                              child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }),
                        DataCell(
                          StatusBadge(
                            label: '$rate%',
                            variant: rate >= 75 ? BadgeVariant.success : BadgeVariant.error,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaulterReportTab() {
    final report = _defaulterReport;
    final defaulters = (report?['condonationShortageList'] as List? ?? []);
    final threshold = report?['condonationThreshold'] ?? 75;
    final overallRate = report?['overallAttendanceRate'] ?? 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Attendance', 'Condonation Compliance', 'Defaulters'],
            title: 'Attendance Defaulters & Condonation Deficiency Report',
            subtitle: 'Identification of learners whose aggregate attendance is below statutory $threshold% condonation threshold.',
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Condonation Threshold',
                  value: '$threshold%',
                  icon: Icons.verified_outlined,
                  subtitle: 'Institutional Minimum',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Defaulters at Risk',
                  value: '${defaulters.length}',
                  icon: Icons.warning_amber_outlined,
                  subtitle: 'Below $threshold% threshold',
                  color: defaulters.isNotEmpty ? AppColors.error : AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Overall Institution Rate',
                  value: '$overallRate%',
                  icon: Icons.analytics_outlined,
                  subtitle: 'Cumulative Presence Ratio',
                  color: overallRate >= 75 ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
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
                    Text('Learners Requiring Condonation Intervention', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    StatusBadge(label: '${defaulters.length} Defaulters', variant: defaulters.isNotEmpty ? BadgeVariant.error : BadgeVariant.success),
                  ],
                ),
                const Divider(height: 24),
                if (defaulters.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text('All enrolled learners satisfy the 75% attendance condonation threshold!'),
                    ),
                  )
                else
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.5),
                      1: FlexColumnWidth(2.5),
                      2: FlexColumnWidth(1.8),
                      3: FlexColumnWidth(1.5),
                      4: FlexColumnWidth(1.5),
                      5: FlexColumnWidth(1.8),
                    },
                    border: TableBorder(
                      horizontalInside: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
                    ),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: AppColors.tableHeaderBg),
                        children: [
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Admission No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Class & Section', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Sessions Attended', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Attendance %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Deficit Sessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                      ...defaulters.map((d) {
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(d['admissionNo'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(d['fullName'] ?? 'Learner', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('${d['className']} (${d['sectionName']})', style: const TextStyle(fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('${d['attendedSessions']} / ${d['totalSessions']}', style: const TextStyle(fontSize: 13))),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text('${d['attendanceRate']}%', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text('${d['deficitSessions']} to reach 75%', style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
