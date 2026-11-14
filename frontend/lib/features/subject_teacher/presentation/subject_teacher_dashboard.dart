import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';

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

  // Linways Academic AMS Data
  Map<String, dynamic>? _syllabusData;
  List<dynamic> _teachingDiaries = [];
  List<dynamic> _courseMaterials = [];

  // Academic metadata
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active classes found for diary logging')),
      );
      return;
    }

    final topicCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String methodology = 'LECTURE';
    int periodNumber = 1;
    String selectedClassId = _classes[0]['id'];
    List<dynamic> sections = _classes[0]['sections'] as List? ?? [];
    String? selectedSectionId = sections.isNotEmpty ? sections[0]['id'] : null;
    List<dynamic> classSubjects = _classes[0]['classSubjects'] as List? ?? [];
    String? selectedSubjectId;
    if (classSubjects.isNotEmpty && classSubjects[0]['subject'] != null) {
      selectedSubjectId = classSubjects[0]['subject']['id'];
    } else if (_subjects.isNotEmpty) {
      selectedSubjectId = _subjects[0]['id'];
    }
    String? selectedStaffId = _staffList.isNotEmpty ? _staffList[0]['id'] : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final currentClass = _classes.firstWhere(
            (c) => c['id'] == selectedClassId,
            orElse: () => _classes[0],
          );
          final currentSections = currentClass['sections'] as List? ?? [];
          final currentSubjects = currentClass['classSubjects'] as List? ?? [];

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.menu_book, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Log Faculty Course Diary', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedClassId,
                            decoration: const InputDecoration(labelText: 'Class / Grade'),
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
                                final subs = c['classSubjects'] as List? ?? [];
                                if (subs.isNotEmpty && subs[0]['subject'] != null) {
                                  selectedSubjectId = subs[0]['subject']['id'];
                                } else if (_subjects.isNotEmpty) {
                                  selectedSubjectId = _subjects[0]['id'];
                                } else {
                                  selectedSubjectId = null;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSectionId,
                            decoration: const InputDecoration(labelText: 'Section'),
                            items: currentSections.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedSectionId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedSubjectId,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      items: currentSubjects.isNotEmpty
                          ? currentSubjects.map<DropdownMenuItem<String>>((cs) {
                              final s = cs['subject'];
                              return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                            }).toList()
                          : _subjects.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                            }).toList(),
                      onChanged: (val) => setDialogState(() => selectedSubjectId = val),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: periodNumber,
                            decoration: const InputDecoration(labelText: 'Conducted Period'),
                            items: [1, 2, 3, 4, 5, 6, 7, 8].map((p) => DropdownMenuItem(value: p, child: Text('Period $p'))).toList(),
                            onChanged: (val) => setDialogState(() => periodNumber = val!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: methodology,
                            decoration: const InputDecoration(labelText: 'Pedagogy / Method'),
                            items: const [
                              DropdownMenuItem(value: 'LECTURE', child: Text('Classroom Lecture')),
                              DropdownMenuItem(value: 'LAB', child: Text('Lab Practical')),
                              DropdownMenuItem(value: 'GROUP_DISCUSSION', child: Text('Group Discussion')),
                              DropdownMenuItem(value: 'FLIPPED_CLASS', child: Text('Flipped Classroom')),
                            ],
                            onChanged: (val) => setDialogState(() => methodology = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: topicCtrl,
                      decoration: const InputDecoration(labelText: 'Topic & Concepts Covered', hintText: 'e.g. Quadratic Roots derivation'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Faculty Remarks / Homework Given', hintText: 'Questions 1-5 assigned'),
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
                        const SnackBar(content: Text('Course Diary entry logged successfully!'), backgroundColor: AppTheme.success),
                      );
                      _loadTeacherData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save diary entry: $e'), backgroundColor: AppTheme.error),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subjects found')),
      );
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
            title: Row(
              children: [
                const Icon(Icons.cloud_upload, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Upload Course Study Material', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
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
                    const SizedBox(height: 12),
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Material Title', hintText: 'e.g. Unit 2 Summary Notes')),
                    const SizedBox(height: 12),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: fileType,
                            decoration: const InputDecoration(labelText: 'Resource Format'),
                            items: const [
                              DropdownMenuItem(value: 'PDF', child: Text('PDF Document')),
                              DropdownMenuItem(value: 'SLIDES', child: Text('PowerPoint Slides')),
                              DropdownMenuItem(value: 'DOC', child: Text('Word Document')),
                            ],
                            onChanged: (val) => setDialogState(() => fileType = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Resource URL / File Path')),
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
                        const SnackBar(content: Text('Study material shared with students!'), backgroundColor: AppTheme.success),
                      );
                      _loadTeacherData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to publish material: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                },
                child: const Text('Publish Material'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showNewAssignmentDialog() {
    if (_classes.isEmpty || _subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Classes or subjects not loaded')),
      );
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
          final currentClass = _classes.firstWhere(
            (c) => c['id'] == selectedClassId,
            orElse: () => _classes[0],
          );
          final currentSections = currentClass['sections'] as List? ?? [];

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.assignment, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Create New Assignment', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Assignment Title', hintText: 'e.g. Chapter 4 Practice Problems'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Instructions / Description', hintText: 'Complete exercises 1 to 10 on page 78'),
                    ),
                    const SizedBox(height: 12),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSectionId,
                            decoration: const InputDecoration(labelText: 'Section'),
                            items: currentSections.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedSectionId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: marksCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Max Marks'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Due Date: ${selectedDueDate.toLocal().toString().split(' ')[0]}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: const Text('Pick Date'),
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
                        const SnackBar(content: Text('Assignment created and assigned to students!'), backgroundColor: AppTheme.success),
                      );
                      _loadTeacherData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create assignment: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                },
                child: const Text('Publish Assignment'),
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
        content: const Text('Are you sure you want to delete this assignment? All student submissions will also be removed.'),
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
        await ApiClient().dio.delete('/assignments/$id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment deleted successfully'), backgroundColor: AppTheme.success),
          );
          _loadTeacherData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete assignment: $e'), backgroundColor: AppTheme.error),
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
          SnackBar(content: Text('Logged +1 hr for ${plan['unitTitle']} (${newHours}/${plan['plannedHours']} hrs)')),
        );
        _loadTeacherData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update progress: $e'), backgroundColor: AppTheme.error),
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
              Text('Failed to load teacher records', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadTeacherData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Linways Tab Navigation Bar
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
                  isScrollable: true,
                  tabs: const [
                    Tab(icon: Icon(Icons.track_changes, size: 18), text: 'OBE Course Plan & Syllabus'),
                    Tab(icon: Icon(Icons.book_outlined, size: 18), text: 'Faculty Teaching Diary'),
                    Tab(icon: Icon(Icons.folder_shared_outlined, size: 18), text: 'Course Study Repository'),
                    Tab(icon: Icon(Icons.schedule, size: 18), text: 'Teaching Timetable'),
                    Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'Homework & Submissions'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Academic Data',
                onPressed: _loadTeacherData,
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

  // 1. Linways OBE Course Delivery Plan & Syllabus Tracker
  Widget _buildSyllabusTab() {
    final plans = _syllabusData?['plans'] as List? ?? [];
    final coverage = _syllabusData?['overallSyllabusCoverage'] ?? 0;
    final planned = _syllabusData?['totalPlannedHours'] ?? 0;
    final conducted = _syllabusData?['totalConductedHours'] ?? 0;

    if (plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.track_changes, size: 48, color: AppTheme.border),
            const SizedBox(height: 12),
            Text('No OBE course lesson plans uploaded yet', style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTeacherData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outcome-Based Course Delivery Plan (OBE)', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('Track planned vs conducted instructional hours and learning outcomes compliance', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_graph, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Syllabus Completion: $coverage%', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (coverage as num) / 100,
                minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
              ),
            ),
            const SizedBox(height: 8),
            Text('$conducted of $planned Total Instructional Hours Completed', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final p = plans[index];
                final isCompleted = p['status'] == 'COMPLETED';

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text('Unit ${p['unitNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 12)),
                                ),
                                const SizedBox(width: 10),
                                Text(p['unitTitle'] ?? 'Unit', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted ? AppTheme.success.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                p['status'] ?? 'PENDING',
                                style: TextStyle(color: isCompleted ? AppTheme.success : AppTheme.warning, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Topic: ${p['topic'] ?? 'General'}', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark)),
                        if (p['learningObjectives'] != null) ...[
                          const SizedBox(height: 6),
                          Text('Course Outcome: ${p['learningObjectives']}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Instructional Hours: ${p['conductedHours']} / ${p['plannedHours']} hrs (${p['coveragePercent']}%)',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              onPressed: () => _logLessonProgress(p),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Log +1 Teaching Hour', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 2. Linways Faculty Teaching Diary (Course Log)
  Widget _buildTeachingDiaryTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Faculty Teaching Diary / Daily Course Log', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Official institutional record of topics delivered per period', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showNewTeachingDiaryDialog,
                icon: const Icon(Icons.post_add, size: 18),
                label: const Text('New Diary Entry'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _teachingDiaries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.book_outlined, size: 48, color: AppTheme.border),
                        const SizedBox(height: 12),
                        Text('No teaching diary records logged yet', style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 16)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _showNewTeachingDiaryDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Log First Lecture Entry'),
                        ),
                      ],
                    ),
                  )
                : Card(
                    child: ListView.separated(
                      itemCount: _teachingDiaries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = _teachingDiaries[index];
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  children: [
                                    Text('P${d['periodNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 16)),
                                    Text('${d['date']?.toString().split('T')[0]}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('${d['subjectName']} • ${d['className']} (${d['sectionName']})',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                          child: Text(d['methodology'] ?? 'LECTURE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(d['topicTaught'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                                    if (d['remarks'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text('Remarks: ${d['remarks']}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                                    ],
                                  ],
                                ),
                              ),
                              Text('By: ${d['teacherName'] ?? 'Faculty'}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
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

  // 3. Linways Course Repository (Learning Materials)
  Widget _buildCourseRepositoryTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Digital Course Repository & Study Materials', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Syllabus notes, presentation decks, and revision documents available to students', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddMaterialDialog,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Publish Resource'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _courseMaterials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_shared_outlined, size: 48, color: AppTheme.border),
                        const SizedBox(height: 12),
                        Text('No study materials uploaded for your courses yet', style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 16)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _showAddMaterialDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Publish First Study Material'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _courseMaterials.length,
                    itemBuilder: (context, index) {
                      final mat = _courseMaterials[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.secondary.withOpacity(0.12),
                                child: Icon(mat['fileType'] == 'SLIDES' ? Icons.slideshow : Icons.picture_as_pdf, color: AppTheme.secondary, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(mat['title'] ?? 'Material', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text('${mat['subjectName'] ?? 'General'} • Unit ${mat['unitNumber']} • Format: ${mat['fileType']}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                                    Text('Uploaded by: ${mat['uploadedBy']} on ${mat['createdAt']?.toString().split('T')[0]}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 4. Timetable
  Widget _buildTimetableView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weekly Teaching Timetable (${_timetable.length} Sessions)', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: _loadTeacherData, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _timetable.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 48, color: AppTheme.border),
                        const SizedBox(height: 12),
                        Text('No active timetable schedules assigned to your profile', style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 16)),
                      ],
                    ),
                  )
                : Card(
                    child: ListView.separated(
                      itemCount: _timetable.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final t = _timetable[index];
                        final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                        final day = (t['dayOfWeek'] is int && t['dayOfWeek'] < dayNames.length) ? dayNames[t['dayOfWeek']] : 'Day ${t['dayOfWeek']}';

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text('P${t['periodNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ),
                          title: Text('${t['subjectName']} • ${t['className']} (${t['sectionName']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$day • ${t['startTime']} - ${t['endTime']} • Room: ${t['room'] ?? 'General'}'),
                          trailing: Chip(label: Text('Period ${t['periodNumber']}'), backgroundColor: const Color(0xFFF1F5F9)),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // 5. Homework
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Homework & Assignments (${_assignments.length})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showNewAssignmentDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Assignment'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search assignments by title or subject...',
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (val) => setState(() => _homeworkSearchQuery = val),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assignment_outlined, size: 48, color: AppTheme.border),
                        const SizedBox(height: 12),
                        Text(
                          _homeworkSearchQuery.isNotEmpty ? 'No assignments match "$_homeworkSearchQuery"' : 'No assignments published yet',
                          style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 16),
                        ),
                        if (_homeworkSearchQuery.isEmpty) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _showNewAssignmentDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Create First Assignment'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final hw = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              const Icon(Icons.assignment, color: AppTheme.primary, size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(hw['title'] ?? 'Assignment', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                                    if (hw['description'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(hw['description'], style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      '${hw['subjectName']} • Due: ${hw['dueDate']?.toString().split('T')[0]} • Max: ${hw['maxMarks']} marks',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Chip(label: Text('${hw['submissionsCount'] ?? 0} Submissions'), backgroundColor: const Color(0xFFF1F5F9)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                                tooltip: 'Delete Assignment',
                                onPressed: () => _deleteAssignment(hw['id']),
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
}
