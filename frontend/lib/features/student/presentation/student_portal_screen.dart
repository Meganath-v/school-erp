import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/state_views.dart';

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
          backgroundColor: AppColors.success,
        ),
      );
      final circRes = await ApiClient().dio.get('/circulars');
      setState(() {
        _circulars = circRes.data as List? ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign circular: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showNewFeedbackDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'ACADEMICS';
    int rating = 5;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Submit Query / Grievance'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: const [
                          DropdownMenuItem(value: 'ACADEMICS', child: Text('Academic & Syllabus')),
                          DropdownMenuItem(value: 'FACILITIES', child: Text('Campus & Facility')),
                          DropdownMenuItem(value: 'TRANSPORT', child: Text('School Transport')),
                          DropdownMenuItem(value: 'CANTEEN', child: Text('Canteen & Mess')),
                          DropdownMenuItem(value: 'GENERAL', child: Text('General Query')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Subject / Title', hintText: 'Brief summary of issue'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: contentCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Details & Remarks', hintText: 'Explain the issue or feedback clearly...'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text('Satisfaction Rating', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          return IconButton(
                            icon: Icon(star <= rating ? Icons.star : Icons.star_border, color: Colors.amber),
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
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
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
                          const SnackBar(content: Text('Feedback successfully logged with administration'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                      }
                    }
                  },
                  child: const Text('Submit Feedback'),
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
          title: Text('Submit Homework: ${a['title']}'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Solution Summary / Notes:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Solved exercises 1 through 10...'),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Attachment URL / Cloud Document Link:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: fileUrlCtrl,
                  decoration: const InputDecoration(hintText: 'https://...'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
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
                      const SnackBar(content: Text('Homework solution submitted successfully!'), backgroundColor: AppColors.success),
                    );
                    _loadAllStudentData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              child: const Text('Submit Solution'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading student academic workspace, schedule, and broadsheets...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Unable to Load Student Portal',
        message: _errorMessage,
        onRetry: _loadAllStudentData,
      );
    }

    final p = _studentProfile ?? {};
    final attendancePct = _reportCard?['attendancePercentage'] ?? 100;
    final isShortage = attendancePct < 75;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Student Portal', 'My Workspace'],
            title: '${p['fullName'] ?? 'Student Profile'} (${p['className'] ?? ''} - ${p['sectionName'] ?? ''})',
            subtitle: 'Admission ID: ${p['admissionNo'] ?? 'N/A'} • Roll No: ${p['rollNo'] ?? 'N/A'} • Blood Group: ${p['bloodGroup'] ?? 'O+'}',
            actions: [
              OutlinedButton.icon(
                onPressed: _showNewFeedbackDialog,
                icon: const Icon(Icons.help_outline, size: 16),
                label: const Text('Helpdesk / Query'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _loadAllStudentData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Student KPI Summary Cards
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Term Attendance',
                  value: '$attendancePct%',
                  icon: isShortage ? Icons.warning_amber : Icons.check_circle_outline,
                  subtitle: isShortage ? '⚠️ Shortage Risk (<75%)' : 'Consistent attendance',
                  color: isShortage ? AppColors.error : AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Daily Periods',
                  value: '${_timetable.length}',
                  icon: Icons.schedule_outlined,
                  subtitle: 'Lectures scheduled',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Course Homework',
                  value: '${_assignments.length}',
                  icon: Icons.assignment_outlined,
                  subtitle: 'Pending & active tasks',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Study Materials',
                  value: '${_courseMaterials.length}',
                  icon: Icons.menu_book_outlined,
                  subtitle: 'Uploaded documents',
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Tabs Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: AppShadows.subtle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(icon: Icon(Icons.schedule_outlined, size: 18), text: 'Timetable Schedule'),
                    Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'Homework & Tasks'),
                    Tab(icon: Icon(Icons.menu_book_outlined, size: 18), text: 'Course Materials'),
                    Tab(icon: Icon(Icons.grade_outlined, size: 18), text: 'Examinations & Marks'),
                    Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'School Circulars'),
                    Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'Feedback Desk'),
                  ],
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                SizedBox(
                  height: 480,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableTab() {
    if (_timetable.isEmpty) {
      return const EmptyStateView(
        icon: Icons.schedule_outlined,
        title: 'No Timetable Periods Configured',
        description: 'Your class timetable schedule has not been issued yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _timetable.length,
      itemBuilder: (ctx, i) {
        final item = _timetable[i];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text('Period ${item['period'] ?? (i + 1)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
            title: Text(item['subject']?['name'] ?? item['subjectName'] ?? 'Course Lecture', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Instructor: ${item['teacher']?['firstName'] ?? 'Assigned Instructor'} • Room: ${item['room'] ?? 'Hall 101'}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: StatusBadge(
              label: '${item['startTime'] ?? '09:00'} - ${item['endTime'] ?? '09:45'}',
              variant: BadgeVariant.neutral,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentsTab() {
    if (_assignments.isEmpty) {
      return const EmptyStateView(
        icon: Icons.task_alt,
        title: 'All Homework Completed',
        description: 'No assignments or problem sets are currently pending for submission.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _assignments.length,
      itemBuilder: (ctx, i) {
        final a = _assignments[i];
        final due = a['dueDate'] != null ? a['dueDate'].toString().split('T')[0] : 'N/A';

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                  StatusBadge(label: a['subject']?['name'] ?? 'General', variant: BadgeVariant.info),
                  StatusBadge(label: 'Due: $due', variant: BadgeVariant.warning),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(a['title'] ?? 'Assignment Task', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (a['description'] != null) ...[
                const SizedBox(height: 4),
                Text(a['description'], style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Max Marks: ${a['maxMarks'] ?? 100}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ElevatedButton.icon(
                    onPressed: () => _showSubmitAssignmentDialog(a),
                    icon: const Icon(Icons.upload, size: 14),
                    label: const Text('Submit Homework', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseMaterialsTab() {
    if (_courseMaterials.isEmpty) {
      return const EmptyStateView(
        icon: Icons.folder_open,
        title: 'No Digital Study Guides Found',
        description: 'Faculty lecture notes, question banks, and slides will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _courseMaterials.length,
      itemBuilder: (ctx, i) {
        final m = _courseMaterials[i];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primarySubtle,
              child: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 20),
            ),
            title: Text(m['title'] ?? 'Study Guide', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(
              '${m['subject']?['name'] ?? m['subjectName'] ?? 'General'} • Uploaded by ${m['uploadedBy'] ?? 'Faculty'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: OutlinedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading "${m['title']}"...')));
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildExaminationsTab() {
    if (_reportCard == null) {
      return const EmptyStateView(
        icon: Icons.grade_outlined,
        title: 'No Examination Records Found',
        description: 'Published report cards and broadsheet scores will be displayed here.',
      );
    }

    final exams = _reportCard!['exams'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        if (exams.isEmpty)
          const EmptyStateView(
            icon: Icons.grade_outlined,
            title: 'No Term Marks Published',
            description: 'Examination evaluation marks are pending moderation.',
          )
        else
          ...exams.map((exam) {
            final subjects = exam['subjects'] as List? ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderLight),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(exam['examName'] ?? 'Examination', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      StatusBadge(
                        label: 'Score: ${exam['totalMarksObtained'] ?? 0} / ${exam['totalMaxMarks'] ?? 0} (${exam['percentage'] ?? 0}%)',
                        variant: BadgeVariant.success,
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.borderLight),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xs)),
                        children: const [
                          Padding(padding: EdgeInsets.all(8.0), child: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8.0), child: Text('Max Marks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8.0), child: Text('Scored', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8.0), child: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                      ...subjects.map((sub) {
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(8.0), child: Text(sub['subjectName'] ?? '', style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8.0), child: Text('${sub['maxMarks'] ?? 100}', style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8.0), child: Text('${sub['marksObtained'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8.0), child: Text(sub['grade'] ?? 'A', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12))),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCircularsTab() {
    if (_circulars.isEmpty) {
      return const EmptyStateView(
        icon: Icons.campaign_outlined,
        title: 'No Circulars Active',
        description: 'All official notices dispatched to students will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _circulars.length,
      itemBuilder: (ctx, i) {
        final c = _circulars[i];
        final requiresAck = c['requiresAck'] == true;
        final isSigned = c['hasAcknowledged'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                  StatusBadge(label: c['priority'] ?? 'STANDARD', variant: c['priority'] == 'URGENT' ? BadgeVariant.error : BadgeVariant.info),
                  if (requiresAck)
                    isSigned
                        ? const StatusBadge(label: 'DIGITALLY SIGNED', variant: BadgeVariant.success)
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                            onPressed: () => _acknowledgeCircular(c['id']),
                            icon: const Icon(Icons.draw, size: 14),
                            label: const Text('Sign Notice', style: TextStyle(fontSize: 11)),
                          ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(c['title'] ?? 'Notice', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(c['content'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedbackTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Logged Queries (${_feedbacks.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: _showNewFeedbackDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Query'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _feedbacks.isEmpty
                ? const EmptyStateView(
                    icon: Icons.chat_bubble_outline,
                    title: 'No Queries Logged',
                    description: 'Submit academic or institutional queries directly to administrators.',
                  )
                : ListView.builder(
                    itemCount: _feedbacks.length,
                    itemBuilder: (ctx, i) {
                      final f = _feedbacks[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(AppRadius.xs)),
                              child: const Icon(Icons.help_center_outlined, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f['title'] ?? 'Query', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (f['content'] != null)
                                    Text(f['content'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            StatusBadge.fromStatus(f['status'] ?? 'SUBMITTED'),
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
