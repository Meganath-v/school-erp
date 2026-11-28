import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../outcomes/presentation/outcomes_screen.dart' show showApiError, showDone, confirmDelete;
import '../data/timetable_api.dart';
import 'schedule_widgets.dart';

/// The school day's periods (the timeline). The office edits it; everyone else reads it.
class BellScheduleView extends StatefulWidget {
  final TimetableApi api;
  final bool canEdit;
  const BellScheduleView({super.key, required this.api, required this.canEdit});

  @override
  State<BellScheduleView> createState() => _BellScheduleViewState();
}

class _BellScheduleViewState extends State<BellScheduleView> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _periods = [];

  static const _standard = [
    ['09:00', '09:45'], ['09:45', '10:30'], ['10:45', '11:30'], ['11:30', '12:15'],
    ['13:00', '13:45'], ['13:45', '14:30'], ['14:35', '15:20'], ['15:20', '16:00'],
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.api.periods();
      if (!mounted) return;
      setState(() {
        _periods = TimetableApi.list(r['periods']);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e);
        });
      }
    }
  }

  List<Map<String, dynamic>> _strip(List<Map<String, dynamic>> list) => [
        for (final p in list)
          {
            'dayOfWeek': p['dayOfWeek'],
            'periodNumber': p['periodNumber'],
            'startTime': p['startTime'],
            'endTime': p['endTime'],
            if ((p['label'] as String?)?.isNotEmpty ?? false) 'label': p['label'],
          },
      ];

  Future<void> _save(List<Map<String, dynamic>> next, String done) async {
    setState(() => _saving = true);
    try {
      Map<String, dynamic> r;
      try {
        r = await widget.api.savePeriods(_strip(next));
      } catch (e) {
        if (toApiException(e).statusCode != 409 || !mounted) rethrow;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Periods are in use'),
            content: Text('${apiErrorMessage(e)}\n\nThose class timetable slots will be cleared.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove them')),
            ],
          ),
        );
        if (ok != true) return;
        r = await widget.api.savePeriods(_strip(next), removeAssignedSlots: true);
      }
      if (!mounted) return;
      setState(() => _periods = TimetableApi.list(r['periods']));
      showDone(context, done);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit({Map<String, dynamic>? period, int? day}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PeriodDialog(period: period, day: day, existing: _periods),
    );
    if (result == null) return;
    final next = [
      for (final p in _periods)
        if (period == null || !(p['dayOfWeek'] == period['dayOfWeek'] && p['periodNumber'] == period['periodNumber'])) p,
      result,
    ];
    await _save(next, period == null ? 'Period added' : 'Period updated');
  }

  Future<void> _delete(Map<String, dynamic> period) async {
    if (!await confirmDelete(context, '${dayNames[period['dayOfWeek']]} ${periodTitle(period)}')) return;
    await _save([
      for (final p in _periods)
        if (!(p['dayOfWeek'] == period['dayOfWeek'] && p['periodNumber'] == period['periodNumber'])) p,
    ], 'Period removed');
  }

  Future<void> _useStandard() async {
    await _save([
      for (var d = 1; d <= 6; d++)
        for (var i = 0; i < _standard.length; i++)
          {'dayOfWeek': d, 'periodNumber': i + 1, 'startTime': _standard[i][0], 'endTime': _standard[i][1]},
    ], 'Standard 8-period day set for Monday to Saturday');
  }

  Future<void> _copyDay(int from) async {
    final source = _periods.where((p) => p['dayOfWeek'] == from).toList();
    final days = await showDialog<Set<int>>(context: context, builder: (_) => _CopyDaysDialog(from: from));
    if (days == null || days.isEmpty) return;
    await _save([
      for (final p in _periods)
        if (!days.contains(p['dayOfWeek'])) p,
      for (final d in days)
        for (final p in source) {...p, 'dayOfWeek': d},
    ], 'Copied ${dayNames[from]} to ${days.length} day(s)');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingStateView(message: 'Loading periods…');
    if (_error != null) return ErrorStateView(title: 'Could not load periods', errorMessage: _error!, onRetry: _load);
    final days = _periods.map((p) => p['dayOfWeek'] as int).toSet().toList()..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (_saving) const LinearProgressIndicator(),
          if (widget.canEdit)
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              FilledButton.icon(
                onPressed: _saving ? null : () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Add period'),
              ),
              if (_periods.isEmpty)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _useStandard,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Use standard 8 periods'),
                ),
            ]),
          if (!widget.canEdit)
            const MessageBanner(message: 'The office sets the periods of the school day.', isError: false),
          const SizedBox(height: AppSpacing.md),
          if (_periods.isEmpty)
            const EmptyStateView(
              icon: Icons.schedule_outlined,
              title: 'No periods yet',
              message: 'Add the periods of each school day, with their start and end times.',
            ),
          for (final d in days)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SectionCard(
                title: dayNames[d] ?? 'Day $d',
                icon: Icons.calendar_view_day_outlined,
                actionLabel: widget.canEdit ? 'Copy to…' : null,
                onAction: widget.canEdit && !_saving ? () => _copyDay(d) : null,
                children: [
                  for (final p in _periods.where((p) => p['dayOfWeek'] == d))
                    InfoRow(
                      icon: Icons.schedule,
                      title: periodTitle(p),
                      trailing: widget.canEdit
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: _saving ? null : () => _edit(period: p)),
                              IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: _saving ? null : () => _delete(p)),
                            ])
                          : null,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Add or edit one period: day, number, start and end time.
class PeriodDialog extends StatefulWidget {
  final Map<String, dynamic>? period;
  final int? day;
  final List<Map<String, dynamic>> existing;
  const PeriodDialog({super.key, this.period, this.day, required this.existing});

  @override
  State<PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<PeriodDialog> {
  late int _day = widget.period?['dayOfWeek'] as int? ?? widget.day ?? 1;
  late final _number = TextEditingController(text: '${widget.period?['periodNumber'] ?? _nextNumber(_day)}');
  late final _label = TextEditingController(text: widget.period?['label'] as String? ?? '');
  late String _start = widget.period?['startTime'] as String? ?? '09:00';
  late String _end = widget.period?['endTime'] as String? ?? '09:45';
  String? _error;

  int _nextNumber(int day) {
    final used = widget.existing.where((p) => p['dayOfWeek'] == day).map((p) => p['periodNumber'] as int);
    return used.isEmpty ? 1 : (used.reduce((a, b) => a > b ? a : b) + 1).clamp(1, 12);
  }

  @override
  void dispose() {
    _number.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final parts = (start ? _start : _end).split(':').map(int.parse).toList();
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: parts[0], minute: parts[1]));
    if (t == null) return;
    final text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _start = text : _end = text);
  }

  int _mins(String t) => int.parse(t.split(':')[0]) * 60 + int.parse(t.split(':')[1]);

  void _submit() {
    final n = int.tryParse(_number.text.trim());
    if (n == null || n < 1 || n > 12) return setState(() => _error = 'Period number must be 1 to 12');
    if (_mins(_end) <= _mins(_start)) return setState(() => _error = 'End time must be after the start time');
    final editingSame = widget.period != null && widget.period!['dayOfWeek'] == _day && widget.period!['periodNumber'] == n;
    if (!editingSame && widget.existing.any((p) => p['dayOfWeek'] == _day && p['periodNumber'] == n)) {
      return setState(() => _error = '${dayNames[_day]} already has period $n');
    }
    Navigator.pop(context, {
      'dayOfWeek': _day,
      'periodNumber': n,
      'startTime': _start,
      'endTime': _end,
      if (_label.text.trim().isNotEmpty) 'label': _label.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.period == null ? 'Add period' : 'Edit period'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'Day'),
              items: [for (final e in dayNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() {
                _day = v ?? _day;
                if (widget.period == null) _number.text = '${_nextNumber(_day)}';
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _number, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Period number')),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _pick(true), icon: const Icon(Icons.schedule), label: Text('Starts $_start'))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: OutlinedButton.icon(onPressed: () => _pick(false), icon: const Icon(Icons.schedule), label: Text('Ends $_end'))),
            ]),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _label, decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'e.g. Lab period')),
            if (_error != null) ...[const SizedBox(height: AppSpacing.md), MessageBanner(message: _error!)],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _CopyDaysDialog extends StatefulWidget {
  final int from;
  const _CopyDaysDialog({required this.from});

  @override
  State<_CopyDaysDialog> createState() => _CopyDaysDialogState();
}

class _CopyDaysDialogState extends State<_CopyDaysDialog> {
  final _days = <int>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Copy ${dayNames[widget.from]} to'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('The chosen days get exactly the same periods.', style: TextStyle(color: AppColors.textMuted)),
          for (final e in dayNames.entries)
            if (e.key != widget.from)
              CheckboxListTile(
                value: _days.contains(e.key),
                title: Text(e.value),
                dense: true,
                onChanged: (v) => setState(() => v == true ? _days.add(e.key) : _days.remove(e.key)),
              ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _days), child: const Text('Copy')),
      ],
    );
  }
}
