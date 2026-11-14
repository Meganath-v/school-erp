import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/state_views.dart';

class ParentPortalScreen extends ConsumerStatefulWidget {
  const ParentPortalScreen({super.key});

  @override
  ConsumerState<ParentPortalScreen> createState() => _ParentPortalScreenState();
}

class _ParentPortalScreenState extends ConsumerState<ParentPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _children = [];
  int _selectedChildIndex = 0;

  Map<String, dynamic>? _selectedChildDetail;
  Map<String, dynamic>? _reportCard;
  List<dynamic> _invoices = [];
  List<dynamic> _timetable = [];
  List<dynamic> _homework = [];
  List<dynamic> _courseMaterials = [];
  List<dynamic> _teachingDiaries = [];
  List<dynamic> _circulars = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadLinkedChildren();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedChildren() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final childrenRes = await ApiClient().dio.get('/students');
      final childrenList = childrenRes.data['data'] as List? ?? [];

      setState(() {
        _children = childrenList;
      });

      if (childrenList.isNotEmpty) {
        await _loadChildData(childrenList[_selectedChildIndex]['id']);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChildData(String studentId) async {
    try {
      final results = await Future.wait([
        ApiClient().dio.get('/students/$studentId'),
        ApiClient().dio.get('/students/$studentId/report-card'),
        ApiClient().dio.get('/fees/invoices', queryParameters: {'studentId': studentId}),
        ApiClient().dio.get('/timetable/entries'),
        ApiClient().dio.get('/assignments'),
        ApiClient().dio.get('/academics/course-materials'),
        ApiClient().dio.get('/academics/teaching-diaries'),
        ApiClient().dio.get('/circulars'),
      ]);

      setState(() {
        _selectedChildDetail = results[0].data['data'];
        _reportCard = results[1].data['data'];
        _invoices = results[2].data['data'] ?? [];
        _timetable = results[3].data['data'] ?? [];
        _homework = results[4].data['data'] ?? [];
        _courseMaterials = results[5].data['data'] ?? [];
        _teachingDiaries = results[6].data['data'] ?? [];
        _circulars = results[7].data as List? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acknowledgeCircular(String circularId) async {
    try {
      await ApiClient().dio.post(
        '/circulars/$circularId/acknowledge',
        data: {'remarks': 'Signed & acknowledged by Guardian'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Circular acknowledged and digitally signed!'),
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

  void _switchChild(int index) {
    setState(() {
      _selectedChildIndex = index;
      _isLoading = true;
    });
    _loadChildData(_children[index]['id']);
  }

  void _showPayInvoiceDialog(dynamic inv) {
    final amountDue = inv['dueAmount'] ?? 0;
    String method = 'ONLINE';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Online Institutional Fee Payment'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv['title'] ?? 'Fee Invoice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('Invoice: ${inv['invoiceNo']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        Text('₹$amountDue', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(labelText: 'Payment Gateway Method'),
                    items: const [
                      DropdownMenuItem(value: 'ONLINE', child: Text('UPI / Net Banking / Debit Card')),
                      DropdownMenuItem(value: 'NET_BANKING', child: Text('Direct Bank Portal')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => method = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await ApiClient().dio.post(
                      '/fees/pay',
                      data: {
                        'invoiceId': inv['id'],
                        'amount': amountDue,
                        'method': method,
                        'notes': 'Online parent portal clearance',
                      },
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment completed & receipt generated!'), backgroundColor: AppColors.success),
                      );
                      _loadChildData(_children[_selectedChildIndex]['id']);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment error: $e'), backgroundColor: AppColors.error));
                    }
                  }
                },
                child: Text('Authorize ₹$amountDue Payment'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showApplyLeaveDialog() {
    final reasonCtrl = TextEditingController();
    DateTimeRange? selectedRange = DateTimeRange(
      start: DateTime.now().add(const Duration(days: 1)),
      end: DateTime.now().add(const Duration(days: 2)),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Apply for Ward Absence Leave'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Leave Duration', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                        initialDateRange: selectedRange,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedRange = picked);
                      }
                    },
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      selectedRange != null
                          ? '${selectedRange!.start.toString().split(' ')[0]} to ${selectedRange!.end.toString().split(' ')[0]}'
                          : 'Select Dates',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Reason for Leave', hintText: 'e.g. Attending family function out of town'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (reasonCtrl.text.trim().isEmpty || selectedRange == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select dates and provide a reason.')));
                    return;
                  }
                  try {
                    await ApiClient().dio.post('/leave-requests', data: {
                      'studentId': _children[_selectedChildIndex]['id'],
                      'startDate': selectedRange!.start.toIso8601String(),
                      'endDate': selectedRange!.end.toIso8601String(),
                      'reason': reasonCtrl.text.trim(),
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Leave application sent to Class Teacher.'), backgroundColor: AppColors.success),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit leave: $e'), backgroundColor: AppColors.error));
                    }
                  }
                },
                child: const Text('Submit Application'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading linked student progress and broadsheet...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Parent Portal Unavailable',
        errorMessage: _errorMessage!,
        onRetry: _loadLinkedChildren,
      );
    }

    if (_children.isEmpty) {
      return const EmptyStateView(
        icon: Icons.people_outline,
        title: 'No Linked Children Registered',
        description: 'No verified students are associated with your parent guardian profile.',
      );
    }

    final attendancePct = _selectedChildDetail?['attendancePercentage'] ?? 100;
    final isShortage = attendancePct < 75;
    final totalFeeDues = _invoices.fold<double>(0.0, (acc, inv) => acc + ((inv['dueAmount'] ?? 0) as num).toDouble());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Parent Portal', 'My Children'],
            title: 'Parent Portal & Student Progress',
            subtitle: 'Academic broadsheet, daily attendance compliance, fee clearance, and coursework diary.',
            actions: [
              ElevatedButton.icon(
                onPressed: _showApplyLeaveDialog,
                icon: const Icon(Icons.event_busy, size: 16),
                label: const Text('Apply for Leave'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Child Selector Chips Row
          Text('Select Enrolled Ward:', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: List.generate(_children.length, (idx) {
              final child = _children[idx];
              final isSelected = idx == _selectedChildIndex;

              return InkWell(
                onTap: () => _switchChild(idx),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.surface : AppColors.surfaceMuted,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderLight,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: isSelected ? AppShadows.subtle : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected ? AppColors.primary : AppColors.textSecondary,
                        child: Text(
                          (child['fullName'] as String).substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child['fullName'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${child['currentClass']} (${child['currentSection']}) • Roll: ${child['rollNo'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Child Overview Metrics
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1000;
              final cards = [
                MetricCard(
                  title: 'Attendance Record',
                  value: '$attendancePct%',
                  icon: isShortage ? Icons.warning_amber : Icons.check_circle_outline,
                  subtitle: isShortage ? '⚠️ Condonation Deficit (<75%)' : 'AY 2026-2027 Good Standing',
                  color: isShortage ? AppColors.error : AppColors.success,
                  onTap: () => _tabController.animateTo(0),
                ),
                MetricCard(
                  title: 'Upcoming Timetable',
                  value: '${_timetable.where((t) => t['dayOfWeek'] == DateTime.now().weekday).length} Classes',
                  icon: Icons.schedule_outlined,
                  subtitle: "Today's Scheduled Periods",
                  color: AppColors.primary,
                  onTap: () => _tabController.animateTo(4),
                ),
                MetricCard(
                  title: 'Exam Performance',
                  value: '${_reportCard != null ? 'Results Published' : 'In Moderation'}',
                  icon: Icons.school_outlined,
                  subtitle: 'Academic Broadsheet',
                  color: AppColors.accent,
                  onTap: () => _tabController.animateTo(0),
                ),
                MetricCard(
                  title: 'Fee Balances',
                  value: '₹${totalFeeDues.toStringAsFixed(0)}',
                  icon: Icons.payments_outlined,
                  subtitle: totalFeeDues > 0 ? 'Pending Invoice Dues' : 'All Invoices Cleared',
                  color: totalFeeDues > 0 ? AppColors.warning : AppColors.success,
                  onTap: () => _tabController.animateTo(5),
                ),
                MetricCard(
                  title: 'Active Homework',
                  value: '${_homework.length} Tasks',
                  icon: Icons.assignment_outlined,
                  subtitle: 'Curriculum Coursework',
                  color: AppColors.info,
                  onTap: () => _tabController.animateTo(3),
                ),
                MetricCard(
                  title: 'Circulars & Notices',
                  value: '${_circulars.where((c) => c['requiresAck'] == true).length} Pending',
                  icon: Icons.campaign_outlined,
                  subtitle: 'Digital Signature Sign-off',
                  color: _circulars.where((c) => c['requiresAck'] == true).isNotEmpty ? AppColors.error : AppColors.secondary,
                  onTap: () => _tabController.animateTo(6),
                ),
              ];

              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: cards.map((c) {
                  final width = isDesktop
                      ? (constraints.maxWidth - 2 * AppSpacing.md) / 3
                      : (constraints.maxWidth - AppSpacing.md) / 2;
                  return SizedBox(width: width, child: c);
                }).toList(),
              );
            },
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
                    Tab(icon: Icon(Icons.verified_outlined, size: 18), text: 'Academic Progress Card'),
                    Tab(icon: Icon(Icons.folder_shared_outlined, size: 18), text: 'Study Materials Repository'),
                    Tab(icon: Icon(Icons.book_outlined, size: 18), text: 'Daily Course Log'),
                    Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'Active Homework'),
                    Tab(icon: Icon(Icons.schedule_outlined, size: 18), text: 'Class Timetable'),
                    Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Fee Invoices & Receipts'),
                    Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'School Notices & Circulars'),
                  ],
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                SizedBox(
                  height: 480,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildReportCardTab(),
                      _buildStudyMaterialsTab(),
                      _buildTeachingDiaryTab(),
                      _buildHomeworkTab(),
                      _buildTimetableTab(),
                      _buildFeesTab(),
                      _buildCircularsTab(),
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

  Widget _buildReportCardTab() {
    final exams = _reportCard?['exams'] as List? ?? [];

    if (exams.isEmpty) {
      return const EmptyStateView(
        icon: Icons.verified_outlined,
        title: 'No Published Report Cards',
        description: 'Official terminal examination broadsheets will appear here after moderation.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
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
                  Text(exam['examName'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  StatusBadge(
                    label: 'Score: ${exam['totalMarksObtained']} / ${exam['totalMaxMarks']}',
                    variant: BadgeVariant.success,
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.borderLight),
              ...subjects.map((sub) {
                final pct = ((sub['marksObtained'] ?? 0) / (sub['maxMarks'] ?? 100)) * 100;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(sub['subjectName'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          Text('${sub['marksObtained']} / ${sub['maxMarks']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge(
                            label: pct >= 85 ? 'Grade A+' : pct >= 70 ? 'Grade A' : 'Pass',
                            variant: pct >= 70 ? BadgeVariant.success : BadgeVariant.neutral,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudyMaterialsTab() {
    if (_courseMaterials.isEmpty) {
      return const EmptyStateView(
        icon: Icons.folder_shared_outlined,
        title: 'No Course Materials Available',
        description: 'Uploaded chapter notes and question banks will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _courseMaterials.length,
      itemBuilder: (context, index) {
        final mat = _courseMaterials[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.secondarySubtle,
              child: Icon(mat['fileType'] == 'SLIDES' ? Icons.slideshow : Icons.picture_as_pdf, color: AppColors.secondary, size: 20),
            ),
            title: Text(mat['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${mat['subjectName']} • Unit ${mat['unitNumber']} • Format: ${mat['fileType']}'),
            trailing: OutlinedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading: ${mat['title']}')));
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeachingDiaryTab() {
    if (_teachingDiaries.isEmpty) {
      return const EmptyStateView(
        icon: Icons.book_outlined,
        title: 'No Course Logs Recorded Today',
        description: 'Daily classroom teaching entries logged by faculty will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _teachingDiaries.length,
      itemBuilder: (context, index) {
        final d = _teachingDiaries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text('P${d['periodNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${d['subjectName']} • ${d['date']?.toString().split('T')[0]}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(d['topicTaught'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                    if (d['remarks'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Faculty Note: ${d['remarks']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              StatusBadge(label: d['methodology'] ?? 'LECTURE', variant: BadgeVariant.neutral),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeworkTab() {
    if (_homework.isEmpty) {
      return const EmptyStateView(
        icon: Icons.assignment_outlined,
        title: 'No Pending Homework',
        description: 'All assigned classroom homework and coursework exercises are completed.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _homework.length,
      itemBuilder: (context, index) {
        final hw = _homework[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hw['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(hw['description'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Subject: ${hw['subjectName']} • Due: ${hw['dueDate']?.toString().split('T')[0]}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const StatusBadge(label: 'Assigned', variant: BadgeVariant.info),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimetableTab() {
    if (_timetable.isEmpty) {
      return const EmptyStateView(
        icon: Icons.schedule_outlined,
        title: 'Timetable Unavailable',
        description: 'Weekly schedule entries have not been published for this section.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _timetable.length,
      itemBuilder: (context, index) {
        final t = _timetable[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text('P${t['periodNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
            title: Text('${t['subjectName']} (${t['teacherName'] ?? 'Faculty'})', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${t['startTime']} - ${t['endTime']} • Room: ${t['room'] ?? 'General Room'}'),
          ),
        );
      },
    );
  }

  Widget _buildFeesTab() {
    if (_invoices.isEmpty) {
      return const EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: 'No Fee Invoices on File',
        description: 'All institutional tuition and ancillary fees are fully cleared.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        final isPaid = inv['status'] == 'PAID';

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.receipt_outlined, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Invoice No: ${inv['invoiceNo']} • Due: ${inv['dueDate']?.toString().split('T')[0]}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('Total: ₹${inv['amount']} • Paid: ₹${inv['paidAmount']} • Due: ₹${inv['dueAmount']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
              if (!isPaid)
                ElevatedButton.icon(
                  onPressed: () => _showPayInvoiceDialog(inv),
                  icon: const Icon(Icons.payment, size: 16),
                  label: Text('Pay ₹${inv['dueAmount']}'),
                )
              else
                const StatusBadge(label: 'PAID & CLEARED', variant: BadgeVariant.success),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircularsTab() {
    if (_circulars.isEmpty) {
      return const EmptyStateView(
        icon: Icons.campaign_outlined,
        title: 'No Broadcast Circulars',
        description: 'No administrative notices or circulars require guardian action at this time.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _circulars.length,
      itemBuilder: (context, index) {
        final circ = _circulars[index];
        final requiresAck = circ['requiresAck'] == true;
        final isUrgent = circ['priority'] == 'URGENT';

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isUrgent ? AppColors.errorSubtle : AppColors.secondarySubtle,
                child: Icon(isUrgent ? Icons.warning_amber : Icons.campaign, color: isUrgent ? AppColors.error : AppColors.secondary, size: 20),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(circ['title'] ?? 'School Circular', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        StatusBadge(
                          label: circ['priority'] ?? 'STANDARD',
                          variant: isUrgent ? BadgeVariant.error : BadgeVariant.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(circ['content'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Dispatched: ${circ['createdAt'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (requiresAck) ...[
                const SizedBox(width: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: () => _acknowledgeCircular(circ['id']),
                  icon: const Icon(Icons.draw, size: 16),
                  label: const Text('Sign & Ack'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
