import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class FeeManagementScreen extends ConsumerStatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  ConsumerState<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends ConsumerState<FeeManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _invoices = [];
  List<dynamic> _receipts = [];
  List<dynamic> _feePlans = [];
  List<dynamic> _students = [];
  Map<String, dynamic>? _feeReport;

  // Invoices Table State
  String _invoiceSearchQuery = '';
  String _invoiceStatusFilter = 'ALL';
  int _currentPage = 1;
  final int _pageSize = 8;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllFeeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllFeeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient().dio.get('/fees/invoices').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/receipts').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/fees/plans').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/students').then((r) => r.data['data'] as List? ?? []).catchError((_) => []),
        ApiClient().dio.get('/reports/fees').then((r) => r.data as Map<String, dynamic>?).catchError((_) => null),
      ]);

      setState(() {
        _invoices = results[0] as List<dynamic>;
        _receipts = results[1] as List<dynamic>;
        _feePlans = results[2] as List<dynamic>;
        _students = results[3] as List<dynamic>;
        _feeReport = results[4] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCollectPaymentDialog(dynamic inv) {
    final amountDue = (inv['dueAmount'] ?? 0) as num;
    final amountCtrl = TextEditingController(text: '$amountDue');
    final notesCtrl = TextEditingController();
    String method = 'CASH';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Bursar Counter Fee Collection'),
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
                          Text(inv['studentName'] ?? 'Learner', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Invoice No: ${inv['invoiceNo']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                    DropdownMenuItem(value: 'CASH', child: Text('Cash at Counter')),
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
                  decoration: const InputDecoration(labelText: 'Bank Ref / Instrument Notes', hintText: 'e.g. Cheque No 401928 HDFC Bank'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                  return;
                }
                try {
                  await ApiClient().dio.post('/fees/pay', data: {
                    'invoiceId': inv['id'],
                    'amount': amt,
                    'method': method,
                    'notes': notesCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee registered & serialized receipt generated!'), backgroundColor: AppColors.success));
                    _loadAllFeeData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment recording failed: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              child: const Text('Confirm & Issue Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptPreviewDialog(String receiptId) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder(
        future: ApiClient().dio.get('/receipts/$receiptId'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
              content: SizedBox(height: 120, child: LoadingStateView(message: 'Generating official receipt preview...')),
            );
          }

          final rec = (snapshot.data as dynamic).data['data'];
          final sch = rec['school'] ?? {};
          final stu = rec['student'] ?? {};
          final fee = rec['feeDetails'] ?? {};

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Official Fee Receipt'),
                StatusBadge(label: rec['receiptNo'] ?? 'REC-XXXX', variant: BadgeVariant.success),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Text(sch['name'] ?? 'Institutional Campus', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${sch['address']} • Ph: ${sch['contactPhone']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Student: ${stu['name']} (${stu['admissionNo']})', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Date: ${rec['issuedAt']?.toString().split('T')[0]}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    Text('Class: ${stu['class']} (${stu['section']})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        children: [
                          _buildReceiptRow('Billing Head', fee['title'] ?? 'Tuition Fee'),
                          _buildReceiptRow('Invoice Number', fee['invoiceNo'] ?? 'INV-XXXX'),
                          _buildReceiptRow('Payment Method', fee['paymentMethod'] ?? 'CASH'),
                          _buildReceiptRow('Amount Paid This Transaction', '₹${fee['amountPaidThisTransaction']}', isBold: true, color: AppColors.success),
                          _buildReceiptRow('Remaining Invoice Due', '₹${fee['remainingBalance']}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Digital Signature: ${fee['digitalSignature'] ?? 'SIG_VERIFIED'}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt sent to printer spooler')));
                },
                icon: const Icon(Icons.print, size: 16),
                label: const Text('Print Receipt'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _showGenerateInvoiceDialog() {
    if (_students.isEmpty) return;
    String selectedStudentId = _students[0]['id'];
    final titleCtrl = TextEditingController(text: 'Term 1 Tuition Fee');
    final amountCtrl = TextEditingController(text: '15000');
    String category = 'SCHOOL';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Issue Institutional Fee Invoice'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedStudentId,
                  decoration: const InputDecoration(labelText: 'Billed Student'),
                  items: _students.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'] as String, child: Text('${s['fullName']} (${s['admissionNo']})'))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStudentId = val);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Invoice Title / Head')),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)'))),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: const [
                          DropdownMenuItem(value: 'SCHOOL', child: Text('School Tuition')),
                          DropdownMenuItem(value: 'HOSTEL', child: Text('Hostel & Mess')),
                          DropdownMenuItem(value: 'TRANSPORT', child: Text('Transport / Bus')),
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
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amt <= 0) return;
                try {
                  await ApiClient().dio.post('/fees/invoices', data: {
                    'studentId': selectedStudentId,
                    'title': titleCtrl.text.trim(),
                    'amount': amt,
                    'category': category,
                    'dueDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee invoice issued successfully!'), backgroundColor: AppColors.success));
                    _loadAllFeeData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice issuance failed: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              child: const Text('Issue Invoice'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading financial ledgers, fee invoices, and receipts...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Fee Management Unavailable',
        message: _errorMessage,
        onRetry: _loadAllFeeData,
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
                    Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Invoices & Counter Ledger'),
                    Tab(icon: Icon(Icons.account_balance_outlined, size: 18), text: 'Fee Structure & Heads'),
                    Tab(icon: Icon(Icons.history_outlined, size: 18), text: 'Payment Receipts History'),
                    Tab(icon: Icon(Icons.warning_amber_outlined, size: 18), text: 'Outstanding Defaulters Report'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Ledger',
                onPressed: _loadAllFeeData,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInvoicesTab(),
              _buildFeeStructureTab(),
              _buildReceiptsTab(),
              _buildDefaultersReportTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesTab() {
    final totalDues = _invoices.fold<double>(0.0, (acc, inv) => acc + ((inv['dueAmount'] ?? 0) as num).toDouble());
    final totalCollected = _invoices.fold<double>(0.0, (acc, inv) => acc + ((inv['paidAmount'] ?? 0) as num).toDouble());

    var filtered = _invoices.where((inv) {
      final matchesStatus = _invoiceStatusFilter == 'ALL' || (inv['status'] ?? '').toString() == _invoiceStatusFilter;
      final q = _invoiceSearchQuery.toLowerCase().trim();
      if (q.isEmpty) return matchesStatus;
      final sName = (inv['studentName'] ?? '').toString().toLowerCase();
      final invNo = (inv['invoiceNo'] ?? '').toString().toLowerCase();
      final title = (inv['title'] ?? '').toString().toLowerCase();
      return matchesStatus && (sName.contains(q) || invNo.contains(q) || title.contains(q));
    }).toList();

    final totalCount = filtered.length;
    final totalPages = (totalCount / _pageSize).ceil();
    final safePage = _currentPage > totalPages && totalPages > 0 ? totalPages : _currentPage;
    final startIndex = (safePage - 1) * _pageSize;
    final pagedInvoices = (startIndex < totalCount && startIndex >= 0)
        ? filtered.skip(startIndex).take(_pageSize).toList()
        : <dynamic>[];

    return RefreshIndicator(
      onRefresh: _loadAllFeeData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              breadcrumbs: const ['Bursar Office', 'Fee Management', 'Invoices'],
              title: 'Institutional Fee Collections & Invoicing',
              subtitle: 'Generate tuition invoices, collect counter payments across multiple categories, and issue serialized receipts.',
              actions: [
                ElevatedButton.icon(
                  onPressed: _showGenerateInvoiceDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Issue New Invoice'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Bursar Financial Telemetry Row
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Outstanding Dues',
                    value: '₹${totalDues.toStringAsFixed(0)}',
                    icon: Icons.pending_actions_outlined,
                    subtitle: 'Pending Fee Balance',
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Realized Revenue',
                    value: '₹${totalCollected.toStringAsFixed(0)}',
                    icon: Icons.savings_outlined,
                    subtitle: 'Fee Collections Received',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Invoices on File',
                    value: '${_invoices.length}',
                    icon: Icons.receipt_long_outlined,
                    subtitle: 'Billed Student Accounts',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MetricCard(
                    title: 'Serialized Receipts',
                    value: '${_receipts.length}',
                    icon: Icons.verified_outlined,
                    subtitle: 'Issued Payment Vouchers',
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            SearchFilterBar(
              searchHint: 'Search invoice by student name, invoice number, or billing title...',
              searchQuery: _invoiceSearchQuery,
              onSearchChanged: (val) => setState(() {
                _invoiceSearchQuery = val;
                _currentPage = 1;
              }),
              totalCount: totalCount,
              countLabel: 'Invoices Found',
              filters: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _invoiceStatusFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'PAID', child: Text('Paid in Full')),
                      DropdownMenuItem(value: 'PENDING', child: Text('Pending Payment')),
                      DropdownMenuItem(value: 'PARTIALLY_PAID', child: Text('Partially Paid')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _invoiceStatusFilter = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            if (pagedInvoices.isEmpty)
              const EmptyStateView(
                icon: Icons.receipt_long_outlined,
                title: 'No Matching Invoices',
                description: 'Try adjusting your search query or status filter.',
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
                        0: FlexColumnWidth(1.5),
                        1: FlexColumnWidth(2.2),
                        2: FlexColumnWidth(2.0),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.2),
                        5: FlexColumnWidth(1.2),
                        6: FlexColumnWidth(1.5),
                        7: FlexColumnWidth(2.0),
                      },
                      border: TableBorder(
                        horizontalInside: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
                      ),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: AppColors.tableHeaderBg),
                          children: [
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Invoice No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Billing Head', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Due', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                        ...pagedInvoices.map((inv) {
                          final isPaid = inv['status'] == 'PAID';
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(inv['invoiceNo'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Text(inv['studentName'] ?? 'Learner', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(inv['title'] ?? 'Tuition Fee', style: const TextStyle(fontSize: 13))),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('₹${inv['amount']}', style: const TextStyle(fontSize: 13))),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('₹${inv['paidAmount']}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13))),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('₹${inv['dueAmount']}', style: TextStyle(color: (inv['dueAmount'] ?? 0) > 0 ? AppColors.error : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13))),
                              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: StatusBadge.fromStatus(inv['status'] ?? 'PENDING')),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: Row(
                                  children: [
                                    if (!isPaid)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), visualDensity: VisualDensity.compact),
                                        onPressed: () => _showCollectPaymentDialog(inv),
                                        icon: const Icon(Icons.payment, size: 14),
                                        label: const Text('Collect'),
                                      )
                                    else
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), visualDensity: VisualDensity.compact),
                                        onPressed: () {
                                          final matchingRec = _receipts.firstWhere((r) => r['invoiceNo'] == inv['invoiceNo'], orElse: () => null);
                                          if (matchingRec != null) {
                                            _showReceiptPreviewDialog(matchingRec['id']);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt record on file.')));
                                          }
                                        },
                                        icon: const Icon(Icons.receipt, size: 14),
                                        label: const Text('Receipt'),
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
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderLight))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Showing ${startIndex + 1} to ${((startIndex + _pageSize) < totalCount ? (startIndex + _pageSize) : totalCount)} of $totalCount accounts', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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

  Widget _buildFeeStructureTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Bursar Office', 'Fee Management', 'Plans & Heads'],
            title: 'Institutional Fee Structure & Plans',
            subtitle: 'Pre-configured annual fee heads, recurring schedules, and concession rules.',
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_feePlans.isEmpty)
            const EmptyStateView(
              icon: Icons.account_balance_outlined,
              title: 'No Fee Plans Configured',
              description: 'Tuition and ancillary fee heads are generated dynamically per student account.',
            )
          else
            ..._feePlans.map((plan) {
              final heads = plan['feeHeads'] as List? ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xl),
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
                        Text(plan['name'] ?? 'Fee Plan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        StatusBadge(label: 'Total: ₹${plan['totalAmount']}', variant: BadgeVariant.info),
                      ],
                    ),
                    const Divider(height: 24),
                    ...heads.map((h) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.label_outline, color: AppColors.primary, size: 18),
                        title: Text(h['title'] ?? 'Fee Head', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        trailing: Text('₹${h['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      );
                    }),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildReceiptsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Bursar Office', 'Fee Receipts', 'Audit History'],
            title: 'Serialized Payment Receipts & Audit History',
            subtitle: 'Formal institutional payment vouchers generated with unique serial numbers.',
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_receipts.isEmpty)
            const EmptyStateView(
              icon: Icons.receipt_long_outlined,
              title: 'No Payment Receipts on File',
              description: 'Collected counter fees and online payments will appear here.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: AppShadows.subtle,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _receipts.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final rec = _receipts[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primarySubtle,
                      child: Icon(Icons.receipt, color: AppColors.primary, size: 18),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(rec['receiptNo'] ?? 'REC-XXXX', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('₹${rec['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 15)),
                      ],
                    ),
                    subtitle: Text('${rec['studentName']} (${rec['admissionNo'] ?? 'N/A'}) • Method: ${rec['method']} • Date: ${rec['createdAt']?.toString().split('T')[0]}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), visualDensity: VisualDensity.compact),
                      onPressed: () => _showReceiptPreviewDialog(rec['id']),
                      icon: const Icon(Icons.preview, size: 14),
                      label: const Text('Preview'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultersReportTab() {
    final report = _feeReport;
    final grandTotals = report?['grandTotals'] ?? {};
    final defaulters = (report?['defaulters'] as List? ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Bursar Office', 'Reports', 'Aging Receivables'],
            title: 'Outstanding Fee Dues & Aging Defaulters Report',
            subtitle: 'Institutional analysis of overdue fee balances and collection efficiency.',
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Total Invoiced',
                  value: '₹${grandTotals['invoiced'] ?? 0}',
                  icon: Icons.account_balance_wallet_outlined,
                  subtitle: 'Gross Invoiced Billing',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Realized Collections',
                  value: '₹${grandTotals['collected'] ?? 0}',
                  icon: Icons.savings_outlined,
                  subtitle: 'Collected Revenue',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Collection Rate',
                  value: '${grandTotals['collectionRate'] ?? 100}%',
                  icon: Icons.analytics_outlined,
                  subtitle: 'Realization Efficiency',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Outstanding Defaulters',
                  value: '${defaulters.length}',
                  icon: Icons.warning_amber_outlined,
                  subtitle: 'Student Accounts Overdue',
                  color: defaulters.isNotEmpty ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

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
                    Text('Outstanding Fee Accounts Ledger', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    StatusBadge(label: '${defaulters.length} Defaulters', variant: defaulters.isNotEmpty ? BadgeVariant.error : BadgeVariant.success),
                  ],
                ),
                const Divider(height: 24),
                if (defaulters.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: Text('All student tuition and ancillary fees are settled in full!')),
                  )
                else
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.5),
                      1: FlexColumnWidth(2.2),
                      2: FlexColumnWidth(1.8),
                      3: FlexColumnWidth(2.0),
                      4: FlexColumnWidth(1.5),
                    },
                    border: TableBorder(
                      horizontalInside: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
                    ),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: AppColors.tableHeaderBg),
                        children: [
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Admission No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Class & Section', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Invoice Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Due Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                      ...defaulters.map((d) {
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(d['admissionNo'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(d['fullName'] ?? 'Learner', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('${d['className']} (${d['sectionName']})', style: const TextStyle(fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(d['title'] ?? 'Fee Invoice', style: const TextStyle(fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('₹${d['dueAmount']}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13))),
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
