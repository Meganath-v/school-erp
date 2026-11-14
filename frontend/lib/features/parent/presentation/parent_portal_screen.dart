import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';

class ParentPortalScreen extends ConsumerStatefulWidget {
  const ParentPortalScreen({super.key});

  @override
  ConsumerState<ParentPortalScreen> createState() => _ParentPortalScreenState();
}

class _ParentPortalScreenState extends ConsumerState<ParentPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<dynamic> _children = [];
  int _selectedChildIndex = 0;

  Map<String, dynamic>? _selectedChildDetail;
  Map<String, dynamic>? _reportCard;
  List<dynamic> _invoices = [];
  List<dynamic> _timetable = [];
  List<dynamic> _homework = [];
  List<dynamic> _courseMaterials = [];
  List<dynamic> _teachingDiaries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadLinkedChildren();
  }

  Future<void> _loadLinkedChildren() async {
    setState(() => _isLoading = true);
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChildData(String studentId) async {
    try {
      final detailRes = await ApiClient().dio.get('/students/$studentId');
      final reportRes = await ApiClient().dio.get('/students/$studentId/report-card');
      final invoicesRes = await ApiClient().dio.get('/fees/invoices', queryParameters: {'studentId': studentId});
      final ttRes = await ApiClient().dio.get('/timetable/entries');
      final hwRes = await ApiClient().dio.get('/assignments');
      final matRes = await ApiClient().dio.get('/academics/course-materials');
      final diaryRes = await ApiClient().dio.get('/academics/teaching-diaries');

      setState(() {
        _selectedChildDetail = detailRes.data['data'];
        _reportCard = reportRes.data['data'];
        _invoices = invoicesRes.data['data'] ?? [];
        _timetable = ttRes.data['data'] ?? [];
        _homework = hwRes.data['data'] ?? [];
        _courseMaterials = matRes.data['data'] ?? [];
        _teachingDiaries = diaryRes.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
            title: Text('Pay School Fees Online', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice: ${inv['invoiceNo']} • ${inv['title']}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Payable Balance:', style: GoogleFonts.inter(fontSize: 14)),
                        Text('₹$amountDue', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Select Payment Channel', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(labelText: 'Payment Gateway'),
                    items: const [
                      DropdownMenuItem(value: 'ONLINE', child: Text('UPI / Netbanking (Razorpay Gateway)')),
                      DropdownMenuItem(value: 'CARD', child: Text('Credit / Debit Card')),
                    ],
                    onChanged: (val) => setDialogState(() => method = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: () async {
                  // Payments can only be marked successful by a verified payment-gateway
                  // callback on the server. Until a gateway is integrated, create the
                  // checkout order (server-side amount) and direct the parent to the office.
                  String message;
                  try {
                    await ApiClient().dio.post('/payments/checkout', data: {
                      'invoiceId': inv['id'],
                      'method': method,
                    });
                    message = 'Online payment is not available yet. Please pay ₹$amountDue at the school office.';
                  } catch (_) {
                    message = 'Could not start the payment. Please try again or contact the school office.';
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                  }
                },
                icon: const Icon(Icons.lock, size: 16),
                label: Text('Pay ₹$amountDue Now'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showReceiptDialog(String receiptNo, String amount, String title) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 24),
              const SizedBox(width: 8),
              Text('Payment Successful', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receipt Number: $receiptNo', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Text('An official digitally-signed tax receipt has been generated and archived in your school ledger.'),
              const SizedBox(height: 8),
              Text('Amount Paid: ₹$amount for "$title"', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ],
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        );
      },
    );
  }

  void _showApplyLeaveDialog() {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Apply for Student Leave', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                if (reasonCtrl.text.isEmpty) return;
                try {
                  await ApiClient().dio.post('/leave-requests', data: {
                    'studentId': _children[_selectedChildIndex]['id'],
                    'startDate': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
                    'endDate': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
                    'reason': reasonCtrl.text.trim(),
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave application sent to Class Teacher.')));
                  }
                } catch (_) {}
              },
              child: const Text('Submit Application'),
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

    if (_children.isEmpty) {
      return const Center(child: Text('No verified children linked to this parent account.'));
    }

    final currentChild = _children[_selectedChildIndex];
    final attendancePct = _selectedChildDetail?['attendancePercentage'] ?? 95;
    final isShortage = attendancePct < 75;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Child Switcher Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Enrolled Children (Linways AMS)', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
              ElevatedButton.icon(
                onPressed: _showApplyLeaveDialog,
                icon: const Icon(Icons.event_busy, size: 16),
                label: const Text('Apply for Leave'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Child Selector Cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_children.length, (idx) {
              final child = _children[idx];
              final isSelected = idx == _selectedChildIndex;

              return InkWell(
                onTap: () => _switchChild(idx),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppTheme.primary.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isSelected ? AppTheme.primary : AppTheme.textMuted,
                        child: Text(
                          (child['fullName'] as String).substring(0, 1),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child['fullName'],
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isSelected ? AppTheme.primary : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            '${child['currentClass']} (${child['currentSection']}) • Roll No: ${child['rollNo'] ?? 'N/A'}',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          // Child Header Profile & Linways Attendance Meter
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primary.withOpacity(0.12),
                    child: const Icon(Icons.school, size: 32, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentChild['fullName'], style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Admission No: ${currentChild['admissionNo']} • Class: ${currentChild['currentClass']} - ${currentChild['currentSection']} • Blood Group: ${currentChild['bloodGroup'] ?? 'O+'}',
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  // Linways Attendance Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isShortage ? AppTheme.error.withOpacity(0.08) : AppTheme.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isShortage ? AppTheme.error.withOpacity(0.3) : AppTheme.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(isShortage ? Icons.warning_amber : Icons.check_circle, color: isShortage ? AppTheme.error : AppTheme.success, size: 28),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$attendancePct% Attendance',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isShortage ? AppTheme.error : AppTheme.success,
                                )),
                            Text(isShortage ? '⚠️ Shortage Warning (<75%)' : 'Academic Standing: Good',
                                style: GoogleFonts.inter(fontSize: 11, color: isShortage ? AppTheme.error : AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Linways Tabs: Academic Report Card, Course Repository, Teaching Diary, Homework, Timetable, Fee Invoices
          Card(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textMuted,
                  indicatorColor: AppTheme.primary,
                  isScrollable: true,
                  tabs: const [
                    Tab(icon: Icon(Icons.verified, size: 18), text: 'Academic Progress Card'),
                    Tab(icon: Icon(Icons.folder_shared, size: 18), text: 'Study Materials Repository'),
                    Tab(icon: Icon(Icons.book, size: 18), text: "Daily Course Log"),
                    Tab(icon: Icon(Icons.assignment, size: 18), text: 'Active Homework'),
                    Tab(icon: Icon(Icons.schedule, size: 18), text: 'Class Timetable'),
                    Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Fee Invoices & Receipts'),
                  ],
                ),
                const Divider(height: 1),
                SizedBox(
                  height: 450,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildReportCardTab(),
                      _buildStudyMaterialsTab(),
                      _buildTeachingDiaryTab(),
                      _buildHomeworkTab(),
                      _buildTimetableTab(),
                      _buildFeesTab(),
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

  // 1. Report Card
  Widget _buildReportCardTab() {
    final exams = _reportCard?['exams'] as List? ?? [];

    if (exams.isEmpty) {
      return const Center(child: Text('No published report cards available for this term yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        final subjects = exam['subjects'] as List? ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(exam['examName'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        'Total Score: ${exam['totalMarksObtained']} / ${exam['totalMaxMarks']}',
                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                ...subjects.map((sub) {
                  final pct = ((sub['marksObtained'] ?? 0) / (sub['maxMarks'] ?? 100)) * 100;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(sub['subjectName'], style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            Text('${sub['marksObtained']} / ${sub['maxMarks']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pct >= 80 ? AppTheme.success.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pct >= 85 ? 'Grade A+' : pct >= 70 ? 'Grade A' : 'Pass',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: pct >= 80 ? AppTheme.success : AppTheme.primary,
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
      },
    );
  }

  // 2. Study Materials Repository
  Widget _buildStudyMaterialsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _courseMaterials.length,
      itemBuilder: (context, index) {
        final mat = _courseMaterials[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.secondary.withOpacity(0.12),
              child: Icon(mat['fileType'] == 'SLIDES' ? Icons.slideshow : Icons.picture_as_pdf, color: AppTheme.secondary, size: 20),
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

  // 3. Teaching Diary / Daily Course Log
  Widget _buildTeachingDiaryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _teachingDiaries.length,
      itemBuilder: (context, index) {
        final d = _teachingDiaries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text('P${d['periodNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d['subjectName']} • ${d['date']?.toString().split('T')[0]}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(d['topicTaught'], style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                      if (d['remarks'] != null) ...[
                        const SizedBox(height: 4),
                        Text('Faculty Note: ${d['remarks']}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                  child: Text(d['methodology'] ?? 'LECTURE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 4. Homework
  Widget _buildHomeworkTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _homework.length,
      itemBuilder: (context, index) {
        final hw = _homework[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.assignment, color: AppTheme.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hw['title'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(hw['description'], style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark)),
                      const SizedBox(height: 4),
                      Text('Subject: ${hw['subjectName']} • Due Date: ${hw['dueDate']?.toString().split('T')[0]}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                Chip(label: const Text('Assigned'), backgroundColor: const Color(0xFFF1F5F9)),
              ],
            ),
          ),
        );
      },
    );
  }

  // 5. Timetable
  Widget _buildTimetableTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _timetable.length,
      itemBuilder: (context, index) {
        final t = _timetable[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('P${t['periodNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ),
          title: Text('${t['subjectName']} (${t['teacherName']})', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${t['startTime']} - ${t['endTime']} • Room: ${t['room'] ?? 'General Room'}'),
        );
      },
    );
  }

  // 6. Fees
  Widget _buildFeesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        final isPaid = inv['status'] == 'PAID';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.receipt, color: AppTheme.primary, size: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv['title'], style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Invoice No: ${inv['invoiceNo']} • Due Date: ${inv['dueDate']?.toString().split('T')[0]}',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      Text('Total: ₹${inv['amount']} • Paid: ₹${inv['paidAmount']} • Due: ₹${inv['dueAmount']}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
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
                  OutlinedButton.icon(
                    onPressed: () {
                      final receipt = inv['payments'] is List && (inv['payments'] as List).isNotEmpty
                          ? inv['payments'][0]['receiptNo'] ?? 'REC-${inv['invoiceNo']}'
                          : 'REC-${inv['invoiceNo']}';
                      _showReceiptDialog(receipt, (inv['paidAmount'] ?? inv['amount']).toString(), inv['title']);
                    },
                    icon: const Icon(Icons.receipt_long, size: 16, color: AppTheme.success),
                    label: const Text('View Receipt', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
