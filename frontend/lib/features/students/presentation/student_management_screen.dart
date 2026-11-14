import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class StudentManagementScreen extends ConsumerStatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  ConsumerState<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends ConsumerState<StudentManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _students = [];
  List<dynamic> _classes = [];

  // Table State: search, sorting, pagination
  String _searchQuery = '';
  String? _selectedClassFilter;
  String? _selectedSectionFilter;
  String _sortField = 'name';
  bool _sortAscending = true;
  int _currentPage = 1;
  final int _pageSize = 8;

  // Selected Student Profile State
  Map<String, dynamic>? _selectedStudent;
  Map<String, dynamic>? _selectedReportCard;
  List<dynamic> _selectedDocuments = [];
  bool _isLoadingStudentDetail = false;

  // Admission Form State
  final _admissionFormKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _genderCtrl = TextEditingController(text: 'MALE');
  final _bloodGroupCtrl = TextEditingController(text: 'O+');
  final _guardianNameCtrl = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  final _guardianRelCtrl = TextEditingController(text: 'FATHER');
  final _guardianEmailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _rollNoCtrl = TextEditingController();
  String? _admissionClassId;
  String? _admissionSectionId;
  bool _isSubmittingAdmission = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _genderCtrl.dispose();
    _bloodGroupCtrl.dispose();
    _guardianNameCtrl.dispose();
    _guardianPhoneCtrl.dispose();
    _guardianRelCtrl.dispose();
    _guardianEmailCtrl.dispose();
    _addressCtrl.dispose();
    _rollNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient().dio.get('/students').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/classes').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
      ]);

      setState(() {
        _students = results[0];
        _classes = results[1];
        _isLoading = false;
      });

      if (_students.isNotEmpty && _selectedStudent == null) {
        _selectStudent(_students[0]['id']);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStudent(String studentId) async {
    setState(() => _isLoadingStudentDetail = true);
    try {
      final results = await Future.wait([
        ApiClient().dio.get('/students/$studentId').then((r) => r.data['data'] as Map<String, dynamic>?),
        ApiClient().dio.get('/students/$studentId/report-card').then((r) => r.data['data'] as Map<String, dynamic>?).catchError((_) => null),
        ApiClient().dio.get('/students/$studentId/documents').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
      ]);

      setState(() {
        _selectedStudent = results[0] as Map<String, dynamic>?;
        _selectedReportCard = results[1] as Map<String, dynamic>?;
        _selectedDocuments = results[2] as List<dynamic>;
        _isLoadingStudentDetail = false;
      });
    } catch (e) {
      setState(() => _isLoadingStudentDetail = false);
    }
  }

  Future<void> _submitAdmission() async {
    if (!_admissionFormKey.currentState!.validate()) return;
    if (_admissionClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an enrollment class')));
      return;
    }

    setState(() => _isSubmittingAdmission = true);
    try {
      await ApiClient().dio.post('/students', data: {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'dateOfBirth': _dobCtrl.text.trim().isNotEmpty ? _dobCtrl.text.trim() : '2010-01-01',
        'gender': _genderCtrl.text.trim(),
        'bloodGroup': _bloodGroupCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'classId': _admissionClassId,
        'sectionId': _admissionSectionId,
        'rollNo': int.tryParse(_rollNoCtrl.text.trim()),
        'guardianName': _guardianNameCtrl.text.trim(),
        'guardianPhone': _guardianPhoneCtrl.text.trim(),
        'guardianRelationship': _guardianRelCtrl.text.trim(),
        'guardianEmail': _guardianEmailCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student admitted and enrolled successfully!'), backgroundColor: AppColors.success),
        );
        _admissionFormKey.currentState!.reset();
        _firstNameCtrl.clear();
        _lastNameCtrl.clear();
        _guardianNameCtrl.clear();
        _guardianPhoneCtrl.clear();
        _addressCtrl.clear();
        _rollNoCtrl.clear();
        _loadInitialData();
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Admission failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingAdmission = false);
    }
  }

  void _showAddDocumentDialog() {
    if (_selectedStudent == null) return;
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String docType = 'BIRTH_CERTIFICATE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Attach Document for ${_selectedStudent!['firstName']}'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: docType,
                  decoration: const InputDecoration(labelText: 'Document Type'),
                  items: const [
                    DropdownMenuItem(value: 'BIRTH_CERTIFICATE', child: Text('Birth Certificate')),
                    DropdownMenuItem(value: 'TRANSFER_CERTIFICATE', child: Text('Transfer Certificate (TC)')),
                    DropdownMenuItem(value: 'MARKS_MEMO', child: Text('Prior Academic Marks Memo')),
                    DropdownMenuItem(value: 'MEDICAL_RECORD', child: Text('Medical / Immunization Record')),
                    DropdownMenuItem(value: 'IDENTIFICATION', child: Text('National ID / Aadhaar Card')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => docType = val);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Document Label / Reference', hintText: 'e.g. Original TC signed by Principal'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'Document File URL / Cloud Path', hintText: 'https://docs.school.edu/files/doc.pdf'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                  return;
                }
                try {
                  await ApiClient().dio.post('/students/${_selectedStudent!['id']}/documents', data: {
                    'title': titleCtrl.text.trim(),
                    'documentType': docType,
                    'fileUrl': urlCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document attached successfully!'), backgroundColor: AppColors.success));
                    _selectStudent(_selectedStudent!['id']);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to attach document: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              child: const Text('Attach Document'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDocumentConfirmation(String docId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Document Deletion'),
        content: Text('Are you sure you want to permanently delete "$title"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              try {
                await ApiClient().dio.delete('/students/${_selectedStudent!['id']}/documents/$docId');
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document removed permanently.'), backgroundColor: AppColors.success));
                  _selectStudent(_selectedStudent!['id']);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _showPromoteDialog() {
    if (_selectedStudent == null) return;
    String? targetClassId = _classes.isNotEmpty ? _classes[0]['id'] : null;
    String? targetSectionId = (_classes.isNotEmpty && (_classes[0]['sections'] as List).isNotEmpty)
        ? _classes[0]['sections'][0]['id']
        : null;
    final rollCtrl = TextEditingController(text: '${_selectedStudent!['rollNo'] ?? 1}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final curClass = _classes.firstWhere((c) => c['id'] == targetClassId, orElse: () => {'sections': []});
          final curSections = curClass['sections'] as List? ?? [];

          return AlertDialog(
            title: Text('Promote Learner: ${_selectedStudent!['firstName']} ${_selectedStudent!['lastName']}'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select next grade and section to advance student academic standing:'),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: targetClassId,
                          decoration: const InputDecoration(labelText: 'Promotion Class'),
                          items: _classes.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                targetClassId = val;
                                final secs = _classes.firstWhere((c) => c['id'] == val)['sections'] as List? ?? [];
                                targetSectionId = secs.isNotEmpty ? secs[0]['id'] : null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: targetSectionId,
                          decoration: const InputDecoration(labelText: 'Section'),
                          items: curSections.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))).toList(),
                          onChanged: (val) => setDialogState(() => targetSectionId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: rollCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'New Roll Number'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await ApiClient().dio.post('/students/${_selectedStudent!['id']}/promote', data: {
                      'academicYear': '2026-2027',
                      'classId': targetClassId,
                      'sectionId': targetSectionId,
                      'rollNo': int.tryParse(rollCtrl.text.trim()) ?? 1,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student successfully promoted!'), backgroundColor: AppColors.success));
                      _loadInitialData();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Promotion failed: $e'), backgroundColor: AppColors.error));
                    }
                  }
                },
                child: const Text('Confirm Promotion'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTransferDialog() {
    if (_selectedStudent == null) return;
    final reasonCtrl = TextEditingController();
    final tcNoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Student Transfer / Withdrawal: ${_selectedStudent!['firstName']}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This operation marks student status as TRANSFERRED, archives enrollment, and issues formal TC records.'),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: tcNoCtrl,
                decoration: const InputDecoration(labelText: 'Transfer Certificate (TC) Number', hintText: 'e.g. TC-2026-0089'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Reason for Transfer / School Leaving', hintText: 'e.g. Relocating to another city'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () async {
              try {
                await ApiClient().dio.post('/students/${_selectedStudent!['id']}/transfer', data: {
                  'tcNumber': tcNoCtrl.text.trim(),
                  'reason': reasonCtrl.text.trim(),
                  'transferDate': DateTime.now().toIso8601String(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student transferred and TC issued.'), backgroundColor: AppColors.warning));
                  _loadInitialData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Complete Transfer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading student directory and academic records...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Student Directory Unavailable',
        message: _errorMessage,
        onRetry: _loadInitialData,
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
                    Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Student Directory'),
                    Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Student Profile & Details'),
                    Tab(icon: Icon(Icons.person_add_outlined, size: 18), text: 'Admission & Enrollment Form'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Students',
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
              _buildDirectoryTab(),
              _buildProfileTab(),
              _buildAdmissionTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectoryTab() {
    // 1. Filter
    var filtered = _students.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          (s['fullName'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s['admissionNo'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesClass = _selectedClassFilter == null || s['currentClass'] == _selectedClassFilter;
      final matchesSection = _selectedSectionFilter == null || s['currentSection'] == _selectedSectionFilter;
      return matchesSearch && matchesClass && matchesSection;
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      int cmp = 0;
      if (_sortField == 'name') {
        cmp = (a['fullName'] ?? '').toString().compareTo((b['fullName'] ?? '').toString());
      } else if (_sortField == 'admissionNo') {
        cmp = (a['admissionNo'] ?? '').toString().compareTo((b['admissionNo'] ?? '').toString());
      } else if (_sortField == 'rollNo') {
        cmp = ((a['rollNo'] ?? 0) as num).compareTo(((b['rollNo'] ?? 0) as num));
      }
      return _sortAscending ? cmp : -cmp;
    });

    // 3. Pagination
    final totalCount = filtered.length;
    final totalPages = (totalCount / _pageSize).ceil();
    final safePage = _currentPage > totalPages && totalPages > 0 ? totalPages : _currentPage;
    final startIndex = (safePage - 1) * _pageSize;
    final pagedStudents = (startIndex < totalCount && startIndex >= 0)
        ? filtered.skip(startIndex).take(_pageSize).toList()
        : <dynamic>[];

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Students', 'Directory & Roster'],
              title: 'Student Master Directory',
              subtitle: 'Institutional registry of admitted students, class enrollments, and academic status.',
              actions: [
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(2),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Admit New Student'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Top Summary Cards
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Total Enrolled',
                    value: '${_students.length}',
                    icon: Icons.groups_outlined,
                    subtitle: 'AY 2026-2027 Learners',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Active Students',
                    value: '${_students.where((s) => s['status'] == 'ACTIVE').length}',
                    icon: Icons.check_circle_outline,
                    subtitle: 'Current matriculated learners',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Classes Configured',
                    value: '${_classes.length}',
                    icon: Icons.meeting_room_outlined,
                    subtitle: 'Academic divisions',
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Search & Filters Bar
            SearchFilterBar(
              searchHint: 'Search by student name or admission number...',
              searchQuery: _searchQuery,
              onSearchChanged: (val) => setState(() {
                _searchQuery = val;
                _currentPage = 1;
              }),
              totalCount: totalCount,
              countLabel: 'Learners Found',
              filters: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedClassFilter,
                    hint: const Text('All Classes'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Classes')),
                      ..._classes.map<DropdownMenuItem<String?>>((c) => DropdownMenuItem(value: c['name'] as String, child: Text(c['name']))),
                    ],
                    onChanged: (val) => setState(() {
                      _selectedClassFilter = val;
                      _currentPage = 1;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Students Table
            if (pagedStudents.isEmpty)
              const EmptyStateView(
                icon: Icons.person_search_outlined,
                title: 'No Matching Students',
                description: 'Try adjusting your search query or class filter criteria.',
              )
            else
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
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.2),
                        5: FlexColumnWidth(2.0),
                      },
                      border: TableBorder(
                        horizontalInside: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
                      ),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: AppColors.tableHeaderBg),
                          children: [
                            _buildTableHeader('Admission No', 'admissionNo'),
                            _buildTableHeader('Student Name', 'name'),
                            _buildTableHeader('Class & Section', null),
                            _buildTableHeader('Roll No', 'rollNo'),
                            _buildTableHeader('Status', null),
                            const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                        ...pagedStudents.map((s) {
                          final isSelected = _selectedStudent?['id'] == s['id'];
                          return TableRow(
                            decoration: BoxDecoration(color: isSelected ? AppColors.primarySubtle.withValues(alpha: 0.3) : Colors.transparent),
                            children: [
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(s['admissionNo'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primarySubtle,
                                      child: Text((s['fullName'] as String).substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(child: Text(s['fullName'] ?? 'Learner', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                  ],
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('${s['currentClass']} - ${s['currentSection']}', style: const TextStyle(fontSize: 13))),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('${s['rollNo'] ?? '—'}', style: const TextStyle(fontSize: 13))),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: StatusBadge.fromStatus(s['status'] ?? 'ACTIVE'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: Row(
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), visualDensity: VisualDensity.compact),
                                      icon: const Icon(Icons.person, size: 14),
                                      label: const Text('Profile'),
                                      onPressed: () {
                                        _selectStudent(s['id']);
                                        _tabController.animateTo(1);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),

                    // Pagination Toolbar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.borderLight)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Showing ${startIndex + 1} to ${((startIndex + _pageSize) < totalCount ? (startIndex + _pageSize) : totalCount)} of $totalCount learners', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 18),
                                onPressed: safePage > 1 ? () => setState(() => _currentPage = safePage - 1) : null,
                              ),
                              Text('Page $safePage of ${totalPages == 0 ? 1 : totalPages}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 18),
                                onPressed: safePage < totalPages ? () => setState(() => _currentPage = safePage + 1) : null,
                              ),
                            ],
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
    );
  }

  Widget _buildTableHeader(String title, String? sortKey) {
    final isSorted = _sortField == sortKey;
    return InkWell(
      onTap: sortKey != null
          ? () {
              setState(() {
                if (_sortField == sortKey) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortField = sortKey;
                  _sortAscending = true;
                }
              });
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (sortKey != null) ...[
              const SizedBox(width: 4),
              Icon(
                isSorted
                    ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                    : Icons.unfold_more,
                size: 14,
                color: isSorted ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    if (_isLoadingStudentDetail) {
      return const LoadingStateView(message: 'Loading comprehensive student profile...');
    }

    if (_selectedStudent == null) {
      return const EmptyStateView(
        icon: Icons.person_off_outlined,
        title: 'No Student Selected',
        description: 'Select a student from the Master Directory to inspect profile and records.',
      );
    }

    final s = _selectedStudent!;
    final enrollments = s['enrollments'] as List? ?? [];
    final guardians = s['guardians'] as List? ?? [];
    final exams = (_selectedReportCard?['exams'] as List? ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Action Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primarySubtle,
                    child: Text(
                      (s['firstName'] as String).substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${s['firstName']} ${s['lastName']}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: AppSpacing.md),
                          StatusBadge.fromStatus(s['status'] ?? 'ACTIVE'),
                        ],
                      ),
                      Text('Admission No: ${s['admissionNo']} • Class: ${s['enrollments'] != null && (s['enrollments'] as List).isNotEmpty ? s['enrollments'][0]['class']['name'] : 'Unassigned'} • DOB: ${s['dateOfBirth'] ?? 'N/A'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showPromoteDialog,
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: const Text('Promote Learner'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
                    onPressed: _showTransferDialog,
                    icon: const Icon(Icons.exit_to_app, size: 16),
                    label: const Text('Transfer / TC'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Two-Column Section: Personal & Guardian Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal & Enrollment Info Card
              Expanded(
                flex: 5,
                child: Container(
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
                        children: [
                          const Icon(Icons.badge, color: AppColors.primary, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Personal & Enrollment Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Full Name', '${s['firstName']} ${s['lastName']}'),
                      _buildInfoRow('Gender', s['gender'] ?? 'Not Specified'),
                      _buildInfoRow('Blood Group', s['bloodGroup'] ?? 'O+'),
                      _buildInfoRow('Date of Birth', s['dateOfBirth']?.toString().split('T')[0] ?? 'N/A'),
                      _buildInfoRow('Address', s['address'] ?? 'Not Provided'),
                      _buildInfoRow('Admitted Date', s['createdAt']?.toString().split('T')[0] ?? 'N/A'),
                      const Divider(height: 24),
                      Text('Enrollment History', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.sm),
                      if (enrollments.isEmpty)
                        const Text('No past or current enrollments recorded.')
                      else
                        ...enrollments.map((e) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${e['class']?['name']} (${e['section']?['name']}) • AY ${e['academicYear']?['name'] ?? '2026-2027'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                StatusBadge.fromStatus(e['status'] ?? 'ACTIVE'),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),

              // Guardian & Family Contact Card
              Expanded(
                flex: 5,
                child: Container(
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
                        children: [
                          const Icon(Icons.family_restroom, color: AppColors.secondary, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Guardian & Emergency Contacts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      if (guardians.isEmpty)
                        const Text('No primary guardian mapped to this student profile.')
                      else
                        ...guardians.map((g) {
                          final p = g['parent'];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('Guardian Full Name', p?['fullName'] ?? 'Guardian'),
                              _buildInfoRow('Relationship', g['relationship'] ?? 'Guardian'),
                              _buildInfoRow('Primary Phone', p?['phone'] ?? 'Not Specified'),
                              _buildInfoRow('Email Address', p?['email'] ?? 'Not Specified'),
                              _buildInfoRow('Emergency Contact', p?['phone'] ?? 'N/A'),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Academic History & Exam Broadsheet Preview
          Container(
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
                        const Icon(Icons.school, color: AppColors.accent, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Academic History & Examination Broadsheet', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    StatusBadge(
                      label: 'Term Attendance: ${_selectedReportCard?['attendancePercentage'] ?? 100}%',
                      variant: BadgeVariant.success,
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (exams.isEmpty)
                  const Text('No examination records compiled for this student yet.')
                else
                  ...exams.map((ex) {
                    final subjects = ex['subjects'] as List? ?? [];
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
                          }),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Document Management Section
          Container(
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
                        const Icon(Icons.folder_shared, color: AppColors.primary, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Student Document Repository', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddDocumentDialog,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Attach Document'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (_selectedDocuments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('No verification documents uploaded for this learner profile.'),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedDocuments.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final doc = _selectedDocuments[i];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primarySubtle,
                          child: Icon(Icons.description, color: AppColors.primary, size: 18),
                        ),
                        title: Text(doc['title'] ?? 'Document', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Type: ${doc['documentType']} • URL: ${doc['fileUrl']}', style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          tooltip: 'Delete Document',
                          onPressed: () => _showDeleteDocumentConfirmation(doc['id'], doc['title'] ?? 'Document'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildAdmissionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Form(
        key: _admissionFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Students', 'Admissions Office', 'New Learner'],
              title: 'Student Admission & Institutional Enrollment',
              subtitle: 'Register a new learner with automated admission number sequencing, guardian mapping, and class placement.',
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
                  Text('1. Student Identity & Demographics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameCtrl,
                          decoration: const InputDecoration(labelText: 'First Name *', hintText: 'Enter student first name'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'First name is required' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameCtrl,
                          decoration: const InputDecoration(labelText: 'Last Name *', hintText: 'Enter student surname'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Last name is required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dobCtrl,
                          decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)', hintText: '2012-05-18'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _genderCtrl.text,
                          decoration: const InputDecoration(labelText: 'Gender'),
                          items: const [
                            DropdownMenuItem(value: 'MALE', child: Text('Male')),
                            DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                            DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                          ],
                          onChanged: (val) {
                            if (val != null) _genderCtrl.text = val;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _bloodGroupCtrl.text,
                          decoration: const InputDecoration(labelText: 'Blood Group'),
                          items: const ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-']
                              .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) _bloodGroupCtrl.text = val;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(labelText: 'Residential Address', hintText: 'Full residential street address'),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  Text('2. Academic Placement & Section Allocation', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.lg),
                  StatefulBuilder(
                    builder: (context, setAllocState) {
                      final curSections = _admissionClassId != null
                          ? (_classes.firstWhere((c) => c['id'] == _admissionClassId, orElse: () => {'sections': []})['sections'] as List? ?? [])
                          : [];

                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _admissionClassId,
                              decoration: const InputDecoration(labelText: 'Target Class / Grade *'),
                              items: _classes.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']))).toList(),
                              onChanged: (val) {
                                setAllocState(() {
                                  _admissionClassId = val;
                                  final secs = _classes.firstWhere((c) => c['id'] == val)['sections'] as List? ?? [];
                                  _admissionSectionId = secs.isNotEmpty ? secs[0]['id'] : null;
                                });
                              },
                              validator: (val) => val == null ? 'Please select a class' : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _admissionSectionId,
                              decoration: const InputDecoration(labelText: 'Section Division'),
                              items: curSections.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))).toList(),
                              onChanged: (val) => setAllocState(() => _admissionSectionId = val),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TextFormField(
                              controller: _rollNoCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Class Roll No (Optional)', hintText: 'e.g. 15'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  Text('3. Parent & Guardian Contact Information', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _guardianNameCtrl,
                          decoration: const InputDecoration(labelText: 'Guardian Full Name *', hintText: 'Father or Mother name'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Guardian name required' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _guardianPhoneCtrl,
                          decoration: const InputDecoration(labelText: 'Guardian Mobile *', hintText: '+91 98765 43210'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Mobile number required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _guardianRelCtrl.text,
                          decoration: const InputDecoration(labelText: 'Relationship'),
                          items: const [
                            DropdownMenuItem(value: 'FATHER', child: Text('Father')),
                            DropdownMenuItem(value: 'MOTHER', child: Text('Mother')),
                            DropdownMenuItem(value: 'GUARDIAN', child: Text('Legal Guardian')),
                          ],
                          onChanged: (val) {
                            if (val != null) _guardianRelCtrl.text = val;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _guardianEmailCtrl,
                          decoration: const InputDecoration(labelText: 'Guardian Email Address', hintText: 'parent@example.com'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _tabController.animateTo(0),
                        child: const Text('Cancel & Return to Directory'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _isSubmittingAdmission ? null : _submitAdmission,
                        icon: _isSubmittingAdmission
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 16),
                        label: const Text('Complete Admission & Enrollment'),
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
}
