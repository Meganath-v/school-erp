import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';

class StudentPortalScreen extends ConsumerStatefulWidget {
  const StudentPortalScreen({super.key});

  @override
  ConsumerState<StudentPortalScreen> createState() => _StudentPortalScreenState();
}

class _StudentPortalScreenState extends ConsumerState<StudentPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _studentProfile;
  Map<String, dynamic>? _reportCard;
  List<dynamic> _timetable = [];
  List<dynamic> _assignments = [];
  List<dynamic> _courseMaterials = [];
  List<dynamic> _circulars = [];
  List<dynamic> _feedbacks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllStudentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllStudentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profileRes = await ApiClient().dio.get('/students/me/profile');
      final profile = profileRes.data['data'] as Map<String, dynamic>;
      final studentId = profile['id'];

      final results = await Future.wait([
        ApiClient().dio.get('/students/$studentId/report-card').then((r) => r.data['data']).catchError((_) => null),
        ApiClient().dio.get('/timetable/entries').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/assignments').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/academics/course-materials').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/circulars').then((r) => r.data as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/feedback').then((r) => r.data as List? ?? []).catchError((_) => []),
      ]);

      setState(() {
        _studentProfile = profile;
        _reportCard = results[0] as Map<String, dynamic>?;
        _timetable = results[1] as List<dynamic>;
        _assignments = results[2] as List<dynamic>;
        _courseMaterials = results[3] as List<dynamic>;
        _circulars = results[4] as List<dynamic>;
        _feedbacks = results[5] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _acknowledgeCircular(String circularId) async {
    try {
      await ApiClient().dio.post(
        '/circulars/$circularId/acknowledge',
        data: {'remarks': 'Read and acknowledged by student'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notice successfully acknowledged & signed'),
          backgroundColor: AppTheme.success,
        ),
      );
      // Reload circulars
      final circRes = await ApiClient().dio.get('/circulars');
      setState(() {
        _circulars = circRes.data as List? ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign circular: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showNewFeedbackDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'ACADEMIC';
    int rating = 5;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Submit Query / Grievance', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'ACADEMIC', child: Text('Academic & Syllabus')),
                          DropdownMenuItem(value: 'INFRASTRUCTURE', child: Text('Campus & Facility')),
                          DropdownMenuItem(value: 'EXAMINATIONS', child: Text('Exams & Grading')),
                          DropdownMenuItem(value: 'TRANSPORT', child: Text('School Transport')),
                          DropdownMenuItem(value: 'GENERAL', child: Text('General Grievance')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      Text('Subject / Title', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Brief summary of query',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Details & Remarks', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: contentCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Describe your query or feedback in detail...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Rating / Satisfaction', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          return IconButton(
                            icon: Icon(
                              star <= rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                            ),
                            onPressed: () => setDialogState(() => rating = star),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }
                    try {
                      await ApiClient().dio.post(
                        '/feedback',
                        data: {
                          'title': titleCtrl.text.trim(),
                          'content': contentCtrl.text.trim(),
                          'category': category,
                          'rating': rating,
                          'isAnonymous': false,
                        },
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAllStudentData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Feedback successfully logged with administration'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                        );
                      }
                    }
                  },
                  child: const Text('Submit Feedback', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSubmitAssignmentDialog(dynamic a) {
    final notesCtrl = TextEditingController();
    final fileUrlCtrl = TextEditingController(text: 'https://docs.erp.com/solutions/homework.pdf');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Submit Homework: ${a['title']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter your homework notes or solution summary:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Solved exercises 1 through 10...'),
                ),
                const SizedBox(height: 12),
                Text('Attachment URL / Cloud Document Link (Optional):', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: fileUrlCtrl,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'https://...'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                if (notesCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter solution notes')));
                  return;
                }
                try {
                  await ApiClient().dio.post('/assignments/${a['id']}/submissions', data: {
                    'studentId': _studentProfile?['id'],
                    'notes': notesCtrl.text.trim(),
                    'fileUrl': fileUrlCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Homework solution submitted successfully!'), backgroundColor: AppTheme.success),
                    );
                    _loadAllStudentData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Submission failed: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              child: const Text('Submit Solution', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
              Text('Unable to load student data', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAllStudentData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final p = _studentProfile ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Banner / Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.15),
                  child: Text(
                    (p['firstName'] ?? 'S')[0],
                    style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p['fullName'] ?? 'Student Profile',
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${p['className'] ?? ''} - ${p['sectionName'] ?? ''}',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Admission: ${p['admissionNo'] ?? 'N/A'}',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Roll No: ${p['rollNo'] ?? 'N/A'}',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          if (p['bloodGroup'] != null) ...[
                            const SizedBox(width: 14),
                            Text(
                              'Blood Group: ${p['bloodGroup']}',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _showNewFeedbackDialog,
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Helpdesk / Feedback'),
                ),
              ],
            ),
          ),

          // Tabs Navigation
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.schedule, size: 18), text: 'Timetable'),
                Tab(icon: Icon(Icons.assignment, size: 18), text: 'Assignments'),
                Tab(icon: Icon(Icons.menu_book, size: 18), text: 'Course Materials'),
                Tab(icon: Icon(Icons.grade, size: 18), text: 'Examinations'),
                Tab(icon: Icon(Icons.campaign, size: 18), text: 'Circulars'),
                Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'Feedback Desk'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTimetableTab(),
                _buildAssignmentsTab(),
                _buildCourseMaterialsTab(),
                _buildExaminationsTab(),
                _buildCircularsTab(),
                _buildFeedbackTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableTab() {
    if (_timetable.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 48, color: AppTheme.border),
            const SizedBox(height: 12),
            Text('No timetable schedules logged yet', style: GoogleFonts.outfit(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _timetable.length,
      itemBuilder: (ctx, i) {
        final item = _timetable[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Period ${item['period'] ?? (i + 1)}',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['subject']?['name'] ?? item['subjectName'] ?? 'Course Lecture',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Faculty: ${item['teacher']?['firstName'] ?? 'Assigned Instructor'} • Room: ${item['room'] ?? 'Hall 101'}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item['startTime'] ?? '09:00'} - ${item['endTime'] ?? '09:45'}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textDark),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentsTab() {
    if (_assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt, size: 48, color: AppTheme.border),
            const SizedBox(height: 12),
            Text('No assignments or tasks currently pending', style: GoogleFonts.outfit(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignments.length,
      itemBuilder: (ctx, i) {
        final a = _assignments[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        a['subject']?['name'] ?? 'General',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                    Text(
                      'Due: ${a['dueDate'] != null ? a['dueDate'].toString().split('T')[0] : 'N/A'}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.error),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(a['title'] ?? 'Assignment Task', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                if (a['description'] != null) ...[
                  const SizedBox(height: 4),
                  Text(a['description'], style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Max Marks: ${a['maxMarks'] ?? 100}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _showSubmitAssignmentDialog(a),
                      icon: const Icon(Icons.upload, size: 16, color: Colors.white),
                      label: const Text('Submit Homework', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCourseMaterialsTab() {
    if (_courseMaterials.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 48, color: AppTheme.border),
            const SizedBox(height: 12),
            Text('No digital study materials or lecture notes uploaded yet', style: GoogleFonts.outfit(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _courseMaterials.length,
      itemBuilder: (ctx, i) {
        final m = _courseMaterials[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEEF2FF),
              child: Icon(Icons.picture_as_pdf, color: AppTheme.primary, size: 20),
            ),
            title: Text(m['title'] ?? 'Study Guide', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(
              '${m['subject']?['name'] ?? m['subjectName'] ?? 'General'} • Uploaded by ${m['uploadedBy'] ?? 'Faculty'}',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.download, color: AppTheme.primary),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Downloading "${m['title']}"...')),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildExaminationsTab() {
    if (_reportCard == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined, size: 48, color: AppTheme.border),
            const SizedBox(height: 12),
            Text('No examination records or report cards found', style: GoogleFonts.outfit(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    final exams = _reportCard!['exams'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overall Academic Stats Card
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(
                  'Attendance',
                  '${_reportCard!['attendancePercentage'] ?? 100}%',
                  Icons.how_to_reg,
                  AppTheme.primary,
                ),
                _buildSummaryStat(
                  'Days Present',
                  '${_reportCard!['daysPresent'] ?? 0} / ${_reportCard!['totalWorkingDays'] ?? 0}',
                  Icons.calendar_month,
                  AppTheme.secondary,
                ),
                _buildSummaryStat(
                  'Total Exams',
                  '${exams.length}',
                  Icons.assignment_turned_in,
                  AppTheme.accent,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text('Term Examination Broadsheets', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        if (exams.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: Text('No term examination marks published yet.')),
          )
        else
          ...exams.map((exam) {
            final subjects = exam['subjects'] as List? ?? [];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(exam['examName'] ?? 'Examination', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Score: ${exam['totalMarksObtained'] ?? 0} / ${exam['totalMaxMarks'] ?? 0} (${exam['percentage'] ?? 0}%)',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                          children: [
                            Padding(padding: const EdgeInsets.all(8.0), child: Text('Subject', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8.0), child: Text('Max Marks', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8.0), child: Text('Scored', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8.0), child: Text('Grade', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                        ...subjects.map((sub) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(sub['subjectName'] ?? '', style: GoogleFonts.inter(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text('${sub['maxMarks'] ?? 100}', style: GoogleFonts.inter(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text('${sub['marksObtained'] ?? 0}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(sub['grade'] ?? 'A', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 12))),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularsTab() {
    if (_circulars.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign_outlined, size: 48, color: AppTheme.border),
            const SizedBox(height: 12),
            Text('No active school or class circulars posted', style: GoogleFonts.outfit(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _circulars.length,
      itemBuilder: (ctx, i) {
        final c = _circulars[i];
        final requiresAck = c['requiresAck'] == true;
        final isSigned = c['hasAcknowledged'] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        c['circularNumber'] ?? 'CIR/2026/001',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary),
                      ),
                    ),
                    Text(
                      c['publishedAt'] != null ? c['publishedAt'].toString().split('T')[0] : '',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(c['title'] ?? 'Announcement', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(c['content'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dispatched by: ${c['senderName'] ?? 'School Office'}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                    if (requiresAck)
                      isSigned
                          ? const Row(
                              children: [
                                Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                                SizedBox(width: 4),
                                Text('Acknowledged & Signed', style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            )
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: () => _acknowledgeCircular(c['id']),
                              icon: const Icon(Icons.done, size: 14, color: Colors.white),
                              label: const Text('Sign Notice', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedbackTab() {
    if (_feedbacks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.border),
            const SizedBox(height: 12),
            Text('No grievance or inquiries logged yet', style: GoogleFonts.outfit(color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showNewFeedbackDialog,
              icon: const Icon(Icons.add),
              label: const Text('Submit New Query'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _feedbacks.length,
      itemBuilder: (ctx, i) {
        final f = _feedbacks[i];
        final isResolved = f['status'] == 'RESOLVED';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isResolved ? AppTheme.success.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        f['status'] ?? 'PENDING',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isResolved ? AppTheme.success : Colors.amber.shade800,
                        ),
                      ),
                    ),
                    Text(
                      f['createdAt'] != null ? f['createdAt'].toString().split('T')[0] : '',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(f['title'] ?? 'Inquiry', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(f['content'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
                if (f['resolution'] != null) ...[
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Administrative Response:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(f['resolution'], style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textDark)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
