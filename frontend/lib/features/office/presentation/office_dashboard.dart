import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class OfficeDashboard extends ConsumerStatefulWidget {
  const OfficeDashboard({super.key});

  @override
  ConsumerState<OfficeDashboard> createState() => _OfficeDashboardState();
}

class _OfficeDashboardState extends ConsumerState<OfficeDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _invoices = [];
  List<dynamic> _students = [];
  List<dynamic> _classes = [];
  List<dynamic> _circulars = [];
  List<dynamic> _tasks = [];
  List<dynamic> _reminders = [];

  String _invoiceSearchQuery = '';
  String _invoiceStatusFilter = 'ALL';
  String _studentSearchQuery = '';
  String? _selectedClassFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllOfficeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllOfficeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient().dio.get('/fees/invoices').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/students').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/schools/classes').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/circulars').then((r) => r.data as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/tasks').then((r) => r.data as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/reminders').then((r) => r.data as List? ?? []).catchError((_) => []),
      ]);

      setState(() {
        _invoices = results[0];
        _students = results[1];
        _classes = results[2];
        _circulars = results[3];
        _tasks = results[4];
        _reminders = results[5];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerAutomatedScan() async {
    try {
      final res = await ApiClient().dio.post('/reminders/trigger-automated');
      final count = res.data['remindersGenerated'] ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Automated campus scan complete: $count notifications dispatched'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadAllOfficeData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e'), backgroundColor: AppColors.error),
      );
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
          final currentSections = _classes.firstWhere(
            (c) => c['id'] == selectedClassId,
            orElse: () => {'sections': []},
          )['sections'] as List;

          return AlertDialog(
            title: const Text('Student Admission Enrollment'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Information',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name'))),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name'))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Academic Allocation',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
                              setDialogState(() {
                                selectedClassId = val;
                                final secs = _classes.firstWhere((c) => c['id'] == val)['sections'] as List;
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
                            items: currentSections.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedSectionId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Parent / Guardian Contacts',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(controller: guardianNameCtrl, decoration: const InputDecoration(labelText: 'Guardian Full Name')),
                    const SizedBox(height: AppSpacing.md),
                    TextField(controller: guardianPhoneCtrl, decoration: const InputDecoration(labelText: 'Guardian Mobile Contact')),
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
                        const SnackBar(content: Text('Student admitted and enrolled successfully!'), backgroundColor: AppColors.success),
                      );
                      _loadAllOfficeData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to complete admission'), backgroundColor: AppColors.error),
                    );
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

  void _showCollectPaymentDialog(dynamic inv) {
    final amountDue = inv['dueAmount'] ?? 0;
    final amountCtrl = TextEditingController(text: amountDue.toString());
    final notesCtrl = TextEditingController();
    String method = 'CASH';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Counter Fee Collection'),
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
                              Text(inv['studentName'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Invoice: ${inv['invoiceNo']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                          Text('Due: ₹$amountDue', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount Received (₹)'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(labelText: 'Payment Instrument'),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash at Bursar Counter')),
                        DropdownMenuItem(value: 'CHEQUE', child: Text('Bank Cheque / DD')),
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('NEFT / RTGS Transfer')),
                        DropdownMenuItem(value: 'UPI', child: Text('Counter QR / UPI')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => method = val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Official Receipt Notes / Bank Ref'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () async {
                    final enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (enteredAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid payment amount')));
                      return;
                    }
                    try {
                      await ApiClient().dio.post(
                        '/fees/pay',
                        data: {
                          'invoiceId': inv['id'],
                          'amount': enteredAmount,
                          'method': method,
                          'notes': notesCtrl.text.trim(),
                        },
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAllOfficeData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fee registered & serialized official receipt generated!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e'), backgroundColor: AppColors.error));
                      }
                    }
                  },
                  child: const Text('Confirm & Print Receipt'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGenerateInvoiceDialog() {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students enrolled to generate invoices for')));
      return;
    }

    String selectedStudentId = _students[0]['id'];
    final amountCtrl = TextEditingController(text: '15000');
    final titleCtrl = TextEditingController(text: 'Term Tuition & Academic Fee');
    String category = 'SCHOOL';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Issue Student Fee Invoice'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedStudentId,
                      decoration: const InputDecoration(labelText: 'Select Student'),
                      items: _students.map<DropdownMenuItem<String>>((s) {
                        return DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text('${s['firstName']} ${s['lastName']} (${s['admissionNo']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedStudentId = val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Fee Title / Purpose'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Total Amount (₹)'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: category,
                            decoration: const InputDecoration(labelText: 'Billing Category'),
                            items: const [
                              DropdownMenuItem(value: 'SCHOOL', child: Text('School Tuition')),
                              DropdownMenuItem(value: 'TRANSPORT', child: Text('Transport / Bus')),
                              DropdownMenuItem(value: 'HOSTEL', child: Text('Hostel & Mess')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => category = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (enteredAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid invoice amount')));
                      return;
                    }
                    try {
                      await ApiClient().dio.post(
                        '/fees/invoices',
                        data: {
                          'studentId': selectedStudentId,
                          'title': titleCtrl.text.trim(),
                          'amount': enteredAmount,
                          'category': category,
                          'dueDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                        },
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAllOfficeData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fee invoice issued successfully!'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice creation failed: $e'), backgroundColor: AppColors.error));
                      }
                    }
                  },
                  child: const Text('Issue Invoice'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateCircularDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String targetAudience = 'ALL_PARENTS';
    String priority = 'STANDARD';
    bool requiresAck = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Dispatch Administrative Circular'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: targetAudience,
                              decoration: const InputDecoration(labelText: 'Target Recipients'),
                              items: const [
                                DropdownMenuItem(value: 'ALL_PARENTS', child: Text('All School Parents')),
                                DropdownMenuItem(value: 'ALL_STAFF', child: Text('All Academic Staff')),
                                DropdownMenuItem(value: 'CLASS', child: Text('Class & Section Roster')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => targetAudience = val);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: priority,
                              decoration: const InputDecoration(labelText: 'Priority Level'),
                              items: const [
                                DropdownMenuItem(value: 'STANDARD', child: Text('Standard')),
                                DropdownMenuItem(value: 'URGENT', child: Text('Urgent Action')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => priority = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Circular Title', hintText: 'e.g. Schedule of Term Tuition Fees'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: contentCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Official Statement Body'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CheckboxListTile(
                        value: requiresAck,
                        title: const Text('Require digital signature acknowledgement from recipients', style: TextStyle(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => requiresAck = val ?? true),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) return;
                    try {
                      await ApiClient().dio.post(
                        '/circulars',
                        data: {
                          'title': titleCtrl.text.trim(),
                          'content': contentCtrl.text.trim(),
                          'targetAudience': targetAudience,
                          'priority': priority,
                          'requiresAck': requiresAck,
                        },
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAllOfficeData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Circular dispatched successfully!'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to publish circular: $e'), backgroundColor: AppColors.error));
                      }
                    }
                  },
                  child: const Text('Dispatch Circular'),
                ),
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
      return const LoadingStateView(message: 'Loading administrative records, bursar ledgers, and rosters...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Office Administration Unavailable',
        message: _errorMessage,
        onRetry: _loadAllOfficeData,
      );
    }

    final totalDues = _invoices.fold<double>(0.0, (acc, inv) => acc + ((inv['dueAmount'] ?? 0) as num).toDouble());
    final totalCollected = _invoices.fold<double>(0.0, (acc, inv) => acc + ((inv['paidAmount'] ?? 0) as num).toDouble());

    return Column(
      children: [
        // Top Tab Navigation Bar
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
                    Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Fee Collection & Invoices'),
                    Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Student Directory & Admissions'),
                    Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'School Circulars'),
                    Tab(icon: Icon(Icons.checklist_outlined, size: 18), text: 'Tasks & Reminders'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Office Data',
                onPressed: _loadAllOfficeData,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInvoicesTab(totalDues, totalCollected),
              _buildStudentsTab(),
              _buildCircularsTab(),
              _buildTasksTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesTab(double totalDues, double totalCollected) {
    final filtered = _invoices.where((inv) {
      final matchesStatus = _invoiceStatusFilter == 'ALL' || (inv['status'] ?? '').toString() == _invoiceStatusFilter;
      final q = _invoiceSearchQuery.toLowerCase().trim();
      if (q.isEmpty) return matchesStatus;
      final sName = (inv['studentName'] ?? '').toString().toLowerCase();
      final invNo = (inv['invoiceNo'] ?? '').toString().toLowerCase();
      final title = (inv['title'] ?? '').toString().toLowerCase();
      return matchesStatus && (sName.contains(q) || invNo.contains(q) || title.contains(q));
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Bursar Office', 'Fee Management', 'Invoices'],
            title: 'Fee Collections & Counter Ledger',
            subtitle: 'Track receivables, collect fee payments across multiple categories, and issue serialized receipts.',
            actions: [
              OutlinedButton.icon(
                onPressed: _triggerAutomatedScan,
                icon: const Icon(Icons.radar, size: 16),
                label: const Text('Run System Scan'),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: _showGenerateInvoiceDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Issue Fee Invoice'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Bursar Metrics
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Outstanding Receivables',
                  value: '₹${totalDues.toStringAsFixed(0)}',
                  icon: Icons.pending_actions_outlined,
                  subtitle: 'Pending fee balance',
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Total Collected Fees',
                  value: '₹${totalCollected.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_outlined,
                  subtitle: 'Realized fee revenue',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Active Invoices',
                  value: '${_invoices.length}',
                  icon: Icons.receipt_long_outlined,
                  subtitle: 'Invoices on record',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Pending Reminders',
                  value: '${_reminders.where((r) => r['status'] == 'PENDING').length}',
                  icon: Icons.notifications_active_outlined,
                  subtitle: 'Fee due alerts queued',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          SearchFilterBar(
            searchHint: 'Search invoices by student name, invoice number, or title...',
            searchQuery: _invoiceSearchQuery,
            onSearchChanged: (val) => setState(() => _invoiceSearchQuery = val),
            totalCount: filtered.length,
            countLabel: 'Invoices Found',
            filters: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _invoiceStatusFilter,
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Invoice Statuses')),
                    DropdownMenuItem(value: 'PAID', child: Text('Paid Only')),
                    DropdownMenuItem(value: 'PENDING', child: Text('Pending / Partial Only')),
                    DropdownMenuItem(value: 'OVERDUE', child: Text('Overdue Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _invoiceStatusFilter = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          filtered.isEmpty
              ? EmptyStateView(
                  icon: Icons.receipt_long_outlined,
                  title: _invoiceSearchQuery.isNotEmpty ? 'No Matching Invoices' : 'No Invoices Created Yet',
                  description: _invoiceSearchQuery.isNotEmpty
                      ? 'No invoice records match your search filter.'
                      : 'Generate your first student fee invoice using the button above.',
                  actionLabel: _invoiceSearchQuery.isNotEmpty ? 'Clear Filter' : 'Issue Fee Invoice',
                  onAction: _invoiceSearchQuery.isNotEmpty ? () => setState(() => _invoiceSearchQuery = '') : _showGenerateInvoiceDialog,
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: AppShadows.subtle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 320),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.tableHeaderBg),
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 64,
                        horizontalMargin: AppSpacing.lg,
                        columnSpacing: AppSpacing.xl,
                        columns: const [
                          DataColumn(label: Text('Invoice No', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Fee Purpose', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Total (₹)', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Paid (₹)', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Due (₹)', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Bursar Action', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                        rows: filtered.map((inv) {
                          final status = (inv['status'] ?? 'PENDING').toString();
                          final isPaid = status == 'PAID';

                          return DataRow(
                            cells: [
                              DataCell(Text(inv['invoiceNo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                              DataCell(Text(inv['studentName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(inv['title'] ?? '')),
                              DataCell(Text('₹${inv['amount']}')),
                              DataCell(Text('₹${inv['paidAmount']}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
                              DataCell(Text('₹${inv['dueAmount']}', style: TextStyle(color: isPaid ? AppColors.textSecondary : AppColors.error, fontWeight: FontWeight.bold))),
                              DataCell(StatusBadge.fromStatus(status)),
                              DataCell(
                                isPaid
                                    ? const StatusBadge(label: 'CLEARED', variant: BadgeVariant.success)
                                    : ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                                          backgroundColor: AppColors.primary,
                                        ),
                                        onPressed: () => _showCollectPaymentDialog(inv),
                                        child: const Text('Collect Payment', style: TextStyle(fontSize: 12)),
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

  Widget _buildStudentsTab() {
    final filtered = _students.where((s) {
      final matchesClass = _selectedClassFilter == null || s['currentClass'] == _selectedClassFilter;
      final q = _studentSearchQuery.toLowerCase().trim();
      if (q.isEmpty) return matchesClass;
      final name = (s['fullName'] ?? '${s['firstName']} ${s['lastName']}').toString().toLowerCase();
      final adm = (s['admissionNo'] ?? '').toString().toLowerCase();
      return matchesClass && (name.contains(q) || adm.contains(q));
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Administration', 'Student Roster'],
            title: 'Student Directory & Admissions',
            subtitle: 'Institutional enrollment, admission records, guardian contact mapping, and status management.',
            actions: [
              ElevatedButton.icon(
                onPressed: _showNewAdmissionDialog,
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('New Admission'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SearchFilterBar(
            searchHint: 'Search by student name or admission number...',
            searchQuery: _studentSearchQuery,
            onSearchChanged: (val) => setState(() => _studentSearchQuery = val),
            totalCount: filtered.length,
            countLabel: 'Students Matriculated',
            filters: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClassFilter,
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Classes')),
                    ..._classes.map((c) => DropdownMenuItem(value: c['name'] as String, child: Text(c['name'] as String))),
                  ],
                  onChanged: (val) => setState(() => _selectedClassFilter = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: filtered.isEmpty
                ? EmptyStateView(
                    icon: Icons.people_outline,
                    title: _studentSearchQuery.isNotEmpty ? 'No Matching Students' : 'No Students Admitted Yet',
                    description: _studentSearchQuery.isNotEmpty
                        ? 'No student records match the active search criteria.'
                        : 'Admit new students into academic sections using the admission action above.',
                    actionLabel: _studentSearchQuery.isNotEmpty ? 'Clear Filter' : 'New Admission',
                    onAction: _studentSearchQuery.isNotEmpty ? () => setState(() => _studentSearchQuery = '') : _showNewAdmissionDialog,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: AppShadows.subtle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 320),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppColors.tableHeaderBg),
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 64,
                          horizontalMargin: AppSpacing.lg,
                          columnSpacing: AppSpacing.xl,
                          columns: const [
                            DataColumn(label: Text('Admission No', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Student Full Name', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Class & Section', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Roll No', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Primary Guardian', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                          rows: filtered.map((s) {
                            final name = s['fullName'] ?? '${s['firstName']} ${s['lastName']}';
                            final guardians = s['guardians'] as List? ?? [];
                            final guardianName = guardians.isNotEmpty ? guardians[0]['name'] : 'N/A';

                            return DataRow(
                              cells: [
                                DataCell(Text(s['admissionNo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                                DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text('${s['currentClass'] ?? 'Class'} - ${s['currentSection'] ?? 'A'}')),
                                DataCell(Text('${s['rollNo'] ?? 'N/A'}')),
                                DataCell(Text(guardianName)),
                                DataCell(StatusBadge.fromStatus(s['status'] ?? 'ACTIVE')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularsTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Administration', 'Circulars & Notices'],
            title: 'School Circulars & Digital Signatures',
            subtitle: 'Dispatch official policies, circulars, and manage parent/staff sign-offs.',
            actions: [
              ElevatedButton.icon(
                onPressed: _showCreateCircularDialog,
                icon: const Icon(Icons.campaign, size: 16),
                label: const Text('Dispatch Circular'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: _circulars.isEmpty
                ? EmptyStateView(
                    icon: Icons.campaign_outlined,
                    title: 'No Circulars Dispatched',
                    description: 'Draft and dispatch official campus announcements with digital acknowledgement tracking.',
                    actionLabel: 'Dispatch Circular',
                    onAction: _showCreateCircularDialog,
                  )
                : ListView.builder(
                    itemCount: _circulars.length,
                    itemBuilder: (context, index) {
                      final c = _circulars[index];
                      final acks = (c['acknowledgments'] as List? ?? []).length;
                      final isUrgent = c['priority'] == 'URGENT';

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.lg),
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
                                    Text(c['title'] ?? 'Circular', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: AppSpacing.sm),
                                    StatusBadge(
                                      label: c['priority'] ?? 'STANDARD',
                                      variant: isUrgent ? BadgeVariant.error : BadgeVariant.info,
                                    ),
                                  ],
                                ),
                                StatusBadge(
                                  label: '$acks Digital Signatures',
                                  variant: BadgeVariant.success,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              c['content'] ?? '',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                const Icon(Icons.group_outlined, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text('Audience: ${c['targetAudience'] ?? 'ALL'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(width: AppSpacing.lg),
                                const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text('Dispatched: ${c['createdAt']?.toString().split('T')[0] ?? 'Today'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
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

  Widget _buildTasksTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Administration', 'Tasks & Reminders'],
            title: 'Administrative Tasks & Reminder Telemetry',
            subtitle: 'Operational task assignments, system-generated reminder triggers, and completion metrics.',
            actions: [
              OutlinedButton.icon(
                onPressed: _triggerAutomatedScan,
                icon: const Icon(Icons.radar, size: 16),
                label: const Text('Run Daily Automated Scan'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tasks Column
                Expanded(
                  flex: 6,
                  child: Container(
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
                          children: [
                            const Icon(Icons.checklist, color: AppColors.primary, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Operational Tasks (${_tasks.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: _tasks.isEmpty
                              ? const EmptyStateView(
                                  icon: Icons.task_alt,
                                  title: 'No Pending Administrative Tasks',
                                  description: 'All operations are up to date.',
                                )
                              : ListView.builder(
                                  itemCount: _tasks.length,
                                  itemBuilder: (context, index) {
                                    final t = _tasks[index];
                                    final isDone = t['status'] == 'COMPLETED';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                      padding: const EdgeInsets.all(AppSpacing.md),
                                      decoration: BoxDecoration(
                                        color: isDone ? AppColors.surfaceMuted : AppColors.surface,
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                        border: Border.all(color: AppColors.borderLight),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                            color: isDone ? AppColors.success : AppColors.textMuted,
                                            size: 20,
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  t['title'] ?? 'Task',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                                  ),
                                                ),
                                                if (t['description'] != null)
                                                  Text(t['description'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                              ],
                                            ),
                                          ),
                                          StatusBadge.fromStatus(t['status'] ?? 'PENDING'),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),

                // Reminders Telemetry Column
                Expanded(
                  flex: 5,
                  child: Container(
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
                          children: [
                            const Icon(Icons.notifications_active, color: AppColors.warning, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Dispatched Reminders (${_reminders.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: _reminders.isEmpty
                              ? const EmptyStateView(
                                  icon: Icons.notifications_none,
                                  title: 'No Active Reminders',
                                  description: 'Run the daily automated scan to trigger attendance & fee reminders.',
                                )
                              : ListView.builder(
                                  itemCount: _reminders.length,
                                  itemBuilder: (context, index) {
                                    final r = _reminders[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                                              Text(r['type'] ?? 'REMINDER', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              StatusBadge.fromStatus(r['status'] ?? 'SENT'),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(r['message'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
