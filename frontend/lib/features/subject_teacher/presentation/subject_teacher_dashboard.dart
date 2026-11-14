import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class SubjectTeacherDashboard extends ConsumerStatefulWidget {
  const SubjectTeacherDashboard({super.key});

  @override
  ConsumerState<SubjectTeacherDashboard> createState() => _SubjectTeacherDashboardState();
}

class _SubjectTeacherDashboardState extends ConsumerState<SubjectTeacherDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _timetable = [];
  List<dynamic> _assignments = [];
  List<dynamic> _exams = [];

  Map<String, dynamic>? _syllabusData;
  List<dynamic> _teachingDiaries = [];
  List<dynamic> _courseMaterials = [];

  List<dynamic> _classes = [];
  List<dynamic> _subjects = [];
  List<dynamic> _staffList = [];
  String _homeworkSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
        ApiClient().dio.get('/timetable/entries').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/assignments').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/exams').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/academics/lesson-plans').then((r) => r.data['data'] as Map<String, dynamic>?).catchError((_) => null),
        ApiClient().dio.get('/academics/teaching-diaries').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/academics/course-materials').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/classes').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/subjects').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/staff').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
      ]);

      setState(() {
        _timetable = results[0] as List<dynamic>;
        _assignments = results[1] as List<dynamic>;
        _exams = results[2] as List<dynamic>;
        _syllabusData = results[3] as Map<String, dynamic>?;
        _teachingDiaries = results[4] as List<dynamic>;
        _courseMaterials = results[5] as List<dynamic>;
        _classes = results[6] as List<dynamic>;
        _subjects = results[7] as List<dynamic>;
        _staffList = results[8] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showNewTeachingDiaryDialog() {
    if (_classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active classes found for diary logging')));
      return;
    }

    final topicCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String methodology = 'LECTURE';
    int periodNumber = 1;
    String selectedClassId = _classes[0]['id'];
    List<dynamic> sections = _classes[0]['sections'] as List? ?? [];
    String? selectedSectionId = sections.isNotEmpty ? sections[0]['id'] : null;
    String? selectedSubjectId = _subjects.isNotEmpty ? _subjects[0]['id'] : null;
    String? selectedStaffId = _staffList.isNotEmpty ? _staffList[0]['id'] : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final curClass = _classes.firstWhere((c) => c['id'] == selectedClassId, orElse: () => _classes[0]);
          final curSections = curClass['sections'] as List? ?? [];

          return AlertDialog(
            title: const Text('Log Teaching Diary Entry'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedClassId,
                            decoration: const InputDecoration(labelText: 'Class'),
                            items: _classes.map<DropdownMenuItem<String>>((c) {
                              return DropdownMenuItem(value: c['id'] as String, child: Text(c['name']));
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setDialogState(() {
                                selectedClassId = val;
                                final c = _classes.firstWhere((item) => item['id'] == val, orElse: () => _classes[0]);
                                final secs = c['sections'] as List? ?? [];
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
                            items: curSections.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedSectionId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSubjectId,
                            decoration: const InputDecoration(labelText: 'Subject'),
                            items: _subjects.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedSubjectId = val),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: periodNumber,
                            decoration: const InputDecoration(labelText: 'Period'),
                            items: [1, 2, 3, 4, 5, 6, 7, 8].map((p) => DropdownMenuItem(value: p, child: Text('Period $p'))).toList(),
                            onChanged: (val) => setDialogState(() => periodNumber = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: methodology,
                      decoration: const InputDecoration(labelText: 'Teaching Methodology'),
                      items: const [
                        DropdownMenuItem(value: 'LECTURE', child: Text('Classroom Interactive Lecture')),
                        DropdownMenuItem(value: 'LAB', child: Text('Laboratory Practical Demonstration')),
                        DropdownMenuItem(value: 'GROUP_DISCUSSION', child: Text('Peer Group Discussion & Problem Solving')),
                        DropdownMenuItem(value: 'FLIPPED_CLASS', child: Text('Flipped Classroom Guided Inquiry')),
                      ],
                      onChanged: (val) => setDialogState(() => methodology = val!),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: topicCtrl,
                      decoration: const InputDecoration(labelText: 'Topic & Concepts Covered', hintText: 'e.g. Quadratic Roots derivation and graph mapping'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: remarksCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Faculty Remarks / Homework Given', hintText: 'Problem set 1 to 5 assigned'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (topicCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter topic covered')));
                    return;
                  }
                  if (selectedSectionId == null || selectedSubjectId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select valid section and subject')));
                    return;
                  }
                  try {
                    await ApiClient().dio.post('/academics/teaching-diaries', data: {
                      'classId': selectedClassId,
                      'sectionId': selectedSectionId,
                      'subjectId': selectedSubjectId,
                      if (selectedStaffId != null) 'teacherId': selectedStaffId,
                      'periodNumber': periodNumber,
                      'topicTaught': topicCtrl.text.trim(),
                      'methodology': methodology,
                      'remarks': remarksCtrl.text.trim(),
                    });

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Course Diary entry logged successfully!'), backgroundColor: AppColors.success),
                      );
                      _loadTeacherData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save diary entry: $e'), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: const Text('Save to Course Log'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showAddMaterialDialog() {
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No subjects found')));
      return;
    }

    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://docs.erp.com/notes.pdf');
    int unitNumber = 1;
    String fileType = 'PDF';
    String selectedSubjectId = _subjects[0]['id'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Publish Course Study Resource'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedSubjectId,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      items: _subjects.map<DropdownMenuItem<String>>((s) {
                        return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedSubjectId = val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Resource Title', hintText: 'e.g. Unit 2 Comprehensive Summary')),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: unitNumber,
                            decoration: const InputDecoration(labelText: 'Curriculum Unit'),
                            items: [1, 2, 3, 4, 5, 6].map((u) => DropdownMenuItem(value: u, child: Text('Unit $u'))).toList(),
                            onChanged: (val) => setDialogState(() => unitNumber = val!),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: fileType,
                            decoration: const InputDecoration(labelText: 'Document Format'),
                            items: const [
                              DropdownMenuItem(value: 'PDF', child: Text('PDF Document')),
                              DropdownMenuItem(value: 'SLIDES', child: Text('PowerPoint Deck')),
                              DropdownMenuItem(value: 'DOC', child: Text('Word Document')),
                            ],
                            onChanged: (val) => setDialogState(() => fileType = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Download Link / File URL')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  try {
                    await ApiClient().dio.post('/academics/course-materials', data: {
                      'subjectId': selectedSubjectId,
                      'title': titleCtrl.text.trim(),
                      'unitNumber': unitNumber,
                      'fileType': fileType,
                      'fileUrl': urlCtrl.text.trim(),
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Study material shared with enrolled students!'), backgroundColor: AppColors.success),
                      );
                      _loadTeacherData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to publish material: $e'), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: const Text('Publish Resource'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showNewAssignmentDialog() {
    if (_classes.isEmpty || _subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Classes or subjects not loaded')));
      return;
    }

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final marksCtrl = TextEditingController(text: '100');
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 7));
    String selectedClassId = _classes[0]['id'];
    List<dynamic> sections = _classes[0]['sections'] as List? ?? [];
    String? selectedSectionId = sections.isNotEmpty ? sections[0]['id'] : null;
    String selectedSubjectId = _subjects[0]['id'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final curClass = _classes.firstWhere((c) => c['id'] == selectedClassId, orElse: () => _classes[0]);
          final curSections = curClass['sections'] as List? ?? [];

          return AlertDialog(
            title: const Text('Create Classroom Homework Assignment'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Assignment Title', hintText: 'e.g. Chapter 4 Practice Problems')),
                    const SizedBox(height: AppSpacing.md),
                    TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Instructions / Assignment Brief')),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedClassId,
                            decoration: const InputDecoration(labelText: 'Class'),
                            items: _classes.map<DropdownMenuItem<String>>((c) {
                              return DropdownMenuItem(value: c['id'] as String, child: Text(c['name']));
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setDialogState(() {
                                selectedClassId = val;
                                final c = _classes.firstWhere((item) => item['id'] == val, orElse: () => _classes[0]);
                                final secs = c['sections'] as List? ?? [];
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
                            items: curSections.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedSectionId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSubjectId,
                            decoration: const InputDecoration(labelText: 'Subject'),
                            items: _subjects.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedSubjectId = val);
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: marksCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Max Marks'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Submission Deadline: ${selectedDueDate.toLocal().toString().split(' ')[0]}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: const Text('Change Date'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDueDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 180)),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDueDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter assignment title')));
                    return;
                  }
                  try {
                    await ApiClient().dio.post('/assignments', data: {
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'classId': selectedClassId,
                      'sectionId': selectedSectionId,
                      'subjectId': selectedSubjectId,
                      'dueDate': selectedDueDate.toIso8601String(),
                      'maxMarks': int.tryParse(marksCtrl.text.trim()) ?? 100,
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Assignment dispatched to student portal!'), backgroundColor: AppColors.success),
                      );
                      _loadTeacherData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to publish assignment: $e'), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: const Text('Dispatch Assignment'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _deleteAssignment(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: const Text('Are you sure you want to permanently remove this assignment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient().dio.delete('/assignments/$id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment deleted successfully'), backgroundColor: AppColors.success),
          );
          _loadTeacherData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete assignment: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _logLessonProgress(dynamic plan) async {
    final newHours = (plan['conductedHours'] as int) + 1;
    final isDone = newHours >= (plan['plannedHours'] as int);

    try {
      await ApiClient().dio.patch('/academics/lesson-plans/${plan['id']}/progress', data: {
        'conductedHours': newHours,
        'status': isDone ? 'COMPLETED' : 'IN_PROGRESS',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged +1 hr for ${plan['unitTitle']} ($newHours/${plan['plannedHours']} hrs)')),
        );
        _loadTeacherData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update progress: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading academic teaching diary, curriculum tracker, and schedule...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Academic Records Unavailable',
        message: _errorMessage,
        onRetry: _loadTeacherData,
      );
    }

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
                    Tab(icon: Icon(Icons.track_changes_outlined, size: 18), text: 'OBE Course Plan & Syllabus'),
                    Tab(icon: Icon(Icons.book_outlined, size: 18), text: 'Faculty Teaching Diary'),
                    Tab(icon: Icon(Icons.folder_shared_outlined, size: 18), text: 'Course Study Repository'),
                    Tab(icon: Icon(Icons.schedule_outlined, size: 18), text: 'Weekly Timetable'),
                    Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'Homework & Assignments'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Academic Data',
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
              _buildSyllabusTab(),
              _buildTeachingDiaryTab(),
              _buildCourseRepositoryTab(),
              _buildTimetableView(),
              _buildHomeworkView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyllabusTab() {
    final plans = _syllabusData?['plans'] as List? ?? [];
    final coverage = _syllabusData?['overallSyllabusCoverage'] ?? 0;
    final planned = _syllabusData?['totalPlannedHours'] ?? 0;
    final conducted = _syllabusData?['totalConductedHours'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadTeacherData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Academics', 'Faculty Dashboard', 'Subject Educator'],
              title: 'Subject Teacher Academic Dashboard',
              subtitle: 'Track assigned subjects, classroom periods, OBE lesson delivery, and student submissions.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _loadTeacherData,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: _showNewTeachingDiaryDialog,
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Log Diary Entry'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Assigned Subjects & Classes Badges
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Chip(
                  avatar: const Icon(Icons.menu_book, size: 16, color: AppColors.primary),
                  label: Text(
                    'Assigned Subjects: ${_subjects.map((s) => s['name']).join(', ')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppColors.primarySubtle,
                ),
                Chip(
                  avatar: const Icon(Icons.meeting_room, size: 16, color: AppColors.secondary),
                  label: Text(
                    'Assigned Classes: ${_classes.map((c) => c['name']).join(', ')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppColors.secondarySubtle,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 8 Subject Teacher Metrics
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1000;
                final todayPeriods = _timetable.where((t) => t['dayOfWeek'] == DateTime.now().weekday).length;
                final pendingMarks = _exams.where((e) => e['status'] == 'DRAFT').length;
                final upcomingDeadlines = _assignments.where((a) => a['dueDate'] != null).length;

                final cards = [
                  MetricCard(
                    title: "Today's Timetable",
                    value: '$todayPeriods Periods',
                    icon: Icons.schedule_outlined,
                    subtitle: 'Today • Classroom Sessions',
                    color: AppColors.primary,
                    onTap: () => _tabController.animateTo(3),
                  ),
                  MetricCard(
                    title: 'Pending Mark Entry',
                    value: '$pendingMarks Exams',
                    icon: Icons.grade_outlined,
                    subtitle: 'Awaiting Marks Entry',
                    color: pendingMarks > 0 ? AppColors.warning : AppColors.success,
                    onTap: () => _tabController.animateTo(4),
                  ),
                  MetricCard(
                    title: 'Assignment Evaluation',
                    value: '${_assignments.length} Tasks',
                    icon: Icons.assignment_turned_in_outlined,
                    subtitle: 'Student Homework Track',
                    color: AppColors.info,
                    onTap: () => _tabController.animateTo(4),
                  ),
                  MetricCard(
                    title: 'Syllabus Completion',
                    value: '$coverage%',
                    icon: Icons.track_changes_outlined,
                    subtitle: '$conducted / $planned Hours Done',
                    color: coverage >= 75 ? AppColors.success : AppColors.accent,
                    onTap: () => _tabController.animateTo(0),
                  ),
                  MetricCard(
                    title: 'Teaching Diary Status',
                    value: '${_teachingDiaries.length} Logs',
                    icon: Icons.book_outlined,
                    subtitle: 'Logged Instructional Hours',
                    color: AppColors.success,
                    onTap: () => _tabController.animateTo(1),
                  ),
                  MetricCard(
                    title: 'Upcoming Deadlines',
                    value: '$upcomingDeadlines Due',
                    icon: Icons.alarm_outlined,
                    subtitle: 'Pending Submissions',
                    color: AppColors.error,
                    onTap: () => _tabController.animateTo(4),
                  ),
                  MetricCard(
                    title: 'Assigned Subjects',
                    value: '${_subjects.length} Subjects',
                    icon: Icons.auto_stories_outlined,
                    subtitle: 'Academic Allocations',
                    color: AppColors.secondary,
                  ),
                  MetricCard(
                    title: 'Assigned Classes',
                    value: '${_classes.length} Classes',
                    icon: Icons.groups_outlined,
                    subtitle: 'Enrolled Cohorts',
                    color: AppColors.accent,
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
            const SizedBox(height: AppSpacing.xl),

            // Syllabus Coverage Metric Card
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
                          const Icon(Icons.auto_graph, color: AppColors.primary, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Curriculum Syllabus Fulfillment', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      StatusBadge(
                        label: '$coverage% Completed',
                        variant: (coverage as num) >= 80 ? BadgeVariant.success : BadgeVariant.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: LinearProgressIndicator(
                      value: ((coverage) / 100).toDouble().clamp(0.0, 1.0),
                      minHeight: 12,
                      backgroundColor: AppColors.surfaceMuted,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('$conducted of $planned Planned Teaching Hours Delivered', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            if (plans.isEmpty)
              const EmptyStateView(
                icon: Icons.track_changes_outlined,
                title: 'No OBE Lesson Plans Uploaded',
                description: 'Course syllabus outcome models will appear here once defined for your subjects.',
              )
            else
              ...plans.map((p) {
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: AppShadows.subtle,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              StatusBadge(label: 'Unit ${p['unitNumber']}', variant: BadgeVariant.info),
                              const SizedBox(width: AppSpacing.md),
                              Text(p['unitTitle'] ?? 'Unit Title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          StatusBadge.fromStatus(p['status'] ?? 'PENDING'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Topic: ${p['topic'] ?? 'General'}', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                      if (p['learningObjectives'] != null) ...[
                        const SizedBox(height: 4),
                        Text('Course Outcome: ${p['learningObjectives']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                      const Divider(height: 24, color: AppColors.borderLight),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Instructional Hours: ${p['conductedHours']} / ${p['plannedHours']} hrs (${p['coveragePercent']}%)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8)),
                            onPressed: () => _logLessonProgress(p),
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Log +1 Teaching Hour', style: TextStyle(fontSize: 12)),
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

  Widget _buildTeachingDiaryTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Academics', 'Faculty Diary'],
            title: 'Faculty Teaching Diary & Course Log',
            subtitle: 'Formal institutional record of syllabus topics delivered per classroom period.',
            actions: [
              ElevatedButton.icon(
                onPressed: _showNewTeachingDiaryDialog,
                icon: const Icon(Icons.post_add, size: 16),
                label: const Text('Log Diary Entry'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: _teachingDiaries.isEmpty
                ? EmptyStateView(
                    icon: Icons.book_outlined,
                    title: 'No Teaching Diary Entries Logged',
                    description: 'Log your delivered classroom periods and topics using the action above.',
                    actionLabel: 'Log First Lecture Entry',
                    onAction: _showNewTeachingDiaryDialog,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: AppShadows.subtle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: _teachingDiaries.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (context, index) {
                        final d = _teachingDiaries[index];
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                                decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                child: Column(
                                  children: [
                                    Text('P${d['periodNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
                                    Text('${d['date']?.toString().split('T')[0]}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('${d['subjectName']} • ${d['className']} (${d['sectionName']})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(width: AppSpacing.sm),
                                        StatusBadge(label: d['methodology'] ?? 'LECTURE', variant: BadgeVariant.neutral),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(d['topicTaught'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                    if (d['remarks'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text('Remarks: ${d['remarks']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ],
                                ),
                              ),
                              Text('By: ${d['teacherName'] ?? 'Faculty'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseRepositoryTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Academics', 'Repository'],
            title: 'Course Study Materials & Question Bank',
            subtitle: 'Structured digital syllabus notes, presentations, and revision documents available to learners.',
            actions: [
              ElevatedButton.icon(
                onPressed: _showAddMaterialDialog,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Publish Resource'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: _courseMaterials.isEmpty
                ? EmptyStateView(
                    icon: Icons.folder_shared_outlined,
                    title: 'No Course Materials Uploaded',
                    description: 'Publish lecture notes, question banks, or slides for your enrolled classes.',
                    actionLabel: 'Publish First Resource',
                    onAction: _showAddMaterialDialog,
                  )
                : ListView.builder(
                    itemCount: _courseMaterials.length,
                    itemBuilder: (context, index) {
                      final mat = _courseMaterials[index];
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
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.secondarySubtle,
                              child: Icon(mat['fileType'] == 'SLIDES' ? Icons.slideshow : Icons.picture_as_pdf, color: AppColors.secondary, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mat['title'] ?? 'Material', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text('${mat['subjectName'] ?? 'General'} • Unit ${mat['unitNumber']} • Format: ${mat['fileType']}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text('Uploaded by: ${mat['uploadedBy']} on ${mat['createdAt']?.toString().split('T')[0]}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening resource: ${mat['fileUrl']}')));
                              },
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Download'),
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

  Widget _buildTimetableView() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Academics', 'Faculty Schedule'],
            title: 'Weekly 8-Period Instructional Schedule',
            subtitle: 'Official timetable matrix of allocated classroom lectures, laboratory sessions, and room numbers.',
            actions: [
              OutlinedButton.icon(
                onPressed: _loadTeacherData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Timetable'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: _timetable.isEmpty
                ? const EmptyStateView(
                    icon: Icons.schedule_outlined,
                    title: 'No Timetable Periods Allocated',
                    description: 'Your weekly teaching periods have not been assigned in the institutional master schedule.',
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: AppShadows.subtle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: _timetable.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (context, index) {
                        final t = _timetable[index];
                        final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                        final day = (t['dayOfWeek'] is int && t['dayOfWeek'] < dayNames.length) ? dayNames[t['dayOfWeek']] : 'Day ${t['dayOfWeek']}';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(AppRadius.sm)),
                            child: Text('P${t['periodNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                          title: Text('${t['subjectName']} • ${t['className']} (${t['sectionName']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$day • ${t['startTime']} - ${t['endTime']} • Room: ${t['room'] ?? 'General'}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          trailing: StatusBadge(label: 'Period ${t['periodNumber']}', variant: BadgeVariant.neutral),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkView() {
    final filtered = _homeworkSearchQuery.isEmpty
        ? _assignments
        : _assignments.where((hw) {
            final q = _homeworkSearchQuery.toLowerCase();
            final title = (hw['title'] ?? '').toString().toLowerCase();
            final sub = (hw['subjectName'] ?? '').toString().toLowerCase();
            return title.contains(q) || sub.contains(q);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Academics', 'Assignments'],
            title: 'Homework & Assignments Roster',
            subtitle: 'Dispatch assignments, monitor student submissions, and grade submissions.',
            actions: [
              ElevatedButton.icon(
                onPressed: _showNewAssignmentDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Assignment'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SearchFilterBar(
            searchHint: 'Search assignments by title or subject...',
            searchQuery: _homeworkSearchQuery,
            onSearchChanged: (val) => setState(() => _homeworkSearchQuery = val),
            totalCount: filtered.length,
            countLabel: 'Assignments Active',
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: filtered.isEmpty
                ? EmptyStateView(
                    icon: Icons.assignment_outlined,
                    title: _homeworkSearchQuery.isNotEmpty ? 'No Matching Assignments' : 'No Assignments Published',
                    description: _homeworkSearchQuery.isNotEmpty ? 'No assignments match "$_homeworkSearchQuery".' : 'Create and assign coursework to students using the button above.',
                    actionLabel: _homeworkSearchQuery.isNotEmpty ? 'Clear Search' : 'Create Assignment',
                    onAction: _homeworkSearchQuery.isNotEmpty ? () => setState(() => _homeworkSearchQuery = '') : _showNewAssignmentDialog,
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final hw = filtered[index];
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
                              decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(AppRadius.sm)),
                              child: const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(hw['title'] ?? 'Assignment', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  if (hw['description'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(hw['description'], style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    '${hw['subjectName']} • Due: ${hw['dueDate']?.toString().split('T')[0]} • Max Marks: ${hw['maxMarks']}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(label: '${hw['submissionsCount'] ?? 0} Submissions', variant: BadgeVariant.info),
                            const SizedBox(width: AppSpacing.md),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              tooltip: 'Delete Assignment',
                              onPressed: () => _deleteAssignment(hw['id']),
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
