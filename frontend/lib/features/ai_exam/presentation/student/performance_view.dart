import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/ai_exam_api.dart';
import '../widgets/ai_widgets.dart';

/// Loads and shows a performance report (student's own, or a teacher's drill-down).
class PerformanceLoader extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() load;
  final bool forTeacher;
  final Widget? footer;
  const PerformanceLoader({super.key, required this.load, this.forTeacher = false, this.footer});

  @override
  State<PerformanceLoader> createState() => _PerformanceLoaderState();
}

class _PerformanceLoaderState extends State<PerformanceLoader> {
  late Future<Map<String, dynamic>> _future = widget.load();

  Future<void> _reload() async {
    final f = widget.load();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Analysing results...');
          if (snap.hasError) return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload)]);
          return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
            ...performanceSections(context, snap.data!, forTeacher: widget.forTeacher),
            if (widget.footer != null) widget.footer!,
          ]);
        },
      ),
    );
  }
}

String _trendText(Map<String, dynamic> t) {
  if (t.isEmpty) return '';
  final c = t['change'] as num;
  return switch (t['direction']) {
    'improving' => 'Improving (+${fmtNum(c)} pts)',
    'declining' => 'Declining (${fmtNum(c)} pts)',
    _ => 'Steady',
  };
}

List<Widget> performanceSections(BuildContext context, Map<String, dynamic> d, {bool forTeacher = false}) {
  final text = Theme.of(context).textTheme;
  if (d['hasData'] != true) {
    return [
      EmptyStateView(
        icon: Icons.insights_outlined,
        title: 'No results yet',
        message: forTeacher ? 'This student has no evaluated tests in your classes yet.' : 'Your analysis appears once a test result is published. Nothing is guessed before that.',
      ),
    ];
  }
  final o = AiExamApi.map(d['overall']);
  final subjects = AiExamApi.list(d['subjects']);
  final topics = AiExamApi.list(d['topics']);
  final history = AiExamApi.list(d['history']);
  final monthly = AiExamApi.list(d['monthly']);
  final trend = AiExamApi.map(o['trend']);
  final strong = AiExamApi.map(o['strongestSubject']);
  final weak = AiExamApi.map(o['weakestSubject']);
  return [
    KpiGrid(tiles: [
      KpiTile(label: 'Tests evaluated', value: '${o['tests']}', icon: Icons.assignment_turned_in_outlined),
      KpiTile(label: 'Overall', value: '${fmtNum(o['overallPercent'] as num?)}%', icon: Icons.percent, color: percentColor(o['overallPercent'] as num?)),
      KpiTile(label: 'Strongest', value: strong.isEmpty ? '—' : '${strong['subject']}', icon: Icons.emoji_events_outlined, color: AppColors.success),
      KpiTile(label: 'Needs work', value: weak.isEmpty ? '—' : '${weak['subject']}', icon: Icons.flag_outlined, color: AppColors.warning),
    ]),
    if (trend.isNotEmpty) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text('Trend across tests: ${_trendText(trend)}', style: text.bodyMedium)),
    const SectionTitle('Test-wise marks'),
    SectionCard(title: '${history.length} test(s)', icon: Icons.stacked_bar_chart, children: [
      TrendBars(points: [for (final (i, h) in history.indexed) (label: 'T${i + 1}', percent: h['percent'] as num?, tooltip: '${h['title']} · ${h['subject']} · ${fmtDate(h['date'], time: false)}')]),
    ]),
    if (monthly.length > 1) ...[
      const SectionTitle('Monthly'),
      SectionCard(title: 'Average by month', icon: Icons.calendar_month_outlined, children: [
        TrendBars(points: [for (final m in monthly) (label: '${m['month']}'.substring(2), percent: m['percent'] as num?, tooltip: '${m['tests']} test(s)')]),
      ]),
    ],
    const SectionTitle('Subjects'),
    SectionCard(title: 'Subject-wise average', icon: Icons.menu_book_outlined, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        child: Column(children: [
          for (final s in subjects)
            PercentBar(label: '${s['subject']} · ${s['status']}', percent: s['average'] as num?, caption: '${s['tests']} test(s)${AiExamApi.map(s['trend']).isNotEmpty ? ' · ${_trendText(AiExamApi.map(s['trend']))}' : ''}'),
        ]),
      ),
    ]),
    const SectionTitle('Topics', subtitle: 'Weakest first'),
    SectionCard(
      title: '${topics.length} topic(s)',
      icon: Icons.topic_outlined,
      children: [
        for (final t in topics)
          InfoRow(
            title: '${t['topic']} · ${t['subject']}',
            subtitle: '${t['recommendation']} · ${t['questions']} question(s), ${fmtNum(t['marksLost'] as num?)} marks lost'
                '${(t['mistakes'] as num? ?? 0) >= 2 ? ' · repeated mistakes' : ''}'
                '${AiExamApi.list(t['commonMissing']).isNotEmpty ? ' · often missing: ${AiExamApi.list(t['commonMissing']).map((m) => m['text']).take(2).join('; ')}' : ''}',
            trailing: Pill(label: '${t['level']} ${fmtNum(t['percent'] as num?)}%', color: levelColor('${t['level']}')),
          ),
      ],
    ),
  ];
}

/// Personalised improvement plan from the student's own records.
class ImprovementPlanCard extends StatefulWidget {
  final AiExamApi api;
  const ImprovementPlanCard({super.key, required this.api});

  @override
  State<ImprovementPlanCard> createState() => _ImprovementPlanCardState();
}

class _ImprovementPlanCardState extends State<ImprovementPlanCard> {
  late Future<Map<String, dynamic>> _future = widget.api.plan();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Center(child: CircularProgressIndicator()));
        if (snap.hasError) return MessageBanner(message: apiErrorMessage(snap.error!), onRetry: () => setState(() => _future = widget.api.plan()));
        final d = snap.data!;
        final plan = AiExamApi.map(d['plan']);
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: SectionCard(
            title: 'Improvement plan',
            icon: Icons.route_outlined,
            actionLabel: plan.isEmpty ? null : 'Refresh',
            onAction: plan.isEmpty ? null : () => setState(() => _future = widget.api.plan(refresh: true)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                child: plan.isEmpty
                    ? Text('${d['message'] ?? 'Not enough results yet.'}', style: text.bodyMedium?.copyWith(color: AppColors.textMuted))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          'Based on ${plan['basedOnTests']} evaluated test(s)${d['source'] == 'AI' ? ' · worded by AI from your results' : ''}.'
                          '${d['enoughData'] == false ? ' Take more tests for a more reliable plan.' : ''}',
                          style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                        if (AiExamApi.map(plan['weakSubject']).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text('Focus subject: ${plan['weakSubject']['subject']} (${fmtNum(plan['weakSubject']['average'] as num?)}%)', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                        if (AiExamApi.list(plan['priorities']).isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final p in AiExamApi.list(plan['priorities'])) Pill(label: '${p['topic']} ${fmtNum(p['percent'] as num?)}%', color: levelColor('${p['level']}')),
                          ]),
                        ],
                        if (plan['note'] != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text('${plan['note']}', style: text.bodyMedium)),
                        for (final (i, s) in AiExamApi.list(plan['steps']).indexed)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              CircleAvatar(radius: 12, backgroundColor: AppColors.primaryAccentSubtle, child: Text('${i + 1}', style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700))),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${s['title']}', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  Text('${s['detail']}', style: text.bodySmall),
                                ]),
                              ),
                            ]),
                          ),
                      ]),
              ),
            ],
          ),
        );
      },
    );
  }
}
