import '../../../core/widgets/adaptive_data_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/report_adapters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/responsive_metric_row.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/roles.dart';
import '../../timetable/data/timetable_api.dart';
import '../../timetable/presentation/daily_periods_view.dart';
import '../../timetable/presentation/my_day_view.dart';
import '../../timetable/presentation/schedule_widgets.dart';

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
        fetchAttendanceCompliance().then<Map<String, dynamic>?>((m) => m).catchError((_) => null),
      ]);

      _classes = results[0] as List<dynamic>;
      _defaulterReport = results[1] as Map<String, dynamic>?;

      if (_classes.isNotEmpty) {
        _selectedClassId = _classes[0]['id'];
        final secs = _classes[0]['sections'] as List? ?? [];
        if (secs.isNotEmpty) {
          _selectedSectionId = secs[0]['id'];
          _className = _classes[0]['name'];
          _sectionName = secs[0]['name'];
        }
      }

      // Teachers start on their own class (the backend picks it when no section is given).
      final role = ref.read(authProvider).activeRole;
      if (role == AppRoles.classTeacher || role == AppRoles.subjectTeacher) {
        final own = await ApiClient().dio.get('/attendance/today').then((r) => r.data['data']?['section']).catchError((_) => null);
        if (own is Map && own['id'] != null) {
          for (final c in _classes) {
            for (final sec in (c['sections'] as List? ?? [])) {
              if (sec['id'] == own['id']) {
                _selectedClassId = c['id'];
                _selectedSectionId = sec['id'];
                _className = c['name'];
                _sectionName = sec['name'];
              }
            }
          }
        }
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
      for (final s in studentsList) {
        dMap[s['studentId']] = s['status'] ?? 'PRESENT';
      }

      setState(() {
        _students = studentsList;
        _dailyAttendanceMap = dMap;
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
                  child: DropdownButtonFormField<String>(isExpanded: true, 
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
                  child: DropdownButtonFormField<String>(isExpanded: true, 
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
            ResponsiveMetricRow(
              children: [
                MetricCard(
                    title: 'Total Learners',
                    value: '$total',
                    icon: Icons.groups_outlined,
                    subtitle: 'Section Roster',
                    color: AppColors.primary,
                  ),
                MetricCard(
                    title: 'Present Today',
                    value: '$presentCount',
                    icon: Icons.check_circle_outline,
                    subtitle: 'Attending learners',
                    color: AppColors.success,
                  ),
                MetricCard(
                    title: 'Absent Learners',
                    value: '$absentCount',
                    icon: Icons.cancel_outlined,
                    subtitle: 'Absence slips',
                    color: AppColors.error,
                  ),
                MetricCard(
                    title: 'Late Arrivals',
                    value: '$lateCount',
                    icon: Icons.schedule_outlined,
                    subtitle: 'Tardy presence',
                    color: AppColors.warning,
                  ),
                MetricCard(
                    title: 'Section Fulfillment',
                    value: '$rate%',
                    icon: Icons.analytics_outlined,
                    subtitle: 'Presence ratio',
                    color: AppColors.secondary,
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

                    final identity = Row(
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
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(s['fullName'] ?? 'Learner', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (s['isShortageRisk'] == true)
                                    const StatusBadge(label: 'Shortage <75%', variant: BadgeVariant.error),
                                ],
                              ),
                              Text('Adm No: ${s['admissionNo'] ?? 'N/A'} • Cumulative: ${s['attendancePercentage'] ?? 100}%', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    );
                    const options = [
                      ('PRESENT', 'Present', Icons.check),
                      ('ABSENT', 'Absent', Icons.close),
                      ('LATE', 'Late', Icons.schedule),
                      ('HALF_DAY', 'Half Day', Icons.timelapse),
                    ];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: LayoutBuilder(builder: (context, constraints) {
                        // Phones: status choices go on their own line under the name.
                        if (constraints.maxWidth < 560) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              identity,
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  for (final o in options)
                                    ChoiceChip(
                                      label: Text(o.$2),
                                      avatar: Icon(o.$3, size: 16),
                                      showCheckmark: false,
                                      selected: status == o.$1,
                                      onSelected: (_) => setState(() => _dailyAttendanceMap[studentId] = o.$1),
                                    ),
                                ],
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: identity),
                            SegmentedButton<String>(
                              segments: [
                                for (final o in options)
                                  ButtonSegment(value: o.$1, label: Text(o.$2), icon: Icon(o.$3, size: 14)),
                              ],
                              selected: {status},
                              onSelectionChanged: (set) {
                                setState(() => _dailyAttendanceMap[studentId] = set.first);
                              },
                            ),
                          ],
                        );
                      }),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Period attendance: teachers see their own periods for the day; office staff pick a class.
  /// Only the teacher taking a period can mark it, on that day; the office can correct it later.
  Widget _buildPeriodMarkingTab() {
    final role = ref.watch(authProvider).activeRole;
    final api = TimetableApi();
    if (role == AppRoles.classTeacher || role == AppRoles.subjectTeacher) return MyDayView(api: api);
    return SectionScope(api: api, pickAny: true, builder: (id) => DailyPeriodsView(api: api, sectionId: id, officeView: true));
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
                child: DropdownButtonFormField<int>(isExpanded: true, 
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
                child: DropdownButtonFormField<int>(isExpanded: true, 
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
                child: AdaptiveDataTable(
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

          ResponsiveMetricRow(
            children: [
              MetricCard(
                  title: 'Condonation Threshold',
                  value: '$threshold%',
                  icon: Icons.verified_outlined,
                  subtitle: 'Institutional Minimum',
                  color: AppColors.primary,
                ),
              MetricCard(
                  title: 'Defaulters at Risk',
                  value: '${defaulters.length}',
                  icon: Icons.warning_amber_outlined,
                  subtitle: 'Below $threshold% threshold',
                  color: defaulters.isNotEmpty ? AppColors.error : AppColors.success,
                ),
              MetricCard(
                  title: 'Overall Institution Rate',
                  value: '$overallRate%',
                  icon: Icons.analytics_outlined,
                  subtitle: 'Cumulative Presence Ratio',
                  color: overallRate >= 75 ? AppColors.success : AppColors.warning,
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
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
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
