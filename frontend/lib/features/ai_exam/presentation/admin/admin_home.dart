import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../outcomes/presentation/outcomes_screen.dart' show showApiError, showDone;
import '../../data/ai_exam_api.dart';
import '../teacher/class_analytics_view.dart';
import '../teacher/teacher_home.dart';
import '../widgets/ai_widgets.dart';

/// Administrators: overview and settings, test monitoring (and creation), academic analytics.
class AdminAiExamHome extends StatefulWidget {
  final AiExamApi? api;
  const AdminAiExamHome({super.key, this.api});

  @override
  State<AdminAiExamHome> createState() => _AdminAiExamHomeState();
}

class _AdminAiExamHomeState extends State<AdminAiExamHome> with SingleTickerProviderStateMixin {
  late final AiExamApi _api = widget.api ?? AiExamApi();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _testsKey = GlobalKey<TestsTabState>();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(controller: _tabs, isScrollable: true, tabAlignment: TabAlignment.start, tabs: const [Tab(text: 'Overview'), Tab(text: 'Test monitoring'), Tab(text: 'Academic analytics')]),
      const Divider(height: 1),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _Overview(api: _api),
          TestsTab(key: _testsKey, api: _api, onChanged: () => _testsKey.currentState?.reload(), adminView: true),
          ClassAnalyticsView(api: _api, admin: true),
        ]),
      ),
    ]);
  }
}

class _Overview extends StatefulWidget {
  final AiExamApi api;
  const _Overview({required this.api});

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future = widget.api.adminOverview();
  Map<String, dynamic>? _settings;
  bool _saving = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _reload() async {
    final f = widget.api.adminOverview();
    setState(() {
      _future = f;
      _settings = null;
    });
    await f;
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final s = await widget.api.saveSettings(_settings!);
      if (mounted) {
        setState(() => _settings = s);
        showDone(context, 'Settings saved');
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading overview...');
          if (snap.hasError) return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload)]);
          final d = snap.data!;
          final c = AiExamApi.map(d['counts']);
          final ai = AiExamApi.map(d['ai']);
          _settings ??= Map<String, dynamic>.from(AiExamApi.map(d['settings']));
          final s = _settings!;
          return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
            Text('AI Examination', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text('Classes ${AiExamApi.list(d['eligibleClasses']).map((x) => x['name']).join(', ').ifEmpty('10–12 (none set up yet)')}', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            AiStatusBanner(ai: ai),
            if (ai['configured'] == true && ai['mock'] != true)
              Pill(label: 'AI evaluator: ${ai['model']}', color: AppColors.success, icon: Icons.check_circle_outline),
            const SizedBox(height: AppSpacing.md),
            KpiGrid(tiles: [
              KpiTile(label: 'Tests', value: '${c['tests'] ?? 0}', icon: Icons.assignment_outlined),
              KpiTile(label: 'Active now', value: '${c['active'] ?? 0}', icon: Icons.play_circle_outline, color: AppColors.success),
              KpiTile(label: 'Submissions', value: '${c['submissions'] ?? 0}', icon: Icons.inbox_outlined, color: AppColors.info),
              KpiTile(label: 'Awaiting teachers', value: '${(c['needsReview'] ?? 0) + (c['pendingEvaluation'] ?? 0) + (c['failed'] ?? 0)}', icon: Icons.rate_review_outlined, color: AppColors.warning),
            ]),
            const SectionTitle('Average by class'),
            _bars(AiExamApi.list(d['byClass'])),
            const SectionTitle('Average by subject'),
            _bars(AiExamApi.list(d['bySubject'])),
            const SectionTitle('Module settings'),
            SectionCard(title: 'Evaluation', icon: Icons.tune, children: [
              SwitchListTile(
                value: s['autoEvaluate'] != false,
                title: const Text('Evaluate with AI as soon as a test is submitted'),
                subtitle: const Text('Off: teachers start AI evaluation from the submissions list'),
                onChanged: (v) => setState(() => s['autoEvaluate'] = v),
              ),
              SwitchListTile(
                value: s['allowVoice'] != false,
                title: const Text('Allow voice answers'),
                subtitle: const Text('Speech is converted to text on the device; no recording is stored'),
                onChanged: (v) => setState(() => s['allowVoice'] = v),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: Text('Send AI marks for teacher review below ${(((s['reviewConfidence'] as num?) ?? 0.6) * 100).round()}% confidence', style: text.bodyMedium),
              ),
              Slider(
                value: ((s['reviewConfidence'] as num?) ?? 0.6).toDouble(),
                min: 0.3,
                max: 0.95,
                divisions: 13,
                label: '${(((s['reviewConfidence'] as num?) ?? 0.6) * 100).round()}%',
                onChanged: (v) => setState(() => s['reviewConfidence'] = double.parse(v.toStringAsFixed(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                child: FilledButton(onPressed: _saving ? null : _saveSettings, child: const Text('Save settings')),
              ),
            ]),
          ]);
        },
      ),
    );
  }

  Widget _bars(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return Text('No evaluated submissions yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted));
    return SectionCard(title: '${items.length} group(s)', icon: Icons.bar_chart, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        child: Column(children: [for (final x in items) PercentBar(label: '${x['label']}', percent: x['average'] as num?, caption: '${x['submissions']} evaluated submission(s)')]),
      ),
    ]);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
