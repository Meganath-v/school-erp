import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/ai_exam_api.dart';
import '../student/performance_view.dart';
import '../widgets/ai_widgets.dart';

/// Class / subject analytics with filters and student drill-down.
class ClassAnalyticsView extends StatefulWidget {
  final AiExamApi api;
  final String? testId;
  final bool compact;
  final bool admin;
  const ClassAnalyticsView({super.key, required this.api, this.testId, this.compact = false, this.admin = false});

  @override
  State<ClassAnalyticsView> createState() => _ClassAnalyticsViewState();
}

class _ClassAnalyticsViewState extends State<ClassAnalyticsView> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _options;
  String? _classId;
  String? _sectionId;
  String? _subjectId;
  String? _yearId;
  DateTimeRange? _range;
  late Future<Map<String, dynamic>> _future = _fetch();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!widget.compact) {
      widget.api.options().then((o) {
        if (mounted) setState(() => _options = o);
      }).catchError((_) {});
    }
  }

  Future<Map<String, dynamic>> _fetch() {
    final f = {
      'testId': widget.testId,
      'classId': _classId,
      'sectionId': _sectionId,
      'subjectId': _subjectId,
      'academicYearId': _yearId,
      'from': _range?.start.toUtc().toIso8601String(),
      'to': _range?.end.add(const Duration(days: 1)).toUtc().toIso8601String(),
    };
    return widget.admin ? widget.api.adminAnalytics(f) : widget.api.classAnalytics(f);
  }

  Future<void> _reload() async {
    final f = _fetch();
    setState(() => _future = f);
    await f;
  }

  List<Map<String, dynamic>> get _classes => AiExamApi.list(_options?['classes']);
  List<Map<String, dynamic>> get _subjects {
    final c = _classes.where((c) => c['id'] == _classId).firstOrNull;
    final list = c == null ? _classes.expand((c) => AiExamApi.list(c['subjects'])) : AiExamApi.list(c['subjects']);
    final seen = <String>{};
    return list.where((s) => seen.add(s['id'] as String)).toList();
  }

  List<Map<String, dynamic>> get _sections {
    final c = _classes.where((c) => c['id'] == _classId).firstOrNull;
    if (c == null) return [];
    final seen = <String>{};
    return AiExamApi.list(c['subjects']).expand((s) => AiExamApi.list(s['sections'])).where((s) => seen.add(s['id'] as String)).toList();
  }

  Widget _filters() {
    if (widget.compact || _options == null) return const SizedBox.shrink();
    Widget dd(String label, String? value, List<Map<String, dynamic>> items, ValueChanged<String?> onChanged, {String all = 'All'}) => SizedBox(
          width: 160,
          child: DropdownButtonFormField<String?>(
            key: ValueKey('$label-$value-${items.length}'),
            initialValue: value,
            isExpanded: true,
            isDense: true,
            decoration: InputDecoration(labelText: label),
            items: [DropdownMenuItem<String?>(value: null, child: Text(all)), for (final i in items) DropdownMenuItem<String?>(value: i['id'] as String, child: Text('${i['name']}', overflow: TextOverflow.ellipsis))],
            onChanged: onChanged,
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
        dd('Class', _classId, _classes, (v) {
          _classId = v;
          _sectionId = null;
          _subjectId = null;
          _reload();
        }),
        if (_classId != null)
          dd('Section', _sectionId, _sections, (v) {
            _sectionId = v;
            _reload();
          }),
        dd('Subject', _subjectId, _subjects, (v) {
          _subjectId = v;
          _reload();
        }),
        dd('Year', _yearId, AiExamApi.list(_options?['academicYears']), (v) {
          _yearId = v;
          _reload();
        }, all: 'All years'),
        ActionChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(_range == null ? 'Any date' : '${fmtDate(_range!.start.toIso8601String(), time: false)} – ${fmtDate(_range!.end.toIso8601String(), time: false)}'),
          onPressed: () async {
            final now = DateTime.now();
            final r = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 2), lastDate: now, initialDateRange: _range);
            setState(() => _range = r);
            _reload();
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          final body = <Widget>[_filters()];
          if (snap.connectionState != ConnectionState.done) {
            body.add(const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator())));
          } else if (snap.hasError) {
            body.add(MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload));
          } else {
            final d = snap.data!;
            final s = AiExamApi.map(d['summary']);
            final tests = AiExamApi.list(d['tests']);
            final trend = AiExamApi.map(s['trend']);
            if ((s['tests'] ?? 0) == 0) {
              body.add(const EmptyStateView(icon: Icons.insights_outlined, title: 'No analytics yet', message: 'Analytics appear once published tests have evaluated submissions.'));
            } else {
              body.addAll([
                KpiGrid(tiles: [
                  KpiTile(label: 'Average', value: s['average'] == null ? '—' : '${fmtNum(s['average'] as num)}%', icon: Icons.percent, color: percentColor(s['average'] as num?)),
                  KpiTile(label: 'Completion', value: s['completionRate'] == null ? '—' : '${fmtNum(s['completionRate'] as num)}%', icon: Icons.task_alt, color: AppColors.info),
                  KpiTile(label: 'Highest', value: s['highest'] == null ? '—' : '${fmtNum(s['highest'] as num)}%', icon: Icons.arrow_upward, color: AppColors.success),
                  KpiTile(label: 'Lowest', value: s['lowest'] == null ? '—' : '${fmtNum(s['lowest'] as num)}%', icon: Icons.arrow_downward, color: AppColors.error),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${s['tests']} test(s) · ${s['submissions']} of ${s['assigned']} submitted · ${s['evaluated']} evaluated'
                  '${(s['awaitingEvaluation'] ?? 0) > 0 ? ' · ${s['awaitingEvaluation']} awaiting evaluation' : ''}'
                  '${trend.isNotEmpty ? ' · class ${trend['direction']} (${(trend['change'] as num) >= 0 ? '+' : ''}${fmtNum(trend['change'] as num)} pts)' : ''}',
                  style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                if (!widget.compact) ...[
                  const SectionTitle('Performance across tests'),
                  SectionCard(title: 'Average by test', icon: Icons.stacked_bar_chart, children: [
                    TrendBars(points: [for (final (i, t) in tests.indexed) (label: 'T${i + 1}', percent: t['average'] as num?, tooltip: '${t['title']} · ${t['className']}')]),
                  ]),
                ],
                const SectionTitle('Subjects'),
                _bars(AiExamApi.list(d['subjects']), (x) => '${x['subject']}', (x) => x['average'] as num?, (x) => '${x['submissions']} evaluated submissions'),
                const SectionTitle('Topics', subtitle: 'Weakest first'),
                _bars(AiExamApi.list(d['topics']), (x) => '${x['topic']} · ${x['subject']}', (x) => x['percent'] as num?, (x) => '${x['answers']} answers · ${fmtNum(x['weakShare'] as num?)}% below half marks'),
                const SectionTitle('Questions with the highest failure rate'),
                SectionCard(
                  title: 'Hardest questions',
                  icon: Icons.warning_amber_outlined,
                  empty: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('No evaluated answers yet.', style: text.bodyMedium)),
                  children: [
                    for (final q in AiExamApi.list(d['hardestQuestions']))
                      InfoRow(title: '${q['text']}', subtitle: '${q['test']} · ${q['topic']} · ${q['answers']} answers', trailing: Pill(label: '${fmtNum(q['failureRate'] as num?)}% fail', color: percentColor(100 - ((q['failureRate'] as num?) ?? 0)))),
                  ],
                ),
                if (AiExamApi.list(d['misunderstoodConcepts']).isNotEmpty) ...[
                  const SectionTitle('Frequently misunderstood'),
                  SectionCard(title: 'From AI feedback', icon: Icons.psychology_alt_outlined, children: [
                    for (final m in AiExamApi.list(d['misunderstoodConcepts'])) InfoRow(title: '${m['text']}', trailing: Text('×${m['count']}')),
                  ]),
                ],
                const SectionTitle('Students needing support', subtitle: 'Average below 40% or declining'),
                SectionCard(
                  title: '${AiExamApi.list(d['studentsNeedingSupport']).length} student(s)',
                  icon: Icons.support_outlined,
                  empty: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('No student is flagged.', style: text.bodyMedium)),
                  children: [for (final st in AiExamApi.list(d['studentsNeedingSupport'])) _studentRow(st)],
                ),
                if (!widget.compact) ...[
                  const SectionTitle('All students'),
                  SectionCard(title: 'Tap a student for details', icon: Icons.groups_outlined, children: [for (final st in AiExamApi.list(d['students'])) _studentRow(st)]),
                ],
              ]);
            }
          }
          return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: body);
        },
      ),
    );
  }

  Widget _bars(List<Map<String, dynamic>> items, String Function(Map) label, num? Function(Map) value, String Function(Map) caption) {
    if (items.isEmpty) return Text('No data yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted));
    return SectionCard(title: '${items.length} item(s)', icon: Icons.bar_chart, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        child: Column(children: [for (final x in items.take(12)) PercentBar(label: label(x), percent: value(x), caption: caption(x))]),
      ),
    ]);
  }

  Widget _studentRow(Map<String, dynamic> st) {
    final trend = AiExamApi.map(st['trend']);
    return InfoRow(
      icon: Icons.person_outline,
      title: '${st['name']}',
      subtitle: '${st['admissionNo']} · ${st['tests']} test(s)${trend.isNotEmpty ? ' · ${trend['direction']}' : ''}',
      trailing: Pill(label: '${fmtNum(st['average'] as num?)}%', color: percentColor(st['average'] as num?)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('${st['name']}')),
          body: PerformanceLoader(load: () => widget.api.studentAnalytics(st['studentId'] as String), forTeacher: true),
        ),
      )),
    );
  }
}
