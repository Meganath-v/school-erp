import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class SearchFilterBar extends StatelessWidget {
  final String hintText;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final List<Widget>? filterControls;
  final int? resultCount;
  final String? countLabel;

  SearchFilterBar({
    super.key,
    String? searchHint,
    String? hintText,
    String? searchQuery,
    String? value,
    ValueChanged<String>? onSearchChanged,
    ValueChanged<String>? onChanged,
    this.onClear,
    List<Widget>? filters,
    List<Widget>? filterControls,
    int? totalCount,
    int? resultCount,
    this.countLabel,
  })  : hintText = searchHint ?? hintText ?? 'Search records...',
        value = searchQuery ?? value ?? '',
        onChanged = onSearchChanged ?? onChanged ?? ((_) {}),
        filterControls = filters ?? filterControls,
        resultCount = totalCount ?? resultCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
                onChanged: onChanged,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: hintText,
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                  suffixIcon: value.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: onClear ?? () => onChanged(''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.smBorderRadius,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.smBorderRadius,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
          ),
          if (filterControls != null && filterControls!.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: filterControls!,
            ),
          if (resultCount != null)
            Text(
              countLabel != null ? '$resultCount $countLabel' : '$resultCount items found',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
