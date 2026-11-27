import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/ai_exam_api.dart';
import '../widgets/ai_widgets.dart';
import 'exam_screen.dart';
import 'performance_view.dart';
import 'result_screen.dart';

/// Student area: dashboard, tests, progress.
class StudentAiExamHome extends StatefulWidget {
  final AiExamApi? api;
  const StudentAiExamHome({super.key, this.api});

  @override
  State<StudentAiExamHome> createState() => _StudentAiExamHomeState();
}

class _StudentAiExamHomeState extends State<StudentAiExamHome> with SingleTickerProviderStateMixin {
  late final AiExamApi _api = widget.api ?? AiExamApi();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late Future<Map<String, dynamic>> _future = _api.myTests();
  int _version = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final f = _api.myTests();
    setState(() {
      _future = f;
      _version++;
    });
    await f;
  }

  Future<void> _open(Map<String, dynamic> t) async {
    if (t['resultPublished'] == true) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(api: _api, testId: t['id'] as String)));
    } else if (t['attempt']?['status'] == 'SUBMITTED' || t['missed'] == true) {
      return;
    } else {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TestIntroScreen(api: _api, testId: t['id'] as String)));
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done && !snap.hasData) return const LoadingStateView(message: 'Loading your tests...');
        if (snap.hasError) return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload)]);
        final d = snap.data!;
        if (d['eligible'] != true) {
          return EmptyStateView(
            icon: Icons.school_outlined,
            title: 'Not available for your class',
            message: 'AI Examination is for Classes 10, 11 and 12. You are in ${d['student']?['className'] ?? 'another class'}.',
          );
        }
        return Column(children: [
          TabBar(controller: _tabs, isScrollable: true, tabAlignment: TabAlignment.start, tabs: const [Tab(text: 'My dashboard'), Tab(text: 'Tests'), Tab(text: 'My progress')]),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(controller: _tabs, children: [
              _dashboard(d),
              _tests(d),
              PerformanceLoader(key: ValueKey('perf-$_version'), load: _api.performance, footer: ImprovementPlanCard(key: ValueKey('plan-$_version'), api: _api)),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _card(Map<String, dynamic> t) {
    final attempt = AiExamApi.map(t['attempt']);
    final submitted = attempt['status'] == 'SUBMITTED';
    final (label, color) = t['resultPublished'] == true
        ? ('${fmtNum(t['score'] as num?)}/${fmtNum(t['maxScore'] as num?)}', percentColor(t['percent'] as num?))
        : submitted
            ? ('Awaiting result', AppColors.info)
            : t['missed'] == true
                ? ('Missed', AppColors.error)
                : attempt['status'] == 'IN_PROGRESS'
                    ? ('Resume', AppColors.warning)
                    : t['phase'] == 'SCHEDULED'
                        ? ('Upcoming', AppColors.info)
                        : ('Start', AppColors.success);
    return InfoRow(
      icon: Icons.assignment_outlined,
      title: '${t['title']}',
      subtitle: [
        '${t['subject']}',
        '${t['questions']} questions · ${fmtNum(t['totalMarks'] as num?)} marks',
        if (t['durationMinutes'] != null) '${t['durationMinutes']} min',
        if (t['phase'] == 'SCHEDULED' && t['startsAt'] != null) 'opens ${fmtDate(t['startsAt'])}',
        if (t['phase'] == 'ACTIVE' && t['endsAt'] != null && !submitted) 'closes ${fmtDate(t['endsAt'])}',
        if (submitted) 'submitted ${fmtDate(attempt['submittedAt'])}',
      ].join(' · '),
      trailing: Pill(label: label, color: color),
      onTap: t['phase'] == 'SCHEDULED' || (submitted && t['resultPublished'] != true) || t['missed'] == true ? null : () => _open(t),
    );
  }

  Widget _dashboard(Map<String, dynamic> d) {
    final text = Theme.of(context).textTheme;
    final available = AiExamApi.list(d['available']);
    final upcoming = AiExamApi.list(d['upcoming']);
    final completed = AiExamApi.list(d['completed']);
    final results = completed.where((t) => t['resultPublished'] == true).toList();
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Text('Hello, ${'${d['student']?['name'] ?? ''}'.split(' ').first}', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        Text('${d['student']?['className']} ${d['student']?['sectionName']}', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.lg),
        KpiGrid(tiles: [
          KpiTile(label: 'Available now', value: '${available.length}', icon: Icons.play_circle_outline, color: AppColors.success, onTap: () => _tabs.animateTo(1)),
          KpiTile(label: 'Upcoming', value: '${upcoming.length}', icon: Icons.event_outlined, color: AppColors.info, onTap: () => _tabs.animateTo(1)),
          KpiTile(label: 'Completed', value: '${completed.where((t) => t['missed'] != true).length}', icon: Icons.task_alt, color: AppColors.primaryAccent, onTap: () => _tabs.animateTo(1)),
          KpiTile(label: 'Results', value: '${results.length}', icon: Icons.grading_outlined, color: AppColors.warning, onTap: () => _tabs.animateTo(2)),
        ]),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Available tests',
          icon: Icons.play_circle_outline,
          empty: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('No test is open right now.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted))),
          children: [for (final t in available) _card(t)],
        ),
        const SizedBox(height: AppSpacing.md),
        if (upcoming.isNotEmpty) ...[
          SectionCard(title: 'Upcoming tests', icon: Icons.event_outlined, children: [for (final t in upcoming.take(3)) _card(t)]),
          const SizedBox(height: AppSpacing.md),
        ],
        SectionCard(
          title: 'Recent results',
          icon: Icons.grading_outlined,
          empty: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('Results appear here once your teacher publishes them.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted))),
          children: [for (final t in results.take(4)) _card(t)],
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionCard(title: 'Score trend', icon: Icons.show_chart, actionLabel: 'Details', onAction: () => _tabs.animateTo(2), children: [
            TrendBars(points: [for (final (i, t) in results.reversed.indexed) (label: 'T${i + 1}', percent: t['percent'] as num?, tooltip: '${t['title']}')]),
          ]),
          ImprovementPlanCard(key: ValueKey('dash-plan-$_version'), api: _api),
        ],
      ]),
    );
  }

  Widget _tests(Map<String, dynamic> d) {
    final text = Theme.of(context).textTheme;
    Widget section(String title, IconData icon, List<Map<String, dynamic>> items, String empty) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: SectionCard(
            title: '$title (${items.length})',
            icon: icon,
            empty: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(empty, style: text.bodyMedium?.copyWith(color: AppColors.textMuted))),
            children: [for (final t in items) _card(t)],
          ),
        );
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        section('Available', Icons.play_circle_outline, AiExamApi.list(d['available']), 'No test is open right now.'),
        section('Upcoming', Icons.event_outlined, AiExamApi.list(d['upcoming']), 'Nothing scheduled.'),
        section('Completed', Icons.task_alt, AiExamApi.list(d['completed']), 'You have not completed any test yet.'),
      ]),
    );
  }
}

// ======================================================================== intro

/// Test details and instructions before starting.
class TestIntroScreen extends StatefulWidget {
  final AiExamApi api;
  final String testId;
  const TestIntroScreen({super.key, required this.api, required this.testId});

  @override
  State<TestIntroScreen> createState() => _TestIntroScreenState();
}

class _TestIntroScreenState extends State<TestIntroScreen> {
  late Future<Map<String, dynamic>> _future = widget.api.myTest(widget.testId);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Test')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading test...');
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: () => setState(() => _future = widget.api.myTest(widget.testId)))]);
          }
          final t = snap.data!;
          final resuming = t['attempt']?['status'] == 'IN_PROGRESS';
          return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
            Text('${t['title']}', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${t['subject']} · ${t['className']}${(t['chapter'] ?? '').toString().isNotEmpty ? ' · ${t['chapter']}' : ''}', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.lg),
            KpiGrid(tiles: [
              KpiTile(label: 'Questions', value: '${t['questions']}', icon: Icons.help_outline),
              KpiTile(label: 'Total marks', value: fmtNum(t['totalMarks'] as num?), icon: Icons.star_outline, color: AppColors.secondary),
              KpiTile(label: 'Duration', value: t['durationMinutes'] == null ? 'No limit' : '${t['durationMinutes']} min', icon: Icons.timer_outlined, color: AppColors.warning),
              KpiTile(label: 'Closes', value: t['endsAt'] == null ? '—' : fmtDate(t['endsAt']), icon: Icons.event_busy_outlined, color: AppColors.info),
            ]),
            if ((t['instructions'] ?? '').toString().isNotEmpty) ...[const SectionTitle('Instructions'), Text('${t['instructions']}', style: text.bodyMedium)],
            const SectionTitle('Before you start'),
            for (final line in [
              'Your answers are saved to the school server as you go, so you can continue after a refresh or a lost connection.',
              'You can type answers or tap the microphone to speak them, then edit the text.',
              if (t['durationMinutes'] != null) 'The timer starts when you begin and keeps running if you leave.',
              if (t['autoSubmit'] == true) 'When time runs out, your saved answers are submitted automatically.',
              'You can submit only once.',
            ])
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $line', style: text.bodyMedium)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ExamScreen(api: widget.api, testId: widget.testId)));
              },
              icon: Icon(resuming ? Icons.play_arrow : Icons.rocket_launch_outlined),
              label: Text(resuming ? 'Resume test' : 'Start test'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ]);
        },
      ),
    );
  }
}
