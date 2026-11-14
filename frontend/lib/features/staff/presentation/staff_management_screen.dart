import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _staffList = [];
  List<dynamic> _classes = [];
  List<dynamic> _subjects = [];
  List<dynamic> _workloadList = [];

  // Directory filter, search, sort, pagination
  String _searchQuery = '';
  String? _selectedRoleFilter;
  String _sortField = 'name';
  bool _sortAscending = true;
  int _currentPage = 1;
  final int _pageSize = 8;

  // Selected Staff Profile
  Map<String, dynamic>? _selectedStaff;

  // Staff Registration Form State
  final _staffFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController(text: 'Science');
  final _designationCtrl = TextEditingController(text: 'Senior Teacher');
  String _selectedRole = 'TEACHER';
  bool _isSubmittingStaff = false;

  // Allocation Form State
  String? _allocStaffId;
  String? _allocClassId;
  String? _allocSectionId;
  String? _allocSubjectId;
  bool _allocIsClassTeacher = false;
  bool _isSubmittingAlloc = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllStaffData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _qualificationCtrl.dispose();
    _departmentCtrl.dispose();
    _designationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllStaffData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient().dio.get('/staff').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/classes').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/subjects').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/reports/teacher-workload').then((r) => r.data as List? ?? []).catchError((_) => []),
      ]);

      setState(() {
        _staffList = results[0];
        _classes = results[1];
        _subjects = results[2];
        _workloadList = results[3];
        _isLoading = false;
      });

      if (_staffList.isNotEmpty && _selectedStaff == null) {
        _selectedStaff = _staffList[0];
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitStaffRegistration() async {
    if (!_staffFormKey.currentState!.validate()) return;

    setState(() => _isSubmittingStaff = true);
    try {
      await ApiClient().dio.post('/staff', data: {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': _selectedRole,
        'department': _departmentCtrl.text.trim(),
        'designation': _designationCtrl.text.trim(),
        'qualification': _qualificationCtrl.text.trim(),
        'password': 'password123',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff member registered successfully! Default password is password123'), backgroundColor: AppColors.success),
        );
        _staffFormKey.currentState!.reset();
        _nameCtrl.clear();
        _emailCtrl.clear();
        _phoneCtrl.clear();
        _qualificationCtrl.clear();
        _loadAllStaffData();
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingStaff = false);
    }
  }

  Future<void> _submitAllocation() async {
    if (_allocStaffId == null || _allocClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select staff member and class')));
      return;
    }

    setState(() => _isSubmittingAlloc = true);
    try {
      await ApiClient().dio.post('/staff/assignments', data: {
        'staffId': _allocStaffId,
        'classId': _allocClassId,
        'sectionId': _allocSectionId,
        'subjectId': _allocSubjectId,
        'isClassTeacher': _allocIsClassTeacher,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher allocation saved successfully!'), backgroundColor: AppColors.success),
        );
        _loadAllStaffData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Allocation failed: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingAlloc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading faculty directory and workload rosters...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Staff Management Unavailable',
        message: _errorMessage,
        onRetry: _loadAllStaffData,
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
                    Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Staff Directory'),
                    Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Faculty Profile'),
                    Tab(icon: Icon(Icons.person_add_outlined, size: 18), text: 'Staff Registration'),
                    Tab(icon: Icon(Icons.assignment_ind_outlined, size: 18), text: 'Teacher Allocation & Workload'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Faculty Data',
                onPressed: _loadAllStaffData,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStaffDirectoryTab(),
              _buildStaffProfileTab(),
              _buildStaffRegistrationTab(),
              _buildAllocationAndWorkloadTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffDirectoryTab() {
    var filtered = _staffList.where((st) {
      final matchesSearch = _searchQuery.isEmpty ||
          (st['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (st['email'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (st['department'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRoleFilter == null || st['role'] == _selectedRoleFilter;
      return matchesSearch && matchesRole;
    }).toList();

    filtered.sort((a, b) {
      int cmp = 0;
      if (_sortField == 'name') {
        cmp = (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      } else if (_sortField == 'department') {
        cmp = (a['department'] ?? '').toString().compareTo((b['department'] ?? '').toString());
      }
      return _sortAscending ? cmp : -cmp;
    });

    final totalCount = filtered.length;
    final totalPages = (totalCount / _pageSize).ceil();
    final safePage = _currentPage > totalPages && totalPages > 0 ? totalPages : _currentPage;
    final startIndex = (safePage - 1) * _pageSize;
    final pagedStaff = (startIndex < totalCount && startIndex >= 0)
        ? filtered.skip(startIndex).take(_pageSize).toList()
        : <dynamic>[];

    return RefreshIndicator(
      onRefresh: _loadAllStaffData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Faculty', 'Staff Management', 'Directory'],
              title: 'Faculty & Administrative Staff Directory',
              subtitle: 'Institutional directory of educators, subject teachers, and administrative officers.',
              actions: [
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(2),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Register Staff'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Total Faculty',
                    value: '${_staffList.length}',
                    icon: Icons.groups_outlined,
                    subtitle: 'Full Institutional Staff',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Teaching Faculty',
                    value: '${_staffList.where((s) => s['role'] == 'TEACHER').length}',
                    icon: Icons.school_outlined,
                    subtitle: 'Active Educators',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Administrative Staff',
                    value: '${_staffList.where((s) => s['role'] != 'TEACHER').length}',
                    icon: Icons.admin_panel_settings_outlined,
                    subtitle: 'Office & Executives',
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            SearchFilterBar(
              searchHint: 'Search staff by name, email, or department...',
              searchQuery: _searchQuery,
              onSearchChanged: (val) => setState(() {
                _searchQuery = val;
                _currentPage = 1;
              }),
              totalCount: totalCount,
              countLabel: 'Staff Members Listed',
              filters: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedRoleFilter,
                    hint: const Text('All Roles'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Roles')),
                      DropdownMenuItem(value: 'TEACHER', child: Text('Teachers')),
                      DropdownMenuItem(value: 'OFFICE', child: Text('Office Staff')),
                      DropdownMenuItem(value: 'PRINCIPAL', child: Text('Principals')),
                      DropdownMenuItem(value: 'SCHOOL_ADMIN', child: Text('School Admins')),
                    ],
                    onChanged: (val) => setState(() {
                      _selectedRoleFilter = val;
                      _currentPage = 1;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            if (pagedStaff.isEmpty)
              const EmptyStateView(
                icon: Icons.people_outline,
                title: 'No Matching Staff Members',
                description: 'Try adjusting your search criteria or role filters.',
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
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.8),
                        3: FlexColumnWidth(1.8),
                        4: FlexColumnWidth(1.2),
                        5: FlexColumnWidth(1.5),
                      },
                      border: TableBorder(
                        horizontalInside: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
                      ),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: AppColors.tableHeaderBg),
                          children: [
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Staff Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                        ...pagedStaff.map((st) {
                          final isSelected = _selectedStaff?['id'] == st['id'];
                          return TableRow(
                            decoration: BoxDecoration(color: isSelected ? AppColors.primarySubtle.withValues(alpha: 0.3) : Colors.transparent),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.secondarySubtle,
                                      child: Text((st['name'] as String).substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 12)),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(st['name'] ?? 'Staff', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          Text(st['email'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: StatusBadge.fromStatus(st['role'] ?? 'TEACHER')),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(st['department'] ?? 'General', style: const TextStyle(fontSize: 13))),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(st['designation'] ?? 'Staff', style: const TextStyle(fontSize: 13))),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: StatusBadge.fromStatus(st['status'] ?? 'ACTIVE')),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), visualDensity: VisualDensity.compact),
                                  onPressed: () {
                                    setState(() => _selectedStaff = st);
                                    _tabController.animateTo(1);
                                  },
                                  child: const Text('View Profile'),
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
                          Text('Showing ${startIndex + 1} to ${((startIndex + _pageSize) < totalCount ? (startIndex + _pageSize) : totalCount)} of $totalCount educators', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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

  Widget _buildStaffProfileTab() {
    if (_selectedStaff == null) {
      return const EmptyStateView(
        icon: Icons.person_off_outlined,
        title: 'No Staff Member Selected',
        description: 'Select an educator or officer from the directory to inspect their profile.',
      );
    }

    final st = _selectedStaff!;
    final assignments = st['teacherAssignments'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.secondarySubtle,
                child: Text(
                  (st['name'] as String).substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 24),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(st['name'], style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: AppSpacing.md),
                      StatusBadge.fromStatus(st['role'] ?? 'TEACHER'),
                    ],
                  ),
                  Text('${st['designation'] ?? 'Faculty'} • Department: ${st['department'] ?? 'General'} • Phone: ${st['phone'] ?? 'N/A'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Credentials Card
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
                      Text('Faculty Identity & Credentials', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Divider(height: 24),
                      _buildInfoRow('Full Legal Name', st['name']),
                      _buildInfoRow('Institutional Email', st['email']),
                      _buildInfoRow('Contact Phone', st['phone'] ?? 'Not Specified'),
                      _buildInfoRow('Qualification', st['qualification'] ?? 'Master of Science / Education'),
                      _buildInfoRow('Department', st['department'] ?? 'General'),
                      _buildInfoRow('Designation', st['designation'] ?? 'Teacher'),
                      _buildInfoRow('Joining Date', st['createdAt']?.toString().split('T')[0] ?? '2026-06-01'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),

              // Assigned Classes & Subjects
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Academic Class Allocations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          StatusBadge(label: '${assignments.length} Allocations', variant: BadgeVariant.info),
                        ],
                      ),
                      const Divider(height: 24),
                      if (assignments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Text('No class or subject assignments allocated to this educator yet.'),
                        )
                      else
                        ...assignments.map((a) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${a['class']?['name']} (${a['section']?['name']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('Subject: ${a['subject']?['name'] ?? 'Class Teacher Responsibility'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                                StatusBadge(
                                  label: a['isClassTeacher'] == true ? 'Class Teacher' : 'Subject Teacher',
                                  variant: a['isClassTeacher'] == true ? BadgeVariant.warning : BadgeVariant.success,
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
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

  Widget _buildStaffRegistrationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Form(
        key: _staffFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Faculty', 'Staff Management', 'Registration'],
              title: 'Staff Onboarding & Faculty Registration',
              subtitle: 'Register new academic educators or office personnel with automated secure credentials.',
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
                  Text('1. Staff Identity & Communication', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'Dr. Jane Smith'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email Address *', hintText: 'jsmith@school.edu'),
                          validator: (val) => val == null || !val.contains('@') ? 'Valid email required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+91 98765 00000'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(labelText: 'Institutional Role'),
                          items: const [
                            DropdownMenuItem(value: 'TEACHER', child: Text('Academic Teacher / Faculty')),
                            DropdownMenuItem(value: 'OFFICE', child: Text('Office Administration / Bursar')),
                            DropdownMenuItem(value: 'PRINCIPAL', child: Text('Principal / Academic Dean')),
                            DropdownMenuItem(value: 'SCHOOL_ADMIN', child: Text('School Administrator')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedRole = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  Text('2. Professional Credentials & Department', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _departmentCtrl,
                          decoration: const InputDecoration(labelText: 'Department', hintText: 'e.g. Mathematics & Computing'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _designationCtrl,
                          decoration: const InputDecoration(labelText: 'Designation / Title', hintText: 'e.g. Head of Department (HOD)'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _qualificationCtrl,
                          decoration: const InputDecoration(labelText: 'Highest Qualification', hintText: 'e.g. M.Sc, B.Ed'),
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
                        child: const Text('Cancel & Return'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _isSubmittingStaff ? null : _submitStaffRegistration,
                        icon: _isSubmittingStaff
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 16),
                        label: const Text('Complete Registration'),
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

  Widget _buildAllocationAndWorkloadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Faculty', 'Staff Management', 'Allocation & Workload'],
            title: 'Teacher Allocation & Workload Management',
            subtitle: 'Assign educators to specific grade divisions, designate class teachers, and monitor teaching hours.',
          ),
          const SizedBox(height: AppSpacing.xl),

          // Allocation Form Card
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
                Text('Assign Teacher to Class & Subject', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _allocStaffId,
                        decoration: const InputDecoration(labelText: 'Select Educator'),
                        items: _staffList.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))).toList(),
                        onChanged: (val) => setState(() => _allocStaffId = val),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _allocClassId,
                        decoration: const InputDecoration(labelText: 'Grade / Class'),
                        items: _classes.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _allocClassId = val;
                            final secs = _classes.firstWhere((c) => c['id'] == val, orElse: () => {'sections': []})['sections'] as List? ?? [];
                            _allocSectionId = secs.isNotEmpty ? secs[0]['id'] : null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _allocSectionId,
                        decoration: const InputDecoration(labelText: 'Section'),
                        items: (_allocClassId != null
                                ? (_classes.firstWhere((c) => c['id'] == _allocClassId, orElse: () => {'sections': []})['sections'] as List? ?? [])
                                : [])
                            .map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'])))
                            .toList(),
                        onChanged: (val) => setState(() => _allocSectionId = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _allocSubjectId,
                        decoration: const InputDecoration(labelText: 'Subject Allocation'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No Subject (Class Teacher Only)')),
                          ..._subjects.map<DropdownMenuItem<String>>((sub) => DropdownMenuItem(value: sub['id'] as String, child: Text(sub['name']))),
                        ],
                        onChanged: (val) => setState(() => _allocSubjectId = val),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: CheckboxListTile(
                        value: _allocIsClassTeacher,
                        title: const Text('Appoint as Class Teacher (Grants Attendance & Leave Authority)', style: TextStyle(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _allocIsClassTeacher = val ?? false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmittingAlloc ? null : _submitAllocation,
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Save Teacher Allocation'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Workload Management Table
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
                    Text('Faculty Teaching Workload Distribution', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    StatusBadge(
                      label: '${_workloadList.length} Active Educators Evaluated',
                      variant: BadgeVariant.success,
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (_workloadList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('No faculty workload analytics recorded.'),
                  )
                else
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.5),
                      1: FlexColumnWidth(2.5),
                      2: FlexColumnWidth(2.5),
                      3: FlexColumnWidth(1.5),
                      4: FlexColumnWidth(1.5),
                    },
                    border: TableBorder(
                      horizontalInside: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
                    ),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: AppColors.tableHeaderBg),
                        children: [
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Staff Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Assigned Classes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Assigned Subjects', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Weekly Periods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Load Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                      ..._workloadList.map((w) {
                        final periods = w['weeklyPeriodsCount'] ?? 0;
                        final classes = (w['assignedClasses'] as List? ?? []).join(', ');
                        final subjects = (w['assignedSubjects'] as List? ?? []).join(', ');
                        final isHigh = periods > 25;

                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(w['staffName'] ?? 'Faculty', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(classes.isEmpty ? 'General' : classes, style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(subjects.isEmpty ? 'Core' : subjects, style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('$periods Periods/Wk', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: StatusBadge(
                                label: isHigh ? 'Heavy Load' : 'Balanced',
                                variant: isHigh ? BadgeVariant.warning : BadgeVariant.success,
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
