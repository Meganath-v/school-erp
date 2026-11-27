import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/ai_exam_api.dart';
import '../widgets/ai_widgets.dart';
import 'class_analytics_view.dart';
import 'test_detail_screen.dart';
import 'test_editor_screen.dart';

/// Teacher area: dashboard, tests, analytics.
class TeacherAiExamHome extends StatefulWidget {
  final AiExamApi? api;
  const TeacherAiExamHome({super.key, this.api});

  @override
  State<TeacherAiExamHome> createState() => _TeacherAiExamHomeState();
}

class _TeacherAiExamHomeState extends State<TeacherAiExamHome> with SingleTickerProviderStateMixin {
  late final AiExamApi _api = widget.api ?? AiExamApi();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _testsKey = GlobalKey<TestsTabState>();
  final _dashKey = GlobalKey<TeacherDashboardTabState>();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refreshAll() {
    _testsKey.currentState?.reload();
    _dashKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [Tab(text: 'Dashboard'), Tab(text: 'Tests'), Tab(text: 'Analytics')],
      ),
      const Divider(height: 1),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          TeacherDashboardTab(key: _dashKey, api: _api, onChanged: _refreshAll, onOpenTests: () => _tabs.animateTo(1)),
          TestsTab(key: _testsKey, api: _api, onChanged: _refreshAll),
          ClassAnalyticsView(api: _api),
        ]),
      ),
    ]);
  }
}

/// Opens the editor for a new test, then its detail page.
Future<void> createTestFlow(BuildContext context, AiExamApi api, VoidCallback onChanged) async {
  final created = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => TestEditorScreen(api: api)));
  if (created == null || !context.mounted) return;
  onChanged();
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TestDetailScreen(api: api, testId: created['id'] as String)));
  onChanged();
}

Widget testTile(BuildContext context, AiExamApi api, Map<String, dynamic> t, VoidCallback onChanged) {
  final phase = '${t['phase']}';
  final attention = (t['needsAttention'] as num?) ?? 0;
  return InfoRow(
    icon: Icons.assignment_outlined,
    title: '${t['title']}',
    subtitle: [
      '${t['subject']?['name'] ?? ''} · ${t['class']?['name'] ?? ''}${t['section'] != null ? ' ${t['section']['name']}' : ''}',
      if (t['questions'] != null) '${t['questions']} questions · ${fmtNum(t['totalMarks'] as num?)} marks',
      if (t['startsAt'] != null) 'Opens ${fmtDate(t['startsAt'])}',
      if (attention > 0) '$attention to evaluate',
    ].join(' · '),
    trailing: Pill(label: phaseLabels[phase] ?? phase, color: phaseColor(phase)),
    onTap: () async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TestDetailScreen(api: api, testId: t['id'] as String)));
      onChanged();
    },
  );
}

// ======================================================================== dashboard

class TeacherDashboardTab extends StatefulWidget {
  final AiExamApi api;
  final VoidCallback onChanged;
  final VoidCallback onOpenTests;
  const TeacherDashboardTab({super.key, required this.api, required this.onChanged, required this.onOpenTests});

  @override
  State<TeacherDashboardTab> createState() => TeacherDashboardTabState();
}

class TeacherDashboardTabState extends State<TeacherDashboardTab> with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future = widget.api.dashboard();

  @override
  bool get wantKeepAlive => true;

  Future<void> reload() async {
    final f = widget.api.dashboard();
    if (mounted) setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading dashboard...');
          if (snap.hasError) return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: reload)]);
          final d = snap.data!;
          final c = AiExamApi.map(d['counts']);
          final active = AiExamApi.list(d['activeTests']);
          final scheduled = AiExamApi.list(d['scheduledTests']);
          final recent = AiExamApi.list(d['recentSubmissions']);
          final perf = AiExamApi.list(d['classPerformance']);
          return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
            Text('AI Examination', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Create tests for Classes 10–12, review evaluations and follow class progress.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            AiStatusBanner(ai: AiExamApi.map(d['ai'])),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => createTestFlow(context, widget.api, widget.onChanged),
              icon: const Icon(Icons.add),
              label: const Text('Create test'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: AppSpacing.lg),
            KpiGrid(tiles: [
              KpiTile(label: 'Active tests', value: '${c['active'] ?? 0}', icon: Icons.play_circle_outline, color: AppColors.success, onTap: widget.onOpenTests),
              KpiTile(label: 'Scheduled', value: '${c['scheduled'] ?? 0}', icon: Icons.event_outlined, color: AppColors.info, onTap: widget.onOpenTests),
              KpiTile(label: 'Needs review', value: '${c['needsReview'] ?? 0}', icon: Icons.rate_review_outlined, color: AppColors.warning),
              KpiTile(label: 'Pending evaluation', value: '${(c['pendingEvaluation'] ?? 0) + (c['failed'] ?? 0)}', icon: Icons.hourglass_empty, color: AppColors.textMuted),
            ]),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Active tests',
              icon: Icons.play_circle_outline,
              empty: _empty(context, 'No test is open right now.'),
              children: [for (final t in active) testTile(context, widget.api, t, widget.onChanged)],
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: 'Scheduled tests',
              icon: Icons.event_outlined,
              empty: _empty(context, 'Nothing scheduled.'),
              children: [for (final t in scheduled) testTile(context, widget.api, t, widget.onChanged)],
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: 'Recent submissions',
              icon: Icons.inbox_outlined,
              empty: _empty(context, 'No submissions yet.'),
              children: [
                for (final s in recent)
                  InfoRow(
                    icon: Icons.person_outline,
                    title: '${s['student']}',
                    subtitle: '${s['test']} · ${fmtDate(s['submittedAt'])}',
                    trailing: Pill(
                      label: s['evaluationStatus'] == 'EVALUATED' ? '${fmtNum(s['score'] as num?)}/${fmtNum(s['maxScore'] as num?)}' : evaluationLabels['${s['evaluationStatus']}'] ?? '',
                      color: evaluationColor('${s['evaluationStatus']}'),
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TestDetailScreen(api: widget.api, testId: s['testId'] as String, initialTab: 2)));
                      widget.onChanged();
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: 'Class performance',
              icon: Icons.bar_chart,
              empty: _empty(context, 'Appears once tests are evaluated.'),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                  child: Column(children: [
                    for (final p in perf) PercentBar(label: '${p['label']}', percent: p['percent'] as num?, caption: '${p['tests']} evaluated test result(s)'),
                  ]),
                ),
              ].where((_) => perf.isNotEmpty).toList(),
            ),
          ]);
        },
      ),
    );
  }
}

Widget _empty(BuildContext context, String msg) => Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(msg, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
    );

// ======================================================================== tests list

class TestsTab extends StatefulWidget {
  final AiExamApi api;
  final VoidCallback onChanged;
  final bool adminView;
  const TestsTab({super.key, required this.api, required this.onChanged, this.adminView = false});

  @override
  State<TestsTab> createState() => TestsTabState();
}

class TestsTabState extends State<TestsTab> with AutomaticKeepAliveClientMixin {
  String _status = 'ACTIVE_ALL';
  late Future<List<Map<String, dynamic>>> _future = _fetch();

  @override
  bool get wantKeepAlive => true;

  Future<List<Map<String, dynamic>>> _fetch() => widget.api.tests(status: _status == 'ALL' ? null : _status);

  Future<void> reload() async {
    final f = _fetch();
    if (mounted) setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const filters = {'ACTIVE_ALL': 'Current', 'DRAFT': 'Drafts', 'PUBLISHED': 'Published', 'CLOSED': 'Closed', 'ARCHIVED': 'Archived'};
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-ai-test',
        onPressed: () => createTestFlow(context, widget.api, widget.onChanged),
        icon: const Icon(Icons.add),
        label: const Text('Test'),
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm), children: [
            for (final e in filters.entries)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _status == e.key,
                  onSelected: (_) {
                    _status = e.key;
                    reload();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: reload,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading tests...');
                if (snap.hasError) return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: reload)]);
                final tests = snap.data!;
                if (tests.isEmpty) {
                  return ListView(children: const [
                    EmptyStateView(icon: Icons.assignment_outlined, title: 'No tests here', message: 'Create a test with questions, answer keys and marking rubrics for Classes 10, 11 or 12.'),
                  ]);
                }
                return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96), children: [
                  SectionCard(title: '${tests.length} test${tests.length == 1 ? '' : 's'}', icon: Icons.assignment_outlined, children: [
                    for (final t in tests) testTile(context, widget.api, t, widget.onChanged),
                  ]),
                ]);
              },
            ),
          ),
        ),
      ]),
    );
  }
}
