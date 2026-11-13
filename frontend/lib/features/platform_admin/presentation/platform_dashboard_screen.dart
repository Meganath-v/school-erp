import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class PlatformDashboardScreen extends ConsumerStatefulWidget {
  const PlatformDashboardScreen({super.key});

  @override
  ConsumerState<PlatformDashboardScreen> createState() => _PlatformDashboardScreenState();
}

class _PlatformDashboardScreenState extends ConsumerState<PlatformDashboardScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic> _schools = [];
  List<dynamic> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlatformData();
  }

  Future<void> _fetchPlatformData() async {
    setState(() => _isLoading = true);
    try {
      final statsRes = await ApiClient().dio.get('/platform/stats');
      final schoolsRes = await ApiClient().dio.get('/platform/schools');
      final plansRes = await ApiClient().dio.get('/platform/plans');

      setState(() {
        _stats = statsRes.data['data'];
        _schools = schoolsRes.data['data'] ?? [];
        _plans = plansRes.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showOnboardSchoolDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    String selectedPlan = 'GROWTH';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Onboard New School Tenant', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('School Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'School Full Name', hintText: 'e.g. Cambridge Academy'),
                      onChanged: (val) {
                        if (slugCtrl.text.isEmpty) {
                          slugCtrl.text = val.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(labelText: 'School Code (Unique)', hintText: 'e.g. CAM03'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: slugCtrl,
                            decoration: const InputDecoration(labelText: 'Slug / Subdomain', hintText: 'e.g. cambridge'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Initial Administrator', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: firstNameCtrl,
                            decoration: const InputDecoration(labelText: 'Admin First Name'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: lastNameCtrl,
                            decoration: const InputDecoration(labelText: 'Admin Last Name'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Admin Work Email', hintText: 'admin@cambridge.edu'),
                    ),
                    const SizedBox(height: 16),
                    Text('Subscription Tier', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedPlan,
                      decoration: const InputDecoration(labelText: 'Select Plan'),
                      items: const [
                        DropdownMenuItem(value: 'STARTER', child: Text('Starter Tier (₹4,999/yr • 250 Students)')),
                        DropdownMenuItem(value: 'GROWTH', child: Text('Growth Enterprise (₹14,999/yr • 1200 Students)')),
                      ],
                      onChanged: (val) => setDialogState(() => selectedPlan = val!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty || emailCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all required fields')),
                    );
                    return;
                  }

                  try {
                    final res = await ApiClient().dio.post('/platform/schools', data: {
                      'name': nameCtrl.text.trim(),
                      'code': codeCtrl.text.trim().toUpperCase(),
                      'slug': slugCtrl.text.trim().toLowerCase(),
                      'adminEmail': emailCtrl.text.trim(),
                      'adminFirstName': firstNameCtrl.text.trim().isEmpty ? 'Admin' : firstNameCtrl.text.trim(),
                      'adminLastName': lastNameCtrl.text.trim().isEmpty ? 'User' : lastNameCtrl.text.trim(),
                      'planCode': selectedPlan,
                    });
                    final creds = res.data['data']?['adminCredentials'];
                    final tempPassword = creds?['temporaryPassword'];

                    if (mounted) {
                      Navigator.pop(ctx);
                      _fetchPlatformData();
                      // The temporary admin password is returned only once; show it so it can be handed over.
                      showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('School provisioned'),
                          content: SelectableText(
                            tempPassword != null
                                ? 'Admin: ${creds['email']}\nTemporary password: $tempPassword\n\n'
                                    'This password is shown only once. Share it securely.'
                                : 'Existing user ${creds?['email'] ?? ''} was made School Admin. Their password is unchanged.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Done')),
                          ],
                        ),
                      );
                    }
                  } catch (err) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to onboard school. Code or slug might already exist.')),
                    );
                  }
                },
                child: const Text('Provision Tenant'),
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
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SaaS Platform Control Plane',
                    style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  Text(
                    'Platform-wide multi-tenant monitoring, provisioning, and subscription management',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showOnboardSchoolDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Onboard New School'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Metric KPI Cards
          Row(
            children: [
              _buildKpiCard('Total Schools', '${_stats?['totalSchools'] ?? 0}', Icons.domain, AppTheme.primary),
              const SizedBox(width: 16),
              _buildKpiCard('Active Tenants', '${_stats?['activeSchools'] ?? 0}', Icons.check_circle_outline, AppTheme.success),
              const SizedBox(width: 16),
              _buildKpiCard('Total Students', '${_stats?['totalStudents'] ?? 0}', Icons.school, AppTheme.secondary),
              const SizedBox(width: 16),
              _buildKpiCard('Total Faculty', '${_stats?['totalStaff'] ?? 0}', Icons.badge, AppTheme.accent),
              const SizedBox(width: 16),
              _buildKpiCard('Estimated ARR', '₹${((_stats?['estimatedArrMinor'] ?? 0) / 100).toStringAsFixed(0)}', Icons.payments, AppTheme.warning),
            ],
          ),
          const SizedBox(height: 32),
          // Tenants Directory Table
          Card(
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
                          const Icon(Icons.apartment, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Provisioned School Campuses (${_schools.length})',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _fetchPlatformData,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('School Name')),
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Plan')),
                        DataColumn(label: Text('Students')),
                        DataColumn(label: Text('Staff')),
                        DataColumn(label: Text('Classes')),
                        DataColumn(label: Text('Contact')),
                      ],
                      rows: _schools.map((s) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                                    child: Text(
                                      (s['code'] as String).substring(0, 2),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(s['name'], style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(s['code'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  s['status'],
                                  style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ),
                            DataCell(Text(s['activeSubscription']?['planName'] ?? 'Standard')),
                            DataCell(Text('${s['studentCount']}')),
                            DataCell(Text('${s['staffCount']}')),
                            DataCell(Text('${s['classCount']}')),
                            DataCell(Text(s['contactEmail'] ?? 'N/A')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
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
                  Text(title, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
