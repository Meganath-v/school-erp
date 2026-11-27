import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../outcomes/presentation/outcomes_screen.dart' show showApiError, showDone;
import '../../data/ai_exam_api.dart';
import '../widgets/ai_widgets.dart';

String evaluatorLabel(Map<String, dynamic> e) {
  if (e['teacherMarks'] != null) return 'Teacher';
  return switch (e['method']) {
    'AUTO' => 'Answer key',
    'AI' => 'AI (${e['model'] ?? 'model'})',
    'MOCK' => 'Development evaluator (not AI)',
    'TEACHER' => 'Teacher',
    _ => 'Not evaluated',
  };
}

/// One student's answers with evaluations; teachers accept or override marks.
class SubmissionReviewScreen extends StatefulWidget {
  final AiExamApi api;
  final String testId;
  final String submissionId;
  const SubmissionReviewScreen({super.key, required this.api, required this.testId, required this.submissionId});

  @override
  State<SubmissionReviewScreen> createState() => _SubmissionReviewScreenState();
}

class _SubmissionReviewScreenState extends State<SubmissionReviewScreen> {
  late Future<Map<String, dynamic>> _future = widget.api.submission(widget.testId, widget.submissionId);

  Future<void> _reload() async {
    final f = widget.api.submission(widget.testId, widget.submissionId);
    setState(() => _future = f);
    await f;
  }

  Future<void> _override(Map<String, dynamic> ev, num max) async {
    final marks = TextEditingController(text: ev['finalMarks'] != null ? fmtNum(ev['finalMarks'] as num) : (ev['aiMarks'] != null ? fmtNum(ev['aiMarks'] as num) : ''));
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set marks'),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: marks,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Marks (0 – ${fmtNum(max)})'),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || n < 0 || n > max ? 'Between 0 and ${fmtNum(max)}' : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: reason,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason (recorded)'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Give a short reason' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => form.currentState!.validate() ? Navigator.pop(ctx, true) : null, child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.overrideMarks(ev['id'] as String, double.parse(marks.text), reason.text.trim());
      if (mounted) {
        showDone(context, 'Marks saved');
        _reload();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _accept(Map<String, dynamic> ev) async {
    try {
      await widget.api.acceptEvaluation(ev['id'] as String);
      if (mounted) {
        showDone(context, 'AI marks accepted');
        _reload();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Review answers')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading answers...');
            if (snap.hasError) return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload)]);
            final d = snap.data!;
            final answers = AiExamApi.list(d['answers']);
            final status = '${d['evaluationStatus']}';
            return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
              Text('${d['student']?['name']}', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text('${d['student']?['admissionNo']} · submitted ${fmtDate(d['submittedAt'])}${d['autoSubmitted'] == true ? ' (auto-submitted)' : ''}', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: 8, children: [
                Pill(label: evaluationLabels[status] ?? status, color: evaluationColor(status)),
                if (d['score'] != null) Pill(label: 'Score ${fmtNum(d['score'] as num?)} / ${fmtNum(d['maxScore'] as num?)}', color: AppColors.primaryAccent),
              ]),
              const SizedBox(height: AppSpacing.md),
              for (final (i, a) in answers.indexed) _answerCard(i, a),
            ]);
          },
        ),
      ),
    );
  }

  Widget _answerCard(int i, Map<String, dynamic> a) {
    final text = Theme.of(context).textTheme;
    final q = AiExamApi.map(a['question']);
    final ev = AiExamApi.map(a['evaluation']);
    final fb = AiExamApi.map(ev['feedback']);
    final status = '${ev['status']}';
    final max = (q['marks'] as num?) ?? 0;
    final options = q['options'] is List ? q['options'] as List : null;
    final answerText = options != null ? (a['choice'] == null ? '' : '${String.fromCharCode(65 + (a['choice'] as int))}. ${options[a['choice'] as int]}') : '${a['text'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SectionCard(
        title: 'Q${i + 1} · ${questionTypeLabels[q['type']]} · ${ev['finalMarks'] != null ? fmtNum(ev['finalMarks'] as num) : '—'} / ${fmtNum(max)}',
        icon: Icons.help_outline,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${q['text']}', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Student answer${a['inputMethod'] == 'VOICE' ? ' (voice)' : a['inputMethod'] == 'MIXED' ? ' (voice + typed)' : ''}', style: text.labelSmall?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Text(answerText.trim().isEmpty ? 'Not answered' : answerText, style: text.bodyMedium),
                ]),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: 8, runSpacing: 4, children: [
                Pill(label: evaluationLabels[status] ?? status, color: evaluationColor(status)),
                Pill(label: evaluatorLabel(ev), color: ev['method'] == 'MOCK' ? AppColors.warning : AppColors.textMuted),
                if (ev['aiMarks'] != null) Pill(label: 'AI ${fmtNum(ev['aiMarks'] as num)}', color: AppColors.info),
                if (ev['teacherMarks'] != null) Pill(label: 'Teacher ${fmtNum(ev['teacherMarks'] as num)}', color: AppColors.primaryAccent),
                if (ev['confidence'] != null) Pill(label: 'Confidence ${((ev['confidence'] as num) * 100).round()}%', color: AppColors.textMuted),
              ]),
              for (final r in (ev['reviewReasons'] as List? ?? const []))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.flag_outlined, size: 16, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(child: Text('$r', style: text.bodySmall)),
                  ]),
                ),
              if (ev['lastError'] != null && status != 'EVALUATED')
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('${ev['lastError']}', style: text.bodySmall?.copyWith(color: AppColors.textMuted))),
              if (ev['overrideReason'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Teacher note: ${ev['overrideReason']}', style: text.bodySmall)),
              if (ev['criteria'] is List) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Rubric', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                for (final c in AiExamApi.list(ev['criteria']))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text('${c['description']}${(c['comment'] ?? '').toString().isNotEmpty ? ' — ${c['comment']}' : ''}', style: text.bodySmall)),
                      const SizedBox(width: 8),
                      Text('${fmtNum(c['awarded'] as num?)}/${fmtNum(c['max'] as num?)}', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ],
              FeedbackList(title: 'Correct', items: (fb['correct_points'] as List?) ?? const [], color: AppColors.success, icon: Icons.check_circle_outline),
              FeedbackList(title: 'Missing', items: (fb['missing_points'] as List?) ?? const [], color: AppColors.warning, icon: Icons.remove_circle_outline),
              FeedbackList(title: 'Incorrect', items: [...?(fb['incorrect_points'] as List?), ...?(fb['conceptual_errors'] as List?)], color: AppColors.error, icon: Icons.cancel_outlined),
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.sm, children: [
                if (status == 'REVIEW' && ev['aiMarks'] != null && ev['method'] != 'MOCK')
                  FilledButton.tonalIcon(onPressed: () => _accept(ev), icon: const Icon(Icons.check), label: Text('Accept ${fmtNum(ev['aiMarks'] as num)}')),
                if (status != 'PROCESSING' && ev['id'] != null)
                  OutlinedButton.icon(onPressed: () => _override(ev, max), icon: const Icon(Icons.edit_outlined), label: Text(ev['finalMarks'] == null ? 'Mark answer' : 'Change marks')),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
