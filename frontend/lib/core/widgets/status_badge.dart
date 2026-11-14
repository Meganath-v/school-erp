import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

enum BadgeVariant {
  neutral,
  success,
  warning,
  error,
  info,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;
  final bool isSmall;

  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.icon,
    this.isSmall = false,
  });

  factory StatusBadge.fromStatus(String status, {bool isSmall = false}) {
    final s = status.toUpperCase();
    if (s == 'ACTIVE' || s == 'PAID' || s == 'APPROVED' || s == 'PUBLISHED' || s == 'PRESENT' || s == 'COMPLETED') {
      return StatusBadge(label: status, variant: BadgeVariant.success, isSmall: isSmall);
    }
    if (s == 'PENDING' || s == 'PARTIAL' || s == 'IN_PROGRESS' || s == 'UNDER_REVIEW' || s == 'TRIAL' || s == 'LATE') {
      return StatusBadge(label: status, variant: BadgeVariant.warning, isSmall: isSmall);
    }
    if (s == 'FAILED' || s == 'REJECTED' || s == 'OVERDUE' || s == 'ABSENT' || s == 'SUSPENDED' || s == 'WITHDRAWN') {
      return StatusBadge(label: status, variant: BadgeVariant.error, isSmall: isSmall);
    }
    if (s == 'PROMOTED' || s == 'TRANSFERRED' || s == 'SCHEDULED' || s == 'ALUMNI' || s == 'EXCUSED') {
      return StatusBadge(label: status, variant: BadgeVariant.info, isSmall: isSmall);
    }
    return StatusBadge(label: status, variant: BadgeVariant.neutral, isSmall: isSmall);
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;

    switch (variant) {
      case BadgeVariant.success:
        bg = AppColors.successBg;
        border = AppColors.successBorder;
        text = AppColors.success;
        break;
      case BadgeVariant.warning:
        bg = AppColors.warningBg;
        border = AppColors.warningBorder;
        text = AppColors.warning;
        break;
      case BadgeVariant.error:
        bg = AppColors.errorBg;
        border = AppColors.errorBorder;
        text = AppColors.error;
        break;
      case BadgeVariant.info:
        bg = AppColors.infoBg;
        border = AppColors.infoBorder;
        text = AppColors.info;
        break;
      case BadgeVariant.neutral:
        bg = AppColors.surfaceVariant;
        border = AppColors.border;
        text = AppColors.textMedium;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.smBorderRadius,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isSmall ? 10 : 12, color: text),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isSmall ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: text,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
