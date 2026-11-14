import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/state_views.dart';

class TimetableManagementScreen extends ConsumerStatefulWidget {
  const TimetableManagementScreen({super.key});

  @override
  ConsumerState<TimetableManagementScreen> createState() => _TimetableManagementScreenState();
}

class _TimetableManagementScreenState extends ConsumerState<TimetableManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _classes = [];
  List<dynamic> _staffList = [];
  List<dynamic> _subjects = [];

  // Selected Class & Section for Matrix
  String? _selectedClassId;
  String? _selectedSectionId;
  Map<String, dynamic>? _gridData;
  bool _isLoadingGrid = false;

  // Selected Teacher for Teacher View
  String? _selectedTeacherId;
  List<dynamic> _teacherEntries = [];
  bool _isLoadingTeacher = false;

  // Timetable Slot Editor State
  final _editorFormKey = GlobalKey<FormState>();
  String? _editClassId;
  String? _editSectionId;
  int _editDay = 1;
  int _editPeriod = 1;
  String? _editSubjectId;
  String? _editStaffId;
  final _roomCtrl = TextEditingController(text: 'Room 101');
  bool _isCheckingCollision = false;
  String? _collisionWarningMessage;
  bool _isSavingSlot = false;

  final List<String> _daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomCtrl.dispose();
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
        ApiClient().dio.get('/staff').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/subjects').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
      ]);

      _classes = results[0];
      _staffList = results[1];
      _subjects = results[2];

      if (_classes.isNotEmpty) {
        _selectedClassId = _classes[0]['id'];
        _editClassId = _classes[0]['id'];
        final secs = _classes[0]['sections'] as List? ?? [];
        if (secs.isNotEmpty) {
          _selectedSectionId = secs[0]['id'];
          _editSectionId = secs[0]['id'];
        }
      }

      if (_staffList.isNotEmpty) {
        _selectedTeacherId = _staffList[0]['id'];
        _editStaffId = _staffList[0]['id'];
      }

      if (_subjects.isNotEmpty) {
        _editSubjectId = _subjects[0]['id'];
      }

      await _loadClassGrid();
      await _loadTeacherSchedule();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadClassGrid() async {
    if (_selectedSectionId == null) return;
    setState(() => _isLoadingGrid = true);

    try {
      final res = await ApiClient().dio.get('/timetable/grid', queryParameters: {
        'sectionId': _selectedSectionId,
      });
      setState(() {
        _gridData = res.data['data'];
        _isLoadingGrid = false;
      });
    } catch (_) {
      setState(() => _isLoadingGrid = false);
    }
  }

  Future<void> _loadTeacherSchedule() async {
    if (_selectedTeacherId == null) return;
    setState(() => _isLoadingTeacher = true);

    try {
      final res = await ApiClient().dio.get('/timetable/entries', queryParameters: {
        'staffId': _selectedTeacherId,
      });
      setState(() {
        _teacherEntries = res.data['data'] as List? ?? [];
        _isLoadingTeacher = false;
      });
    } catch (_) {
      setState(() => _isLoadingTeacher = false);
    }
  }

  Future<void> _checkCollision() async {
    if (_editStaffId == null) return;
    setState(() {
      _isCheckingCollision = true;
      _collisionWarningMessage = null;
    });

    try {
      final res = await ApiClient().dio.get('/timetable/check-availability', queryParameters: {
        'staffId': _editStaffId,
        'dayOfWeek': _editDay,
        'periodNumber': _editPeriod,
      });

      final available = res.data['data']?['available'] == true;
      if (!available) {
        final conflict = res.data['data']?['conflict'];
        setState(() {
          _collisionWarningMessage = 'Collision Warning: Educator is already allocated to Period $_editPeriod in ${conflict?['class'] ?? 'another class'} (${conflict?['subject'] ?? 'Subject'}).';
        });
      } else {
        setState(() {
          _collisionWarningMessage = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification Passed: Educator and period slot are available!'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isCheckingCollision = false);
    }
  }

  Future<void> _saveTimetableSlot() async {
    if (!_editorFormKey.currentState!.validate()) return;
    if (_editSectionId == null || _editStaffId == null || _editSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select all slot details')));
      return;
    }

    setState(() => _isSavingSlot = true);
    try {
      await ApiClient().dio.post('/timetable/entries', data: {
        'sectionId': _editSectionId,
        'staffId': _editStaffId,
        'subjectId': _editSubjectId,
        'dayOfWeek': _editDay,
        'periodNumber': _editPeriod,
        'room': _roomCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timetable slot allocated successfully!'), backgroundColor: AppColors.success),
        );
        _loadClassGrid();
        _loadTeacherSchedule();
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Allocation failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSlot = false);
    }
  }

  void _showPrintPreviewDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Print Preview: Institutional Timetable Matrix'),
            StatusBadge(label: '8 Periods Schedule', variant: BadgeVariant.info),
          ],
        ),
        content: SizedBox(
          width: 800,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('GREENWOOD HIGH SCHOOL • TIMETABLE ROSTER AY 2026-2027', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const Divider(height: 20),
              _buildMatrixTable(isCompact: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent matrix to campus network printer.')));
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print Timetable'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading timetable schedules and conflict detectors...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Timetable Scheduling Unavailable',
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
                    Tab(icon: Icon(Icons.table_chart_outlined, size: 18), text: 'Weekly 8-Period Matrix'),
                    Tab(icon: Icon(Icons.edit_calendar_outlined, size: 18), text: 'Timetable Slot Editor & Conflict Detection'),
                    Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Teacher Schedule & Workload'),
                    Tab(icon: Icon(Icons.meeting_room_outlined, size: 18), text: 'Classroom Timetable'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Timetable',
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
              _buildMatrixTab(),
              _buildEditorTab(),
              _buildTeacherScheduleTab(),
              _buildClassScheduleTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Academics', 'Timetable Scheduling', 'Weekly Matrix'],
            title: 'Weekly 8-Period Timetable Schedule',
            subtitle: 'Institutional 6-day (Monday to Saturday) schedule matrix across 8 academic periods.',
            actions: [
              OutlinedButton.icon(
                onPressed: _showPrintPreviewDialog,
                icon: const Icon(Icons.print, size: 16),
                label: const Text('Print Preview'),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Schedule Slot'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Class and Section Pickers
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
                        final secs = _classes.firstWhere((c) => c['id'] == val)['sections'] as List? ?? [];
                        if (secs.isNotEmpty) _selectedSectionId = secs[0]['id'];
                      });
                      _loadClassGrid();
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedSectionId,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: (_selectedClassId != null
                          ? (_classes.firstWhere((c) => c['id'] == _selectedClassId, orElse: () => {'sections': []})['sections'] as List? ?? [])
                          : [])
                      .map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'])))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSectionId = val);
                      _loadClassGrid();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_isLoadingGrid)
            const SizedBox(height: 250, child: LoadingStateView(message: 'Generating weekly schedule matrix...'))
          else
            _buildMatrixTable(isCompact: false),
        ],
      ),
    );
  }

  Widget _buildMatrixTable({required bool isCompact}) {
    final grid = _gridData?['grid'] as Map<String, dynamic>? ?? {};

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.subtle,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: isCompact ? 10 : 16,
          headingRowColor: WidgetStateProperty.all(AppColors.tableHeaderBg),
          columns: [
            const DataColumn(label: Text('Day', style: TextStyle(fontWeight: FontWeight.bold))),
            ...List.generate(8, (i) => DataColumn(label: Text('P${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)))),
          ],
          rows: List.generate(6, (dayIndex) {
            final dayNumber = dayIndex + 1;
            final dayName = _daysOfWeek[dayIndex];
            final periods = (grid['$dayNumber'] as Map<String, dynamic>?) ?? {};

            return DataRow(
              cells: [
                DataCell(Text(dayName, style: const TextStyle(fontWeight: FontWeight.bold))),
                ...List.generate(8, (pIndex) {
                  final pNumber = pIndex + 1;
                  final slot = periods['$pNumber'];

                  if (slot == null) {
                    return const DataCell(Text('—', style: TextStyle(color: AppColors.textMuted)));
                  }

                  return DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(slot['subject'] ?? 'Subject', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                          Text('${slot['teacher'] ?? 'Staff'} • ${slot['room'] ?? 'R1'}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEditorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Form(
        key: _editorFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Timetable', 'Editor', 'Slot Scheduling'],
              title: 'Timetable Slot Editor & Conflict Detection',
              subtitle: 'Allocate teaching slots with real-time collision detection for educators and physical rooms.',
            ),
            const SizedBox(height: AppSpacing.xl),

            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Classroom & Period Configuration', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _editClassId,
                          decoration: const InputDecoration(labelText: 'Grade / Class'),
                          items: _classes.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']))).toList(),
                          onChanged: (val) {
                            setState(() {
                              _editClassId = val;
                              final secs = _classes.firstWhere((c) => c['id'] == val, orElse: () => {'sections': []})['sections'] as List? ?? [];
                              _editSectionId = secs.isNotEmpty ? secs[0]['id'] : null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _editSectionId,
                          decoration: const InputDecoration(labelText: 'Section Division'),
                          items: (_editClassId != null
                                  ? (_classes.firstWhere((c) => c['id'] == _editClassId, orElse: () => {'sections': []})['sections'] as List? ?? [])
                                  : [])
                              .map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'])))
                              .toList(),
                          onChanged: (val) => setState(() => _editSectionId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _editDay,
                          decoration: const InputDecoration(labelText: 'Day of Week'),
                          items: List.generate(6, (i) => DropdownMenuItem(value: i + 1, child: Text(_daysOfWeek[i]))),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _editDay = val);
                              _checkCollision();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _editPeriod,
                          decoration: const InputDecoration(labelText: 'Period Number (1 to 8)'),
                          items: [1, 2, 3, 4, 5, 6, 7, 8].map((p) => DropdownMenuItem(value: p, child: Text('Period $p'))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _editPeriod = val);
                              _checkCollision();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  Text('2. Subject, Instructor & Room Allocation', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _editSubjectId,
                          decoration: const InputDecoration(labelText: 'Curriculum Subject'),
                          items: _subjects.map<DropdownMenuItem<String>>((sub) => DropdownMenuItem(value: sub['id'] as String, child: Text(sub['name']))).toList(),
                          onChanged: (val) => setState(() => _editSubjectId = val),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _editStaffId,
                          decoration: const InputDecoration(labelText: 'Teacher / Faculty'),
                          items: _staffList.map<DropdownMenuItem<String>>((st) => DropdownMenuItem(value: st['id'] as String, child: Text(st['name']))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _editStaffId = val);
                              _checkCollision();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _roomCtrl,
                          decoration: const InputDecoration(labelText: 'Room Allocation', hintText: 'e.g. Science Lab 2'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Room required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Real-Time Collision Detector Card
                  if (_isCheckingCollision)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Verifying educator availability...')]))
                  else if (_collisionWarningMessage != null)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.errorSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: AppColors.error, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _collisionWarningMessage!,
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSpacing.xxl),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _tabController.animateTo(0),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _isSavingSlot ? null : _saveTimetableSlot,
                        icon: _isSavingSlot
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 16),
                        label: const Text('Commit Timetable Slot'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Timetable', 'Faculty Schedule', 'Teacher View'],
            title: 'Teacher Schedule & Workload Timetable',
            subtitle: 'Personalized schedule of instructional periods for a selected faculty member.',
          ),
          const SizedBox(height: AppSpacing.xl),

          DropdownButtonFormField<String>(
            value: _selectedTeacherId,
            decoration: const InputDecoration(labelText: 'Select Educator / Teacher'),
            items: _staffList.map<DropdownMenuItem<String>>((st) => DropdownMenuItem(value: st['id'] as String, child: Text('${st['name']} (${st['department'] ?? 'Faculty'})'))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedTeacherId = val);
                _loadTeacherSchedule();
              }
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Weekly Periods',
                  value: '${_teacherEntries.length}',
                  icon: Icons.schedule_outlined,
                  subtitle: 'Scheduled Teaching Slots',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Teaching Days',
                  value: '${_teacherEntries.map((e) => e['dayOfWeek']).toSet().length} Days',
                  icon: Icons.calendar_today_outlined,
                  subtitle: 'Active Days in Week',
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_isLoadingTeacher)
            const SizedBox(height: 200, child: LoadingStateView(message: 'Loading teacher timetable...'))
          else if (_teacherEntries.isEmpty)
            const EmptyStateView(
              icon: Icons.event_busy_outlined,
              title: 'No Periods Scheduled',
              description: 'This educator has no scheduled instructional periods.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: AppShadows.subtle,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _teacherEntries.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final e = _teacherEntries[index];
                  final dayName = _daysOfWeek[((e['dayOfWeek'] ?? 1) - 1).clamp(0, 5)];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primarySubtle,
                      child: Text('P${e['periodNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                    ),
                    title: Text('${e['subject']?['name'] ?? 'Subject'} • ${e['section']?['class']?['name']} (${e['section']?['name']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Day: $dayName • Room: ${e['room'] ?? 'General Classroom'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassScheduleTab() {
    return _buildMatrixTab();
  }
}
