import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../outcomes/data/outcomes_api.dart';
import '../../outcomes/presentation/outcomes_screen.dart' show confirmDelete, showApiError, showDone;
import '../data/assessment_api.dart';

Color quizStatusColor(String? s) => switch (s) {
      'PUBLISHED' => AppColors.success,
      'CLOSED' => AppColors.textMuted,
      _ => AppColors.warning,
    };

String formatDateTime(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse('$v')?.toLocal();
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Online MCQ quizzes of a subject.
class QuizzesTab extends StatefulWidget {
  final Map<String, dynamic> subject;
  const QuizzesTab({super.key, required this.subject});

  @override
  State<QuizzesTab> createState() => _QuizzesTabState();
}

class _QuizzesTabState extends State<QuizzesTab> with AutomaticKeepAliveClientMixin {
  final _api = AssessmentApi();
  late Future<List<Map<String, dynamic>>> _future = _api.quizzes(widget.subject['id'] as String);
  bool get _canEdit => widget.subject['canEdit'] == true;

  @override
  bool get wantKeepAlive => true;

  Future<void> _reload() async {
    final f = _api.quizzes(widget.subject['id'] as String);
    setState(() => _future = f);
    await f;
  }

  Future<void> _create() async {
    final created = await showQuizForm(context, subject: widget.subject);
    if (created == null || !mounted) return;
    await _open(created);
  }

  Future<void> _open(Map<String, dynamic> q) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizDetailScreen(subject: widget.subject, quizId: q['id'] as String)));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(heroTag: 'fab-quiz', onPressed: _create, icon: const Icon(Icons.add), label: const Text('Quiz'))
          : null,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading quizzes...');
            if (snap.hasError) {
              return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload)]);
            }
            final quizzes = snap.data!;
            if (quizzes.isEmpty) {
              return ListView(children: const [
                EmptyStateView(
                  icon: Icons.quiz_outlined,
                  title: 'No quizzes',
                  message: 'Create a quiz from multiple-choice questions in the question bank. Students take it in the app and it is marked automatically.',
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
              children: [
                SectionCard(title: 'Quizzes', icon: Icons.quiz_outlined, children: [
                  for (final q in quizzes)
                    InfoRow(
                      icon: Icons.quiz_outlined,
                      title: '${q['title']}',
                      subtitle: '${(q['_count'] as Map)['questions']} questions · ${(q['_count'] as Map)['attempts']} attempts'
                          '${q['closesAt'] != null ? ' · closes ${formatDateTime(q['closesAt'])}' : ''}',
                      trailing: StatusChip(label: '${q['status']}', color: quizStatusColor(q['status'] as String?)),
                      onTap: () => _open(q),
                    ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Create or edit a quiz's details. Returns the saved quiz.
Future<Map<String, dynamic>?> showQuizForm(BuildContext context, {required Map<String, dynamic> subject, Map<String, dynamic>? quiz}) {
  return Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => _QuizForm(subject: subject, quiz: quiz)));
}

class _QuizForm extends StatefulWidget {
  final Map<String, dynamic> subject;
  final Map<String, dynamic>? quiz;
  const _QuizForm({required this.subject, this.quiz});

  @override
  State<_QuizForm> createState() => _QuizFormState();
}

class _QuizFormState extends State<_QuizForm> {
  final _api = AssessmentApi();
  late final _title = TextEditingController(text: widget.quiz?['title'] ?? '');
  late final _instructions = TextEditingController(text: widget.quiz?['instructions'] ?? '');
  late final _duration = TextEditingController(text: widget.quiz?['durationMinutes']?.toString() ?? '20');
  late String? _classId = widget.quiz?['classId'] as String? ??
      ((widget.subject['classes'] as List).isNotEmpty ? (widget.subject['classes'] as List).first['id'] as String : null);
  late DateTime? _opensAt = DateTime.tryParse('${widget.quiz?['opensAt']}')?.toLocal();
  late DateTime? _closesAt = DateTime.tryParse('${widget.quiz?['closesAt']}')?.toLocal();
  late bool _showAnswers = widget.quiz?['showAnswers'] as bool? ?? true;
  bool _saving = false;
  String? _error;

  Future<DateTime?> _pick(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final minutes = _duration.text.trim().isEmpty ? null : int.tryParse(_duration.text.trim());
    if (_title.text.trim().isEmpty || _classId == null) {
      setState(() => _error = 'Enter a title and choose a class.');
      return;
    }
    if (_duration.text.trim().isNotEmpty && (minutes == null || minutes < 1 || minutes > 600)) {
      setState(() => _error = 'Time limit must be between 1 and 600 minutes.');
      return;
    }
    if (_opensAt != null && _closesAt != null && !_closesAt!.isAfter(_opensAt!)) {
      setState(() => _error = 'The quiz must close after it opens.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'title': _title.text.trim(),
      'subjectId': widget.subject['id'],
      'classId': _classId,
      'instructions': _instructions.text.trim(),
      'durationMinutes': minutes,
      'opensAt': _opensAt?.toUtc().toIso8601String(),
      'closesAt': _closesAt?.toUtc().toIso8601String(),
      'showAnswers': _showAnswers,
    };
    try {
      final saved = widget.quiz == null ? await _api.createQuiz(body) : await _api.updateQuiz(widget.quiz!['id'] as String, body);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = (widget.subject['classes'] as List).cast<Map>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.quiz == null ? 'New quiz' : 'Edit quiz')),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _classId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Class'),
          items: [for (final c in classes) DropdownMenuItem(value: c['id'] as String, child: Text('${c['name']}'))],
          onChanged: (v) => setState(() => _classId = v),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: _instructions, maxLines: 3, decoration: const InputDecoration(labelText: 'Instructions (optional)')),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _duration,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Time limit in minutes', helperText: 'Leave empty for no time limit'),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_available_outlined),
          title: const Text('Opens'),
          subtitle: Text(_opensAt == null ? 'As soon as it is published' : formatDateTime(_opensAt!.toIso8601String())),
          trailing: _opensAt == null
              ? null
              : IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: () => setState(() => _opensAt = null)),
          onTap: () async {
            final d = await _pick(_opensAt);
            if (d != null) setState(() => _opensAt = d);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_busy_outlined),
          title: const Text('Closes'),
          subtitle: Text(_closesAt == null ? 'When you close it' : formatDateTime(_closesAt!.toIso8601String())),
          trailing: _closesAt == null
              ? null
              : IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: () => setState(() => _closesAt = null)),
          onTap: () async {
            final d = await _pick(_closesAt);
            if (d != null) setState(() => _closesAt = d);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _showAnswers,
          title: const Text('Show correct answers after submitting'),
          onChanged: (v) => setState(() => _showAnswers = v),
        ),
        if (_error != null) ...[const SizedBox(height: AppSpacing.md), MessageBanner(message: _error!)],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ]),
    );
  }
}

// ======================================================================== quiz detail

class QuizDetailScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String quizId;
  const QuizDetailScreen({super.key, required this.subject, required this.quizId});

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  final _api = AssessmentApi();
  late Future<List<Map<String, dynamic>>> _future = _fetch();
  bool _busy = false;
  bool get _canEdit => widget.subject['canEdit'] == true;

  Future<List<Map<String, dynamic>>> _fetch() async {
    final res = await Future.wait([_api.quiz(widget.quizId), _api.quizResults(widget.quizId)]);
    return [res[0], res[1]];
  }

  Future<void> _reload() async {
    final f = _fetch();
    setState(() => _future = f);
    await f;
  }

  Future<void> _act(Future<void> Function() action, String done) async {
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

  Future<void> _pickQuestions(Map<String, dynamic> quiz) async {
    final current = {for (final q in (quiz['questions'] as List).cast<Map>()) q['questionId'] as String: (q['marks'] as num).toDouble()};
    final bank = await OutcomesApi().questions(widget.subject['id'] as String).catchError((Object e) {
      if (mounted) showApiError(context, e);
      return <Map<String, dynamic>>[];
    });
    if (!mounted) return;
    final mcq = bank.where((q) => q['type'] == 'MCQ').toList();
    final selected = await Navigator.of(context).push<List<String>>(MaterialPageRoute(
      builder: (_) => _QuestionPicker(questions: mcq, initial: current.keys.toList()),
    ));
    if (selected == null) return;
    await _act(
      () => _api.setQuizQuestions(widget.quizId, [
        for (final id in selected) {'questionId': id, 'marks': ?current[id]},
      ]),
      'Questions saved',
    );
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'this quiz and its attempts')) return;
    try {
      await _api.deleteQuiz(widget.quizId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        actions: [
          if (_canEdit) IconButton(tooltip: 'Delete quiz', icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading quiz...');
            if (snap.hasError) {
              return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload)]);
            }
            final quiz = snap.data![0];
            final results = snap.data![1];
            final questions = (quiz['questions'] as List).cast<Map>();
            final attempts = (quiz['_count'] as Map)['attempts'] as int;
            final status = quiz['status'] as String;
            final summary = results['summary'] as Map;
            final maxScore = (results['quiz'] as Map)['maxScore'] as num;
            return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
              Text('${quiz['title']}', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                StatusChip(label: status, color: quizStatusColor(status)),
                Text(quiz['durationMinutes'] == null ? 'No time limit' : '${quiz['durationMinutes']} min',
                    style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                if (quiz['closesAt'] != null)
                  Text('Closes ${formatDateTime(quiz['closesAt'])}', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
              ]),
              const SizedBox(height: AppSpacing.lg),
              KpiGrid(tiles: [
                KpiTile(label: 'Questions', value: '${questions.length}', icon: Icons.help_outline),
                KpiTile(label: 'Max score', value: formatLevel(maxScore), icon: Icons.star_outline, color: AppColors.secondary),
                KpiTile(label: 'Submitted', value: '${summary['submitted']}/${summary['students']}', icon: Icons.task_alt, color: AppColors.success),
                KpiTile(label: 'Average', value: formatLevel(summary['average'] as num?), icon: Icons.percent, color: AppColors.warning),
              ]),
              if (_canEdit) ...[
                const SizedBox(height: AppSpacing.lg),
                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                  if (status == 'DRAFT')
                    FilledButton.icon(
                      onPressed: _busy || questions.isEmpty ? null : () => _act(() => _api.publishQuiz(widget.quizId), 'Quiz published'),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Publish'),
                    ),
                  if (status == 'PUBLISHED')
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _act(() => _api.closeQuiz(widget.quizId), 'Quiz closed'),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Close quiz'),
                    ),
                  if (attempts == 0)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickQuestions(quiz),
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Choose questions'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final saved = await showQuizForm(context, subject: widget.subject, quiz: quiz);
                            if (saved != null && mounted) _reload();
                          },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit details'),
                  ),
                ]),
                if (status == 'DRAFT' && questions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text('Choose at least one question before publishing.', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                title: 'Questions',
                icon: Icons.help_outline,
                empty: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('No questions chosen yet.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ),
                children: [
                  for (final (i, q) in questions.indexed)
                    InfoRow(
                      title: '${i + 1}. ${(q['question'] as Map)['text']}',
                      subtitle: '${formatLevel(q['marks'] as num)} marks · ${((q['question'] as Map)['options'] as List? ?? []).length} options',
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                title: 'Results',
                icon: Icons.leaderboard_outlined,
                empty: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('No students in this class.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ),
                children: [
                  for (final s in (results['students'] as List).cast<Map>())
                    InfoRow(
                      icon: Icons.person_outline,
                      title: '${s['name']}',
                      subtitle: switch (s['status']) {
                        'SUBMITTED' => 'Submitted ${formatDateTime(s['submittedAt'])}${s['late'] == true ? ' · late' : ''}',
                        'IN_PROGRESS' => 'In progress',
                        _ => 'Not started',
                      },
                      trailing: Text(s['score'] == null ? '—' : '${formatLevel(s['score'] as num)}/${formatLevel(maxScore)}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _QuestionPicker extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final List<String> initial;
  const _QuestionPicker({required this.questions, required this.initial});

  @override
  State<_QuestionPicker> createState() => _QuestionPickerState();
}

class _QuestionPickerState extends State<_QuestionPicker> {
  late final List<String> _selected = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_selected.length} selected'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Done'))],
      ),
      body: widget.questions.isEmpty
          ? const EmptyStateView(
              icon: Icons.help_outline,
              title: 'No multiple-choice questions',
              message: 'Add questions of type "Multiple choice" with options in the question bank (Outcomes → Question bank).',
            )
          : ListView(children: [
              for (final q in widget.questions)
                CheckboxListTile(
                  value: _selected.contains(q['id']),
                  title: Text('${q['text']}'),
                  subtitle: Text('${formatLevel(q['marks'] as num)} marks · ${(q['options'] as List? ?? []).length} options'),
                  onChanged: (v) => setState(() => v == true ? _selected.add(q['id'] as String) : _selected.remove(q['id'])),
                ),
            ]),
    );
  }
}
