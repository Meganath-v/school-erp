import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../data/outcomes_api.dart';
import 'outcomes_screen.dart';
import 'paper_detail_screen.dart';

/// Exam subjects and assignments of a subject; each can carry a question paper
/// with question-wise marks.
class AssessmentsTab extends StatefulWidget {
  final Map<String, dynamic> subject;
  const AssessmentsTab({super.key, required this.subject});

  @override
  State<AssessmentsTab> createState() => _AssessmentsTabState();
}

class _AssessmentsTabState extends State<AssessmentsTab> with AutomaticKeepAliveClientMixin {
  final _api = OutcomesApi();
  late Future<List<Map<String, dynamic>>> _future = _api.assessments(widget.subject['id'] as String);

  bool get _canEdit => widget.subject['canEdit'] == true;

  @override
  bool get wantKeepAlive => true;

  Future<void> _reload() async {
    final f = _api.assessments(widget.subject['id'] as String);
    setState(() => _future = f);
    await f;
  }

  Future<void> _setType(Map<String, dynamic> a, String type) async {
    try {
      await _api.setAssessmentType(a['id'] as String, type);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading assessments...');
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
              MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload),
            ]);
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return ListView(children: const [
              EmptyStateView(
                icon: Icons.event_note_outlined,
                title: 'No exams or assignments',
                message: 'Schedule an exam for this subject or create an assignment, then build its question paper here.',
              ),
            ]);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xxl),
            children: [
              Text('Question-wise marks feed outcome attainment. Internal = continuous assessment, External = final/board exam.',
                  style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.md),
              for (final a in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: AppRadius.xlBorderRadius,
                    child: InkWell(
                      borderRadius: AppRadius.xlBorderRadius,
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PaperDetailScreen(assessment: a, subject: widget.subject),
                        ));
                        if (mounted) _reload();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(borderRadius: AppRadius.xlBorderRadius, border: Border.all(color: AppColors.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(a['kind'] == 'exam' ? Icons.assignment_outlined : Icons.edit_note_outlined, color: AppColors.primaryAccent),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text('${a['title']}', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                            const Icon(Icons.chevron_right, color: AppColors.textMuted),
                          ]),
                          const SizedBox(height: 4),
                          Text('${a['subtitle']} · ${_date(a['date'])} · max ${a['maxMarks']}',
                              style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(spacing: AppSpacing.sm, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            StatusChip(
                              label: a['hasPaper'] == true ? 'Paper ready' : 'No paper yet',
                              color: a['hasPaper'] == true ? AppColors.success : AppColors.warning,
                            ),
                            if (a['kind'] == 'exam')
                              _canEdit
                                  ? PopupMenuButton<String>(
                                      tooltip: 'Assessment type',
                                      onSelected: (v) => _setType(a, v),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'INTERNAL', child: Text('Internal (continuous)')),
                                        PopupMenuItem(value: 'EXTERNAL', child: Text('External (final / board)')),
                                      ],
                                      child: StatusChip(label: '${_typeLabel(a['assessmentType'])} ▾', color: AppColors.secondary),
                                    )
                                  : StatusChip(label: _typeLabel(a['assessmentType']), color: AppColors.secondary)
                            else
                              const StatusChip(label: 'Internal', color: AppColors.secondary),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _typeLabel(dynamic t) => t == 'EXTERNAL' ? 'External' : 'Internal';
  static String _date(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}');
    return d == null ? '' : DateFormat('d MMM y').format(d.toLocal());
  }
}
