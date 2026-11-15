import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<String>? breadcrumbs;
  final Widget? badge;
  final List<Widget>? actions;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.breadcrumbs,
    this.badge,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (breadcrumbs != null && breadcrumbs!.isNotEmpty) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (int i = 0; i < breadcrumbs!.length; i++) ...[
                  Text(
                    breadcrumbs![i],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: i == breadcrumbs!.length - 1 ? FontWeight.w600 : FontWeight.w400,
                      color: i == breadcrumbs!.length - 1 ? AppColors.primaryAccent : AppColors.textMuted,
                    ),
                  ),
                  if (i < breadcrumbs!.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.chevron_right, size: 14, color: AppColors.textSubtle),
                    ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          // Title wraps instead of running off narrow screens; actions sit beside it
          // on wide layouts and drop below it on phones.
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 640;
            final titleRow = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: narrow ? 20 : 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  badge!,
                ],
              ],
            );
            final hasActions = actions != null && actions!.isNotEmpty;
            if (!hasActions) return titleRow;
            final actionsWrap = Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: actions!);
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [titleRow, const SizedBox(height: AppSpacing.md), actionsWrap],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleRow),
                const SizedBox(width: AppSpacing.md),
                Flexible(child: Align(alignment: Alignment.centerRight, child: actionsWrap)),
              ],
            );
          }),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

