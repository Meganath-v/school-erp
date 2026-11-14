import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/state_views.dart';

class ExaminationManagementScreen extends ConsumerStatefulWidget {
  const ExaminationManagementScreen({super.key});

  @override
  ConsumerState<ExaminationManagementScreen> createState() => _ExaminationManagementScreenState();
}

class _ExaminationManagementScreenState extends ConsumerState<ExaminationManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _exams = [];
  List<dynamic> _classes = [];
  List<dynamic> _subjects = [];

  // Selected Exam & Subject for Marks Entry
  dynamic _selectedExam;
  dynamic _selectedExamSubject;
  List<dynamic> _marksRoster = [];
  final Map<String, TextEditingController> _marksInputs = {};
  bool _isLoadingMarks = false;
  bool _isSavingMarks = false;

  // Excel Import Wizard State
  final _excelImportTextCtrl = TextEditingController();
  List<Map<String, dynamic>> _parsedImportRows = [];

  // Broadsheet State
  Map<String, dynamic>? _broadsheetData;
  String? _broadsheetClassId;
  bool _isLoadingBroadsheet = false;

  // Exam Creation Form State
  final _examFormKey = GlobalKey<FormState>();
  final _examNameCtrl = TextEditingController();
  final _examDescCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();
  String _selectedTerm = 'FIRST_TERM';
  bool _isCreatingExam = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllExamData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _excelImportTextCtrl.dispose();
    _examNameCtrl.dispose();
    _examDescCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    for (final c in _marksInputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAllExamData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient().dio.get('/exams').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/classes').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/subjects').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
      ]);

      setState(() {
        _exams = results[0];
        _classes = results[1];
        _subjects = results[2];
        _isLoading = false;
      });

      if (_exams.isNotEmpty && _selectedExam == null) {
        _selectedExam = _exams[0];
        final subjects = _selectedExam['subjects'] as List? ?? [];
        if (subjects.isNotEmpty) {
          _selectExamSubject(subjects[0]);
        }
      }

      if (_classes.isNotEmpty && _broadsheetClassId == null) {
        _broadsheetClassId = _classes[0]['id'];
        _loadBroadsheet();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectExamSubject(dynamic examSubject) async {
    setState(() {
      _selectedExamSubject = examSubject;
      _isLoadingMarks = true;
      _parsedImportRows.clear();
      _excelImportTextCtrl.clear();
    });

    try {
      final res = await ApiClient().dio.get('/exams/subjects/${examSubject['id']}/details');
      final data = res.data['data'];
      final roster = data['roster'] as List? ?? [];

      for (final r in roster) {
        final sid = r['studentId'];
        if (!_marksInputs.containsKey(sid)) {
          _marksInputs[sid] = TextEditingController(text: r['marksObtained'] != null ? '${r['marksObtained']}' : '');
        } else {
          _marksInputs[sid]!.text = r['marksObtained'] != null ? '${r['marksObtained']}' : '';
        }
      }

      setState(() {
        _marksRoster = roster;
        _isLoadingMarks = false;
      });
    } catch (_) {
      setState(() => _isLoadingMarks = false);
    }
  }

  Future<void> _saveMarks() async {
    if (_selectedExamSubject == null) return;
    setState(() => _isSavingMarks = true);

    try {
      final marks = _marksRoster.map((r) {
        final sid = r['studentId'];
        final text = _marksInputs[sid]?.text.trim() ?? '';
        final val = double.tryParse(text);
        return {
          'studentId': sid,
          'marksObtained': val,
          'isAbsent': text.toUpperCase() == 'ABSENT' || text.toUpperCase() == 'AB',
        };
      }).toList();

      await ApiClient().dio.post('/exams/subjects/${_selectedExamSubject['id']}/marks', data: {
        'marks': marks,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marks recorded and GPA recalculations committed!'), backgroundColor: AppColors.success),
        );
        _selectExamSubject(_selectedExamSubject);
        _loadBroadsheet();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save marks: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSavingMarks = false);
    }
  }

  Future<void> _publishExam(String examId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Official Result Publication'),
        content: const Text('Publishing this examination series authorizes student broadsheets, generates final grades, and reveals marks on all Parent & Student Portals.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish Officially'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient().dio.post('/exams/$examId/publish');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Examination results successfully published!'), backgroundColor: AppColors.success),
          );
          _loadAllExamData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publication failed: $e'), backgroundColor: AppColors.error));
        }
      }
    }
  }

  Future<void> _loadBroadsheet() async {
    if (_selectedExam == null || _broadsheetClassId == null) return;
    setState(() => _isLoadingBroadsheet = true);

    try {
      final res = await ApiClient().dio.get('/exams/${_selectedExam['id']}/classes/$_broadsheetClassId/broadsheet');
      setState(() {
        _broadsheetData = res.data['data'];
        _isLoadingBroadsheet = false;
      });
    } catch (_) {
      setState(() => _isLoadingBroadsheet = false);
    }
  }

  void _validateExcelImportPreview() {
    final text = _excelImportTextCtrl.text.trim();
    if (text.isEmpty) return;

    final lines = text.split('\n');
    final List<Map<String, dynamic>> parsed = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'[,\t]'));
      if (parts.length >= 2) {
        final admNo = parts[0].trim();
        final marksStr = parts[1].trim();
        final marksVal = double.tryParse(marksStr);
        final maxMarks = (_selectedExamSubject?['maxMarks'] ?? 100) as num;

        final bool isValidNumber = marksVal != null && marksVal >= 0 && marksVal <= maxMarks;
        final bool isMatch = _marksRoster.any((r) => (r['admissionNo'] ?? '').toString().toLowerCase() == admNo.toLowerCase());

        parsed.add({
          'admissionNo': admNo,
          'marks': marksVal ?? 0,
          'isValid': isValidNumber && isMatch,
          'error': !isMatch
              ? 'Admission No not in section'
              : (!isValidNumber ? 'Marks out of range (0-$maxMarks)' : null),
        });
      }
    }

    setState(() {
      _parsedImportRows = parsed;
    });
  }

  Future<void> _commitExcelImport() async {
    if (_selectedExamSubject == null || _parsedImportRows.isEmpty) return;
    final validRows = _parsedImportRows.where((r) => r['isValid'] == true).toList();

    try {
      await ApiClient().dio.post('/exams/subjects/${_selectedExamSubject['id']}/import', data: {
        'rows': validRows.map((r) => {'admissionNo': r['admissionNo'], 'marks': r['marks']}).toList(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported ${validRows.length} marks!'), backgroundColor: AppColors.success),
        );
        _selectExamSubject(_selectedExamSubject);
        _loadBroadsheet();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import commit failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _submitExamCreation() async {
    if (!_examFormKey.currentState!.validate()) return;
    setState(() => _isCreatingExam = true);

    try {
      await ApiClient().dio.post('/exams', data: {
        'name': _examNameCtrl.text.trim(),
        'term': _selectedTerm,
        'academicYear': '2026-2027',
        'startDate': _startDateCtrl.text.trim().isNotEmpty ? _startDateCtrl.text.trim() : DateTime.now().toIso8601String().split('T')[0],
        'endDate': _endDateCtrl.text.trim().isNotEmpty ? _endDateCtrl.text.trim() : DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T')[0],
        'description': _examDescCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Examination series created successfully!'), backgroundColor: AppColors.success),
        );
        _examFormKey.currentState!.reset();
        _examNameCtrl.clear();
        _examDescCtrl.clear();
        _loadAllExamData();
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create exam: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isCreatingExam = false);
    }
  }

  void _showAddSubjectScheduleDialog(String examId) {
    String? selectedClassId = _classes.isNotEmpty ? _classes[0]['id'] : null;
    String? selectedSubId = _subjects.isNotEmpty ? _subjects[0]['id'] : null;
    final maxMarksCtrl = TextEditingController(text: '100');
    final passMarksCtrl = TextEditingController(text: '35');
    final dateCtrl = TextEditingController(text: DateTime.now().add(const Duration(days: 3)).toIso8601String().split('T')[0]);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Subject Schedule to Examination'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedClassId,
                  decoration: const InputDecoration(labelText: 'Grade / Class'),
                  items: _classes.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']))).toList(),
                  onChanged: (val) => setDialogState(() => selectedClassId = val),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: selectedSubId,
                  decoration: const InputDecoration(labelText: 'Curriculum Subject'),
                  items: _subjects.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))).toList(),
                  onChanged: (val) => setDialogState(() => selectedSubId = val),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: maxMarksCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Max Marks'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: passMarksCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Pass Marks'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(labelText: 'Examination Date (YYYY-MM-DD)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedClassId == null || selectedSubId == null) return;
                try {
                  await ApiClient().dio.post('/exams/$examId/subjects', data: {
                    'classId': selectedClassId,
                    'subjectId': selectedSubId,
                    'maxMarks': int.tryParse(maxMarksCtrl.text.trim()) ?? 100,
                    'passMarks': int.tryParse(passMarksCtrl.text.trim()) ?? 35,
                    'examDate': dateCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subject added to examination schedule!'), backgroundColor: AppColors.success));
                    _loadAllExamData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add subject: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              child: const Text('Add Subject'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading examination schedules and marks broadsheets...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Examinations Unavailable',
        message: _errorMessage,
        onRetry: _loadAllExamData,
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
                    Tab(icon: Icon(Icons.list_alt_outlined, size: 18), text: 'Exam Schedules & Publishing'),
                    Tab(icon: Icon(Icons.add_box_outlined, size: 18), text: 'Create Examination'),
                    Tab(icon: Icon(Icons.edit_note_outlined, size: 18), text: 'Marks Entry & Excel Wizard'),
                    Tab(icon: Icon(Icons.table_chart_outlined, size: 18), text: 'Class Broadsheet & Report Cards'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Exam Data',
                onPressed: _loadAllExamData,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildExamListTab(),
              _buildCreateExamTab(),
              _buildMarksEntryTab(),
              _buildBroadsheetTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExamListTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Academics', 'Examinations', 'Series List'],
            title: 'Examinations & Term Moderation',
            subtitle: 'Schedule institutional exam terms, configure subject schedules, enter marks, and publish broadsheets.',
            actions: [
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Schedule New Exam'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_exams.isEmpty)
            const EmptyStateView(
              icon: Icons.school_outlined,
              title: 'No Examinations Scheduled',
              description: 'Create an examination term to begin configuring subject schedules and entering grades.',
            )
          else
            ..._exams.map((ex) {
              final isPublished = ex['status'] == 'PUBLISHED';
              final subjects = ex['subjects'] as List? ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xl),
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
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isPublished ? AppColors.successSubtle : AppColors.primarySubtle,
                              child: Icon(Icons.school, color: isPublished ? AppColors.success : AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(ex['name'] ?? 'Term Exam', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(width: AppSpacing.sm),
                                    StatusBadge.fromStatus(ex['status'] ?? 'DRAFT'),
                                  ],
                                ),
                                Text('Term: ${ex['term']} • Academic Year: ${ex['academicYear'] ?? '2026-2027'} • Dates: ${ex['startDate']?.toString().split('T')[0]} to ${ex['endDate']?.toString().split('T')[0]}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showAddSubjectScheduleDialog(ex['id']),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Add Subject'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            if (!isPublished)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                onPressed: () => _publishExam(ex['id']),
                                icon: const Icon(Icons.publish, size: 14),
                                label: const Text('Publish Results'),
                              )
                            else
                              const StatusBadge(label: 'OFFICIALLY PUBLISHED', variant: BadgeVariant.success),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    Text('Scheduled Subject Tests (${subjects.length} Subjects)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.sm),

                    if (subjects.isEmpty)
                      const Text('No subjects added to this examination series yet. Click "Add Subject" above.')
                    else
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: subjects.map((sub) {
                          return ActionChip(
                            avatar: const Icon(Icons.menu_book, size: 16, color: AppColors.primary),
                            label: Text('${sub['subject']?['name'] ?? 'Subject'} (${sub['class']?['name'] ?? 'Class'}) • Max: ${sub['maxMarks']}'),
                            backgroundColor: AppColors.surfaceMuted,
                            onPressed: () {
                              setState(() => _selectedExam = ex);
                              _selectExamSubject(sub);
                              _tabController.animateTo(2);
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCreateExamTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Form(
        key: _examFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Academics', 'Examinations', 'Create Term'],
              title: 'Schedule New Examination Series',
              subtitle: 'Configure term evaluation series with commencement dates and grading configuration.',
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
                  TextFormField(
                    controller: _examNameCtrl,
                    decoration: const InputDecoration(labelText: 'Examination Title *', hintText: 'e.g. Mid-Term Summative Assessment 2026'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedTerm,
                          decoration: const InputDecoration(labelText: 'Academic Term'),
                          items: const [
                            DropdownMenuItem(value: 'FIRST_TERM', child: Text('Term 1 / Quarterly')),
                            DropdownMenuItem(value: 'MID_TERM', child: Text('Term 2 / Half-Yearly')),
                            DropdownMenuItem(value: 'FINAL_TERM', child: Text('Term 3 / Annual Final Exam')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedTerm = val);
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _startDateCtrl,
                          decoration: const InputDecoration(labelText: 'Commencement Date', hintText: '2026-10-15'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _endDateCtrl,
                          decoration: const InputDecoration(labelText: 'Conclusion Date', hintText: '2026-10-30'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _examDescCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Examination Guidelines & Instructions'),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isCreatingExam ? null : _submitExamCreation,
                      icon: _isCreatingExam
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 16),
                      label: const Text('Create Examination Series'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarksEntryTab() {
    if (_selectedExamSubject == null) {
      return const EmptyStateView(
        icon: Icons.grade_outlined,
        title: 'No Exam Subject Selected',
        description: 'Select an exam subject from the schedules tab to enter marks or import spreadsheets.',
      );
    }

    final maxMarks = (_selectedExamSubject['maxMarks'] ?? 100) as num;
    final passMarks = (_selectedExamSubject['passMarks'] ?? 35) as num;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Examinations', 'Gradebook', 'Marks Entry'],
            title: '${_selectedExamSubject['subject']?['name']} (${_selectedExamSubject['class']?['name']}) - ${_selectedExam?['name']}',
            subtitle: 'Max Marks: $maxMarks • Pass Marks: $passMarks • Enter marks or use the bulk spreadsheet import wizard below.',
            actions: [
              ElevatedButton.icon(
                onPressed: _isSavingMarks ? null : _saveMarks,
                icon: _isSavingMarks
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 16),
                label: const Text('Save Marks & Update GPA'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Two-Tab Section: Manual Entry vs Excel Wizard
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.edit, size: 16), text: 'Student Roster Mark Entry'),
                    Tab(icon: Icon(Icons.upload_file, size: 16), text: 'Excel / CSV Import Wizard & Preview'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 600,
                  child: TabBarView(
                    children: [
                      // Manual Table
                      _isLoadingMarks
                          ? const LoadingStateView(message: 'Loading student roster...')
                          : Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: ListView.separated(
                                itemCount: _marksRoster.length,
                                separatorBuilder: (ctx, i) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final r = _marksRoster[index];
                                  final sid = r['studentId'];
                                  final ctrl = _marksInputs[sid];

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppColors.primarySubtle,
                                          child: Text('${r['rollNo'] ?? index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(r['studentName'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              Text('Adm No: ${r['admissionNo']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 140,
                                          child: TextField(
                                            controller: ctrl,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'Marks (/$maxMarks)',
                                              hintText: 'or ABSENT',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                      // Excel Import Wizard & Preview
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Paste CSV / Spreadsheet Data (Format: AdmissionNo, Marks)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _excelImportTextCtrl,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'ADM-2026-001, 85\nADM-2026-002, 92\nADM-2026-003, 78',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _validateExcelImportPreview,
                                  icon: const Icon(Icons.rule, size: 16),
                                  label: const Text('Validate & Preview Rows'),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                if (_parsedImportRows.isNotEmpty)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                    onPressed: _commitExcelImport,
                                    icon: const Icon(Icons.file_upload, size: 16),
                                    label: Text('Commit ${_parsedImportRows.where((r) => r['isValid']).length} Valid Rows'),
                                  ),
                              ],
                            ),
                            const Divider(height: 24),

                            // Preview Table
                            Expanded(
                              child: _parsedImportRows.isEmpty
                                  ? const Center(child: Text('Paste spreadsheet rows above and click "Validate & Preview Rows"'))
                                  : ListView.separated(
                                      itemCount: _parsedImportRows.length,
                                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                                      itemBuilder: (ctx, i) {
                                        final row = _parsedImportRows[i];
                                        final bool isValid = row['isValid'] == true;

                                        return ListTile(
                                          leading: Icon(isValid ? Icons.check_circle : Icons.error, color: isValid ? AppColors.success : AppColors.error),
                                          title: Text('Admission: ${row['admissionNo']} • Marks: ${row['marks']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          subtitle: Text(isValid ? 'Validation passed: Ready for import' : 'Error: ${row['error']}', style: TextStyle(color: isValid ? AppColors.success : AppColors.error, fontSize: 12)),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadsheetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Examinations', 'Results', 'Broadsheet'],
            title: 'Consolidated Class Broadsheet & Rankings',
            subtitle: 'Multi-subject comparative ledger with cumulative totals, percentages, class ranks, and pass status.',
            actions: [
              OutlinedButton.icon(
                onPressed: _loadBroadsheet,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Broadsheet'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Filters Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedExam?['id'],
                  decoration: const InputDecoration(labelText: 'Select Examination Series'),
                  items: _exams.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name']))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedExam = _exams.firstWhere((e) => e['id'] == val));
                      _loadBroadsheet();
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _broadsheetClassId,
                  decoration: const InputDecoration(labelText: 'Select Class'),
                  items: _classes.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _broadsheetClassId = val);
                      _loadBroadsheet();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_isLoadingBroadsheet)
            const SizedBox(height: 200, child: LoadingStateView(message: 'Compiling broadsheet results...'))
          else if (_broadsheetData == null || (_broadsheetData!['broadsheet'] as List? ?? []).isEmpty)
            const EmptyStateView(
              icon: Icons.table_rows_outlined,
              title: 'No Broadsheet Data',
              description: 'No examination marks compiled for this class and examination series yet.',
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
                  headingRowColor: WidgetStateProperty.all(AppColors.tableHeaderBg),
                  columns: const [
                    DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Admission No', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Total Marks', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Result', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: (_broadsheetData!['broadsheet'] as List).map<DataRow>((b) {
                    final isPass = b['resultStatus'] == 'PASS';
                    return DataRow(
                      cells: [
                        DataCell(Text('#${b['rank'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(b['admissionNo'] ?? '—')),
                        DataCell(Text(b['fullName'] ?? 'Learner', style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text('${b['totalObtained']} / ${b['totalMax']}')),
                        DataCell(Text('${b['percentage']}%', style: TextStyle(fontWeight: FontWeight.bold, color: isPass ? AppColors.success : AppColors.error))),
                        DataCell(StatusBadge(label: b['resultStatus'] ?? 'PASS', variant: isPass ? BadgeVariant.success : BadgeVariant.error)),
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
}
