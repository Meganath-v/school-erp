import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small, consistent building blocks for the phone layouts.

class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primaryAccent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.xlBorderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.xlBorderRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.xlBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.mdBorderRadius,
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  value,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-column grid of [KpiTile]s that adapts to wider phones/tablets.
class KpiGrid extends StatelessWidget {
  final List<Widget> tiles;
  const KpiGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 4 : 2;
      const gap = AppSpacing.md;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: width, child: t)],
      );
    });
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? empty;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.actionLabel,
    this.onAction,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // A Material (not a decorated box) so list tiles inside can paint their ink.
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlBorderRadius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.xs, AppSpacing.xs),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryAccent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!))
                else
                  const SizedBox(height: 48),
              ],
            ),
          ),
          const Divider(height: 1),
          if (children.isEmpty)
            empty ??
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('Nothing here yet.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                )
          else
            ...children,
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const InfoRow({super.key, required this.title, this.subtitle, this.icon, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Own Material so ink splashes show inside the white SectionCard.
    return Material(
      type: MaterialType.transparency,
      child: _tile(),
    );
  }

  Widget _tile() {
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 10,
      leading: icon == null
          ? null
          : CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryAccentSubtle,
              child: Icon(icon, size: 18, color: AppColors.primaryAccent),
            ),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing,
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  factory StatusChip.forStatus(String status) {
    final s = status.toUpperCase();
    final color = switch (s) {
      'PAID' || 'APPROVED' || 'ACTIVE' || 'COMPLETED' || 'PRESENT' || 'PUBLISHED' => AppColors.success,
      'PENDING' || 'PARTIAL' || 'PARTIALLY_PAID' || 'DRAFT' || 'TRIAL' => AppColors.warning,
      'OVERDUE' || 'REJECTED' || 'SUSPENDED' || 'ABSENT' || 'CANCELLED' => AppColors.error,
      _ => AppColors.textMuted,
    };
    final label = s.replaceAll('_', ' ');
    return StatusChip(label: label[0] + label.substring(1).toLowerCase(), color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.pillBorderRadius,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Full-width message used for errors and notices inside forms and pages.
class MessageBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const MessageBanner({super.key, required this.message, this.isError = true, this.onRetry, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final fg = isError ? AppColors.error : AppColors.info;
    final bg = isError ? AppColors.errorBg : AppColors.infoBg;
    final border = isError ? AppColors.errorBorder : AppColors.infoBorder;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.lgBorderRadius,
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isError ? Icons.error_outline : Icons.info_outline, color: fg, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(message, style: TextStyle(color: AppColors.textDark, fontSize: 14, height: 1.35)),
              ),
            ),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
