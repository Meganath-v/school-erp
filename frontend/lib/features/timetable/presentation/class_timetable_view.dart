import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../outcomes/presentation/outcomes_screen.dart' show showApiError, showDone;
import '../data/timetable_api.dart';
import 'schedule_widgets.dart';

/// A section's weekly timetable. The class teacher (or office) sets, for each period,
/// the subject and the teacher's username or email; that teacher then gets the subject's modules.
class ClassTimetableView extends StatefulWidget {
  final TimetableApi api;
  final String sectionId;
  const ClassTimetableView({super.key, required this.api, required this.sectionId});

  @override
  State<ClassTimetableView> createState() => _ClassTimetableViewState();
}

class _ClassTimetableViewState extends State<ClassTimetableView> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  int? _day;
  bool _saving = false;

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
      final r = await widget.api.classTimetable(widget.sectionId);
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

  void _apply(Map<String, dynamic> r) {
    _data = r;
    final days = _days;
    if (_day == null || !days.contains(_day)) {
      final today = DateTime.now().weekday;
      _day = days.contains(today) ? today : (days.isEmpty ? null : days.first);
    }
  }

  List<Map<String, dynamic>> get _periods => TimetableApi.list(_data['periods']);
  List<Map<String, dynamic>> get _entries => TimetableApi.list(_data['entries']);
  List<Map<String, dynamic>> get _subjects => TimetableApi.list(_data['subjects']);
  bool get _canEdit => _data['canEdit'] == true;
  List<int> get _days => (_periods.map((p) => p['dayOfWeek'] as int).toSet().toList()..sort());

  Map<String, dynamic>? _entryFor(Map<String, dynamic> p) {
    for (final e in _entries) {
      if (e['dayOfWeek'] == p['dayOfWeek'] && e['periodNumber'] == p['periodNumber']) return e;
    }
    return null;
  }

  Future<void> _editSlot(Map<String, dynamic> period) async {
    final entry = _entryFor(period);
    final result = await showDialog<_SlotResult>(
      context: context,
      builder: (_) => SlotDialog(
        title: '${dayNames[period['dayOfWeek']]} · ${periodTitle(period)}',
        subjects: _subjects,
        subjectId: (entry?['subject'] as Map?)?['id'] as String?,
        teacher: teacherLogin(entry?['teacher']),
        canClear: entry != null,
      ),
    );
    if (result == null) return;
    setState(() => _saving = true);
    try {
      final r = result.clear
          ? await widget.api.clearSlot(widget.sectionId, period['dayOfWeek'] as int, period['periodNumber'] as int)
          : await widget.api.setSlot(widget.sectionId, {
              'dayOfWeek': period['dayOfWeek'],
              'periodNumber': period['periodNumber'],
              'subjectId': result.subjectId,
              'teacher': result.teacher,
            });
      if (!mounted) return;
      setState(() => _apply(r));
      showDone(context, result.clear ? 'Period cleared' : 'Period saved');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingStateView(message: 'Loading timetable…');
    if (_error != null) return ErrorStateView(title: 'Could not load the timetable', errorMessage: _error!, onRetry: _load);
    final section = TimetableApi.map(_data['section']);
    final days = _days;
    final filled = _entries.where((e) => e['outsideSchedule'] != true).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (_saving) const Padding(padding: EdgeInsets.only(bottom: AppSpacing.sm), child: LinearProgressIndicator()),
          Text('${section['className']} ${section['name']}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text('$filled of ${_periods.length} periods filled', style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.md),
          if (_canEdit)
            const MessageBanner(
              message: 'Tap a period to set its subject and teacher. The teacher gets access to that subject’s modules.',
              isError: false,
            ),
          if (days.isEmpty)
            const EmptyStateView(
              icon: Icons.schedule_outlined,
              title: 'No periods yet',
              message: 'The office has not set the periods of the school day yet.',
            )
          else ...[
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final d in days)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(dayShort[d] ?? '$d'),
                      selected: _day == d,
                      onSelected: (_) => setState(() => _day = d),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: dayNames[_day] ?? '',
              icon: Icons.view_agenda_outlined,
              children: [
                for (final p in _periods.where((p) => p['dayOfWeek'] == _day))
                  Builder(builder: (_) {
                    final e = _entryFor(p);
                    final subject = (e?['subject'] as Map?)?['name'] as String?;
                    return InfoRow(
                      icon: e == null ? Icons.radio_button_unchecked : Icons.check_circle_outline,
                      title: periodTitle(p),
                      subtitle: e == null ? 'Not set' : '$subject · ${teacherName(e['teacher'])}',
                      trailing: _canEdit ? const Icon(Icons.edit_outlined, size: 20) : null,
                      onTap: _canEdit && !_saving ? () => _editSlot(p) : null,
                    );
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SlotResult {
  final bool clear;
  final String? subjectId;
  final String? teacher;
  const _SlotResult.save(this.subjectId, this.teacher) : clear = false;
  const _SlotResult.clear()
      : clear = true,
        subjectId = null,
        teacher = null;
}

/// Subject + teacher (username or email) for one period.
class SlotDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> subjects;
  final String? subjectId;
  final String teacher;
  final bool canClear;
  const SlotDialog({super.key, required this.title, required this.subjects, this.subjectId, this.teacher = '', this.canClear = false});

  @override
  State<SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<SlotDialog> {
  late String? _subjectId = widget.subjects.any((s) => s['id'] == widget.subjectId) ? widget.subjectId : null;
  late final _teacher = TextEditingController(text: widget.teacher);
  String? _error;

  @override
  void dispose() {
    _teacher.dispose();
    super.dispose();
  }

  void _save() {
    if (_subjectId == null) return setState(() => _error = 'Choose a subject');
    if (_teacher.text.trim().isEmpty) return setState(() => _error = 'Enter the teacher’s username or email');
    Navigator.pop(context, _SlotResult.save(_subjectId, _teacher.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              initialValue: _subjectId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [for (final s in widget.subjects) DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String))],
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _teacher,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Teacher username or email', hintText: 'e.g. teacher.jones@school.edu'),
            ),
            if (_error != null) ...[const SizedBox(height: AppSpacing.md), MessageBanner(message: _error!)],
          ]),
        ),
      ),
      actions: [
        if (widget.canClear)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, const _SlotResult.clear()),
            child: const Text('Clear'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
