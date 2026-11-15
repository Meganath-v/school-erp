import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Drop-in replacement for [DataTable]: a normal table on tablets/desktop,
/// and one card per row on phones (first column as the card title, the rest as
/// label/value lines) so nothing needs horizontal scrolling or overflows.
class AdaptiveDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final WidgetStateProperty<Color?>? headingRowColor;
  final double? columnSpacing;
  final double? horizontalMargin;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;

  /// Below this screen width rows are shown as cards.
  static const double phoneBreakpoint = 600;

  const AdaptiveDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.headingRowColor,
    this.columnSpacing,
    this.horizontalMargin,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= phoneBreakpoint) {
      return DataTable(
        columns: columns,
        rows: rows,
        headingRowColor: headingRowColor,
        columnSpacing: columnSpacing,
        horizontalMargin: horizontalMargin,
        dataRowMinHeight: dataRowMinHeight,
        dataRowMaxHeight: dataRowMaxHeight,
      );
    }

    // Tables usually sit inside a horizontal scroll view (unbounded width),
    // so size the card list to the screen explicitly.
    final width = screenWidth - 2 * AppSpacing.lg - 2;
    final text = Theme.of(context).textTheme;

    if (rows.isEmpty) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('No records to show.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const Divider(height: 1),
            _RowCard(columns: columns, row: rows[r]),
          ],
        ],
      ),
    );
  }
}

/// Drop-in replacement for a [Table] whose first [TableRow] is a header row.
/// Phones get one card per data row; wider screens get the original table.
class AdaptiveTable extends StatelessWidget {
  final List<TableRow> children;
  final Map<int, TableColumnWidth>? columnWidths;
  final TableBorder? border;
  final TableCellVerticalAlignment defaultVerticalAlignment;

  const AdaptiveTable({
    super.key,
    required this.children,
    this.columnWidths,
    this.border,
    this.defaultVerticalAlignment = TableCellVerticalAlignment.top,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width >= AdaptiveDataTable.phoneBreakpoint || children.isEmpty) {
      return Table(
        columnWidths: columnWidths,
        border: border,
        defaultVerticalAlignment: defaultVerticalAlignment,
        children: children,
      );
    }
    final header = children.first.children;
    final columns = [for (final h in header) DataColumn(label: _HeaderLabel(child: h))];
    final rows = [
      for (final r in children.skip(1)) DataRow(cells: [for (final c in r.children) DataCell(c)]),
    ];
    final text = Theme.of(context).textTheme;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('No records to show.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _RowCard(columns: columns, row: rows[i]),
        ],
      ],
    );
  }
}

/// Header cells are usually padded, bold text; strip the padding and bold for card labels.
class _HeaderLabel extends StatelessWidget {
  final Widget child;
  const _HeaderLabel({required this.child});

  @override
  Widget build(BuildContext context) {
    var w = child;
    while (w is Padding && w.child != null) {
      w = w.child!;
    }
    if (w is Text && w.data != null) return Text(w.data!);
    return w;
  }
}

class _RowCard extends StatelessWidget {
  final List<DataColumn> columns;
  final DataRow row;
  const _RowCard({required this.columns, required this.row});

  Widget _cell(DataCell cell) {
    final child = cell.child;
    if (cell.onTap == null) return child;
    return InkWell(onTap: cell.onTap, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cells = row.cells;
    if (cells.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle.merge(
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textDark),
            child: _cell(cells.first),
          ),
          for (var i = 1; i < cells.length && i < columns.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: DefaultTextStyle.merge(
                      style: text.bodySmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w500),
                      child: columns[i].label,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: _cell(cells[i])),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
