import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class PlatformDashboardScreen extends ConsumerStatefulWidget {
  const PlatformDashboardScreen({super.key});

  @override
  ConsumerState<PlatformDashboardScreen> createState() => _PlatformDashboardScreenState();
}

class _PlatformDashboardScreenState extends ConsumerState<PlatformDashboardScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic> _schools = [];
  List<dynamic> _plans = [];
  List<dynamic> _auditLogs = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchPlatformData();
  }

  Future<void> _fetchPlatformData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ApiClient().dio.get('/platform/stats'),
        ApiClient().dio.get('/platform/schools'),
        ApiClient().dio.get('/platform/plans').catchError((_) => null as dynamic),
        ApiClient().dio.get('/audit-logs').catchError((_) => null as dynamic),
      ]);

      setState(() {
        _stats = results[0].data['data'];
        _schools = results[1].data['data'] ?? [];
        _plans = results[2]?.data?['data'] ?? [];
        _auditLogs = results[3]?.data?['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
            title: const Text('Provision Institution Tenant'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Institutional Identity',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Institution Legal Name',
                        hintText: 'e.g. Cambridge International Academy',
                      ),
                      onChanged: (val) {
                        if (slugCtrl.text.isEmpty) {
                          slugCtrl.text = val.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Unique Campus Code',
                              hintText: 'e.g. CAM03',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: slugCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Subdomain / Slug',
                              hintText: 'e.g. cambridge',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Primary Administrator Account',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: firstNameCtrl,
                            decoration: const InputDecoration(labelText: 'Admin First Name'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: lastNameCtrl,
                            decoration: const InputDecoration(labelText: 'Admin Last Name'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Official Work Email',
                        hintText: 'principal@institution.edu',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'SaaS Subscription Plan',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      value: selectedPlan,
                      decoration: const InputDecoration(labelText: 'Service Tier'),
                      items: const [
                        DropdownMenuItem(value: 'STARTER', child: Text('Starter Tier (₹4,999/yr • 250 Students)')),
                        DropdownMenuItem(value: 'GROWTH', child: Text('Growth Tier (₹14,999/yr • 1,200 Students)')),
                        DropdownMenuItem(value: 'ENTERPRISE', child: Text('Enterprise Campus (Unlimited)')),
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
                  if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all required institution credentials')),
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
                      showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.check_circle, color: AppColors.success),
                              SizedBox(width: AppSpacing.sm),
                              Text('Institution Provisioned'),
                            ],
                          ),
                          content: SelectableText(
                            tempPassword != null
                                ? 'School Administrator: ${creds['email']}\nTemporary Password: $tempPassword\n\n'
                                    'This temporary credential is generated once. Securely transmit it to the school authority.'
                                : 'Existing account ${creds?['email'] ?? ''} granted School Administrator role. Password remains unchanged.',
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
      return const LoadingStateView(message: 'Loading SaaS platform management telemetry...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Platform Control Plane Error',
        errorMessage: _errorMessage,
        onRetry: _fetchPlatformData,
      );
    }

    final filteredSchools = _schools.where((s) {
      final matchesStatus = _selectedStatusFilter == 'ALL' || (s['status'] ?? '').toString() == _selectedStatusFilter;
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return matchesStatus;
      final name = (s['name'] ?? '').toString().toLowerCase();
      final code = (s['code'] ?? '').toString().toLowerCase();
      final email = (s['contactEmail'] ?? '').toString().toLowerCase();
      return matchesStatus && (name.contains(q) || code.contains(q) || email.contains(q));
    }).toList();

    final suspendedCount = _stats?['suspendedSchools'] ?? _schools.where((s) => s['status'] == 'SUSPENDED').length;
    final totalSchools = _stats?['totalSchools'] ?? _schools.length;
    final activeSchools = _stats?['activeSchools'] ?? _schools.where((s) => s['status'] == 'ACTIVE').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Platform Owner', 'Multi-Tenant Control Plane'],
            title: 'SaaS Platform Control Plane',
            subtitle: 'Multi-institutional tenant orchestration, provisioning, resource quotas, and ARR telemetry. (Click cards to filter)',
            actions: [
              OutlinedButton.icon(
                onPressed: _fetchPlatformData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: _showOnboardSchoolDialog,
                icon: const Icon(Icons.add_business, size: 16),
                label: const Text('Provision Institution'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Platform KPI Metric Cards with Interactive Filtering
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              final cards = [
                MetricCard(
                  title: 'Registered Schools',
                  value: '$totalSchools',
                  icon: Icons.domain_outlined,
                  subtitle: 'All tenants • Click to view all',
                  color: AppColors.primary,
                  onTap: () => setState(() => _selectedStatusFilter = 'ALL'),
                ),
                MetricCard(
                  title: 'Active Schools',
                  value: '$activeSchools',
                  icon: Icons.verified_outlined,
                  subtitle: 'Operational • Click to filter',
                  color: AppColors.success,
                  onTap: () => setState(() => _selectedStatusFilter = 'ACTIVE'),
                ),
                MetricCard(
                  title: 'Suspended Schools',
                  value: '$suspendedCount',
                  icon: Icons.block_outlined,
                  subtitle: 'Dormant • Click to filter',
                  color: suspendedCount > 0 ? AppColors.error : AppColors.textMuted,
                  onTap: () => setState(() => _selectedStatusFilter = 'SUSPENDED'),
                ),
                MetricCard(
                  title: 'Enrolled Students',
                  value: '${_stats?['totalStudents'] ?? 0}',
                  icon: Icons.school_outlined,
                  subtitle: 'Platform-wide enrollment',
                  color: AppColors.info,
                ),
                MetricCard(
                  title: 'Annualized ARR',
                  value: '₹${((_stats?['estimatedArrMinor'] ?? 0) / 100).toStringAsFixed(0)}',
                  icon: Icons.monetization_on_outlined,
                  subtitle: 'Contracted subscription revenue',
                  color: AppColors.warning,
                ),
              ];

              if (isDesktop) {
                return Row(
                  children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: AppSpacing.md), child: c))).toList(),
                );
              } else {
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: cards.map((c) => SizedBox(width: (constraints.maxWidth - AppSpacing.md) / 2, child: c)).toList(),
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Platform Usage Statistics
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: AppShadows.subtle,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildUsagePill('Platform Students', '${_stats?['totalStudents'] ?? 0}', Icons.people_outline, AppColors.primary),
                _buildUsagePill('Academic Faculty', '${_stats?['totalStaff'] ?? 0}', Icons.badge_outlined, AppColors.secondary),
                _buildUsagePill('Active Classrooms', '${_stats?['totalClasses'] ?? 0}', Icons.meeting_room_outlined, AppColors.accent),
                _buildUsagePill('Subscription Tiers', '${_plans.isNotEmpty ? _plans.length : (_stats?['plansAvailable'] ?? 2)}', Icons.card_membership_outlined, AppColors.warning),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          SearchFilterBar(
            searchHint: 'Search institutions by school name, campus code, or email...',
            searchQuery: _searchQuery,
            onSearchChanged: (val) => setState(() => _searchQuery = val),
            totalCount: filteredSchools.length,
            countLabel: 'Institutions Found',
            filters: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatusFilter,
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Campus Statuses')),
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                    DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatusFilter = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          filteredSchools.isEmpty
              ? EmptyStateView(
                  icon: Icons.domain_disabled_outlined,
                  title: _searchQuery.isNotEmpty ? 'No Matching Institutions' : 'No Provisioned Institutions Found',
                  description: _searchQuery.isNotEmpty
                      ? 'No school tenant records match your search filter.'
                      : 'Provision your first educational institution using the button above.',
                  actionLabel: _searchQuery.isNotEmpty ? 'Clear Filter' : 'Provision School',
                  onAction: _searchQuery.isNotEmpty ? () => setState(() => _searchQuery = '') : _showOnboardSchoolDialog,
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
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 68,
                        horizontalMargin: AppSpacing.lg,
                        columnSpacing: AppSpacing.xl,
                        columns: const [
                          DataColumn(label: Text('Institution Campus', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Tenant Status', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Subscription Tier', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Students', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Faculty', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Classes', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Contact Work Email', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                        rows: filteredSchools.map((s) {
                          final code = (s['code'] ?? 'SC').toString();
                          final monogram = code.length >= 2 ? code.substring(0, 2) : code;
                          final status = (s['status'] ?? 'ACTIVE').toString();
                          final plan = s['activeSubscription']?['planName'] ?? 'Growth Enterprise';

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primarySubtle,
                                      child: Text(
                                        monogram,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          s['name'] ?? 'Institution',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        Text(
                                          'slug: ${s['slug'] ?? 'default'}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(AppRadius.xs),
                                    border: Border.all(color: AppColors.borderLight),
                                  ),
                                  child: Text(
                                    code,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace'),
                                  ),
                                ),
                              ),
                              DataCell(StatusBadge.fromStatus(status)),
                              DataCell(
                                StatusBadge(
                                  label: plan,
                                  variant: BadgeVariant.info,
                                ),
                              ),
                              DataCell(Text('${s['studentCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text('${s['staffCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text('${s['classCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(
                                Text(
                                  s['contactEmail'] ?? 'N/A',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: AppSpacing.xxl),

          // Recent Platform Events from Audit Logs
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
                    const Row(
                      children: [
                        Icon(Icons.history_outlined, color: AppColors.primary, size: 20),
                        SizedBox(width: AppSpacing.sm),
                        Text('Recent Platform Events & Security Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Text('${_auditLogs.length} events logged', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_auditLogs.isEmpty)
                  const Text('No recent platform events recorded yet.', style: TextStyle(color: AppColors.textSecondary))
                else
                  ..._auditLogs.take(5).map((log) {
                    final ts = (log['timestamp'] ?? '').toString();
                    final formattedTs = ts.length >= 19 ? ts.replaceAll('T', ' ').substring(0, 19) : ts;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(log['action'] ?? 'EVENT', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: AppSpacing.sm),
                          Text('by ${log['actorName'] ?? 'Operator'} • $formattedTs', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsagePill(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}
