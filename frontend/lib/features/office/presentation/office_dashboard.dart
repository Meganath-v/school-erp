import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';

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
          backgroundColor: AppTheme.success,
        ),
      );
      _loadAllOfficeData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e'), backgroundColor: AppTheme.error),
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
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currentClassSections = _classes.firstWhere(
              (c) => c['id'] == selectedClassId,
              orElse: () => {'sections': []},
            )['sections'] as List;

            return AlertDialog(
              title: Text('Student Admission Enrollment', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Candidate Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: firstNameCtrl,
                              decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: lastNameCtrl,
                              decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Guardian Contact Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: guardianNameCtrl,
                        decoration: const InputDecoration(labelText: 'Guardian Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: guardianPhoneCtrl,
                        decoration: const InputDecoration(labelText: 'Emergency Phone', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      Text('Class Assignment', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedClassId,
                              decoration: const InputDecoration(labelText: 'Grade', border: OutlineInputBorder()),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSectionId,
                              decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                              items: currentClassSections.map<DropdownMenuItem<String>>((s) {
                                return DropdownMenuItem(value: s['id'] as String, child: Text(s['name']));
                              }).toList(),
                              onChanged: (val) {
                                setDialogState(() => selectedSectionId = val);
                              },
                            ),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () async {
                    if (firstNameCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter student first and last name')),
                      );
                      return;
                    }
                    try {
                      await ApiClient().dio.post(
                        '/students',
                        data: {
                          'firstName': firstNameCtrl.text.trim(),
                          'lastName': lastNameCtrl.text.trim(),
                          'classId': selectedClassId,
                          'sectionId': selectedSectionId,
                          'guardianName': guardianNameCtrl.text.trim(),
                          'emergencyContact': guardianPhoneCtrl.text.trim(),
                        },
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAllOfficeData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Student successfully admitted and enrolled'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to admit student: $e'), backgroundColor: AppTheme.error),
                        );
                      }
                    }
                  },
                  child: const Text('Enroll Student', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordPaymentDialog(dynamic inv) {
    final amountCtrl = TextEditingController(text: '${inv['dueAmount'] ?? 0}');
    String method = 'CASH';
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Record Counter Payment', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice #${inv['invoiceNumber']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      'Student: ${inv['student']?['firstName'] ?? ''} ${inv['student']?['lastName'] ?? ''} (${inv['student']?['admissionNo'] ?? ''})',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const Divider(height: 24),
                    Text('Payment Method', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash at Counter')),
                        DropdownMenuItem(value: 'CHEQUE', child: Text('Bank Cheque / DD')),
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Direct Bank Transfer / NEFT')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => method = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('Amount Received (₹)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                    Text('Reference / Receipt Notes', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Cheque No #89123 or Counter Receipt',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                  onPressed: () async {
                    final enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (enteredAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid payment amount')),
                      );
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
                            content: Text('Payment registered and official receipt generated'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Payment failed: $e'), backgroundColor: AppTheme.error),
                        );
                      }
                    }
                  },
                  child: const Text('Confirm Payment', style: TextStyle(color: Colors.white)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students available to invoice')),
      );
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
              title: Text('Generate School Fee Invoice', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Student', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedStudentId,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
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
                    const SizedBox(height: 14),
                    Text('Invoice Description', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Amount (₹)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: amountCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: OutlineInputBorder()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Category', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: category,
                                decoration: const InputDecoration(border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'SCHOOL', child: Text('School Tuition')),
                                  DropdownMenuItem(value: 'TRANSPORT', child: Text('Transport')),
                                  DropdownMenuItem(value: 'HOSTEL', child: Text('Hostel & Mess')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => category = val);
                                },
                              ),
                            ],
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () async {
                    final enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (enteredAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid invoice amount')),
                      );
                      return;
                    }
                    try {
                      final dueDate = DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0];
                      await ApiClient().dio.post(
                        '/fees/invoices/generate',
                        data: {
                          'studentId': selectedStudentId,
                          'amount': enteredAmount,
                          'dueDate': dueDate,
                          'title': titleCtrl.text.trim(),
                          'category': category,
                        },
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAllOfficeData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fee invoice generated and dispatched to student account'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to generate invoice: $e'), backgroundColor: AppTheme.error),
                        );
                      }
                    }
                  },
                  child: const Text('Create Invoice', style: TextStyle(color: Colors.white)),
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
              title: Text('Dispatch Official Campus Notice', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Target Recipients', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: targetAudience,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'ALL_PARENTS', child: Text('All School Parents')),
                          DropdownMenuItem(value: 'ALL_STAFF', child: Text('All Academic & Support Staff')),
                          DropdownMenuItem(value: 'CLASS', child: Text('Class & Section Roster')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => targetAudience = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      Text('Priority Level', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: priority,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'STANDARD', child: Text('Standard Information')),
                          DropdownMenuItem(value: 'URGENT', child: Text('Urgent Action Required')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => priority = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      Text('Notice Title', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(hintText: 'e.g. Schedule of Term-1 Tuition Payment', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 14),
                      Text('Circular Content', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: contentCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(hintText: 'Official statement from school office...', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 14),
                      CheckboxListTile(
                        value: requiresAck,
                        title: Text('Require digital signature sign-off from recipients', style: GoogleFonts.inter(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setDialogState(() => requiresAck = val ?? true);
                        },
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
                        const SnackBar(content: Text('Please fill title and content')),
                      );
                      return;
                    }
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
                          const SnackBar(
                            content: Text('Notice successfully broadcasted to campus'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Dispatch failed: $e'), backgroundColor: AppTheme.error),
                        );
                      }
                    }
                  },
                  child: const Text('Publish Notice', style: TextStyle(color: Colors.white)),
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
              Text('Failed to load office operations', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAllOfficeData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final totalDues = _invoices.fold<double>(0, (acc, curr) => acc + ((curr['dueAmount'] ?? 0) as num).toDouble());
    final totalCollected = _invoices.fold<double>(0, (acc, curr) => acc + ((curr['paidAmount'] ?? 0) as num).toDouble());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Office Header & Quick Stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('School Office Operations & Registry', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Student enrollment, fee accounts, receipts, and campus dispatches', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _triggerAutomatedScan,
                  icon: const Icon(Icons.radar, size: 16),
                  label: const Text('Run System Scan'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: _showNewAdmissionDialog,
                  icon: const Icon(Icons.person_add, size: 16, color: Colors.white),
                  label: const Text('New Admission', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),

          // Operational Summary Metric Cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildTopMetric('Outstanding Dues', '₹${totalDues.toStringAsFixed(0)}', Icons.payment, AppTheme.error),
                const SizedBox(width: 12),
                _buildTopMetric('Total Collected', '₹${totalCollected.toStringAsFixed(0)}', Icons.account_balance_wallet, AppTheme.success),
                const SizedBox(width: 12),
                _buildTopMetric('Enrolled Students', '${_students.length}', Icons.groups, AppTheme.primary),
                const SizedBox(width: 12),
                _buildTopMetric('Active Tasks', '${_tasks.where((t) => t['status'] == 'PENDING').length}', Icons.assignment_late, AppTheme.accent),
              ],
            ),
          ),

          // Tabs Bar
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
                Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Fee Collection & Invoices'),
                Tab(icon: Icon(Icons.people, size: 18), text: 'Student Directory'),
                Tab(icon: Icon(Icons.campaign, size: 18), text: 'School Circulars'),
                Tab(icon: Icon(Icons.checklist, size: 18), text: 'Tasks & Reminders'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInvoicesTab(),
                _buildStudentsTab(),
                _buildCircularsTab(),
                _buildTasksTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMetric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesTab() {
    final filteredInvoices = _invoices.where((inv) {
      final status = (inv['status'] ?? 'DUE').toString().toUpperCase();
      final matchStatus = _invoiceStatusFilter == 'ALL' || status == _invoiceStatusFilter;
      final q = _invoiceSearchQuery.toLowerCase();
      final sName = '${inv['student']?['firstName'] ?? ''} ${inv['student']?['lastName'] ?? ''}'.toLowerCase();
      final adm = (inv['student']?['admissionNo'] ?? '').toString().toLowerCase();
      final invNum = (inv['invoiceNumber'] ?? '').toString().toLowerCase();
      final matchSearch = q.isEmpty || sName.contains(q) || adm.contains(q) || invNum.contains(q);
      return matchStatus && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateInvoiceDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Generate Invoice', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by student name, admission no, or invoice #...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _invoiceSearchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 6,
                  children: ['ALL', 'PAID', 'DUE', 'OVERDUE'].map((st) {
                    final isSelected = _invoiceStatusFilter == st;
                    return ChoiceChip(
                      label: Text(st),
                      selected: isSelected,
                      onSelected: (sel) {
                        if (sel) setState(() => _invoiceStatusFilter = st);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: filteredInvoices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt, size: 48, color: AppTheme.border),
                          const SizedBox(height: 12),
                          Text(
                            _invoiceSearchQuery.isNotEmpty || _invoiceStatusFilter != 'ALL'
                                ? 'No invoices match current filter criteria'
                                : 'No fee invoices issued yet',
                            style: GoogleFonts.outfit(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredInvoices.length,
                      itemBuilder: (ctx, i) {
                        final inv = filteredInvoices[i];
                        final isPaid = inv['status'] == 'PAID';
                        final isOverdue = inv['status'] == 'OVERDUE';

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
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: (isPaid ? AppTheme.success : (isOverdue ? AppTheme.error : Colors.amber)).withValues(alpha: 0.15),
                                  child: Icon(
                                    isPaid ? Icons.check : Icons.access_time,
                                    color: isPaid ? AppTheme.success : (isOverdue ? AppTheme.error : Colors.amber.shade800),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${inv['student']?['firstName'] ?? ''} ${inv['student']?['lastName'] ?? ''} (Adm: ${inv['student']?['admissionNo'] ?? ''})',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Invoice #${inv['invoiceNumber']} • Due: ${inv['dueDate'] != null ? inv['dueDate'].toString().split('T')[0] : ''}',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${inv['totalAmount'] ?? 0}',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      isPaid ? 'Fully Paid' : 'Due: ₹${inv['dueAmount'] ?? 0}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isPaid ? AppTheme.success : AppTheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                if (!isPaid)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                                    onPressed: () => _showRecordPaymentDialog(inv),
                                    child: const Text('Record Payment', style: TextStyle(color: Colors.white, fontSize: 12)),
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
      ),
    );
  }

  Widget _buildStudentsTab() {
    final filteredStudents = _students.where((s) {
      final q = _studentSearchQuery.toLowerCase();
      final sName = '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'.toLowerCase();
      final adm = (s['admissionNo'] ?? '').toString().toLowerCase();
      return q.isEmpty || sName.contains(q) || adm.contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search students by candidate name or admission number...',
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (val) => setState(() => _studentSearchQuery = val),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 48, color: AppTheme.border),
                        const SizedBox(height: 12),
                        Text(
                          _studentSearchQuery.isNotEmpty ? 'No students match "$_studentSearchQuery"' : 'No students registered',
                          style: GoogleFonts.outfit(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredStudents.length,
                    itemBuilder: (ctx, i) {
                      final s = filteredStudents[i];
                      final enrollments = s['enrollments'] as List?;
                      final className = (enrollments != null && enrollments.isNotEmpty)
                          ? (enrollments[0]['class']?['name'] ?? 'Enrolled')
                          : 'Enrolled';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.15),
                            child: Text(
                              (s['firstName'] ?? 'S')[0],
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                          title: Text(
                            '${s['firstName']} ${s['lastName']}',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            'Admission: ${s['admissionNo']} • Class: $className',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s['status'] ?? 'ACTIVE',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success),
                            ),
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

  Widget _buildCircularsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCircularDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.campaign, color: Colors.white),
        label: const Text('Dispatch Circular', style: TextStyle(color: Colors.white)),
      ),
      body: _circulars.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.campaign_outlined, size: 48, color: AppTheme.border),
                  const SizedBox(height: 12),
                  Text('No school circulars issued', style: GoogleFonts.outfit(color: AppTheme.textMuted)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _circulars.length,
              itemBuilder: (ctx, i) {
                final c = _circulars[i];
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
                        Text(c['title'] ?? 'Notice', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(c['content'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Target: ${c['targetAudience'] ?? 'ALL'}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                            Text('Dispatched by: ${c['senderName'] ?? 'Office'}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTasksTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Daily Administrative Tasks', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('All office tasks completed for today.'),
          )
        else
          ..._tasks.map((t) {
            final isDone = t['status'] == 'COMPLETED';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.border),
              ),
              child: CheckboxListTile(
                value: isDone,
                title: Text(
                  t['title'] ?? '',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  '${t['category'] ?? 'OFFICE'} • Due: ${t['dueDate'] != null ? t['dueDate'].toString().split('T')[0] : 'Today'}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                ),
                onChanged: (val) async {
                  try {
                    await ApiClient().dio.patch(
                      '/tasks/${t['id']}/status',
                      data: {'status': val == true ? 'COMPLETED' : 'PENDING'},
                    );
                    _loadAllOfficeData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  }
                },
              ),
            );
          }),
        const SizedBox(height: 20),
        Text('Automated System Reminders', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_reminders.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No active reminders logged.'),
          )
        else
          ..._reminders.map((r) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.border),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.alarm, color: Color(0xFFD97706), size: 20),
                ),
                title: Text(r['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(r['description'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                trailing: Text(
                  r['remindAt'] != null ? r['remindAt'].toString().split('T')[0] : '',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            );
          }),
      ],
    );
  }
}
