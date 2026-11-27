import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../outcomes/presentation/outcomes_screen.dart' show confirmDelete, showApiError, showDone;
import '../../data/ai_exam_api.dart';
import '../widgets/ai_widgets.dart';
import 'class_analytics_view.dart';
import 'questions_editor_screen.dart';
import 'submission_review_screen.dart';
import 'test_editor_screen.dart';

class TestDetailScreen extends StatefulWidget {
  final AiExamApi api;
  final String testId;
  final int initialTab;
  const TestDetailScreen({super.key, required this.api, required this.testId, this.initialTab = 0});

  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen> {
  late Future<Map<String, dynamic>> _future = widget.api.test(widget.testId);
  bool _busy = false;
  int _version = 0;

  Future<void> _reload() async {
    final f = widget.api.test(widget.testId);
    setState(() {
      _future = f;
      _version++;
    });
    await f;
  }

  Future<void> _act(Future<void> Function() action, String done, {String? confirm, String? confirmBody}) async {
    if (confirm != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(confirm),
          content: confirmBody == null ? null : Text(confirmBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        showDone(context, done);
        await _reload();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        final t = snap.data;
        final scheduleOnly = t?['access'] == 'SCHEDULE';
        return DefaultTabController(
          key: ValueKey('tabs-$scheduleOnly'),
          length: scheduleOnly ? 1 : 4,
          initialIndex: scheduleOnly ? 0 : widget.initialTab,
          child: Scaffold(
            appBar: AppBar(
              title: Text(t == null ? 'Test' : '${t['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
              bottom: t == null || scheduleOnly
                  ? null
                  : const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [Tab(text: 'Overview'), Tab(text: 'Questions'), Tab(text: 'Submissions'), Tab(text: 'Analytics')]),
            ),
            body: snap.connectionState != ConnectionState.done && t == null
                ? const LoadingStateView(message: 'Loading test...')
                : snap.hasError
                    ? ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload)])
                    : scheduleOnly
                        ? _overview(t!)
                        : TabBarView(children: [
                        _overview(t!),
                        _questions(t),
                        _SubmissionsTab(key: ValueKey('subs-$_version'), api: widget.api, test: t, onChanged: _reload),
                        ClassAnalyticsView(key: ValueKey('an-$_version'), api: widget.api, testId: widget.testId, compact: true),
                      ]),
          ),
        );
      },
    );
  }

  Widget _overview(Map<String, dynamic> t) {
    final text = Theme.of(context).textTheme;
    final stats = AiExamApi.map(t['stats']);
    final status = '${t['status']}';
    final phase = '${t['phase']}';
    final questions = AiExamApi.list(t['questions']);
    final canEditQuestions = t['canEditQuestions'] == true && (status == 'DRAFT' || status == 'PUBLISHED');
    final ended = status == 'CLOSED' || status == 'ARCHIVED' || phase == 'ENDED';
    final scheduleOnly = t['access'] == 'SCHEDULE';
    final canReschedule = status != 'ARCHIVED' && t['resultsPublishedAt'] == null;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Wrap(spacing: 8, runSpacing: 6, children: [
          Pill(label: phaseLabels[phase] ?? phase, color: phaseColor(phase)),
          if (t['resultsPublishedAt'] != null) const Pill(label: 'Results published', color: AppColors.success, icon: Icons.check),
          Pill(label: '${t['subject']?['name']}', color: AppColors.info),
          Pill(label: '${t['class']?['name']}${t['section'] != null ? ' ${t['section']['name']}' : ' (all sections)'}', color: AppColors.textMuted),
        ]),
        if (scheduleOnly) ...[
          const SizedBox(height: AppSpacing.md),
          const MessageBanner(message: 'You are the class teacher of this section, so you can change when this test runs. Questions, answers and marks stay with the subject teacher.', isError: false),
        ],
        const SizedBox(height: AppSpacing.md),
        if ((t['chapter'] ?? '').toString().isNotEmpty) Text('Chapter: ${t['chapter']}', style: text.bodyMedium),
        if (((t['topics'] as List?) ?? const []).isNotEmpty) Text('Topics: ${(t['topics'] as List).join(', ')}', style: text.bodyMedium),
        Text(
          '${t['questionCount'] ?? questions.length} questions · ${fmtNum(t['totalMarks'] as num?)} marks · ${t['durationMinutes'] == null ? 'no time limit' : '${t['durationMinutes']} min'}',
          style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        Text('Opens ${t['startsAt'] == null ? 'on publishing' : fmtDate(t['startsAt'])} · closes ${t['endsAt'] == null ? 'when you close it' : fmtDate(t['endsAt'])}', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.lg),
        if (scheduleOnly)
          KpiGrid(tiles: [
            KpiTile(label: 'Assigned', value: '${stats['assigned'] ?? 0}', icon: Icons.groups_outlined),
            KpiTile(label: 'Submitted', value: '${stats['submitted'] ?? 0}', icon: Icons.task_alt, color: AppColors.success),
            KpiTile(label: 'In progress', value: '${stats['inProgress'] ?? 0}', icon: Icons.edit_note, color: AppColors.warning),
            KpiTile(label: 'Questions', value: '${t['questionCount'] ?? 0}', icon: Icons.help_outline, color: AppColors.info),
          ])
        else
        KpiGrid(tiles: [
          KpiTile(label: 'Assigned', value: '${stats['assigned'] ?? 0}', icon: Icons.groups_outlined),
          KpiTile(label: 'Submitted', value: '${stats['submitted'] ?? 0}', icon: Icons.task_alt, color: AppColors.success),
          KpiTile(label: 'Needs review', value: '${stats['needsReview'] ?? 0}', icon: Icons.rate_review_outlined, color: AppColors.warning),
          KpiTile(label: 'Pending / failed', value: '${(stats['pendingEvaluation'] ?? 0) + (stats['failed'] ?? 0)}', icon: Icons.hourglass_empty, color: AppColors.textMuted),
        ]),
        const SizedBox(height: AppSpacing.lg),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          if (canReschedule)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _reschedule(t),
              icon: const Icon(Icons.event_repeat_outlined),
              label: Text(status == 'CLOSED' ? 'Reschedule / reopen' : 'Reschedule'),
            ),
          if (!scheduleOnly && (status == 'DRAFT' || status == 'PUBLISHED'))
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final saved = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TestEditorScreen(api: widget.api, test: t)));
                      if (saved != null) _reload();
                    },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit details'),
            ),
          if (canEditQuestions && !scheduleOnly)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => QuestionsEditorScreen(api: widget.api, test: t)));
                      if (saved == true) _reload();
                    },
              icon: const Icon(Icons.edit_note),
              label: Text(questions.isEmpty ? 'Add questions' : 'Edit questions'),
            ),
          if (!scheduleOnly)
          OutlinedButton.icon(
            onPressed: questions.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TestPreviewScreen(api: widget.api, test: t))),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview'),
          ),
          if (status == 'DRAFT' && !scheduleOnly)
            FilledButton.icon(
              onPressed: _busy || questions.isEmpty
                  ? null
                  : () => _act(() => widget.api.publish(widget.testId), 'Test published',
                      confirm: 'Publish this test?', confirmBody: 'Assigned students will see it${t['startsAt'] != null ? ' from ${fmtDate(t['startsAt'])}' : ' now'}. Questions can be changed until someone starts.'),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Publish'),
            ),
          if (status == 'PUBLISHED' && !scheduleOnly)
            FilledButton.tonalIcon(
              onPressed: _busy
                  ? null
                  : () => _act(() => widget.api.close(widget.testId), 'Test closed', confirm: 'Close this test?', confirmBody: 'Students can no longer answer. Open attempts are submitted with their saved answers.'),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Close test'),
            ),
          if (!scheduleOnly && ended && t['resultsPublishedAt'] == null && (stats['submitted'] ?? 0) > 0)
            FilledButton.icon(
              onPressed: _busy ? null : () => _act(() => widget.api.publishResults(widget.testId), 'Results published to students', confirm: 'Publish results?', confirmBody: 'Students will see their marks, feedback and the model answers.'),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Publish results'),
            ),
          if (!scheduleOnly && (status == 'CLOSED' || status == 'DRAFT'))
            TextButton.icon(onPressed: _busy ? null : () => _act(() => widget.api.archive(widget.testId), 'Test archived'), icon: const Icon(Icons.archive_outlined), label: const Text('Archive')),
          if (!scheduleOnly && (stats['started'] ?? 0) == 0)
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      if (!await confirmDelete(context, 'this test')) return;
                      try {
                        await widget.api.deleteTest(widget.testId);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (mounted) showApiError(context, e);
                      }
                    },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
        ]),
        if (!scheduleOnly && status == 'DRAFT' && questions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text('Add questions before publishing.', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
          ),
        if ((t['instructions'] ?? '').toString().isNotEmpty) ...[
          const SectionTitle('Instructions'),
          Text('${t['instructions']}', style: text.bodyMedium),
        ],
        if (t['assignMode'] == 'STUDENTS') ...[
          const SectionTitle('Assigned students'),
          for (final a in AiExamApi.list(t['assignees'])) Text('• ${a['name']} (${a['admissionNo']})', style: text.bodyMedium),
        ],
      ]),
    );
  }

  Future<void> _reschedule(Map<String, dynamic> t) async {
    final r = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => RescheduleDialog(test: t));
    if (r == null) return;
    await _act(() => widget.api.reschedule(widget.testId, r), t['status'] == 'CLOSED' && r['endsAt'] != null ? 'Test rescheduled and reopened' : 'Test rescheduled');
  }

  Widget _questions(Map<String, dynamic> t) {
    final text = Theme.of(context).textTheme;
    final questions = AiExamApi.list(t['questions']);
    if (questions.isEmpty) return const EmptyStateView(icon: Icons.quiz_outlined, title: 'No questions', message: 'Use "Add questions" on the overview.');
    return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
      for (final (i, q) in questions.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: SectionCard(
            title: 'Q${i + 1} · ${questionTypeLabels[q['type']]} · ${fmtNum(q['marks'] as num?)} marks',
            icon: Icons.help_outline,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${q['text']}', style: text.bodyLarge),
                  if (q['imageUrl'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Image.network(widget.api.imageUrl('${q['imageUrl']}'), height: 140, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                    ),
                  if (q['options'] is List)
                    for (final (j, o) in (q['options'] as List).indexed)
                      Text('${String.fromCharCode(65 + j)}. $o${q['correctOption'] == j ? '   ✓' : ''}', style: text.bodyMedium?.copyWith(color: q['correctOption'] == j ? AppColors.success : null)),
                  if ((q['answerKey'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Answer key', style: text.labelLarge?.copyWith(color: AppColors.success)),
                    Text('${q['answerKey']}', style: text.bodyMedium),
                  ],
                  if (AiExamApi.list(q['rubric']).isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Rubric', style: text.labelLarge?.copyWith(color: AppColors.info)),
                    for (final r in AiExamApi.list(q['rubric'])) Text('• ${r['description']} — ${fmtNum(r['marks'] as num?)}', style: text.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text([q['topic'], '${q['difficulty']}'.toLowerCase()].where((x) => x != null && '$x'.isNotEmpty).join(' · '), style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]),
              ),
            ],
          ),
        ),
    ]);
  }
}

// ======================================================================== submissions

class _SubmissionsTab extends StatefulWidget {
  final AiExamApi api;
  final Map<String, dynamic> test;
  final Future<void> Function() onChanged;
  const _SubmissionsTab({super.key, required this.api, required this.test, required this.onChanged});

  @override
  State<_SubmissionsTab> createState() => _SubmissionsTabState();
}

class _SubmissionsTabState extends State<_SubmissionsTab> {
  late Future<List<Map<String, dynamic>>> _future = widget.api.submissions(widget.test['id'] as String);
  bool _running = false;

  Future<void> _reload() async {
    final f = widget.api.submissions(widget.test['id'] as String);
    setState(() => _future = f);
    await f;
  }

  Future<void> _runAi() async {
    setState(() => _running = true);
    try {
      final r = await widget.api.runEvaluation(testId: widget.test['id'] as String);
      if (mounted) showDone(context, '${r['queued']} answer(s) queued for AI evaluation');
      await Future.delayed(const Duration(seconds: 2));
      await _reload();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = AiExamApi.map(widget.test['stats']);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading submissions...');
          if (snap.hasError) return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload)]);
          final rows = snap.data!;
          final pendingAi = (stats['pendingEvaluation'] ?? 0) + (stats['failed'] ?? 0);
          return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
            if (pendingAi > 0) ...[
              OutlinedButton.icon(
                onPressed: _running ? null : _runAi,
                icon: _running ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_outlined),
                label: const Text('Run AI evaluation for pending answers'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            SectionCard(
              title: '${rows.where((r) => r['status'] == 'SUBMITTED').length} of ${rows.length} submitted',
              icon: Icons.inbox_outlined,
              empty: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('No students assigned.', style: Theme.of(context).textTheme.bodyMedium)),
              children: [
                for (final r in rows)
                  InfoRow(
                    icon: Icons.person_outline,
                    title: '${r['name']}',
                    subtitle: [
                      '${r['admissionNo']} · ${r['section']}',
                      switch (r['status']) {
                        'SUBMITTED' => 'Submitted ${fmtDate(r['submittedAt'])}${r['autoSubmitted'] == true ? ' (auto)' : ''}',
                        'IN_PROGRESS' => 'In progress',
                        _ => 'Not started',
                      },
                    ].join(' · '),
                    trailing: r['status'] != 'SUBMITTED'
                        ? null
                        : Pill(
                            label: r['evaluationStatus'] == 'EVALUATED' ? '${fmtNum(r['score'] as num?)}/${fmtNum(r['maxScore'] as num?)}' : evaluationLabels['${r['evaluationStatus']}'] ?? '',
                            color: evaluationColor('${r['evaluationStatus']}'),
                          ),
                    onTap: r['submissionId'] == null || r['status'] != 'SUBMITTED'
                        ? null
                        : () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SubmissionReviewScreen(api: widget.api, testId: widget.test['id'] as String, submissionId: r['submissionId'] as String)));
                            await widget.onChanged();
                          },
                  ),
              ],
            ),
          ]);
        },
      ),
    );
  }
}

// ======================================================================== preview

/// How the test looks to students (no answers shown).
class TestPreviewScreen extends StatelessWidget {
  final AiExamApi api;
  final Map<String, dynamic> test;
  const TestPreviewScreen({super.key, required this.api, required this.test});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final questions = AiExamApi.list(test['questions']);
    return Scaffold(
      appBar: AppBar(title: const Text('Student preview')),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Text('${test['title']}', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text('${test['subject']?['name']} · ${fmtNum(test['totalMarks'] as num?)} marks · ${test['durationMinutes'] == null ? 'no time limit' : '${test['durationMinutes']} min'}', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
        if ((test['instructions'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: AppSpacing.md), MessageBanner(message: '${test['instructions']}', isError: false)],
        const SizedBox(height: AppSpacing.md),
        for (final (i, q) in questions.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: SectionCard(title: 'Question ${i + 1} · ${fmtNum(q['marks'] as num?)} marks', icon: Icons.help_outline, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${q['text']}', style: text.bodyLarge),
                  if (q['imageUrl'] != null) Image.network(api.imageUrl('${q['imageUrl']}'), height: 140, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                  const SizedBox(height: AppSpacing.sm),
                  if (q['options'] is List)
                    for (final (j, o) in (q['options'] as List).indexed) Text('○  ${String.fromCharCode(65 + j)}. $o', style: text.bodyMedium)
                  else
                    Container(
                      height: q['type'] == 'LONG' ? 110 : 52,
                      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text('Answer (type or speak)', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                    ),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ======================================================================== reschedule

/// Pick new start/end times and a reason. Pops with the request body.
class RescheduleDialog extends StatefulWidget {
  final Map<String, dynamic> test;
  const RescheduleDialog({super.key, required this.test});

  @override
  State<RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<RescheduleDialog> {
  late DateTime? _startsAt = DateTime.tryParse('${widget.test['startsAt']}')?.toLocal();
  late DateTime? _endsAt = DateTime.tryParse('${widget.test['endsAt']}')?.toLocal();
  final _reason = TextEditingController();
  String? _error;

  bool get _started => ((widget.test['stats'] as Map?)?['started'] ?? 0) > 0;

  Future<void> _pick(bool start) async {
    final initial = (start ? _startsAt : _endsAt) ?? DateTime.now().add(const Duration(hours: 1));
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: initial.isBefore(now) ? now : initial, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 400)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    final d = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => start ? _startsAt = d : _endsAt = d);
  }

  void _save() {
    if (_reason.text.trim().length < 3) return setState(() => _error = 'Give a short reason (it is recorded).');
    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) return setState(() => _error = 'The test must end after it starts.');
    if (widget.test['status'] != 'DRAFT' && _endsAt != null && !_endsAt!.isAfter(DateTime.now())) return setState(() => _error = 'The new end time must be in the future.');
    Navigator.pop(context, {
      if (!_started) 'startsAt': _startsAt?.toUtc().toIso8601String(),
      'endsAt': _endsAt?.toUtc().toIso8601String(),
      'reason': _reason.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final closed = widget.test['status'] == 'CLOSED';
    return AlertDialog(
      title: const Text('Reschedule test'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (closed) Text('Setting a future end time reopens the test for students who have not submitted.', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: !_started,
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Starts'),
              subtitle: Text(_started ? '${fmtDate(_startsAt?.toIso8601String())} (locked: students have started)' : _startsAt == null ? 'As soon as it is published' : fmtDate(_startsAt!.toIso8601String())),
              trailing: _started || _startsAt == null ? null : IconButton(tooltip: 'Clear start time', icon: const Icon(Icons.clear), onPressed: () => setState(() => _startsAt = null)),
              onTap: _started ? null : () => _pick(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('Ends'),
              subtitle: Text(_endsAt == null ? 'When it is closed' : fmtDate(_endsAt!.toIso8601String())),
              trailing: _endsAt == null ? null : IconButton(tooltip: 'Clear end time', icon: const Icon(Icons.clear), onPressed: () => setState(() => _endsAt = null)),
              onTap: () => _pick(false),
            ),
            if (widget.test['durationMinutes'] != null)
              Text('Each student still gets at most ${widget.test['durationMinutes']} minutes; students who are mid-test get the new end time.', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason (recorded)')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(_error!, style: text.bodySmall?.copyWith(color: AppColors.error))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
