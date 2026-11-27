import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/ai_exam_api.dart';

/// Colour of a percentage (same bands the server uses for subject status).
Color percentColor(num? p) {
  if (p == null) return AppColors.textMuted;
  if (p >= 80) return AppColors.success;
  if (p >= 65) return AppColors.info;
  if (p >= 50) return AppColors.warning;
  return AppColors.error;
}

Color levelColor(String? level) => switch (level) {
      'Strong' || 'strong' => AppColors.success,
      'Good' => AppColors.info,
      'Moderate' || 'Average' || 'partial' => AppColors.warning,
      _ => AppColors.error,
    };

Color evaluationColor(String? s) => switch (s) {
      'EVALUATED' => AppColors.success,
      'REVIEW' => AppColors.warning,
      'FAILED' => AppColors.error,
      'PROCESSING' => AppColors.info,
      _ => AppColors.textMuted,
    };

Color phaseColor(String? s) => switch (s) {
      'ACTIVE' => AppColors.success,
      'SCHEDULED' => AppColors.info,
      'DRAFT' => AppColors.warning,
      _ => AppColors.textMuted,
    };

/// Small rounded label.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const Pill({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// Horizontal percentage bar with a label.
class PercentBar extends StatelessWidget {
  final String label;
  final num? percent;
  final String? caption;
  final Color? color;
  const PercentBar({super.key, required this.label, required this.percent, this.caption, this.color});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = (percent ?? 0).clamp(0, 100).toDouble();
    final c = color ?? percentColor(percent);
    return Semantics(
      label: '$label: ${percent == null ? 'no data' : '${fmtNum(percent)} percent'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Text(percent == null ? '—' : '${fmtNum(percent)}%', style: text.bodyMedium?.copyWith(color: c, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: p / 100, minHeight: 8, color: c, backgroundColor: AppColors.surfaceMuted),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(caption!, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
        ]),
      ),
    );
  }
}

/// Vertical bars over time (test-wise or monthly scores). Scrolls sideways when there are many.
class TrendBars extends StatelessWidget {
  final List<({String label, num? percent, String? tooltip})> points;
  final double height;
  const TrendBars({super.key, required this.points, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('No evaluated tests yet.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
      );
    }
    return SizedBox(
      height: height + 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        itemCount: points.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final pt = points[i];
          final p = (pt.percent ?? 0).clamp(0, 100).toDouble();
          return Tooltip(
            message: pt.tooltip ?? pt.label,
            child: SizedBox(
              width: 46,
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(pt.percent == null ? '—' : fmtNum(pt.percent), style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  height: (height - 30) * p / 100 + 2,
                  decoration: BoxDecoration(color: percentColor(pt.percent), borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                ),
                const SizedBox(height: 6),
                Text(pt.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall?.copyWith(color: AppColors.textMuted)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Explains the evaluator state; never implies AI marking when it is not configured.
class AiStatusBanner extends StatelessWidget {
  final Map<String, dynamic>? ai;
  const AiStatusBanner({super.key, required this.ai});

  @override
  Widget build(BuildContext context) {
    if (ai == null) return const SizedBox.shrink();
    final configured = ai!['configured'] == true;
    final mock = ai!['mock'] == true;
    if (configured && !mock) return const SizedBox.shrink();
    final (color, bg, icon, msg) = mock
        ? (AppColors.warning, AppColors.warningBg, Icons.science_outlined, 'Development evaluator active: its marks are for testing only and always need a teacher\'s review.')
        : (AppColors.info, AppColors.infoBg, Icons.info_outline, 'AI evaluation is not configured yet. Objective questions are marked from the answer key; descriptive answers stay "Pending" until you mark them or the AI key is added.');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(msg, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textDark))),
      ]),
    );
  }
}

/// Bulleted list with a coloured heading (feedback sections).
class FeedbackList extends StatelessWidget {
  final String title;
  final List items;
  final Color color;
  final IconData icon;
  const FeedbackList({super.key, required this.title, required this.items, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title, style: text.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(left: 22, bottom: 3),
            child: Text('• $i', style: text.bodyMedium),
          ),
      ]),
    );
  }
}

/// Section title used inside lists.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        if (subtitle != null) Text(subtitle!, style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
      ]),
    );
  }
}
