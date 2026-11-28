import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../outcomes/presentation/outcomes_screen.dart' show showApiError, showDone;
import '../data/timetable_api.dart';
import 'schedule_widgets.dart';

/// Attendance for one period. Only the teacher taking the period can mark it, and only on that day;
/// the office can correct it later. Everyone else sees it read-only.
class PeriodAttendanceScreen extends StatefulWidget {
  final TimetableApi api;
  final String sectionId;
  final String date;
  final int periodNumber;
  const PeriodAttendanceScreen({super.key, required this.api, required this.sectionId, required this.date, required this.periodNumber});

  @override
  State<PeriodAttendanceScreen> createState() => _PeriodAttendanceScreenState();
}

class _PeriodAttendanceScreenState extends State<PeriodAttendanceScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _data = {};
  final Map<String, String> _status = {};

  static const _choices = {'PRESENT': 'P', 'ABSENT': 'A', 'LATE': 'L'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _apply(Map<String, dynamic> r) {
    _data = r;
    _status.clear();
    for (final s in TimetableApi.list(r['students'])) {
      _status[s['studentId'] as String] = (s['status'] as String?) ?? 'PRESENT';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.api.periodAttendance(widget.sectionId, widget.date, widget.periodNumber);
      if (!mounted) return;
      setState(() {
        _apply(r);
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final r = await widget.api.savePeriodAttendance({
        'sectionId': widget.sectionId,
        'date': widget.date,
        'periodNumber': widget.periodNumber,
        'records': [for (final e in _status.entries) {'studentId': e.key, 'status': e.value}],
      });
      if (!mounted) return;
      final wasTaken = _data['taken'] == true;
      setState(() => _apply(r));
      showDone(context, wasTaken ? 'Attendance updated' : 'Attendance saved');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canMark = _data['canMark'] == true;
    final students = TimetableApi.list(_data['students']);
    final absent = _status.values.where((s) => s == 'ABSENT').length;
    return Scaffold(
      appBar: AppBar(title: Text('Period ${widget.periodNumber} attendance')),
      bottomNavigationBar: canMark && students.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_data['taken'] == true ? 'Update attendance' : 'Save attendance'),
                ),
              ),
            )
          : null,
      body: _loading
          ? const LoadingStateView(message: 'Loading class list…')
          : _error != null
              ? ErrorStateView(title: 'Could not load', errorMessage: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _header(),
                      const SizedBox(height: AppSpacing.md),
                      if (!canMark && _data['reason'] != null) ...[
                        MessageBanner(message: _data['reason'] as String, isError: false),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (students.isEmpty)
                        const EmptyStateView(icon: Icons.groups_outlined, title: 'No students', message: 'No students are enrolled in this class.')
                      else
                        SectionCard(
                          title: '${students.length} students · $absent absent',
                          icon: Icons.groups_outlined,
                          actionLabel: canMark ? 'All present' : null,
                          onAction: canMark ? () => setState(() => _status.updateAll((_, _) => 'PRESENT')) : null,
                          children: [for (final s in students) _studentRow(s, canMark)],
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _header() {
    final section = TimetableApi.map(_data['section']);
    final subject = TimetableApi.map(_data['subject']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${section['className']} ${section['name']}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.xs),
      Text(
        '${niceDate(widget.date)} · ${_data['startTime']}–${_data['endTime']}${subject['name'] != null ? ' · ${subject['name']}' : ''}',
        style: const TextStyle(color: AppColors.textMuted),
      ),
      Text(
        '${teacherName(_data['teacher'])}${_data['isSubstitution'] == true ? ' (substitute)' : ''}'
        '${_data['taken'] == true ? ' · taken' : ' · not taken yet'}',
        style: const TextStyle(color: AppColors.textMuted),
      ),
    ]);
  }

  Widget _studentRow(Map<String, dynamic> s, bool canMark) {
    final id = s['studentId'] as String;
    final status = _status[id] ?? 'PRESENT';
    final roll = s['rollNo'] != null ? '${s['rollNo']}. ' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Row(children: [
        Expanded(child: Text('$roll${s['name']}', overflow: TextOverflow.ellipsis)),
        const SizedBox(width: AppSpacing.sm),
        if (canMark)
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            segments: [for (final c in _choices.entries) ButtonSegment(value: c.key, label: Text(c.value), tooltip: c.key)],
            selected: {_choices.containsKey(status) ? status : 'PRESENT'},
            onSelectionChanged: (v) => setState(() => _status[id] = v.first),
          )
        else
          Text(s['status'] == null ? '—' : (s['status'] as String), style: TextStyle(color: s['status'] == 'ABSENT' ? AppColors.error : AppColors.textMedium)),
      ]),
    );
  }
}
