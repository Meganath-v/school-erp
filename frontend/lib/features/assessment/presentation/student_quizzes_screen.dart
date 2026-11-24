import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../outcomes/data/outcomes_api.dart';
import '../../outcomes/presentation/outcomes_screen.dart' show showApiError;
import '../data/assessment_api.dart';
import 'quizzes_tab.dart' show formatDateTime;

/// Quizzes published for the signed-in student's class.
class StudentQuizzesScreen extends StatefulWidget {
  final AssessmentApi? api;
  const StudentQuizzesScreen({super.key, this.api});

  @override
  State<StudentQuizzesScreen> createState() => _StudentQuizzesScreenState();
}

class _StudentQuizzesScreenState extends State<StudentQuizzesScreen> {
  late final AssessmentApi _api = widget.api ?? AssessmentApi();
  late Future<List<Map<String, dynamic>>> _future = _api.myQuizzes();

  Future<void> _reload() async {
    final f = _api.myQuizzes();
    setState(() => _future = f);
    await f;
  }

  Future<void> _open(Map<String, dynamic> q) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TakeQuizScreen(api: _api, quizId: q['id'] as String)));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
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
              EmptyStateView(icon: Icons.quiz_outlined, title: 'No quizzes', message: 'Quizzes your teachers publish will appear here.'),
            ]);
          }
          return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
            SectionCard(title: 'Quizzes', icon: Icons.quiz_outlined, children: [
              for (final q in quizzes) _row(q),
            ]),
          ]);
        },
      ),
    );
  }

  Widget _row(Map<String, dynamic> q) {
    final attempt = q['attempt'] as Map?;
    final submitted = attempt?['status'] == 'SUBMITTED';
    final open = q['open'] == true;
    final (label, color) = submitted
        ? ('${formatLevel(attempt!['score'] as num?)}/${formatLevel(q['maxScore'] as num)}', AppColors.success)
        : attempt != null && open
            ? ('Resume', AppColors.warning)
            : open
                ? ('Open', AppColors.primaryAccent)
                : ('Closed', AppColors.textMuted);
    return InfoRow(
      icon: Icons.quiz_outlined,
      title: '${q['title']}',
      subtitle: '${q['subject']} · ${q['questions']} questions'
          '${q['durationMinutes'] != null ? ' · ${q['durationMinutes']} min' : ''}'
          '${q['closesAt'] != null ? ' · closes ${formatDateTime(q['closesAt'])}' : ''}',
      trailing: StatusChip(label: label, color: color),
      onTap: submitted || open ? () => _open(q) : null,
    );
  }
}

/// Takes a quiz (or shows the review of a submitted one).
class TakeQuizScreen extends StatefulWidget {
  final AssessmentApi api;
  final String quizId;
  const TakeQuizScreen({super.key, required this.api, required this.quizId});

  @override
  State<TakeQuizScreen> createState() => _TakeQuizScreenState();
}

class _TakeQuizScreenState extends State<TakeQuizScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  final Map<String, int> _answers = {};
  Timer? _timer;
  Duration? _left;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final d = await widget.api.startQuiz(widget.quizId);
      if (!mounted) return;
      setState(() => _data = d);
      _startTimer();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final deadline = DateTime.tryParse('${_data?['deadline']}');
    if (_data?['status'] != 'IN_PROGRESS' || deadline == null) return;
    void tick() {
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) {
        _timer?.cancel();
        setState(() => _left = Duration.zero);
        if (!_submitting) _submit(auto: true);
      } else {
        setState(() => _left = left);
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) tick();
    });
  }

  Future<void> _submit({bool auto = false}) async {
    final questions = (_data!['questions'] as List).cast<Map>();
    if (!auto) {
      final unanswered = questions.length - _answers.length;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit quiz?'),
          content: Text(unanswered > 0 ? '$unanswered question(s) are not answered. You cannot change answers after submitting.' : 'You cannot change answers after submitting.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep working')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _submitting = true);
    try {
      final review = await widget.api.submitQuiz(widget.quizId, _answers);
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _data = review;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showApiError(context, e);
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final inProgress = d?['status'] == 'IN_PROGRESS';
    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave the quiz?'),
            content: const Text('Your answers on this screen are not saved, and the timer keeps running. You can come back and resume until time runs out.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(d == null ? 'Quiz' : '${d['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (inProgress && _left != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.timer_outlined, size: 18, color: _left!.inMinutes < 1 ? AppColors.error : null),
                    const SizedBox(width: 4),
                    Text(_fmt(_left!), style: TextStyle(fontWeight: FontWeight.w700, color: _left!.inMinutes < 1 ? AppColors.error : null)),
                  ]),
                ),
              ),
          ],
        ),
        body: _error != null
            ? ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: _error!, onRetry: _start)])
            : d == null
                ? const LoadingStateView(message: 'Opening quiz...')
                : inProgress
                    ? _takeView(d)
                    : _reviewView(d),
      ),
    );
  }

  Widget _takeView(Map<String, dynamic> d) {
    final text = Theme.of(context).textTheme;
    final questions = (d['questions'] as List).cast<Map>();
    return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
      if ('${d['instructions'] ?? ''}'.isNotEmpty) ...[
        MessageBanner(message: '${d['instructions']}', isError: false),
        const SizedBox(height: AppSpacing.md),
      ],
      Text('${_answers.length} of ${questions.length} answered', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.md),
      for (final (i, q) in questions.indexed) ...[
        SectionCard(
          title: 'Question ${i + 1} · ${formatLevel(q['marks'] as num)} marks',
          icon: Icons.help_outline,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text('${q['text']}', style: text.bodyLarge),
            ),
            RadioGroup<int>(
              groupValue: _answers[q['questionId']],
              onChanged: (v) => setState(() => v == null ? null : _answers[q['questionId'] as String] = v),
              child: Column(children: [
                for (final (j, o) in (q['options'] as List).indexed)
                  RadioListTile<int>(value: j, title: Text('${String.fromCharCode(65 + j)}. $o')),
              ]),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      FilledButton(
        onPressed: _submitting ? null : () => _submit(),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: _submitting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Submit'),
      ),
    ]);
  }

  Widget _reviewView(Map<String, dynamic> d) {
    final text = Theme.of(context).textTheme;
    final questions = (d['questions'] as List).cast<Map>();
    return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
      KpiGrid(tiles: [
        KpiTile(label: 'Score', value: '${formatLevel(d['score'] as num?)}/${formatLevel(d['maxScore'] as num)}', icon: Icons.star_outline, color: AppColors.success),
        KpiTile(label: 'Submitted', value: formatDateTime(d['submittedAt']), icon: Icons.schedule, color: d['late'] == true ? AppColors.warning : AppColors.secondary),
      ]),
      if (d['late'] == true) ...[
        const SizedBox(height: AppSpacing.md),
        const MessageBanner(message: 'Submitted after the time limit.', isError: false),
      ],
      const SizedBox(height: AppSpacing.lg),
      for (final (i, q) in questions.indexed) ...[
        SectionCard(
          title: 'Question ${i + 1} · ${formatLevel(q['marks'] as num)} marks',
          icon: Icons.help_outline,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text('${q['text']}', style: text.bodyLarge),
            ),
            for (final (j, o) in (q['options'] as List).indexed)
              ListTile(
                dense: true,
                leading: Icon(
                  q['correctOption'] == j
                      ? Icons.check_circle
                      : q['chosen'] == j
                          ? (q.containsKey('correctOption') ? Icons.cancel : Icons.radio_button_checked)
                          : Icons.radio_button_unchecked,
                  color: q['correctOption'] == j
                      ? AppColors.success
                      : q['chosen'] == j && q.containsKey('correctOption')
                          ? AppColors.error
                          : null,
                ),
                title: Text('${String.fromCharCode(65 + j)}. $o'),
                subtitle: q['chosen'] == j ? const Text('Your answer') : null,
              ),
            if (q['chosen'] == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                child: Text('Not answered', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ]);
  }
}
