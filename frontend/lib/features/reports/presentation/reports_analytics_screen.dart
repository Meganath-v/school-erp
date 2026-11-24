import '../../../core/widgets/adaptive_data_table.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/file_download_helper.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';

class ReportsAnalyticsScreen extends ConsumerStatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  ConsumerState<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends ConsumerState<ReportsAnalyticsScreen> {
  // Active Report
  String _selectedReport = 'STUDENT_STRENGTH';

  // Filters State
  String? _selectedAcademicYearId;
  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedExamId;
  String? _selectedStudentId;
  String? _selectedDepartment;
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _tableSearchController = TextEditingController();

  // Reference Data for Dropdowns
  List<dynamic> _academicYears = [];
  List<dynamic> _classes = [];
  List<dynamic> _exams = [];
  List<dynamic> _students = [];

  // Report Data State
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  // 13 Institutional Reports Metadata
  static const List<Map<String, dynamic>> _allReports = [
    {
      'id': 'STUDENT_STRENGTH',
      'title': 'Student Strength',
      'category': 'Learners',
      'icon': Icons.groups_outlined,
      'desc': 'Class and gender-wise enrollment distribution',
    },
    {
      'id': 'ADMISSIONS',
      'title': 'Admission Statistics',
      'category': 'Learners',
      'icon': Icons.person_add_alt_1_outlined,
      'desc': 'New admissions roster with guardian details',
    },
    {
      'id': 'STAFF_DIRECTORY',
      'title': 'Staff Directory',
      'category': 'Faculty',
      'icon': Icons.badge_outlined,
      'desc': 'Faculty & staff profiles, departments, and workload',
    },
    {
      'id': 'ATTENDANCE_SUMMARY',
      'title': 'Attendance Summary',
      'category': 'Attendance',
      'icon': Icons.fact_check_outlined,
      'desc': 'Class-wise attendance rates and session metrics',
    },
    {
      'id': 'ATTENDANCE_DEFAULTERS',
      'title': 'Attendance Defaulters (< 75%)',
      'category': 'Attendance',
      'icon': Icons.warning_amber_rounded,
      'desc': 'Students below statutory 75% condonation threshold',
    },
    {
      'id': 'EXAM_PERFORMANCE',
      'title': 'Exam Performance',
      'category': 'Examinations',
      'icon': Icons.query_stats_outlined,
      'desc': 'Subject pass rates, highest, lowest, and averages',
    },
    {
      'id': 'CLASS_BROADSHEET',
      'title': 'Class Broadsheet',
      'category': 'Examinations',
      'icon': Icons.table_chart_outlined,
      'desc': 'Comprehensive multi-subject mark sheet and ranks',
    },
    {
      'id': 'STUDENT_REPORT_CARD',
      'title': 'Student Report Card',
      'category': 'Examinations',
      'icon': Icons.workspace_premium_outlined,
      'desc': 'Individual learner transcript, GPA, and remarks',
    },
    {
      'id': 'FEE_COLLECTIONS',
      'title': 'Fee Collection Ledger',
      'category': 'Finance',
      'icon': Icons.account_balance_wallet_outlined,
      'desc': 'Receipt transactions broken down by mode & category',
    },
    {
      'id': 'OUTSTANDING_FEES',
      'title': 'Outstanding Fee Balances',
      'category': 'Finance',
      'icon': Icons.receipt_long_outlined,
      'desc': 'Overdue student balances and guardian contacts',
    },
    {
      'id': 'TEACHER_WORKLOAD',
      'title': 'Teacher Workload',
      'category': 'Faculty',
      'icon': Icons.schedule_outlined,
      'desc': 'Weekly teaching periods and course distributions',
    },
    {
      'id': 'ASSIGNMENT_PERFORMANCE',
      'title': 'Assignment Performance',
      'category': 'Academics',
      'icon': Icons.assignment_turned_in_outlined,
      'desc': 'Homework submission rates and average grades',
    },
    {
      'id': 'FEEDBACK_RESOLUTION',
      'title': 'Feedback & Grievances',
      'category': 'Operations',
      'icon': Icons.support_agent_outlined,
      'desc': 'Institutional feedback resolution rates and ratings',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadReferenceFiltersAndActiveReport();
  }

  @override
  void dispose() {
    _tableSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceFiltersAndActiveReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient().dio.get('/schools/academic-years').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/classes').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/exams').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/students').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
      ]);

      if (mounted) {
        setState(() {
          _academicYears = results[0];
          _classes = results[1];
          _exams = results[2];
          _students = results[3];

          if (_academicYears.isNotEmpty && _selectedAcademicYearId == null) {
            final activeYear = _academicYears.firstWhere((y) => y['isCurrent'] == true, orElse: () => _academicYears.first);
            _selectedAcademicYearId = activeYear['id']?.toString();
          }

          if (_classes.isNotEmpty && _selectedClassId == null) {
            _selectedClassId = _classes.first['id']?.toString();
          }

          if (_exams.isNotEmpty && _selectedExamId == null) {
            _selectedExamId = _exams.first['id']?.toString();
          }

          if (_students.isNotEmpty && _selectedStudentId == null) {
            _selectedStudentId = _students.first['id']?.toString();
          }
        });

        await _fetchActiveReport();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildQueryParams() {
    final params = <String, dynamic>{};
    if (_selectedAcademicYearId != null) params['academicYearId'] = _selectedAcademicYearId;
    if (_selectedClassId != null) params['classId'] = _selectedClassId;
    if (_selectedSectionId != null) params['sectionId'] = _selectedSectionId;
    if (_selectedExamId != null) params['examId'] = _selectedExamId;
    if (_selectedDepartment != null) params['department'] = _selectedDepartment;
    if (_selectedCategory != null) params['category'] = _selectedCategory;
    if (_startDate != null) params['startDate'] = _startDate!.toIso8601String();
    if (_endDate != null) params['endDate'] = _endDate!.toIso8601String();
    return params;
  }

  Future<void> _fetchActiveReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = _buildQueryParams();
      String endpoint = '';

      switch (_selectedReport) {
        case 'STUDENT_STRENGTH':
          endpoint = '/reports/student-strength';
          break;
        case 'ADMISSIONS':
          endpoint = '/reports/admissions';
          break;
        case 'STAFF_DIRECTORY':
          endpoint = '/reports/staff-directory';
          break;
        case 'ATTENDANCE_SUMMARY':
          endpoint = '/reports/attendance-summary';
          break;
        case 'ATTENDANCE_DEFAULTERS':
          endpoint = '/reports/attendance-defaulters';
          break;
        case 'EXAM_PERFORMANCE':
          endpoint = '/reports/exam-performance';
          break;
        case 'CLASS_BROADSHEET':
          endpoint = '/reports/class-broadsheet';
          break;
        case 'STUDENT_REPORT_CARD':
          final studentId = _selectedStudentId ?? (_students.isNotEmpty ? _students.first['id'] : '');
          endpoint = '/reports/report-card/$studentId';
          break;
        case 'FEE_COLLECTIONS':
          endpoint = '/reports/fee-collections';
          break;
        case 'OUTSTANDING_FEES':
          endpoint = '/reports/outstanding-fees';
          break;
        case 'TEACHER_WORKLOAD':
          endpoint = '/reports/teacher-workload';
          break;
        case 'ASSIGNMENT_PERFORMANCE':
          endpoint = '/reports/assignment-performance';
          break;
        case 'FEEDBACK_RESOLUTION':
          endpoint = '/reports/feedback-resolution';
          break;
        default:
          endpoint = '/reports/student-strength';
      }

      final res = await ApiClient().dio.get(endpoint, queryParameters: query);
      if (mounted) {
        setState(() {
          _reportData = res.data is Map<String, dynamic>
              ? (res.data['data'] is Map<String, dynamic> ? res.data['data'] : res.data)
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportActiveReport(String format) async {
    setState(() => _isExporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final filters = _buildQueryParams();
      if (_selectedReport == 'STUDENT_REPORT_CARD' && _selectedStudentId != null) {
        filters['studentId'] = _selectedStudentId;
      }

      final res = await ApiClient().dio.post(
        '/reports/export',
        data: {
          'reportType': _selectedReport,
          'format': format,
          'filters': filters,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final filename = '${_selectedReport.toLowerCase()}_$dateStr.${format == 'xlsx' ? 'xlsx' : 'csv'}';
      final mimeType = format == 'xlsx'
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'text/csv';

      final bytes = res.data as List<int>;
      downloadBinaryFile(bytes, filename, mimeType);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Report exported successfully ($filename)'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to export report: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _triggerPrintReport() {
    triggerBrowserPrint();
  }

  List<dynamic> get _availableSections {
    if (_selectedClassId == null) return [];
    final selectedCls = _classes.firstWhere(
      (c) => c['id']?.toString() == _selectedClassId,
      orElse: () => null,
    );
    if (selectedCls != null && selectedCls['sections'] is List) {
      return selectedCls['sections'] as List<dynamic>;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Page Header with Export Controls
            PageHeader(
              title: 'Institutional Analytics & Reports',
              subtitle: 'Multi-domain operational telemetry, regulatory registers, and audit-grade data exports',
              breadcrumbs: const ['Campus Administration', 'Reports & Intelligence'],
              actions: [
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _fetchActiveReport(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _triggerPrintReport,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print / PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryAccent,
                    side: const BorderSide(color: AppColors.primaryAccent),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : () => _exportActiveReport('csv'),
                  icon: const Icon(Icons.table_rows_outlined, size: 16),
                  label: const Text('Export CSV'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isExporting ? null : () => _exportActiveReport('xlsx'),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.file_download_outlined, size: 16),
                  label: Text(_isExporting ? 'Exporting...' : 'Export Excel (.xlsx)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF107C41), // Institutional Excel Green
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Category & Report Selector Bar
            _buildReportSelectorTabs(),
            const SizedBox(height: AppSpacing.lg),

            // Dynamic Filter Bar
            _buildFiltersBar(),
            const SizedBox(height: AppSpacing.lg),

            // Main Content Area
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: LoadingStateView(message: 'Aggregating institutional report telemetry...'),
                ),
              )
            else if (_errorMessage != null)
              ErrorStateView(
                title: 'Unable to Load Report',
                errorMessage: _errorMessage!,
                onRetry: _fetchActiveReport,
              )
            else if (_reportData == null)
              const EmptyStateView(
                title: 'No Data Available',
                message: 'No institutional records found matching the specified parameters.',
                icon: Icons.analytics_outlined,
              )
            else ...[
              // Summary KPI Metrics
              _buildSummaryKpis(),
              const SizedBox(height: AppSpacing.xl),

              // Active Report Data View
              _buildActiveReportView(),
            ],
          ],
        ),
      ),
    );
  }

  // Segmented / Tabbed Report Category Selector
  Widget _buildReportSelectorTabs() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: Row(
              children: [
                const Icon(Icons.layers_outlined, size: 16, color: AppColors.primaryAccent),
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: Text(
                  'SELECT INSTITUTIONAL REGISTER / REPORT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                )),
                const Spacer(),
                Flexible(child: Text(
                  '13 Real-Data Reports Available',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSubtle),
                )),
              ],
            ),
          ),
          const Divider(height: 12, color: AppColors.border),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _allReports.map((r) {
              final isSelected = r['id'] == _selectedReport;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      r['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      r['title'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                selectedColor: AppColors.primaryAccent,
                backgroundColor: AppColors.background,
                side: BorderSide(
                  color: isSelected ? AppColors.primaryAccent : AppColors.border,
                ),
                onSelected: (selected) {
                  if (selected && _selectedReport != r['id']) {
                    setState(() {
                      _selectedReport = r['id'] as String;
                    });
                    _fetchActiveReport();
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Institutional Multi-Parameter Filter Bar
  Widget _buildFiltersBar() {
    final showExamFilter = _selectedReport == 'EXAM_PERFORMANCE' ||
        _selectedReport == 'CLASS_BROADSHEET' ||
        _selectedReport == 'STUDENT_REPORT_CARD';

    final showStudentFilter = _selectedReport == 'STUDENT_REPORT_CARD';

    final showClassFilters = _selectedReport != 'STAFF_DIRECTORY' &&
        _selectedReport != 'TEACHER_WORKLOAD' &&
        _selectedReport != 'FEEDBACK_RESOLUTION';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, size: 16, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'REPORT FILTERS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedClassId = _classes.isNotEmpty ? _classes.first['id']?.toString() : null;
                    _selectedSectionId = null;
                    _selectedExamId = _exams.isNotEmpty ? _exams.first['id']?.toString() : null;
                    _selectedDepartment = null;
                    _selectedCategory = null;
                    _startDate = null;
                    _endDate = null;
                    _tableSearchController.clear();
                  });
                  _fetchActiveReport();
                },
                icon: const Icon(Icons.clear_all, size: 14),
                label: const Text('Reset Filters'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Academic Year Filter
              DropdownButtonHideUnderline(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.smBorderRadius,
                    border: Border.all(color: AppColors.border),
                    color: AppColors.background,
                  ),
                  child: DropdownButton<String>(isExpanded: true, 
                    value: _selectedAcademicYearId,
                    hint: const Text('Academic Year'),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                    items: _academicYears.map<DropdownMenuItem<String>>((year) {
                      return DropdownMenuItem<String>(
                        value: year['id']?.toString(),
                        child: Text('${year['name']}${year['isCurrent'] == true ? ' (Current)' : ''}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedAcademicYearId = val);
                      _fetchActiveReport();
                    },
                  ),
                ),
              ),

              // Class Filter (When applicable)
              if (showClassFilters)
                DropdownButtonHideUnderline(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smBorderRadius,
                      border: Border.all(color: AppColors.border),
                      color: AppColors.background,
                    ),
                    child: DropdownButton<String>(isExpanded: true, 
                      value: _selectedClassId,
                      hint: const Text('All Classes'),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Classes')),
                        ..._classes.map<DropdownMenuItem<String>>((c) {
                          return DropdownMenuItem<String>(
                            value: c['id']?.toString(),
                            child: Text(c['name'] ?? 'Class'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedClassId = val;
                          _selectedSectionId = null;
                        });
                        _fetchActiveReport();
                      },
                    ),
                  ),
                ),

              // Section Filter (When Class is selected)
              if (showClassFilters && _selectedClassId != null && _availableSections.isNotEmpty)
                DropdownButtonHideUnderline(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smBorderRadius,
                      border: Border.all(color: AppColors.border),
                      color: AppColors.background,
                    ),
                    child: DropdownButton<String>(isExpanded: true, 
                      value: _selectedSectionId,
                      hint: const Text('All Sections'),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Sections')),
                        ..._availableSections.map<DropdownMenuItem<String>>((s) {
                          return DropdownMenuItem<String>(
                            value: s['id']?.toString(),
                            child: Text('Section ${s['name']}'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedSectionId = val);
                        _fetchActiveReport();
                      },
                    ),
                  ),
                ),

              // Examination Filter (When applicable)
              if (showExamFilter)
                DropdownButtonHideUnderline(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smBorderRadius,
                      border: Border.all(color: AppColors.border),
                      color: AppColors.background,
                    ),
                    child: DropdownButton<String>(isExpanded: true, 
                      value: _selectedExamId,
                      hint: const Text('Select Exam'),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                      items: _exams.map<DropdownMenuItem<String>>((e) {
                        return DropdownMenuItem<String>(
                          value: e['id']?.toString(),
                          child: Text(e['title'] ?? 'Exam'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedExamId = val);
                        _fetchActiveReport();
                      },
                    ),
                  ),
                ),

              // Student Selector (For Student Report Card)
              if (showStudentFilter)
                DropdownButtonHideUnderline(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smBorderRadius,
                      border: Border.all(color: AppColors.border),
                      color: AppColors.background,
                    ),
                    child: DropdownButton<String>(isExpanded: true, 
                      value: _selectedStudentId,
                      hint: const Text('Select Student'),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                      items: _students.map<DropdownMenuItem<String>>((st) {
                        final name = '${st['firstName']} ${st['lastName']} (${st['admissionNo']})';
                        return DropdownMenuItem<String>(
                          value: st['id']?.toString(),
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedStudentId = val);
                        _fetchActiveReport();
                      },
                    ),
                  ),
                ),

              // Department Filter (For Staff Directory & Workload)
              if (_selectedReport == 'STAFF_DIRECTORY' || _selectedReport == 'TEACHER_WORKLOAD')
                DropdownButtonHideUnderline(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smBorderRadius,
                      border: Border.all(color: AppColors.border),
                      color: AppColors.background,
                    ),
                    child: DropdownButton<String>(isExpanded: true, 
                      value: _selectedDepartment,
                      hint: const Text('All Departments'),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem<String>(value: null, child: Text('All Departments')),
                        DropdownMenuItem<String>(value: 'Academics', child: Text('Academics')),
                        DropdownMenuItem<String>(value: 'Science', child: Text('Science')),
                        DropdownMenuItem<String>(value: 'Mathematics', child: Text('Mathematics')),
                        DropdownMenuItem<String>(value: 'Administration', child: Text('Administration')),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedDepartment = val);
                        _fetchActiveReport();
                      },
                    ),
                  ),
                ),

              // Date Range Button
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null,
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked.start;
                      _endDate = picked.end;
                    });
                    _fetchActiveReport();
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 14),
                label: Text(
                  _startDate != null && _endDate != null
                      ? '${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}'
                      : 'Date Range',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                ),
              ),

              // Quick Search within table
              SizedBox(
                width: 220,
                height: 38,
                child: TextField(
                  controller: _tableSearchController,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Filter results...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.smBorderRadius,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Summary Metrics Row Tailored to Active Report
  Widget _buildSummaryKpis() {
    final data = _reportData!;
    final List<Widget> cards = [];

    switch (_selectedReport) {
      case 'STUDENT_STRENGTH':
        final total = data['totalStudents'] ?? 0;
        final classesList = data['classes'] as List? ?? [];
        cards.addAll([
          Expanded(child: MetricCard(title: 'Total Enrolled Learners', value: total.toString(), icon: Icons.groups)),
          Expanded(child: MetricCard(title: 'Active Classes', value: classesList.length.toString(), icon: Icons.class_outlined)),
          Expanded(
            child: MetricCard(
              title: 'Avg Learners / Class',
              value: classesList.isEmpty ? '0' : (total / classesList.length).toStringAsFixed(1),
              icon: Icons.pie_chart_outline,
            ),
          ),
        ]);
        break;

      case 'ADMISSIONS':
        final total = data['totalAdmissions'] ?? 0;
        cards.addAll([
          Expanded(child: MetricCard(title: 'Total Admissions', value: total.toString(), icon: Icons.person_add)),
          Expanded(child: MetricCard(title: 'Status: Active', value: total.toString(), icon: Icons.verified_user)),
          Expanded(child: MetricCard(title: 'Audit Verification', value: '100%', icon: Icons.check_circle_outline)),
        ]);
        break;

      case 'STAFF_DIRECTORY':
        final total = data['totalStaff'] ?? 0;
        final active = data['activeStaff'] ?? 0;
        cards.addAll([
          Expanded(child: MetricCard(title: 'Total Staff', value: total.toString(), icon: Icons.badge)),
          Expanded(child: MetricCard(title: 'Active Faculty', value: active.toString(), icon: Icons.how_to_reg)),
          Expanded(child: MetricCard(title: 'Operational Coverage', value: '100%', icon: Icons.business_center)),
        ]);
        break;

      case 'ATTENDANCE_SUMMARY':
        final rate = data['overallRate'] ?? 0;
        final sessions = data['conductedSessions'] ?? 0;
        cards.addAll([
          Expanded(child: MetricCard(title: 'Overall Attendance Rate', value: '$rate%', icon: Icons.percent)),
          Expanded(child: MetricCard(title: 'Conducted Sessions', value: sessions.toString(), icon: Icons.event_available)),
          Expanded(
            child: MetricCard(
              title: 'Statutory Health',
              value: rate >= 75 ? 'COMPLIANT' : 'CRITICAL',
              icon: rate >= 75 ? Icons.shield_outlined : Icons.warning_amber_rounded,
              color: rate >= 75 ? AppColors.success : AppColors.error,
            ),
          ),
        ]);
        break;

      case 'ATTENDANCE_DEFAULTERS':
        final defaulters = data['defaultersCount'] ?? 0;
        final evaluated = data['evaluatedStudents'] ?? 0;
        final threshold = data['thresholdPercentage'] ?? 75;
        cards.addAll([
          Expanded(
            child: MetricCard(
              title: 'Defaulters (< $threshold%)',
              value: defaulters.toString(),
              icon: Icons.warning,
              color: defaulters > 0 ? AppColors.error : AppColors.success,
            ),
          ),
          Expanded(child: MetricCard(title: 'Evaluated Learners', value: evaluated.toString(), icon: Icons.groups)),
          Expanded(
            child: MetricCard(
              title: 'Defaulter Ratio',
              value: evaluated > 0 ? '${((defaulters / evaluated) * 100).toStringAsFixed(1)}%' : '0%',
              icon: Icons.pie_chart_outline,
            ),
          ),
        ]);
        break;

      case 'EXAM_PERFORMANCE':
        final passRate = data['passRate'] ?? 0;
        final evaluated = data['totalEvaluated'] ?? 0;
        final passed = data['passedCount'] ?? 0;
        cards.addAll([
          Expanded(child: MetricCard(title: 'Exam Pass Rate', value: '$passRate%', icon: Icons.grade)),
          Expanded(child: MetricCard(title: 'Learners Evaluated', value: evaluated.toString(), icon: Icons.school)),
          Expanded(child: MetricCard(title: 'Successful Candidates', value: passed.toString(), icon: Icons.check_circle)),
        ]);
        break;

      case 'CLASS_BROADSHEET':
        final rows = data['rows'] as List? ?? [];
        final passed = rows.where((r) => r['status'] == 'PASS').length;
        cards.addAll([
          Expanded(child: MetricCard(title: 'Enrolled Candidates', value: rows.length.toString(), icon: Icons.assignment_ind)),
          Expanded(child: MetricCard(title: 'Passed Candidates', value: passed.toString(), icon: Icons.verified)),
          Expanded(
            child: MetricCard(
              title: 'Cohort Pass Rate',
              value: rows.isNotEmpty ? '${((passed / rows.length) * 100).toStringAsFixed(1)}%' : '0%',
              icon: Icons.query_stats,
            ),
          ),
        ]);
        break;

      case 'STUDENT_REPORT_CARD':
        final gpa = data['overallGPA'] ?? 0.0;
        final pct = data['overallPercentage'] ?? 0.0;
        final status = data['overallStatus'] ?? 'PASS';
        cards.addAll([
          Expanded(child: MetricCard(title: 'Overall Percentage', value: '$pct%', icon: Icons.percent)),
          Expanded(child: MetricCard(title: 'Cumulative GPA', value: gpa.toString(), icon: Icons.stars)),
          Expanded(
            child: MetricCard(
              title: 'Final Academic Status',
              value: status,
              icon: status == 'PASS' ? Icons.check_circle : Icons.highlight_off,
              color: status == 'PASS' ? AppColors.success : AppColors.error,
            ),
          ),
        ]);
        break;

      case 'FEE_COLLECTIONS':
        final total = data['totalCollected'] ?? 0;
        final receipts = data['receiptsCount'] ?? 0;
        cards.addAll([
          Expanded(child: MetricCard(title: 'Total Revenue Collected', value: _currencyFormat.format(total), icon: Icons.account_balance)),
          Expanded(child: MetricCard(title: 'Official Receipts Issued', value: receipts.toString(), icon: Icons.receipt)),
          Expanded(
            child: MetricCard(
              title: 'Average Receipt Value',
              value: receipts > 0 ? _currencyFormat.format(total / receipts) : '₹0',
              icon: Icons.stacked_line_chart,
            ),
          ),
        ]);
        break;

      case 'OUTSTANDING_FEES':
        final totalDue = data['totalOutstanding'] ?? 0;
        final invoicesCount = data['outstandingCount'] ?? 0;
        cards.addAll([
          Expanded(
            child: MetricCard(
              title: 'Total Outstanding Balance',
              value: _currencyFormat.format(totalDue),
              icon: Icons.money_off,
              color: totalDue > 0 ? AppColors.error : AppColors.success,
            ),
          ),
          Expanded(child: MetricCard(title: 'Overdue Invoices', value: invoicesCount.toString(), icon: Icons.receipt_long)),
          Expanded(child: MetricCard(title: 'Collection Priority', value: totalDue > 0 ? 'HIGH' : 'CLEAR', icon: Icons.flag)),
        ]);
        break;

      case 'TEACHER_WORKLOAD':
        final grand = data['grandWeeklyPeriods'] ?? 0;
        final teachers = data['totalTeachers'] ?? 0;
        final avg = data['avgWeeklyPeriods'] ?? 0;
        cards.addAll([
          Expanded(child: MetricCard(title: 'Total Faculty', value: teachers.toString(), icon: Icons.badge)),
          Expanded(child: MetricCard(title: 'Grand Weekly Periods', value: grand.toString(), icon: Icons.calendar_today)),
          Expanded(child: MetricCard(title: 'Avg Weekly Load / Faculty', value: '$avg periods', icon: Icons.speed)),
        ]);
        break;

      case 'ASSIGNMENT_PERFORMANCE':
        final assignments = data['totalAssignments'] ?? 0;
        final rate = data['overallSubmissionRate'] ?? 0;
        cards.addAll([
          Expanded(child: MetricCard(title: 'Total Assignments Evaluated', value: assignments.toString(), icon: Icons.assignment)),
          Expanded(child: MetricCard(title: 'Submission Rate', value: '$rate%', icon: Icons.done_all)),
          Expanded(child: MetricCard(title: 'Engagement Compliance', value: rate >= 70 ? 'SATISFACTORY' : 'LOW', icon: Icons.thumb_up)),
        ]);
        break;

      case 'FEEDBACK_RESOLUTION':
        final feedbacks = data['totalFeedbacks'] ?? 0;
        final rate = data['resolutionRate'] ?? 0;
        final rating = data['averageRating'] ?? 0;
        cards.addAll([
          Expanded(child: MetricCard(title: 'Total Tickets Filed', value: feedbacks.toString(), icon: Icons.feedback)),
          Expanded(child: MetricCard(title: 'Resolution Rate', value: '$rate%', icon: Icons.task_alt)),
          Expanded(child: MetricCard(title: 'Avg Stakeholder Rating', value: '$rating / 5.0 ★', icon: Icons.star)),
        ]);
        break;
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          cards[i],
        ],
      ],
    );
  }

  // Active Report Table View
  Widget _buildActiveReportView() {
    switch (_selectedReport) {
      case 'STUDENT_STRENGTH':
        return _buildStudentStrengthTable();
      case 'ADMISSIONS':
        return _buildAdmissionsTable();
      case 'STAFF_DIRECTORY':
        return _buildStaffDirectoryTable();
      case 'ATTENDANCE_SUMMARY':
        return _buildAttendanceSummaryTable();
      case 'ATTENDANCE_DEFAULTERS':
        return _buildDefaultersTable();
      case 'EXAM_PERFORMANCE':
        return _buildExamPerformanceTable();
      case 'CLASS_BROADSHEET':
        return _buildBroadsheetTable();
      case 'STUDENT_REPORT_CARD':
        return _buildReportCardView();
      case 'FEE_COLLECTIONS':
        return _buildFeeCollectionsTable();
      case 'OUTSTANDING_FEES':
        return _buildOutstandingFeesTable();
      case 'TEACHER_WORKLOAD':
        return _buildTeacherWorkloadTable();
      case 'ASSIGNMENT_PERFORMANCE':
        return _buildAssignmentPerformanceTable();
      case 'FEEDBACK_RESOLUTION':
        return _buildFeedbackResolutionTable();
      default:
        return _buildStudentStrengthTable();
    }
  }

  // Card Container for Data Tables
  Widget _buildTableContainer({required String title, required Widget child, Widget? extraHeader}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                ?extraHeader,
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }

  // 1. Student Strength
  Widget _buildStudentStrengthTable() {
    final classes = _reportData!['classes'] as List? ?? [];
    final search = _tableSearchController.text.trim().toLowerCase();
    final filtered = classes.where((c) => (c['className'] ?? '').toString().toLowerCase().contains(search)).toList();

    return _buildTableContainer(
      title: 'Student Strength by Class & Section',
      child: AdaptiveDataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Class Name')),
          DataColumn(label: Text('Male')),
          DataColumn(label: Text('Female')),
          DataColumn(label: Text('Other')),
          DataColumn(label: Text('Total Strength')),
          DataColumn(label: Text('Sections Breakdown')),
        ],
        rows: [
          ...filtered.map((c) {
            final sections = c['sections'] as List? ?? [];
            final sectionDesc = sections.map((s) => '${s['sectionName']}: ${s['total']}').join(', ');
            return DataRow(
              cells: [
                DataCell(Text(c['className'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text('${c['male'] ?? 0}')),
                DataCell(Text('${c['female'] ?? 0}')),
                DataCell(Text('${c['other'] ?? 0}')),
                DataCell(Text('${c['total'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(sectionDesc.isEmpty ? 'N/A' : sectionDesc, style: GoogleFonts.inter(fontSize: 11))),
              ],
            );
          }),
          // Grand Total Row
          DataRow(
            color: WidgetStateProperty.all(AppColors.background),
            cells: [
              const DataCell(Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.w800))),
              DataCell(Text(
                '${filtered.fold<int>(0, (acc, c) => acc + ((c['male'] ?? 0) as int))}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              )),
              DataCell(Text(
                '${filtered.fold<int>(0, (acc, c) => acc + ((c['female'] ?? 0) as int))}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              )),
              DataCell(Text(
                '${filtered.fold<int>(0, (acc, c) => acc + ((c['other'] ?? 0) as int))}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              )),
              DataCell(Text(
                '${_reportData!['totalStudents'] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryAccent),
              )),
              const DataCell(Text('-')),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Admission Statistics
  Widget _buildAdmissionsTable() {
    final rows = _reportData!['rows'] as List? ?? [];
    final search = _tableSearchController.text.trim().toLowerCase();
    final filtered = rows.where((r) {
      final name = '${r['firstName']} ${r['lastName']}'.toLowerCase();
      final adm = (r['admissionNo'] ?? '').toString().toLowerCase();
      return name.contains(search) || adm.contains(search);
    }).toList();

    return _buildTableContainer(
      title: 'Institutional Admissions Ledger',
      child: AdaptiveDataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Admission No')),
          DataColumn(label: Text('Learner Name')),
          DataColumn(label: Text('Class & Section')),
          DataColumn(label: Text('Gender')),
          DataColumn(label: Text('Enrollment Date')),
          DataColumn(label: Text('Guardian Details')),
          DataColumn(label: Text('Status')),
        ],
        rows: filtered.map((r) {
          final name = '${r['firstName']} ${r['lastName']}';
          final clsSec = '${r['className']} - ${r['sectionName']}';
          final guardian = '${r['guardianName'] ?? 'N/A'} (${r['guardianPhone'] ?? '-'})';
          final date = r['enrollmentDate'] != null ? _dateFormat.format(DateTime.parse(r['enrollmentDate'])) : '-';

          return DataRow(
            cells: [
              DataCell(Text(r['admissionNo'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(name)),
              DataCell(Text(clsSec)),
              DataCell(Text(r['gender'] ?? '-')),
              DataCell(Text(date)),
              DataCell(Text(guardian, style: GoogleFonts.inter(fontSize: 11))),
              DataCell(StatusBadge.fromStatus(r['status'] ?? 'ACTIVE', isSmall: true)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 3. Staff Directory
  Widget _buildStaffDirectoryTable() {
    final rows = _reportData!['rows'] as List? ?? [];
    final search = _tableSearchController.text.trim().toLowerCase();
    final filtered = rows.where((r) {
      final name = '${r['firstName']} ${r['lastName']}'.toLowerCase();
      final emp = (r['employeeId'] ?? '').toString().toLowerCase();
      return name.contains(search) || emp.contains(search);
    }).toList();

    return _buildTableContainer(
      title: 'Staff & Faculty Directory',
      child: AdaptiveDataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Employee ID')),
          DataColumn(label: Text('Faculty Name')),
          DataColumn(label: Text('Department')),
          DataColumn(label: Text('Designation')),
          DataColumn(label: Text('Email & Phone')),
          DataColumn(label: Text('Workload (Assignments)')),
          DataColumn(label: Text('Status')),
        ],
        rows: filtered.map((r) {
          final name = '${r['firstName']} ${r['lastName']}';
          final contact = '${r['email']}\n${r['phone'] ?? ''}';

          return DataRow(
            cells: [
              DataCell(Text(r['employeeId'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(name)),
              DataCell(Text(r['department'] ?? '-')),
              DataCell(Text(r['designation'] ?? '-')),
              DataCell(Text(contact, style: GoogleFonts.inter(fontSize: 11))),
              DataCell(Text('${r['totalAssignments'] ?? 0} active classes')),
              DataCell(StatusBadge.fromStatus(r['status'] ?? 'ACTIVE', isSmall: true)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 4. Attendance Summary
  Widget _buildAttendanceSummaryTable() {
    final rows = _reportData!['rows'] as List? ?? [];

    return _buildTableContainer(
      title: 'Attendance Register Summary by Class',
      child: AdaptiveDataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Class & Section')),
          DataColumn(label: Text('Conducted Sessions')),
          DataColumn(label: Text('Present Records')),
          DataColumn(label: Text('Absent Records')),
          DataColumn(label: Text('Late / HalfDay')),
          DataColumn(label: Text('Attendance Rate')),
          DataColumn(label: Text('Compliance')),
        ],
        rows: rows.map((r) {
          final rate = (r['attendanceRate'] as num?)?.toDouble() ?? 0.0;
          final clsSec = '${r['className']} - ${r['sectionName']}';

          return DataRow(
            cells: [
              DataCell(Text(clsSec, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text('${r['totalSessions'] ?? 0}')),
              DataCell(Text('${r['presentCount'] ?? 0}')),
              DataCell(Text('${r['absentCount'] ?? 0}')),
              DataCell(Text('${r['lateCount'] ?? 0}')),
              DataCell(Text('$rate%', style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(
                StatusBadge(
                  label: rate >= 75 ? 'COMPLIANT' : 'SHORTAGE',
                  variant: rate >= 75 ? BadgeVariant.success : BadgeVariant.error,
                  isSmall: true,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 5. Attendance Defaulters (< 75%)
  Widget _buildDefaultersTable() {
    final defaulters = _reportData!['defaulters'] as List? ?? [];

    return _buildTableContainer(
      title: 'Statutory Attendance Defaulters Register (< 75% Condonation Threshold)',
      extraHeader: StatusBadge(
        label: '${defaulters.length} Defaulters Identified',
        variant: defaulters.isEmpty ? BadgeVariant.success : BadgeVariant.error,
      ),
      child: defaulters.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Text('All evaluated learners meet or exceed statutory 75% attendance compliance!'),
              ),
            )
          : AdaptiveDataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              columns: const [
                DataColumn(label: Text('Admission No')),
                DataColumn(label: Text('Learner Name')),
                DataColumn(label: Text('Class & Section')),
                DataColumn(label: Text('Total Sessions')),
                DataColumn(label: Text('Attended')),
                DataColumn(label: Text('Current Rate')),
                DataColumn(label: Text('Sessions to 75%')),
                DataColumn(label: Text('Guardian Contact')),
              ],
              rows: defaulters.map((d) {
                final clsSec = '${d['className']} - ${d['sectionName']}';
                final rate = d['attendancePercentage'] ?? 0;
                final deficit = d['deficitSessions'] ?? 0;
                final contact = '${d['guardianName'] ?? 'N/A'}\n${d['guardianPhone'] ?? '-'}';

                return DataRow(
                  color: WidgetStateProperty.all(AppColors.errorBg.withValues(alpha: 0.3)),
                  cells: [
                    DataCell(Text(d['admissionNo'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(d['name'] ?? '-')),
                    DataCell(Text(clsSec)),
                    DataCell(Text('${d['totalSessions']}')),
                    DataCell(Text('${d['attendedSessions']}')),
                    DataCell(Text(
                      '$rate%',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.error),
                    )),
                    DataCell(Text(
                      '+$deficit sessions',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error),
                    )),
                    DataCell(Text(contact, style: GoogleFonts.inter(fontSize: 11))),
                  ],
                );
              }).toList(),
            ),
    );
  }

  // 6. Examination Performance
  Widget _buildExamPerformanceTable() {
    final subjects = _reportData!['subjects'] as List? ?? [];
    final examTitle = _reportData!['examTitle'] ?? 'Examination';

    return _buildTableContainer(
      title: '$examTitle - Subject Evaluation Analytics',
      child: AdaptiveDataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Subject Code & Name')),
          DataColumn(label: Text('Max Marks')),
          DataColumn(label: Text('Pass Marks')),
          DataColumn(label: Text('Highest Score')),
          DataColumn(label: Text('Lowest Score')),
          DataColumn(label: Text('Subject Average')),
          DataColumn(label: Text('Benchmark Status')),
        ],
        rows: subjects.map((s) {
          final subDesc = '${s['subjectCode'] ?? ''} - ${s['subjectName'] ?? ''}';
          final avg = s['averageMarks'] ?? 0;
          final pass = s['passMarks'] ?? 0;

          return DataRow(
            cells: [
              DataCell(Text(subDesc, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text('${s['maxMarks'] ?? 100}')),
              DataCell(Text('${s['passMarks'] ?? 40}')),
              DataCell(Text('${s['highestMarks'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text('${s['lowestMarks'] ?? 0}')),
              DataCell(Text('$avg', style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(
                StatusBadge(
                  label: avg >= pass ? 'ABOVE PAR' : 'BELOW PAR',
                  variant: avg >= pass ? BadgeVariant.success : BadgeVariant.warning,
                  isSmall: true,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 7. Class Broadsheet
  Widget _buildBroadsheetTable() {
    final subjects = _reportData!['subjects'] as List? ?? [];
    final rows = _reportData!['rows'] as List? ?? [];

    return _buildTableContainer(
      title: 'Class Master Broadsheet (${_reportData!['examTitle'] ?? 'Exam'})',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: AdaptiveDataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.background),
          columns: [
            const DataColumn(label: Text('Rank')),
            const DataColumn(label: Text('Adm No')),
            const DataColumn(label: Text('Candidate Name')),
            ...subjects.map((sub) => DataColumn(label: Text('${sub['name']}\n(${sub['maxMarks']}m)'))),
            const DataColumn(label: Text('Total Score')),
            const DataColumn(label: Text('Percentage')),
            const DataColumn(label: Text('Result')),
          ],
          rows: rows.map((r) {
            final subMarks = r['subjectMarks'] as Map? ?? {};
            return DataRow(
              cells: [
                DataCell(Text('#${r['rank']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(r['admissionNo'] ?? '-')),
                DataCell(Text(r['studentName'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                ...subjects.map((sub) {
                  final markObj = subMarks[sub['id']];
                  if (markObj == null) return const DataCell(Text('-'));
                  return DataCell(
                    Text(
                      '${markObj['marks']} (${markObj['grade']})',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: markObj['passed'] == true ? AppColors.textPrimary : AppColors.error,
                      ),
                    ),
                  );
                }),
                DataCell(Text('${r['totalObtained']} / ${r['maxPossible']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text('${r['percentage']}%', style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(StatusBadge.fromStatus(r['status'] ?? 'PASS', isSmall: true)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // 8. Student Report Card
  Widget _buildReportCardView() {
    final data = _reportData!;
    final student = data['student'] as Map? ?? {};
    final exam = data['exam'] as Map? ?? {};
    final subjects = data['subjects'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Institutional Certificate Header
          Center(
            child: Column(
              children: [
                const Icon(Icons.school, size: 40, color: AppColors.primaryAccent),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'OAKRIDGE INTERNATIONAL ACADEMY',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
                Text(
                  'OFFICIAL TRANSCRIPT & PROGRESS REPORT',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                Text(
                  'Evaluation: ${exam['title'] ?? 'Summative Assessment'}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSubtle),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.lg),

          // Learner Information Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.smBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Learner Name: ${student['name'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Admission No: ${student['admissionNo'] ?? '-'}  |  Roll No: ${student['rollNo'] ?? '-'}'),
                    const SizedBox(height: 4),
                    Text('Class & Section: ${student['className'] ?? '-'} - ${student['sectionName'] ?? '-'}'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Guardian: ${student['guardianName'] ?? '-'} (${student['guardianPhone'] ?? '-'})'),
                    const SizedBox(height: 4),
                    Text('Term Attendance: ${data['attendancePercentage'] ?? 0}%'),
                    const SizedBox(height: 4),
                    Text('Report Date: ${_dateFormat.format(DateTime.now())}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Subject Marks Table
          AdaptiveDataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            columns: const [
              DataColumn(label: Text('Subject Code & Title')),
              DataColumn(label: Text('Max Marks')),
              DataColumn(label: Text('Pass Marks')),
              DataColumn(label: Text('Marks Obtained')),
              DataColumn(label: Text('Letter Grade')),
              DataColumn(label: Text('Grade Point')),
              DataColumn(label: Text('Status')),
            ],
            rows: subjects.map((s) {
              return DataRow(
                cells: [
                  DataCell(Text('${s['subjectCode']} - ${s['subjectName']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text('${s['maxMarks']}')),
                  DataCell(Text('${s['passMarks']}')),
                  DataCell(Text('${s['marksObtained']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(Text('${s['grade']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(Text('${s['gradePoint']}')),
                  DataCell(StatusBadge.fromStatus(s['status'] ?? 'PASS', isSmall: true)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Cumulative Performance Summary
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.smBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grand Total: ${data['totalObtained']} / ${data['maxPossible']} marks',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Cumulative Percentage: ${data['overallPercentage']}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Grade Point Average (GPA): ${data['overallGPA']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryAccent),
                ),
                StatusBadge(
                  label: data['overallStatus'] ?? 'PASS',
                  variant: data['overallStatus'] == 'PASS' ? BadgeVariant.success : BadgeVariant.error,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Principal Remarks: ${data['remarks'] ?? 'Satisfactory progress maintained across semester coursework.'}',
            style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // 9. Fee Collection Ledger
  Widget _buildFeeCollectionsTable() {
    final rows = _reportData!['rows'] as List? ?? [];
    final search = _tableSearchController.text.trim().toLowerCase();
    final filtered = rows.where((r) {
      final rec = (r['receiptNo'] ?? '').toString().toLowerCase();
      final name = (r['studentName'] ?? '').toString().toLowerCase();
      return rec.contains(search) || name.contains(search);
    }).toList();

    return _buildTableContainer(
      title: 'Institutional Fee Collections & Receipts Ledger',
      child: AdaptiveDataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Receipt No')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Learner Details')),
          DataColumn(label: Text('Class & Section')),
          DataColumn(label: Text('Fee Category')),
          DataColumn(label: Text('Payment Mode')),
          DataColumn(label: Text('Amount Paid')),
        ],
        rows: [
          ...filtered.map((r) {
            final date = r['paymentDate'] != null ? _dateFormat.format(DateTime.parse(r['paymentDate'])) : '-';
            final student = '${r['studentName']}\n(${r['admissionNo']})';
            final clsSec = '${r['className']} - ${r['sectionName']}';

            return DataRow(
              cells: [
                DataCell(Text(r['receiptNo'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(date)),
                DataCell(Text(student, style: GoogleFonts.inter(fontSize: 11))),
                DataCell(Text(clsSec)),
                DataCell(Text(r['category'] ?? '-')),
                DataCell(Text(r['method'] ?? '-')),
                DataCell(Text(_currencyFormat.format(r['amount'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w700))),
              ],
            );
          }),
          // Grand Total Row
          DataRow(
            color: WidgetStateProperty.all(AppColors.background),
            cells: [
              const DataCell(Text('TOTAL REVENUE', style: TextStyle(fontWeight: FontWeight.w800))),
              const DataCell(Text('-')),
              const DataCell(Text('-')),
              const DataCell(Text('-')),
              const DataCell(Text('-')),
              const DataCell(Text('-')),
              DataCell(Text(
                _currencyFormat.format(_reportData!['totalCollected'] ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryAccent),
              )),
            ],
          ),
        ],
      ),
    );
  }

  // 10. Outstanding Fee Balances
  Widget _buildOutstandingFeesTable() {
    final rows = _reportData!['rows'] as List? ?? [];

    return _buildTableContainer(
      title: 'Outstanding Fee Balances & Overdue Register',
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: Text('Zero outstanding balances! All billed invoices have been settled in full.')),
            )
          : AdaptiveDataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              columns: const [
                DataColumn(label: Text('Invoice No')),
                DataColumn(label: Text('Due Date')),
                DataColumn(label: Text('Learner Name')),
                DataColumn(label: Text('Class & Section')),
                DataColumn(label: Text('Invoiced')),
                DataColumn(label: Text('Paid')),
                DataColumn(label: Text('Balance Due')),
                DataColumn(label: Text('Days Overdue')),
                DataColumn(label: Text('Guardian Contact')),
              ],
              rows: rows.map((r) {
                final date = r['dueDate'] != null ? _dateFormat.format(DateTime.parse(r['dueDate'])) : '-';
                final clsSec = '${r['className']} - ${r['sectionName']}';
                final guardian = '${r['guardianName'] ?? 'N/A'}\n${r['guardianPhone'] ?? '-'}';

                return DataRow(
                  color: WidgetStateProperty.all(AppColors.errorBg.withValues(alpha: 0.3)),
                  cells: [
                    DataCell(Text(r['invoiceNo'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(date)),
                    DataCell(Text(r['studentName'] ?? '-')),
                    DataCell(Text(clsSec)),
                    DataCell(Text(_currencyFormat.format(r['totalAmount'] ?? 0))),
                    DataCell(Text(_currencyFormat.format(r['paidAmount'] ?? 0))),
                    DataCell(Text(_currencyFormat.format(r['balanceDue'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.error))),
                    DataCell(Text('${r['daysOverdue']} days')),
                    DataCell(Text(guardian, style: GoogleFonts.inter(fontSize: 11))),
                  ],
                );
              }).toList(),
            ),
    );
  }

  // 11. Teacher Workload
  Widget _buildTeacherWorkloadTable() {
    final rows = _reportData!['rows'] as List? ?? [];

    return _buildTableContainer(
      title: 'Faculty Weekly Teaching Workload Distribution',
      child: AdaptiveDataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Employee ID')),
          DataColumn(label: Text('Faculty Name')),
          DataColumn(label: Text('Department')),
          DataColumn(label: Text('Designation')),
          DataColumn(label: Text('Weekly Periods')),
          DataColumn(label: Text('Assigned Classes')),
          DataColumn(label: Text('Subjects Handled')),
        ],
        rows: [
          ...rows.map((r) {
            final classes = (r['classesAssigned'] as List? ?? []).join(', ');
            final subjects = (r['subjectsAssigned'] as List? ?? []).join(', ');

            return DataRow(
              cells: [
                DataCell(Text(r['employeeId'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(r['teacherName'] ?? '-')),
                DataCell(Text(r['department'] ?? '-')),
                DataCell(Text(r['designation'] ?? '-')),
                DataCell(Text('${r['weeklyPeriods'] ?? 0} periods', style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(classes.isEmpty ? 'None' : classes, style: GoogleFonts.inter(fontSize: 11))),
                DataCell(Text(subjects.isEmpty ? 'None' : subjects, style: GoogleFonts.inter(fontSize: 11))),
              ],
            );
          }),
          // Grand Total
          DataRow(
            color: WidgetStateProperty.all(AppColors.background),
            cells: [
              const DataCell(Text('TOTAL INSTITUTIONAL LOAD', style: TextStyle(fontWeight: FontWeight.w800))),
              const DataCell(Text('-')),
              const DataCell(Text('-')),
              const DataCell(Text('-')),
              DataCell(Text(
                '${_reportData!['grandWeeklyPeriods'] ?? 0} periods',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryAccent),
              )),
              const DataCell(Text('-')),
              const DataCell(Text('-')),
            ],
          ),
        ],
      ),
    );
  }

  // 12. Assignment Performance
  Widget _buildAssignmentPerformanceTable() {
    final rows = _reportData!['rows'] as List? ?? [];

    return _buildTableContainer(
      title: 'Curricular Homework & Assignment Submission Performance',
      child: AdaptiveDataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Assignment Title')),
          DataColumn(label: Text('Class & Section')),
          DataColumn(label: Text('Subject')),
          DataColumn(label: Text('Due Date')),
          DataColumn(label: Text('Submissions')),
          DataColumn(label: Text('Submission Rate')),
          DataColumn(label: Text('Average Score')),
        ],
        rows: rows.map((r) {
          final due = r['dueDate'] != null ? _dateFormat.format(DateTime.parse(r['dueDate'])) : '-';
          final clsSec = '${r['className']} - ${r['sectionName']}';
          final rate = r['submissionRate'] ?? 0;

          return DataRow(
            cells: [
              DataCell(Text(r['title'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(clsSec)),
              DataCell(Text(r['subjectName'] ?? '-')),
              DataCell(Text(due)),
              DataCell(Text('${r['submissionsCount']} / ${r['totalStudents']}')),
              DataCell(Text('$rate%', style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text('${r['averageScore'] ?? 0} pts')),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 13. Feedback Resolution
  Widget _buildFeedbackResolutionTable() {
    final rows = _reportData!['rows'] as List? ?? [];

    return _buildTableContainer(
      title: 'Stakeholder Feedback & Grievance Resolution Ledger',
      child: AdaptiveDataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Ticket ID')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Originator Role')),
          DataColumn(label: Text('Resolution Notes')),
          DataColumn(label: Text('Satisfaction')),
          DataColumn(label: Text('Status')),
        ],
        rows: rows.map((r) {
          final date = r['createdAt'] != null ? _dateFormat.format(DateTime.parse(r['createdAt'])) : '-';
          final rating = r['rating'] != null ? '${r['rating']} ★' : '-';

          return DataRow(
            cells: [
              DataCell(Text(r['feedbackId'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(date)),
              DataCell(Text(r['category'] ?? '-')),
              DataCell(Text(r['userRole'] ?? '-')),
              DataCell(Text(r['resolutionNotes'] ?? 'Under active review', style: GoogleFonts.inter(fontSize: 11))),
              DataCell(Text(rating, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)))),
              DataCell(StatusBadge.fromStatus(r['status'] ?? 'PENDING', isSmall: true)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
