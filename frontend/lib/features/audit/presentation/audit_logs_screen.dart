import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/search_filter_bar.dart';
import '../../../core/widgets/state_views.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedActionFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchAuditLogs();
  }

  Future<void> _fetchAuditLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await ApiClient().dio.get('/audit-logs');
      setState(() {
        _logs = res.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  BadgeVariant _getActionVariant(String action) {
    final act = action.toUpperCase();
    if (act.contains('CREATE') || act.contains('ADMISSION') || act.contains('PAID') || act.contains('PUBLISH')) {
      return BadgeVariant.success;
    }
    if (act.contains('UPDATE') || act.contains('EDIT') || act.contains('PROMOT') || act.contains('SUBMIT')) {
      return BadgeVariant.info;
    }
    if (act.contains('DELETE') || act.contains('SUSPEND') || act.contains('FAIL') || act.contains('REJECT')) {
      return BadgeVariant.error;
    }
    if (act.contains('WARN') || act.contains('LATE') || act.contains('OVERDUE')) {
      return BadgeVariant.warning;
    }
    return BadgeVariant.neutral;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading institutional compliance and audit trail...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Audit Logs Unavailable',
        message: _errorMessage,
        onRetry: _fetchAuditLogs,
      );
    }

    final filteredLogs = _logs.where((log) {
      final matchesAction = _selectedActionFilter == 'ALL' ||
          (log['action'] ?? '').toString().toUpperCase() == _selectedActionFilter;
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return matchesAction;
      final actor = (log['actorName'] ?? '').toString().toLowerCase();
      final entity = (log['entity'] ?? '').toString().toLowerCase();
      final details = (log['details'] ?? '').toString().toLowerCase();
      final action = (log['action'] ?? '').toString().toLowerCase();
      return matchesAction && (actor.contains(q) || entity.contains(q) || details.contains(q) || action.contains(q));
    }).toList();

    final distinctActions = ['ALL', ...{..._logs.map((l) => (l['action'] ?? '').toString().toUpperCase())}.where((a) => a.isNotEmpty)];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            breadcrumbs: const ['Governance', 'System Compliance', 'Audit Trail'],
            title: 'Compliance & Activity Audit Log',
            subtitle: 'Immutable record of academic, administrative, financial and tenant configuration mutations.',
            actions: [
              OutlinedButton.icon(
                onPressed: _fetchAuditLogs,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Trail'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SearchFilterBar(
            searchHint: 'Search audit records by actor, target entity, or event details...',
            searchQuery: _searchQuery,
            onSearchChanged: (val) => setState(() => _searchQuery = val),
            totalCount: filteredLogs.length,
            countLabel: 'Events Recorded',
            filters: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedActionFilter,
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: distinctActions.map((action) {
                    return DropdownMenuItem(
                      value: action,
                      child: Text(action == 'ALL' ? 'All Event Types' : action),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedActionFilter = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          filteredLogs.isEmpty
              ? EmptyStateView(
                  icon: Icons.shield_outlined,
                  title: _searchQuery.isNotEmpty ? 'No Matching Audit Records' : 'Audit Trail is Empty',
                  description: _searchQuery.isNotEmpty
                      ? 'No activity records match your current search and action filters.'
                      : 'All subsequent institutional actions will be immutably recorded here.',
                  actionLabel: _searchQuery.isNotEmpty ? 'Clear Search' : null,
                  onAction: _searchQuery.isNotEmpty ? () => setState(() => _searchQuery = '') : null,
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
                          DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Action Type', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Target Entity', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Actor / Operator', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Event Details', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                        rows: filteredLogs.map((log) {
                          final ts = (log['timestamp'] ?? '').toString();
                          final formattedTs = ts.length >= 19 ? ts.replaceAll('T', ' ').substring(0, 19) : ts;
                          final action = (log['action'] ?? 'UNKNOWN').toString();

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  formattedTs,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              DataCell(
                                StatusBadge(
                                  label: action,
                                  variant: _getActionVariant(action),
                                ),
                              ),
                              DataCell(
                                Text(
                                  log['entity'] ?? 'System',
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppColors.primarySubtle,
                                      child: Text(
                                        (log['actorName'] ?? 'O').toString().substring(0, 1).toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      log['actorName'] ?? 'Operator',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 320,
                                  child: Text(
                                    log['details'] ?? 'N/A',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
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
}
