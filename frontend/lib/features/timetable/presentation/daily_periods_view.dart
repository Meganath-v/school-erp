import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../ai_exam/presentation/widgets/ai_widgets.dart' show Pill;
import '../../outcomes/presentation/outcomes_screen.dart' show showApiError, showDone;
import '../data/timetable_api.dart';
import 'period_attendance_screen.dart';
import 'schedule_widgets.dart';

/// A section's periods on one date. The class teacher (or office) can give a period to another
/// teacher for that day; only the teacher shown for the period can take its attendance.
class DailyPeriodsView extends StatefulWidget {
  final TimetableApi api;
  final String sectionId;
  final bool officeView;
  const DailyPeriodsView({super.key, required this.api, required this.sectionId, this.officeView = false});

  @override
  State<DailyPeriodsView> createState() => _DailyPeriodsViewState();
}

class _DailyPeriodsViewState extends State<DailyPeriodsView> {
  bool _loading = true;
  String? _error;
  String _date = dateText(DateTime.now());
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>>? _subjects;
  bool _saving = false;

  Future<void> _run(Future<Map<String, dynamic>> Function() call, String done) async {
    setState(() => _saving = true);
    try {
      final r = await call();
      if (!mounted) return;
      setState(() => _data = r);
      showDone(context, done);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
      final r = await widget.api.daily(widget.sectionId, _date);
      if (!mounted) return;
      setState(() {
        _data = r;
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

  Future<void> _openAttendance(Map<String, dynamic> p) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PeriodAttendanceScreen(api: widget.api, sectionId: widget.sectionId, date: _date, periodNumber: p['periodNumber'] as int),
    ));
    if (mounted) _load();
  }

  Future<void> _substitute(Map<String, dynamic> p) async {
    _subjects ??= TimetableApi.list((await widget.api.classTimetable(widget.sectionId).catchError((_) => <String, dynamic>{}))['subjects']);
    if (!mounted) return;
    final sub = TimetableApi.map(p['substitution']);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SubstituteDialog(
        title: periodTitle(p),
        timetableTeacher: teacherName(p['teacher']),
        subjects: _subjects ?? const [],
        needsSubject: p['subject'] == null,
        teacher: teacherLogin(sub['teacher']),
        reason: sub['reason'] as String? ?? '',
      ),
    );
    if (result == null) return;
    await _run(() => widget.api.substitute(widget.sectionId, {'date': _date, 'periodNumber': p['periodNumber'], ...result}), 'Teacher changed for this day');
  }

  Future<void> _removeSubstitute(Map<String, dynamic> p) =>
      _run(() => widget.api.clearSubstitution(widget.sectionId, _date, p['periodNumber'] as int), 'Back to the timetable teacher');

  void _actions(Map<String, dynamic> p) {
    final canChange = p['canChange'] == true;
    final hasSub = p['substitution'] != null;
    final canTake = p['canTakeAttendance'] == true || (widget.officeView && p['effectiveTeacher'] != null);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(periodTitle(p), style: const TextStyle(fontWeight: FontWeight.w700))),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: Text(canTake ? (p['attendanceTaken'] == true ? 'Open attendance' : 'Take attendance') : 'View attendance'),
            onTap: () {
              Navigator.pop(ctx);
              _openAttendance(p);
            },
          ),
          if (canChange)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(hasSub ? 'Change substitute' : 'Give this period to another teacher'),
              onTap: () {
                Navigator.pop(ctx);
                _substitute(p);
              },
            ),
          if (canChange && hasSub)
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Remove substitute'),
              onTap: () {
                Navigator.pop(ctx);
                _removeSubstitute(p);
              },
            ),
          if (!canChange && p['attendanceTaken'] == true && _data['canEdit'] == true)
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Attendance is taken, so the teacher cannot be changed'),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periods = TimetableApi.list(_data['periods']);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: DateStepper(
          date: _date,
          badge: _data['isToday'] == true ? 'Today' : null,
          onChanged: (d) {
            _date = d;
            _load();
          },
        ),
      ),
      if (_saving) const LinearProgressIndicator(),
      Expanded(
        child: _loading
            ? const LoadingStateView(message: 'Loading periods…')
            : _error != null
                ? ErrorStateView(title: 'Could not load', errorMessage: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                      children: [
                        if (periods.isEmpty)
                          EmptyStateView(
                            icon: Icons.event_busy_outlined,
                            title: 'No periods on ${_data['dayName'] ?? 'this day'}',
                            message: 'The bell schedule has no periods for this day.',
                          )
                        else
                          SectionCard(
                            title: '${_data['dayName']} periods',
                            icon: Icons.view_agenda_outlined,
                            children: [for (final p in periods) _row(p)],
                          ),
                      ],
                    ),
                  ),
      ),
    ]);
  }

  Widget _row(Map<String, dynamic> p) {
    final sub = TimetableApi.map(p['substitution']);
    final subject = TimetableApi.map(p['effectiveSubject'])['name'] as String?;
    final who = teacherName(p['effectiveTeacher']);
    final lines = <String>[
      if (p['effectiveTeacher'] == null) 'Not set in the timetable' else '${subject ?? ''} · $who',
      if (sub.isNotEmpty) 'Instead of ${teacherName(p['teacher']).isEmpty ? 'free period' : teacherName(p['teacher'])}${(sub['reason'] as String?)?.isNotEmpty == true ? ' — ${sub['reason']}' : ''}',
    ];
    return InfoRow(
      icon: sub.isNotEmpty ? Icons.swap_horiz : Icons.schedule,
      title: periodTitle(p),
      subtitle: lines.join('\n'),
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (sub.isNotEmpty) const Pill(label: 'Substitute', color: AppColors.warning),
        if (p['attendanceTaken'] == true) const Pill(label: 'Taken', color: AppColors.success, icon: Icons.check),
        if (p['attendanceTaken'] != true && p['canTakeAttendance'] == true) const Pill(label: 'Take', color: AppColors.primaryAccent),
      ]),
      onTap: _saving ? null : () => _actions(p),
    );
  }
}

/// Another teacher (username or email) takes the period on this day.
class SubstituteDialog extends StatefulWidget {
  final String title;
  final String timetableTeacher;
  final List<Map<String, dynamic>> subjects;
  final bool needsSubject;
  final String teacher;
  final String reason;
  const SubstituteDialog({
    super.key,
    required this.title,
    required this.timetableTeacher,
    required this.subjects,
    required this.needsSubject,
    this.teacher = '',
    this.reason = '',
  });

  @override
  State<SubstituteDialog> createState() => _SubstituteDialogState();
}

class _SubstituteDialogState extends State<SubstituteDialog> {
  late final _teacher = TextEditingController(text: widget.teacher);
  late final _reason = TextEditingController(text: widget.reason);
  String? _subjectId;
  String? _error;

  @override
  void dispose() {
    _teacher.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    if (_teacher.text.trim().isEmpty) return setState(() => _error = 'Enter the teacher’s username or email');
    if (widget.needsSubject && _subjectId == null) return setState(() => _error = 'Choose the subject for this period');
    Navigator.pop(context, {
      'teacher': _teacher.text.trim(),
      if (_subjectId != null) 'subjectId': _subjectId,
      if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change teacher for this day'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (widget.timetableTeacher.isNotEmpty)
              Text('Timetable teacher: ${widget.timetableTeacher}', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _teacher,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Substitute username or email'),
            ),
            if (widget.needsSubject || widget.subjects.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _subjectId,
                isExpanded: true,
                decoration: InputDecoration(labelText: widget.needsSubject ? 'Subject' : 'Subject (if different)'),
                items: [for (final s in widget.subjects) DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String))],
                onChanged: (v) => setState(() => _subjectId = v),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason (optional)', hintText: 'e.g. on leave')),
            if (_error != null) ...[const SizedBox(height: AppSpacing.md), MessageBanner(message: _error!)],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
