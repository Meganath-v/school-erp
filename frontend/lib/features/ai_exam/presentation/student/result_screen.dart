import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/ai_exam_api.dart';
import '../widgets/ai_widgets.dart';

/// Published result with question-wise feedback.
class ResultScreen extends StatefulWidget {
  final AiExamApi api;
  final String testId;
  const ResultScreen({super.key, required this.api, required this.testId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Future<Map<String, dynamic>> _future = widget.api.result(widget.testId);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading your result...');
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: () => setState(() => _future = widget.api.result(widget.testId)))]);
          }
          final d = snap.data!;
          if (d['published'] != true) {
            return const EmptyStateView(icon: Icons.hourglass_top, title: 'Result not published yet', message: 'Your answers are submitted. Your teacher will publish the result after evaluation.');
          }
          final t = AiExamApi.map(d['test']);
          final p = d['percent'] as num?;
          final questions = AiExamApi.list(d['questions']);
          return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
            Text('${t['title']}', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text('${t['subject']} · ${t['className']} · ${fmtDate(t['date'], time: false)}', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: percentColor(p).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: percentColor(p).withValues(alpha: 0.3))),
              child: Row(children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(value: ((p ?? 0) / 100).clamp(0, 1).toDouble(), strokeWidth: 7, color: percentColor(p), backgroundColor: AppColors.surfaceMuted),
                    Text('${fmtNum(p)}%', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${fmtNum(d['score'] as num?)} / ${fmtNum(d['maxScore'] as num?)}', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${questions.length} questions', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  ]),
                ),
              ]),
            ),
            const SectionTitle('Question-wise feedback'),
            for (final (i, q) in questions.indexed) _question(i, q),
          ]);
        },
      ),
    );
  }

  Widget _question(int i, Map<String, dynamic> q) {
    final text = Theme.of(context).textTheme;
    final fb = AiExamApi.map(q['feedback']);
    final marks = (q['marks'] as num?) ?? 0;
    final max = (q['maxMarks'] as num?) ?? 0;
    final options = q['options'] as List?;
    final yours = options != null ? (q['yourChoice'] == null ? '' : '${String.fromCharCode(65 + (q['yourChoice'] as int))}. ${options[q['yourChoice'] as int]}') : '${q['yourAnswer'] ?? ''}';
    final by = switch (q['evaluatedBy']) {
      'TEACHER' => 'Marked by your teacher',
      'AI' => 'Evaluated by AI and released by your teacher',
      'AUTO' => 'Marked from the answer key',
      _ => 'Marked by your teacher',
    };
    final pct = max > 0 ? marks / max * 100 : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        child: ExpansionTile(
          initiallyExpanded: pct < 100,
          title: Text('Q${i + 1}. ${q['text']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text('${q['topic'] ?? ''}', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
          trailing: Pill(label: '${fmtNum(marks)}/${fmtNum(max)}', color: percentColor(pct)),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${q['text']}', style: text.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            _box('Your answer', yours.trim().isEmpty ? 'Not answered' : yours, AppColors.surfaceMuted),
            if ((fb['overall'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text('${fb['overall']}', style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic))),
            FeedbackList(title: 'Correct points', items: (fb['correctPoints'] as List?) ?? const [], color: AppColors.success, icon: Icons.check_circle_outline),
            FeedbackList(title: 'Missing points', items: (fb['missingPoints'] as List?) ?? const [], color: AppColors.warning, icon: Icons.remove_circle_outline),
            FeedbackList(title: 'Incorrect points', items: (fb['incorrectPoints'] as List?) ?? const [], color: AppColors.error, icon: Icons.cancel_outlined),
            FeedbackList(title: 'How to improve', items: (fb['improvement'] as List?) ?? const [], color: AppColors.info, icon: Icons.lightbulb_outline),
            if (q['criteria'] is List) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Marks by criterion', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              for (final c in AiExamApi.list(q['criteria']))
                Row(children: [
                  Expanded(child: Text('${c['description']}', style: text.bodySmall)),
                  Text('${fmtNum(c['awarded'] as num?)}/${fmtNum(c['max'] as num?)}', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ]),
            ],
            if (options != null && q['correctOption'] != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _box('Correct answer', '${String.fromCharCode(65 + (q['correctOption'] as int))}. ${options[q['correctOption'] as int]}', AppColors.successBg),
              )
            else if ((q['modelAnswer'] ?? '').toString().isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: _box('Model answer', '${q['modelAnswer']}', AppColors.successBg)),
            if ((q['explanation'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text('Explanation: ${q['explanation']}', style: text.bodySmall)),
            if (q['teacherNote'] != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text('Teacher\'s note: ${q['teacherNote']}', style: text.bodySmall)),
            Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(by, style: text.labelSmall?.copyWith(color: AppColors.textMuted))),
          ],
        ),
      ),
    );
  }

  Widget _box(String label, String body, Color bg) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: text.labelSmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(body, style: text.bodyMedium),
      ]),
    );
  }
}
