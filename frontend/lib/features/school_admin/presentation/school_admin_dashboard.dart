import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class SchoolAdminDashboard extends ConsumerStatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  ConsumerState<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends ConsumerState<SchoolAdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  Map<String, dynamic>? _overview;
  List<dynamic> _students = [];
  List<dynamic> _classes = [];
  List<dynamic> _staff = [];
  List<dynamic> _invoices = [];

  String? _selectedClassFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final overviewRes = await ApiClient().dio.get('/reports/overview');
      final studentsRes = await ApiClient().dio.get('/students');
      final classesRes = await ApiClient().dio.get('/schools/classes');
      final staffRes = await ApiClient().dio.get('/staff');
      final invoicesRes = await ApiClient().dio.get('/fees/invoices');

      setState(() {
        _overview = overviewRes.data['data'];
        _students = studentsRes.data['data'] ?? [];
        _classes = classesRes.data['data'] ?? [];
        _staff = staffRes.data['data'] ?? [];
        _invoices = invoicesRes.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
            title: Text('New Student Admission', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: firstNameCtrl,
                            decoration: const InputDecoration(labelText: 'First Name'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: lastNameCtrl,
                            decoration: const InputDecoration(labelText: 'Last Name'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Academic Allocation', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedClassId,
                            decoration: const InputDecoration(labelText: 'Grade / Class'),
                            items: _classes.map<DropdownMenuItem<String>>((c) {
                              return DropdownMenuItem(value: c['id'], child: Text(c['name']));
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSectionId,
                            decoration: const InputDecoration(labelText: 'Section'),
                            items: currentClassSections.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'], child: Text(s['name']));
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedSectionId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Parent / Guardian Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: guardianNameCtrl,
                      decoration: const InputDecoration(labelText: 'Guardian Name', hintText: 'Father or Mother name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: guardianPhoneCtrl,
                      decoration: const InputDecoration(labelText: 'Guardian Mobile', hintText: '+91 98765 00000'),
                    ),
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
                        const SnackBar(content: Text('Student admitted and enrolled successfully!')),
                      );
                      _loadAllData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to admit student')));
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
              return const Center(child: CircularProgressIndicator());
            }

            final data = (snapshot.data as dynamic).data['data'];
            final exams = data['exams'] as List;

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Report Card: $studentName', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Attendance: ${data['attendancePercentage']}%',
                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Class: ${data['student']['class']} (${data['student']['section']}) • Roll No: ${data['student']['rollNo']} • Academic Year: ${data['student']['academicYear']}',
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      if (exams.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('No published exam records found for this student.')),
                        )
                      else
                        ...exams.map((exam) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(exam['examName'], style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                                      Text(
                                        'Total: ${exam['totalMarksObtained']} / ${exam['totalMaxMarks']}',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  ...(exam['subjects'] as List).map((sub) {
                                    final percentage = ((sub['marksObtained'] ?? 0) / (sub['maxMarks'] ?? 100)) * 100;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(sub['subjectName'], style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                          Row(
                                            children: [
                                              Text('${sub['marksObtained']} / ${sub['maxMarks']}',
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: percentage >= 40 ? AppTheme.success.withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  percentage >= 85 ? 'Grade A+' : percentage >= 70 ? 'Grade A' : percentage >= 40 ? 'Pass' : 'Fail',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: percentage >= 40 ? AppTheme.success : AppTheme.error,
                                                  ),
                                                ),
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
                        }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _overview?['stats'] ?? {};

    return Column(
      children: [
        // Tab Header
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
              Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Students & Admissions'),
              Tab(icon: Icon(Icons.account_tree_outlined, size: 18), text: 'Academics & Classes'),
              Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Faculty & Staff'),
              Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Fees & Invoices'),
            ],
          ),
        ),
        const Divider(height: 1),
        // Tab Content
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMetricCard('Total Enrolled Students', '${stats['totalStudents'] ?? 0}', Icons.people, AppTheme.primary),
              const SizedBox(width: 16),
              _buildMetricCard('Teaching Faculty', '${stats['totalStaff'] ?? 0}', Icons.badge, AppTheme.secondary),
              const SizedBox(width: 16),
              _buildMetricCard('Classrooms', '${stats['totalClasses'] ?? 0}', Icons.meeting_room, AppTheme.accent),
              const SizedBox(width: 16),
              _buildMetricCard('Today Attendance Rate', '${stats['todayAttendanceRate'] ?? 0}%', Icons.check_circle, AppTheme.success),
              const SizedBox(width: 16),
              _buildMetricCard('Fee Collected', '₹${(stats['totalCollected'] ?? 0).toStringAsFixed(0)}', Icons.payments, AppTheme.warning),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recent Notices
              Expanded(
                flex: 5,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.campaign, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text('Campus Announcements', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...((_overview?['recentAnnouncements'] as List? ?? []).map((ann) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(ann['title'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                    if (ann['priority'] == 'URGENT')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('URGENT', style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(ann['content'], style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            ),
                          );
                        }).toList()),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Recent Audit Events
              Expanded(
                flex: 5,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history, color: AppTheme.secondary),
                            const SizedBox(width: 8),
                            Text('System Audit Trail', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...((_overview?['recentAuditLogs'] as List? ?? []).map((log) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${log['action']} by ${log['actorName'] ?? 'System'}',
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'Entity: ${log['entity']} • ${log['timestamp']}',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student Lifecycle & Enrollment (${_students.length})',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showNewAdmissionDialog,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('New Admission'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Admission No')),
                    DataColumn(label: Text('Student Full Name')),
                    DataColumn(label: Text('Class & Section')),
                    DataColumn(label: Text('Roll No')),
                    DataColumn(label: Text('Primary Guardian')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: _students.map((s) {
                    return DataRow(
                      cells: [
                        DataCell(Text(s['admissionNo'], style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(s['fullName'], style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                        DataCell(Text('${s['currentClass']} - ${s['currentSection']}')),
                        DataCell(Text('${s['rollNo'] ?? 'N/A'}')),
                        DataCell(Text((s['guardians'] as List).isNotEmpty ? s['guardians'][0]['name'] : 'N/A')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(s['status'], style: const TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
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
        ],
      ),
    );
  }

  Widget _buildAcademicsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Classes, Sections & Subjects Configuration', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._classes.map((c) {
            final sections = c['sections'] as List? ?? [];
            final subjects = c['classSubjects'] as List? ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.class_, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text(c['name'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                              child: Text('Code: ${c['code']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        Text('${sections.length} Sections Active', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('Sections:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: sections.map((sec) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.meeting_room, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Text('${sec['name']} (${sec['room'] ?? 'No Room'})', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              Text('• Cap: ${sec['capacity']}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Text('Curriculum Subjects:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: subjects.map((sub) {
                        return Chip(
                          label: Text(sub['subject']['name'], style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppTheme.primary.withOpacity(0.06),
                          side: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStaffTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Faculty & Staff Directory (${_staff.length})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Employee No')),
                    DataColumn(label: Text('Staff Name')),
                    DataColumn(label: Text('Designation')),
                    DataColumn(label: Text('Department')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Active Assignments')),
                  ],
                  rows: _staff.map((st) {
                    final assignments = st['assignments'] as List? ?? [];
                    return DataRow(
                      cells: [
                        DataCell(Text(st['employeeNo'], style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(st['fullName'], style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                        DataCell(Text(st['designation'])),
                        DataCell(Text(st['department'])),
                        DataCell(Text(st['email'])),
                        DataCell(
                          Wrap(
                            spacing: 4,
                            children: assignments.map((a) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: a['isClassTeacher'] ? AppTheme.accent.withOpacity(0.1) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${a['className']} (${a['sectionName']}) ${a['isClassTeacher'] ? '• Class Teacher' : ''}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: a['isClassTeacher'] ? AppTheme.accent : AppTheme.textDark,
                                  ),
                                ),
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
        ],
      ),
    );
  }

  Widget _buildFeesTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fee Demands, Invoices & Collections (${_invoices.length})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Invoice No')),
                    DataColumn(label: Text('Student')),
                    DataColumn(label: Text('Fee Title')),
                    DataColumn(label: Text('Total Amount')),
                    DataColumn(label: Text('Paid Amount')),
                    DataColumn(label: Text('Due Amount')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _invoices.map((inv) {
                    final isPaid = inv['status'] == 'PAID';
                    return DataRow(
                      cells: [
                        DataCell(Text(inv['invoiceNo'], style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(inv['studentName'], style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                        DataCell(Text(inv['title'])),
                        DataCell(Text('₹${inv['amount']}')),
                        DataCell(Text('₹${inv['paidAmount']}', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold))),
                        DataCell(Text('₹${inv['dueAmount']}', style: TextStyle(color: isPaid ? AppTheme.textMuted : AppTheme.error, fontWeight: FontWeight.bold))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPaid ? AppTheme.success.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              inv['status'],
                              style: TextStyle(
                                color: isPaid ? AppTheme.success : AppTheme.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            ],
          ),
        ),
      ),
    );
  }
}
