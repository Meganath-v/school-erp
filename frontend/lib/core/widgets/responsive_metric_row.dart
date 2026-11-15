import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A row of equal-width stat cards on wide screens; a two-column grid on phones
/// (three columns on mid-size screens) so card text is never squeezed.
class ResponsiveMetricRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ResponsiveMetricRow({super.key, required this.children, this.spacing = AppSpacing.md});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final columns = w >= 900 ? children.length : (w >= 600 ? 3 : 2);
      if (columns >= children.length) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      }
      final itemWidth = (w - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final c in children) SizedBox(width: itemWidth, child: c)],
      );
    });
  }
}
