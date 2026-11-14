import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class SchoolAdminDashboard extends ConsumerStatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  ConsumerState<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends ConsumerState<SchoolAdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _overview;
  List<dynamic> _students = [];
  List<dynamic> _classes = [];
  List<dynamic> _staff = [];
  List<dynamic> _invoices = [];

  String? _selectedClassFilter;
  String _studentSearchQuery = '';
  String _staffSearchQuery = '';
  String _invoiceSearchQuery = '';
  String _selectedInvoiceStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient().dio.get('/reports/overview').then((r) => r.data['data'] as Map<String, dynamic>?).catchError((_) => null),
        ApiClient().dio.get('/students').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/classes').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/staff').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/fees/invoices').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
      ]);

      setState(() {
        _overview = results[0] as Map<String, dynamic>?;
        _students = results[1] as List<dynamic>;
        _classes = results[2] as List<dynamic>;
        _staff = results[3] as List<dynamic>;
        _invoices = results[4] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showNewAdmissionDialog() {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final guardianNameCtrl = TextEditingController();
    final guardianPhoneCtrl = TextEditingController();
    String? selectedClassId = _classes.isNotEmpty ? _classes[0]['id'] : null;
    String? selectedSectionId = (_classes.isNotEmpty && (_classes[0]['sections'] as List).isNotEmpty)
        ? _classes[0]['sections'][0]['id']
        : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final currentClassSections = _classes.firstWhere(
            (c) => c['id'] == selectedClassId,
            orElse: () => {'sections': []},
          )['sections'] as List;

          return AlertDialog(
            title: const Text('Student Admission & Enrollment'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Identity',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name'))),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name'))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Academic Allocation',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedClassId,
                            decoration: const InputDecoration(labelText: 'Grade / Class'),
                            items: _classes.map<DropdownMenuItem<String>>((c) {
                              return DropdownMenuItem(value: c['id'] as String, child: Text(c['name']));
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedClassId = val;
                                final secs = _classes.firstWhere((c) => c['id'] == val)['sections'] as List;
                                selectedSectionId = secs.isNotEmpty ? secs[0]['id'] : null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSectionId,
                            decoration: const InputDecoration(labelText: 'Section'),
                            items: currentClassSections.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedSectionId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Parent / Guardian Contacts',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(controller: guardianNameCtrl, decoration: const InputDecoration(labelText: 'Guardian Name', hintText: 'Father / Mother full name')),
                    const SizedBox(height: AppSpacing.md),
                    TextField(controller: guardianPhoneCtrl, decoration: const InputDecoration(labelText: 'Guardian Mobile', hintText: '+91 98765 00000')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (firstNameCtrl.text.isEmpty || lastNameCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter student name')));
                    return;
                  }

                  try {
                    await ApiClient().dio.post('/admissions', data: {
                      'firstName': firstNameCtrl.text.trim(),
                      'lastName': lastNameCtrl.text.trim(),
                      'classId': selectedClassId,
                      'sectionId': selectedSectionId,
                      'guardianName': guardianNameCtrl.text.trim(),
                      'guardianPhone': guardianPhoneCtrl.text.trim(),
                    });

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Student admitted and enrolled successfully!'), backgroundColor: AppColors.success),
                      );
                      _loadAllData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to admit student'), backgroundColor: AppColors.error));
                  }
                },
                child: const Text('Complete Admission'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showStudentReportCard(String studentId, String studentName) async {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder(
          future: ApiClient().dio.get('/students/$studentId/report-card'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const AlertDialog(
                content: SizedBox(height: 120, child: LoadingStateView(message: 'Compiling student broadsheet...')),
              );
            }

            final data = (snapshot.data as dynamic).data['data'];
            final exams = data['exams'] as List? ?? [];

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Report Card: $studentName'),
                  StatusBadge(
                    label: 'Attendance: ${data['attendancePercentage']}%',
                    variant: BadgeVariant.success,
                  ),
                ],
              ),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Class: ${data['student']['class']} (${data['student']['section']}) • Roll No: ${data['student']['rollNo']} • Academic Year: ${data['student']['academicYear']}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (exams.isEmpty)
                        const Text('No examinations recorded for this student yet.')
                      else
                        ...exams.map((ex) {
                          final subjects = ex['subjects'] as List? ?? [];
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(ex['examName'] ?? 'Examination', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(
                                      'Total: ${ex['totalMarksObtained']} / ${ex['totalMaxMarks']} (${ex['percentage']}%) • Grade: ${ex['grade']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                ...subjects.map((sub) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(sub['subject'] ?? 'Subject', style: const TextStyle(fontSize: 13)),
                                        Text('${sub['marksObtained']} / ${sub['maxMarks']} (${sub['grade']})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading institutional administration telemetry...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Administration Data Unavailable',
        message: _errorMessage,
        onRetry: _loadAllData,
      );
    }

    final stats = _overview?['stats'] ?? {};

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
                    Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
                    Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Students & Admissions'),
                    Tab(icon: Icon(Icons.account_tree_outlined, size: 18), text: 'Academics & Classes'),
                    Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Faculty & Staff'),
                    Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Fees & Invoices'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh School Data',
                onPressed: _loadAllData,
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
              _buildStudentsTab(),
              _buildAcademicsTab(),
              _buildStaffTab(),
              _buildFeesTab(),
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
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Administration', 'School Operations'],
              title: 'Institutional Operations Dashboard',
              subtitle: 'Comprehensive status of enrollment, academic classrooms, teaching staff, and fee performance.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _loadAllData,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: _showNewAdmissionDialog,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('New Admission'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Top Metric Cards Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1000;
                final cards = [
                  MetricCard(
                    title: 'Total Students',
                    value: '${stats['totalStudents'] ?? 0}',
                    icon: Icons.people_outline,
                    subtitle: 'AY 2026-2027 Enrolled',
                    color: AppColors.primary,
                    onTap: () => _tabController.animateTo(1),
                  ),
                  MetricCard(
                    title: 'Total Staff',
                    value: '${stats['totalStaff'] ?? 0}',
                    icon: Icons.badge_outlined,
                    subtitle: 'Full Faculty Roster',
                    color: AppColors.secondary,
                    onTap: () => _tabController.animateTo(3),
                  ),
                  MetricCard(
                    title: 'Classes & Sections',
                    value: '${stats['totalClasses'] ?? 0} Classes',
                    icon: Icons.meeting_room_outlined,
                    subtitle: '${stats['totalSections'] ?? 0} Active Sections',
                    color: AppColors.accent,
                    onTap: () => _tabController.animateTo(2),
                  ),
                  MetricCard(
                    title: 'Admissions',
                    value: '${_students.length}',
                    icon: Icons.how_to_reg_outlined,
                    subtitle: 'Enrolled Learners',
                    color: AppColors.info,
                    onTap: () => _tabController.animateTo(1),
                  ),
                  MetricCard(
                    title: 'Attendance Overview',
                    value: attendanceStr,
                    icon: Icons.check_circle_outline,
                    subtitle: 'Today • Morning Session',
                    color: todayRate != null ? AppColors.success : AppColors.textMuted,
                    onTap: () => _tabController.animateTo(1),
                  ),
                  MetricCard(
                    title: 'Fee Collections',
                    value: '₹${(stats['totalCollected'] ?? 0).toStringAsFixed(0)}',
                    icon: Icons.payments_outlined,
                    subtitle: '₹${(stats['totalDue'] ?? 0).toStringAsFixed(0)} Outstanding',
                    color: AppColors.warning,
                    onTap: () => _tabController.animateTo(4),
                  ),
                  MetricCard(
                    title: 'Pending Admin Work',
                    value: '${stats['pendingAdminWork'] ?? 0}',
                    icon: Icons.pending_actions_outlined,
                    subtitle: 'Leaves & Due Invoices',
                    color: (stats['pendingAdminWork'] ?? 0) > 0 ? AppColors.error : AppColors.success,
                    onTap: () {
                      _tabController.animateTo(4);
                      setState(() => _selectedInvoiceStatusFilter = 'PENDING');
                    },
                  ),
                ];

                if (isDesktop) {
                  return Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: cards.map((c) => SizedBox(width: (constraints.maxWidth - (cards.length > 4 ? 3 : 2) * AppSpacing.md) / (cards.length > 4 ? 4 : 3), child: c)).toList(),
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

            // Two Column Layout: Notices & Audit Logs
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Announcements
                Expanded(
                  flex: 5,
                  child: Container(
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
                            const Icon(Icons.campaign, color: AppColors.primary, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Campus Announcements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if ((_overview?['recentAnnouncements'] as List? ?? []).isEmpty)
                          const Text('No school announcements posted yet.', style: TextStyle(color: AppColors.textSecondary))
                        else
                          ...((_overview?['recentAnnouncements'] as List? ?? []).map((ann) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: AppSpacing.md),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(ann['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (ann['priority'] == 'URGENT')
                                        const StatusBadge(label: 'URGENT', variant: BadgeVariant.error),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(ann['content'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            );
                          }).toList()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),

                // Recent Audit Events
                Expanded(
                  flex: 5,
                  child: Container(
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
                            const Icon(Icons.history, color: AppColors.secondary, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text('System Audit Trail', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if ((_overview?['recentAuditLogs'] as List? ?? []).isEmpty)
                          const Text('No audit events registered yet.', style: TextStyle(color: AppColors.textSecondary))
                        else
                          ...((_overview?['recentAuditLogs'] as List? ?? []).map((log) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${log['action']} by ${log['actorName'] ?? 'System'}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          'Entity: ${log['entity']} • ${log['timestamp']}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    final filteredStudents = _students.where((s) {
      final matchClass = _selectedClassFilter == null || s['currentClass'] == _selectedClassFilter;
      final q = _studentSearchQuery.toLowerCase().trim();
      final matchSearch = q.isEmpty ||
          (s['fullName'] ?? '').toString().toLowerCase().contains(q) ||
          (s['admissionNo'] ?? '').toString().toLowerCase().contains(q);
      return matchClass && matchSearch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Administration', 'Student Directory'],
            title: 'Student Lifecycle & Enrollment',
            subtitle: 'Enrolled students roster, class assignments, and individual academic report cards.',
            actions: [
              ElevatedButton.icon(
                onPressed: _showNewAdmissionDialog,
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('New Admission'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SearchFilterBar(
            searchHint: 'Search by student name or admission number...',
            searchQuery: _studentSearchQuery,
            onSearchChanged: (val) => setState(() => _studentSearchQuery = val),
            totalCount: filteredStudents.length,
            countLabel: 'Students Active',
            filters: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClassFilter,
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('All Classes')),
                    ..._classes.map((c) => DropdownMenuItem<String>(value: c['name'] as String, child: Text(c['name'] as String))),
                  ],
                  onChanged: (val) => setState(() => _selectedClassFilter = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: filteredStudents.isEmpty
                ? EmptyStateView(
                    icon: Icons.people_outline,
                    title: _studentSearchQuery.isNotEmpty ? 'No Matching Students' : 'No Students Enrolled',
                    description: _studentSearchQuery.isNotEmpty
                        ? 'No student records match the active search filter.'
                        : 'Admit new learners using the New Admission action.',
                    actionLabel: _studentSearchQuery.isNotEmpty ? 'Clear Filter' : 'New Admission',
                    onAction: _studentSearchQuery.isNotEmpty ? () => setState(() => _studentSearchQuery = '') : _showNewAdmissionDialog,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: AppShadows.subtle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 320),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppColors.tableHeaderBg),
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 64,
                          horizontalMargin: AppSpacing.lg,
                          columnSpacing: AppSpacing.xl,
                          columns: const [
                            DataColumn(label: Text('Admission No', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Student Full Name', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Class & Section', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Roll No', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Primary Guardian', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Broadsheet Action', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                          rows: filteredStudents.map((s) {
                            return DataRow(
                              cells: [
                                DataCell(Text(s['admissionNo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                                DataCell(Text(s['fullName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text('${s['currentClass']} - ${s['currentSection']}')),
                                DataCell(Text('${s['rollNo'] ?? 'N/A'}')),
                                DataCell(Text((s['guardians'] as List? ?? []).isNotEmpty ? s['guardians'][0]['name'] : 'N/A')),
                                DataCell(StatusBadge.fromStatus(s['status'] ?? 'ACTIVE')),
                                DataCell(
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                    onPressed: () => _showStudentReportCard(s['id'], s['fullName']),
                                    child: const Text('Report Card', style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Administration', 'Curricula'],
            title: 'Classes, Sections & Subjects Configuration',
            subtitle: 'Academic divisions, room allocations, student capacity, and curriculum subject allocations.',
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_classes.isEmpty)
            const EmptyStateView(
              icon: Icons.account_tree_outlined,
              title: 'No Classes Configured',
              description: 'Configure standard grades and section allocations for this institution.',
            )
          else
            ..._classes.map((c) {
              final sections = c['sections'] as List? ?? [];
              final subjects = c['classSubjects'] as List? ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
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
                            const Icon(Icons.class_outlined, color: AppColors.primary, size: 22),
                            const SizedBox(width: AppSpacing.sm),
                            Text(c['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(width: AppSpacing.sm),
                            StatusBadge(label: 'Code: ${c['code']}', variant: BadgeVariant.neutral),
                          ],
                        ),
                        Text('${sections.length} Active Sections', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.borderLight),
                    Text('Sections & Classrooms:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.sm,
                      children: sections.map((sec) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('${sec['name']} (${sec['room'] ?? 'No Room'})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(width: 6),
                              Text('• Cap: ${sec['capacity']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Curriculum Subjects:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: subjects.map((sub) {
                        return StatusBadge(
                          label: sub['subject']?['name'] ?? 'Subject',
                          variant: BadgeVariant.info,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildStaffTab() {
    final filteredStaff = _staffSearchQuery.isEmpty
        ? _staff
        : _staff.where((st) {
            final q = _staffSearchQuery.toLowerCase();
            final name = (st['fullName'] ?? '').toString().toLowerCase();
            final empNo = (st['employeeNo'] ?? '').toString().toLowerCase();
            final dept = (st['department'] ?? '').toString().toLowerCase();
            final desig = (st['designation'] ?? '').toString().toLowerCase();
            return name.contains(q) || empNo.contains(q) || dept.contains(q) || desig.contains(q);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Administration', 'Faculty Directory'],
            title: 'Faculty & Academic Staff',
            subtitle: 'Teaching personnel, designation hierarchy, departmental mapping, and classroom assignments.',
          ),
          const SizedBox(height: AppSpacing.lg),

          SearchFilterBar(
            searchHint: 'Search faculty by name, employee ID, designation, or department...',
            searchQuery: _staffSearchQuery,
            onSearchChanged: (val) => setState(() => _staffSearchQuery = val),
            totalCount: filteredStaff.length,
            countLabel: 'Educators on Record',
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: filteredStaff.isEmpty
                ? EmptyStateView(
                    icon: Icons.badge_outlined,
                    title: _staffSearchQuery.isNotEmpty ? 'No Matching Faculty' : 'No Faculty Records Found',
                    description: _staffSearchQuery.isNotEmpty
                        ? 'No faculty records match your search filter.'
                        : 'Onboard academic personnel into departments and classes.',
                    actionLabel: _staffSearchQuery.isNotEmpty ? 'Clear Search' : null,
                    onAction: _staffSearchQuery.isNotEmpty ? () => setState(() => _staffSearchQuery = '') : null,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: AppShadows.subtle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 320),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppColors.tableHeaderBg),
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 64,
                          horizontalMargin: AppSpacing.lg,
                          columnSpacing: AppSpacing.xl,
                          columns: const [
                            DataColumn(label: Text('Employee No', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Staff Name', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Work Email', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Class & Subject Allocations', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                          rows: filteredStaff.map((st) {
                            final assignments = st['assignments'] as List? ?? [];
                            return DataRow(
                              cells: [
                                DataCell(Text(st['employeeNo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                                DataCell(Text(st['fullName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(st['designation'] ?? '')),
                                DataCell(Text(st['department'] ?? '')),
                                DataCell(Text(st['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                                DataCell(
                                  Wrap(
                                    spacing: 4,
                                    children: assignments.map((a) {
                                      final isCT = a['isClassTeacher'] == true;
                                      return StatusBadge(
                                        label: '${a['className']} (${a['sectionName']})${isCT ? ' • Class Teacher' : ''}',
                                        variant: isCT ? BadgeVariant.warning : BadgeVariant.neutral,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeesTab() {
    final filteredInvoices = _invoices.where((inv) {
      final matchStatus = _selectedInvoiceStatusFilter == 'ALL' || inv['status'] == _selectedInvoiceStatusFilter;
      final q = _invoiceSearchQuery.toLowerCase().trim();
      final matchSearch = q.isEmpty ||
          (inv['studentName'] ?? '').toString().toLowerCase().contains(q) ||
          (inv['invoiceNo'] ?? '').toString().toLowerCase().contains(q) ||
          (inv['title'] ?? '').toString().toLowerCase().contains(q);
      return matchStatus && matchSearch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Administration', 'Fee Oversight'],
            title: 'Fee Demands & Invoices Oversight',
            subtitle: 'Institutional billing records, payment reconciliation, and receivable collections.',
            actions: [
              OutlinedButton.icon(
                onPressed: _loadAllData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SearchFilterBar(
            searchHint: 'Search by student name, invoice number, or fee title...',
            searchQuery: _invoiceSearchQuery,
            onSearchChanged: (val) => setState(() => _invoiceSearchQuery = val),
            totalCount: filteredInvoices.length,
            countLabel: 'Invoices Recorded',
            filters: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedInvoiceStatusFilter,
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'PAID', child: Text('Paid Only')),
                    DropdownMenuItem(value: 'PENDING', child: Text('Pending Only')),
                    DropdownMenuItem(value: 'OVERDUE', child: Text('Overdue Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedInvoiceStatusFilter = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: filteredInvoices.isEmpty
                ? EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: _invoiceSearchQuery.isNotEmpty ? 'No Matching Invoices' : 'No Invoices on Record',
                    description: 'No billing invoices match current filtering criteria.',
                    actionLabel: _invoiceSearchQuery.isNotEmpty ? 'Clear Filter' : null,
                    onAction: _invoiceSearchQuery.isNotEmpty ? () => setState(() => _invoiceSearchQuery = '') : null,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: AppShadows.subtle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 320),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppColors.tableHeaderBg),
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 64,
                          horizontalMargin: AppSpacing.lg,
                          columnSpacing: AppSpacing.xl,
                          columns: const [
                            DataColumn(label: Text('Invoice No', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Student', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Fee Title', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Paid Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Due Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                          rows: filteredInvoices.map((inv) {
                            final status = (inv['status'] ?? 'PENDING').toString();
                            final isPaid = status == 'PAID';
                            return DataRow(
                              cells: [
                                DataCell(Text(inv['invoiceNo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                                DataCell(Text(inv['studentName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(inv['title'] ?? '')),
                                DataCell(Text('₹${inv['amount']}')),
                                DataCell(Text('₹${inv['paidAmount']}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
                                DataCell(Text('₹${inv['dueAmount']}', style: TextStyle(color: isPaid ? AppColors.textSecondary : AppColors.error, fontWeight: FontWeight.bold))),
                                DataCell(StatusBadge.fromStatus(status)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
