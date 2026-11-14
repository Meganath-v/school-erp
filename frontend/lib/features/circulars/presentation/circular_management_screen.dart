import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class CircularManagementScreen extends ConsumerStatefulWidget {
  const CircularManagementScreen({super.key});

  @override
  ConsumerState<CircularManagementScreen> createState() => _CircularManagementScreenState();
}

class _CircularManagementScreenState extends ConsumerState<CircularManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _circulars = [];
  List<dynamic> _classes = [];
  String _searchQuery = '';
  String _selectedAudienceFilter = 'ALL';
  String _selectedPriorityFilter = 'ALL';

  // Create Form State
  final _createFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _fileUrlController = TextEditingController();
  String _createTargetAudience = 'ALL';
  String _createPriority = 'NORMAL';
  bool _createRequiresAck = true;
  String? _createSelectedClassId;
  bool _isCreating = false;

  // Acknowledgment Report State
  String? _selectedCircularIdForReport;
  Map<String, dynamic>? _selectedCircularAckData;
  bool _isLoadingAckReport = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _fileUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient().dio.get('/circulars'),
        ApiClient().dio.get('/academics/classes'),
      ]);

      final circularsList = (results[0].data['data'] ?? results[0].data) as List<dynamic>? ?? [];
      final classesList = results[1].data['data'] as List<dynamic>? ?? [];

      setState(() {
        _circulars = circularsList;
        _classes = classesList;
        _isLoading = false;
        if (circularsList.isNotEmpty && _selectedCircularIdForReport == null) {
          _selectedCircularIdForReport = circularsList.first['id'];
        }
      });

      if (_selectedCircularIdForReport != null) {
        _loadAckReport(_selectedCircularIdForReport!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAckReport(String circularId) async {
    setState(() {
      _isLoadingAckReport = true;
    });

    try {
      final res = await ApiClient().dio.get('/circulars/$circularId/acknowledgements');
      setState(() {
        _selectedCircularAckData = (res.data['data'] ?? res.data) as Map<String, dynamic>?;
        _isLoadingAckReport = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAckReport = false;
      });
    }
  }

  Future<void> _dispatchCircular() async {
    if (!_createFormKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final payload = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'targetAudience': _createTargetAudience,
        'priority': _createPriority,
        'requiresAck': _createRequiresAck,
        if (_createSelectedClassId != null && _createTargetAudience == 'CLASS')
          'classId': _createSelectedClassId,
        if (_fileUrlController.text.trim().isNotEmpty)
          'fileUrl': _fileUrlController.text.trim(),
      };

      await ApiClient().dio.post('/circulars', data: payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notice dispatched and circular notifications sent to recipients!'),
          backgroundColor: AppColors.success,
        ),
      );

      _titleController.clear();
      _contentController.clear();
      _fileUrlController.clear();
      setState(() {
        _createTargetAudience = 'ALL';
        _createPriority = 'NORMAL';
        _createRequiresAck = true;
        _createSelectedClassId = null;
        _isCreating = false;
      });

      _loadInitialData();
      _tabController.animateTo(0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to dispatch circular: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() {
        _isCreating = false;
      });
    }
  }

  List<dynamic> get _filteredCirculars {
    return _circulars.where((c) {
      final title = (c['title'] ?? '').toString().toLowerCase();
      final num = (c['circularNumber'] ?? '').toString().toLowerCase();
      final sender = (c['senderName'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = q.isEmpty || title.contains(q) || num.contains(q) || sender.contains(q);
      final matchesAudience = _selectedAudienceFilter == 'ALL' || c['targetAudience'] == _selectedAudienceFilter;
      final matchesPriority = _selectedPriorityFilter == 'ALL' || c['priority'] == _selectedPriorityFilter;

      return matchesSearch && matchesAudience && matchesPriority;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading school circulars & notice registry...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Registry Sync Error',
        message: _errorMessage!,
        onRetry: _loadInitialData,
      );
    }

    final totalCirculars = _circulars.length;
    final urgentCount = _circulars.where((c) => c['priority'] == 'URGENT').length;
    final ackRequiredCount = _circulars.where((c) => c['requiresAck'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Institutional Circulars & Notices',
              subtitle: 'Dispatch official directives, broadcast policy bulletins, and track digital acknowledgements.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _loadInitialData,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Circular'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Top Metrics
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                MetricCard(
                  title: 'Total Dispatches',
                  value: totalCirculars.toString(),
                  icon: Icons.campaign_outlined,
                  color: AppColors.primary,
                  subtitle: 'Published institutional notices',
                ),
                MetricCard(
                  title: 'Urgent Directives',
                  value: urgentCount.toString(),
                  icon: Icons.priority_high,
                  color: AppColors.warning,
                  subtitle: 'High priority alerts',
                ),
                MetricCard(
                  title: 'Requires Sign-Off',
                  value: ackRequiredCount.toString(),
                  icon: Icons.draw_outlined,
                  color: AppColors.secondary,
                  subtitle: 'Mandatory parent/staff sign-offs',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Tab Navigation
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Circular Directory'),
                  Tab(icon: Icon(Icons.post_add, size: 18), text: 'Dispatch Circular'),
                  Tab(icon: Icon(Icons.fact_check_outlined, size: 18), text: 'Sign-off Compliance'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Tab Content
            SizedBox(
              height: 750,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCircularDirectoryTab(),
                  _buildDispatchCircularTab(),
                  _buildSignoffComplianceTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularDirectoryTab() {
    return Column(
      children: [
        SearchFilterBar(
          searchHint: 'Search circulars by number, title, or dispatcher...',
          searchQuery: _searchQuery,
          onSearchChanged: (val) => setState(() => _searchQuery = val),
          filters: [
            DropdownButton<String>(
              value: _selectedAudienceFilter,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Audiences')),
                DropdownMenuItem(value: 'ALL_PARENTS', child: Text('Parents Only')),
                DropdownMenuItem(value: 'ALL_TEACHERS', child: Text('Teachers Only')),
                DropdownMenuItem(value: 'CLASS', child: Text('Specific Classes')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedAudienceFilter = val);
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            DropdownButton<String>(
              value: _selectedPriorityFilter,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Priorities')),
                DropdownMenuItem(value: 'NORMAL', child: Text('Normal Priority')),
                DropdownMenuItem(value: 'URGENT', child: Text('Urgent Only')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedPriorityFilter = val);
              },
            ),
          ],
          totalCount: _filteredCirculars.length,
          countLabel: 'circulars found',
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _filteredCirculars.isEmpty
              ? const EmptyStateView(
                  icon: Icons.campaign_outlined,
                  title: 'No Circulars Found',
                  description: 'No circular matches your search and filter criteria.',
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    itemCount: _filteredCirculars.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final c = _filteredCirculars[index];
                      final isUrgent = c['priority'] == 'URGENT';
                      final requiresAck = c['requiresAck'] == true;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isUrgent
                              ? AppColors.errorSubtle
                              : AppColors.primarySubtle,
                          child: Icon(
                            isUrgent ? Icons.priority_high : Icons.campaign,
                            color: isUrgent ? AppColors.error : AppColors.primary,
                          ),
                        ),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Text(
                                c['circularNumber'] ?? 'CIR-REF',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                c['title'] ?? 'Untitled Notice',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUrgent) ...[
                              const SizedBox(width: AppSpacing.xs),
                              const StatusBadge(label: 'URGENT', variant: BadgeVariant.error, isSmall: true),
                            ],
                            const SizedBox(width: AppSpacing.xs),
                            StatusBadge(
                              label: (c['targetAudience'] ?? 'ALL').toString().replaceAll('_', ' '),
                              variant: BadgeVariant.info,
                              isSmall: true,
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['content'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.person_outline, size: 13, color: AppColors.textSubtle),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Issued by: ${c['senderName'] ?? 'Office Administration'}',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSubtle),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  if (requiresAck) ...[
                                    const Icon(Icons.verified_user_outlined, size: 13, color: AppColors.secondary),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Digital Sign-off Mandatory',
                                      style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                  if (c['fileUrl'] != null && c['fileUrl'].toString().isNotEmpty) ...[
                                    const SizedBox(width: AppSpacing.md),
                                    const Icon(Icons.attachment, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Has Attachment',
                                      style: TextStyle(fontSize: 11, color: AppColors.primary),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showInspectNoticeModal(c),
                              icon: const Icon(Icons.visibility, size: 14),
                              label: const Text('Read', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedCircularIdForReport = c['id'];
                                });
                                _loadAckReport(c['id']);
                                _tabController.animateTo(2);
                              },
                              icon: const Icon(Icons.checklist, size: 14),
                              label: const Text('Sign-offs', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDispatchCircularTab() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _createFormKey,
        child: ListView(
          children: [
            const Text(
              'Compose Institutional Notice / Circular',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Published circulars are instantly broadcasted to mobile portals and audit logs.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: AppSpacing.xl),

            // Notice Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Notice Subject / Title *',
                hintText: 'e.g. Schedule of Term-End Examinations & Advisory',
                prefixIcon: Icon(Icons.subtitles_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 5) {
                  return 'Please enter a descriptive title (at least 5 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Targeting & Priority Row
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
                  child: DropdownButtonFormField<String>(
                    initialValue: _createTargetAudience,
                    decoration: const InputDecoration(
                      labelText: 'Target Audience *',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Entire Campus (All Users)')),
                      DropdownMenuItem(value: 'ALL_PARENTS', child: Text('All Parents & Guardians')),
                      DropdownMenuItem(value: 'ALL_TEACHERS', child: Text('All Teaching Faculty')),
                      DropdownMenuItem(value: 'CLASS', child: Text('Specific Class & Section')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _createTargetAudience = val;
                        });
                      }
                    },
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
                  child: DropdownButtonFormField<String>(
                    initialValue: _createPriority,
                    decoration: const InputDecoration(
                      labelText: 'Priority Level *',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'NORMAL', child: Text('Standard Bulletin')),
                      DropdownMenuItem(value: 'URGENT', child: Text('Urgent Directive')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _createPriority = val);
                    },
                  ),
                ),
                if (_createTargetAudience == 'CLASS')
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
                    child: DropdownButtonFormField<String>(
                      initialValue: _createSelectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Select Class *',
                        prefixIcon: Icon(Icons.class_outlined),
                      ),
                      items: _classes.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem<String>(
                          value: c['id'],
                          child: Text('${c['name']} (Grade ${c['gradeLevel'] ?? ''})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _createSelectedClassId = val);
                      },
                      validator: (val) {
                        if (_createTargetAudience == 'CLASS' && val == null) {
                          return 'Please select target class';
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Attachment Link
            TextFormField(
              controller: _fileUrlController,
              decoration: const InputDecoration(
                labelText: 'Official Document / Attachment Link (Optional)',
                hintText: 'e.g. https://storage.school.edu/circulars/sports_circular.pdf',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Checkbox for Digital Signature Requirement
            CheckboxListTile(
              title: const Text('Require Explicit Digital Signature / Acknowledgement'),
              subtitle: const Text(
                'Guardians and staff will receive a sign-off requirement prompt on their portal.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _createRequiresAck,
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) {
                setState(() => _createRequiresAck = val ?? false);
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Circular Content Body
            TextFormField(
              controller: _contentController,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Circular Content & Directives *',
                hintText: 'Enter the complete announcement body, rules, schedule, and guidelines for recipients...',
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 10) {
                  return 'Please provide comprehensive notice content (min 10 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // Dispatch Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    _titleController.clear();
                    _contentController.clear();
                    _fileUrlController.clear();
                  },
                  child: const Text('Reset Form'),
                ),
                const SizedBox(width: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: _isCreating ? null : _dispatchCircular,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isCreating ? 'Broadcasting...' : 'Publish & Broadcast Notice'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignoffComplianceTab() {
    if (_circulars.isEmpty) {
      return const EmptyStateView(
        icon: Icons.fact_check_outlined,
        title: 'No Circulars for Audit',
        description: 'Publish a circular first to inspect parent and staff sign-off compliance.',
      );
    }

    final currentCircular = _circulars.firstWhere(
      (c) => c['id'] == _selectedCircularIdForReport,
      orElse: () => _circulars.first,
    );

    final acks = (_selectedCircularAckData?['acknowledgements'] as List<dynamic>?) ?? [];

    return Column(
      children: [
        // Circular Selector Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              const Text('Audit Circular:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButton<String>(
                  value: currentCircular['id'],
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _circulars.map<DropdownMenuItem<String>>((c) {
                    return DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(
                        '${c['circularNumber'] ?? ''} - ${c['title'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCircularIdForReport = val);
                      _loadAckReport(val);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                onPressed: () => _loadAckReport(currentCircular['id']),
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh acknowledgments',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Compliance Summary Banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentCircular['title'] ?? 'Selected Notice',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dispatched to ${currentCircular['targetAudience']} • Requires sign-off: ${currentCircular['requiresAck'] ? 'YES' : 'NO'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.primaryLight),
                ),
                child: Column(
                  children: [
                    Text(
                      '${acks.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text('Total Sign-offs', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Acknowledgements List / Table
        Expanded(
          child: _isLoadingAckReport
              ? const LoadingStateView(message: 'Querying digital audit logs & signature timestamps...')
              : acks.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.fact_check_outlined,
                      title: 'No Digital Acknowledgements Yet',
                      description: 'No recipients have signed off this notice yet.',
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        itemCount: acks.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final a = acks[index];
                          final user = a['user'] ?? {};
                          final name = user['name'] ?? a['userName'] ?? 'Acknowledging User';
                          final role = user['role'] ?? 'GUARDIAN';
                          final ackAt = a['acknowledgedAt'] != null
                              ? DateTime.tryParse(a['acknowledgedAt'])
                              : null;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.successSubtle,
                              child: const Icon(Icons.verified, color: AppColors.success, size: 20),
                            ),
                            title: Row(
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(width: AppSpacing.sm),
                                StatusBadge(label: role, variant: BadgeVariant.neutral, isSmall: true),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.schedule, size: 12, color: AppColors.textSubtle),
                                  const SizedBox(width: 4),
                                  Text(
                                    ackAt != null
                                        ? '${ackAt.year}-${ackAt.month.toString().padLeft(2, '0')}-${ackAt.day.toString().padLeft(2, '0')} ${ackAt.hour.toString().padLeft(2, '0')}:${ackAt.minute.toString().padLeft(2, '0')}'
                                        : 'Recorded',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  if (a['remarks'] != null && a['remarks'].toString().isNotEmpty) ...[
                                    const SizedBox(width: AppSpacing.md),
                                    Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.textSubtle),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Note: "${a['remarks']}"',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.successSubtle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 12, color: AppColors.success),
                                  SizedBox(width: 4),
                                  Text(
                                    'Signed',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _showInspectNoticeModal(dynamic c) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  c['circularNumber'] ?? 'CIR-REF',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  c['title'] ?? 'Notice Details',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge(label: c['priority'] ?? 'NORMAL', variant: c['priority'] == 'URGENT' ? BadgeVariant.error : BadgeVariant.neutral),
                      const SizedBox(width: AppSpacing.sm),
                      StatusBadge(label: 'Audience: ${c['targetAudience']}', variant: BadgeVariant.info),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Dispatcher: ${c['senderName'] ?? 'Office Administration'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const Divider(height: AppSpacing.lg),
                  const Text('Notice Directives & Body:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      c['content'] ?? '',
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                  if (c['fileUrl'] != null && c['fileUrl'].toString().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Text('Attached Document Link:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    SelectableText(
                      c['fileUrl'].toString(),
                      style: const TextStyle(color: AppColors.primary, fontSize: 12, decoration: TextDecoration.underline),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close Preview'),
            ),
          ],
        );
      },
    );
  }
}
