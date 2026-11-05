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

  List<dynamic> _timetable = [];
  List<dynamic> _assignments = [];
  List<dynamic> _exams = [];

  // Linways Academic AMS Data
  Map<String, dynamic>? _syllabusData;
  List<dynamic> _teachingDiaries = [];
  List<dynamic> _courseMaterials = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);
    try {
      final ttRes = await ApiClient().dio.get('/timetable/entries');
      final hwRes = await ApiClient().dio.get('/assignments');
      final exRes = await ApiClient().dio.get('/exams');
      final sylRes = await ApiClient().dio.get('/academics/lesson-plans');
      final diaryRes = await ApiClient().dio.get('/academics/teaching-diaries');
      final matRes = await ApiClient().dio.get('/academics/course-materials');

      setState(() {
        _timetable = ttRes.data['data'] ?? [];
        _assignments = hwRes.data['data'] ?? [];
        _exams = exRes.data['data'] ?? [];
        _syllabusData = sylRes.data['data'];
        _teachingDiaries = diaryRes.data['data'] ?? [];
        _courseMaterials = matRes.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showNewTeachingDiaryDialog() {
    final topicCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String methodology = 'LECTURE';
    int periodNumber = 1;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
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
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: periodNumber,
                            decoration: const InputDecoration(labelText: 'Conducted Period'),
                            items: [1, 2, 3, 4, 5, 6].map((p) => DropdownMenuItem(value: p, child: Text('Period $p'))).toList(),
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
                  if (topicCtrl.text.isEmpty) return;
                  try {
                    final clRes = await ApiClient().dio.get('/schools/classes');
                    final classes = clRes.data['data'] as List;
                    final staffRes = await ApiClient().dio.get('/staff');
                    final staffList = staffRes.data['data'] as List;

                    if (classes.isNotEmpty && staffList.isNotEmpty) {
                      final c = classes[0];
                      final sec = (c['sections'] as List)[0];
                      final sub = (c['classSubjects'] as List)[0]['subject'];

                      await ApiClient().dio.post('/academics/teaching-diaries', data: {
                        'classId': c['id'],
                        'sectionId': sec['id'],
                        'subjectId': sub['id'],
                        'teacherId': staffList[0]['id'],
                        'periodNumber': periodNumber,
                        'topicTaught': topicCtrl.text.trim(),
                        'methodology': methodology,
                        'remarks': remarksCtrl.text.trim(),
                      });

                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course Diary entry logged successfully!')));
                        _loadTeacherData();
                      }
                    }
                  } catch (_) {}
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
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://docs.erp.com/notes.pdf');
    int unitNumber = 1;
    String fileType = 'PDF';

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Material Title', hintText: 'e.g. Unit 2 Summary Notes')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: unitNumber,
                          decoration: const InputDecoration(labelText: 'Curriculum Unit'),
                          items: [1, 2, 3, 4, 5].map((u) => DropdownMenuItem(value: u, child: Text('Unit $u'))).toList(),
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
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty) return;
                  try {
                    final subRes = await ApiClient().dio.get('/schools/subjects');
                    final subjects = subRes.data['data'] as List;
                    if (subjects.isNotEmpty) {
                      await ApiClient().dio.post('/academics/course-materials', data: {
                        'subjectId': subjects[0]['id'],
                        'title': titleCtrl.text.trim(),
                        'unitNumber': unitNumber,
                        'fileType': fileType,
                        'fileUrl': urlCtrl.text.trim(),
                      });
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Study material shared with students!')));
                        _loadTeacherData();
                      }
                    }
                  } catch (_) {}
                },
                child: const Text('Publish Material'),
              ),
            ],
          );
        });
      },
    );
  }

  void _logLessonProgress(dynamic plan) async {
    final newHours = (plan['conductedHours'] as int) + 1;
    final isDone = newHours >= (plan['plannedHours'] as int);

    await ApiClient().dio.patch('/academics/lesson-plans/${plan['id']}/progress', data: {
      'conductedHours': newHours,
      'status': isDone ? 'COMPLETED' : 'IN_PROGRESS',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged +1 hr for ${plan['unitTitle']} (${newHours}/${plan['plannedHours']} hrs)')),
    );
    _loadTeacherData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Linways Tab Navigation Bar
        Container(
          color: Colors.white,
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

    return SingleChildScrollView(
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
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: coverage / 100,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
            ),
          ),
          const SizedBox(height: 8),
          Text('$conducted of $planned Total Instructional Hours Completed', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 20),
          // Course Units List
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
                              Text(p['unitTitle'], style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCompleted ? AppTheme.success.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              p['status'],
                              style: TextStyle(color: isCompleted ? AppTheme.success : AppTheme.warning, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Topic: ${p['topic']}', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark)),
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
            child: Card(
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
                                    child: Text(d['methodology'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(d['topicTaught'], style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                              if (d['remarks'] != null) ...[
                                const SizedBox(height: 4),
                                Text('Remarks: ${d['remarks']}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            ],
                          ),
                        ),
                        Text('By: ${d['teacherName']}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
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
            child: ListView.builder(
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
                              Text(mat['title'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text('${mat['subjectName']} • Unit ${mat['unitNumber']} • Format: ${mat['fileType']}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
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
          Text('Weekly Teaching Timetable', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: _timetable.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final t = _timetable[index];
                  final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                  final day = t['dayOfWeek'] < dayNames.length ? dayNames[t['dayOfWeek']] : 'Day ${t['dayOfWeek']}';

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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Homework Assignments (${_assignments.length})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _assignments.length,
              itemBuilder: (context, index) {
                final hw = _assignments[index];
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
                              Text(hw['title'], style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(hw['description'], style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                              const SizedBox(height: 6),
                              Text(
                                '${hw['subjectName']} • Due: ${hw['dueDate']?.toString().split('T')[0]} • Max: ${hw['maxMarks']} marks',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Chip(label: Text('${hw['submissionsCount']} Submissions'), backgroundColor: const Color(0xFFF1F5F9)),
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
