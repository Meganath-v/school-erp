import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/ai_exam_api.dart';
import '../widgets/ai_widgets.dart';

/// Create or edit a test's details and assignment. Pops with the saved test.
class TestEditorScreen extends StatefulWidget {
  final AiExamApi api;
  final Map<String, dynamic>? test;
  const TestEditorScreen({super.key, required this.api, this.test});

  @override
  State<TestEditorScreen> createState() => _TestEditorScreenState();
}

class _TestEditorScreenState extends State<TestEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.test?['title'] ?? '');
  late final _chapter = TextEditingController(text: widget.test?['chapter'] ?? '');
  late final _topics = TextEditingController(text: ((widget.test?['topics'] as List?) ?? const []).join(', '));
  late final _description = TextEditingController(text: widget.test?['description'] ?? '');
  late final _instructions = TextEditingController(text: widget.test?['instructions'] ?? '');
  late final _duration = TextEditingController(text: widget.test?['durationMinutes']?.toString() ?? '30');
  Map<String, dynamic>? _options;
  String? _error;
  bool _saving = false;
  String? _yearId;
  String? _classId;
  String? _subjectId;
  String? _sectionId;
  late String _mode = widget.test?['assignMode'] as String? ?? 'SECTION';
  late DateTime? _startsAt = DateTime.tryParse('${widget.test?['startsAt']}')?.toLocal();
  late DateTime? _endsAt = DateTime.tryParse('${widget.test?['endsAt']}')?.toLocal();
  late bool _autoSubmit = widget.test?['autoSubmit'] as bool? ?? true;
  late final Set<String> _students = {for (final a in AiExamApi.list(widget.test?['assignees'])) a['id'] as String};
  List<Map<String, dynamic>> _candidates = [];

  bool get _editing => widget.test != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await widget.api.options();
      if (!mounted) return;
      final t = widget.test;
      setState(() {
        _options = o;
        final years = AiExamApi.list(o['academicYears']);
        _yearId = t?['academicYear']?['id'] as String? ?? years.where((y) => y['isCurrent'] == true).map((y) => y['id'] as String).firstOrNull;
        final classes = AiExamApi.list(o['classes']);
        _classId = t?['class']?['id'] as String? ?? (classes.isNotEmpty ? classes.first['id'] as String : null);
        _subjectId = t?['subject']?['id'] as String?;
        _sectionId = t?['section']?['id'] as String?;
        _fixSelection();
      });
      if (_mode == 'STUDENTS') _loadCandidates();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    }
  }

  List<Map<String, dynamic>> get _classes => AiExamApi.list(_options?['classes']);
  Map<String, dynamic>? get _class => _classes.where((c) => c['id'] == _classId).firstOrNull;
  List<Map<String, dynamic>> get _subjects => AiExamApi.list(_class?['subjects']);
  Map<String, dynamic>? get _subject => _subjects.where((s) => s['id'] == _subjectId).firstOrNull;
  List<Map<String, dynamic>> get _sections => AiExamApi.list(_subject?['sections']);

  void _fixSelection() {
    if (_subject == null) _subjectId = _subjects.isNotEmpty ? _subjects.first['id'] as String : null;
    if (!_sections.any((s) => s['id'] == _sectionId)) _sectionId = _sections.isNotEmpty ? _sections.first['id'] as String : null;
    if (_mode == 'CLASS' && _subject?['wholeClass'] != true) _mode = 'SECTION';
  }

  Future<void> _loadCandidates() async {
    if (_classId == null) return;
    try {
      final c = await widget.api.candidates(_classId!, sectionId: _sectionId);
      if (mounted) setState(() => _candidates = c);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    }
  }

  Future<DateTime?> _pick(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: initial ?? now, firstDate: now.subtract(const Duration(days: 30)), lastDate: now.add(const Duration(days: 400)));
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_classId == null || _subjectId == null) return setState(() => _error = 'Choose a class and subject.');
    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) return setState(() => _error = 'The test must end after it starts.');
    if (_mode == 'STUDENTS' && _students.isEmpty) return setState(() => _error = 'Choose at least one student.');
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'title': _title.text.trim(),
      'academicYearId': _yearId,
      'classId': _classId,
      'subjectId': _subjectId,
      'assignMode': _mode,
      'sectionId': _mode == 'CLASS' ? null : _sectionId,
      if (_mode == 'STUDENTS') 'studentIds': _students.toList(),
      'chapter': _chapter.text.trim(),
      'topics': _topics.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      'description': _description.text.trim(),
      'instructions': _instructions.text.trim(),
      'durationMinutes': int.tryParse(_duration.text.trim()),
      'startsAt': _startsAt?.toUtc().toIso8601String(),
      'endsAt': _endsAt?.toUtc().toIso8601String(),
      'autoSubmit': _autoSubmit,
    };
    try {
      final saved = _editing ? await widget.api.updateTest(widget.test!['id'] as String, body) : await widget.api.createTest(body);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit test' : 'New test')),
      body: _options == null
          ? (_error != null ? ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: _error!, onRetry: _load)]) : const LoadingStateView(message: 'Loading your classes...'))
          : _classes.isEmpty
              ? const EmptyStateView(
                  icon: Icons.school_outlined,
                  title: 'No eligible class',
                  message: 'AI Examination is for Classes 10, 11 and 12. You need a subject assignment in one of those classes to create tests.',
                )
              : Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
                    TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Test title'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
                    const SectionTitle('Class and subject'),
                    DropdownButtonFormField<String>(
                      initialValue: _yearId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Academic year'),
                      items: [for (final y in AiExamApi.list(_options!['academicYears'])) DropdownMenuItem(value: y['id'] as String, child: Text('${y['name']}${y['isCurrent'] == true ? ' (current)' : ''}'))],
                      onChanged: (v) => setState(() => _yearId = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      key: ValueKey('class-$_classId'),
                      initialValue: _classId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Class'),
                      items: [for (final c in _classes) DropdownMenuItem(value: c['id'] as String, child: Text('${c['name']}'))],
                      onChanged: (v) => setState(() {
                        _classId = v;
                        _subjectId = null;
                        _students.clear();
                        _fixSelection();
                        if (_mode == 'STUDENTS') _loadCandidates();
                      }),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      key: ValueKey('subject-$_classId-$_subjectId'),
                      initialValue: _subjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      items: [for (final s in _subjects) DropdownMenuItem(value: s['id'] as String, child: Text('${s['name']} (${s['code']})', overflow: TextOverflow.ellipsis))],
                      onChanged: (v) => setState(() {
                        _subjectId = v;
                        _fixSelection();
                      }),
                    ),
                    const SectionTitle('Assign to'),
                    SegmentedButton<String>(
                      segments: [
                        const ButtonSegment(value: 'SECTION', label: Text('Section')),
                        if (_subject?['wholeClass'] == true) const ButtonSegment(value: 'CLASS', label: Text('Whole class')),
                        const ButtonSegment(value: 'STUDENTS', label: Text('Students')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => setState(() {
                        _mode = s.first;
                        if (_mode == 'STUDENTS') _loadCandidates();
                      }),
                    ),
                    if (_mode != 'CLASS') ...[
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        key: ValueKey('section-$_subjectId-$_sectionId'),
                        initialValue: _sectionId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Section'),
                        items: [for (final s in _sections) DropdownMenuItem(value: s['id'] as String, child: Text('${s['name']}'))],
                        onChanged: (v) => setState(() {
                          _sectionId = v;
                          _students.clear();
                          if (_mode == 'STUDENTS') _loadCandidates();
                        }),
                      ),
                    ],
                    if (_mode == 'STUDENTS') ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text('${_students.length} selected', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                      for (final c in _candidates)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _students.contains(c['id']),
                          title: Text('${c['name']}'),
                          subtitle: Text('${c['admissionNo']} · ${c['section']}'),
                          onChanged: (v) => setState(() => v == true ? _students.add(c['id'] as String) : _students.remove(c['id'])),
                        ),
                    ],
                    const SectionTitle('Content'),
                    TextFormField(controller: _chapter, decoration: const InputDecoration(labelText: 'Chapter')),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(controller: _topics, decoration: const InputDecoration(labelText: 'Topics covered', helperText: 'Separate topics with commas')),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)')),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(controller: _instructions, maxLines: 4, decoration: const InputDecoration(labelText: 'Instructions for students')),
                    const SectionTitle('Schedule'),
                    TextFormField(
                      controller: _duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration in minutes', helperText: 'Leave empty for no time limit'),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) return null;
                        final n = int.tryParse(v!.trim());
                        return n == null || n < 1 || n > 600 ? 'Between 1 and 600' : null;
                      },
                    ),
                    _dateTile('Starts', _startsAt, 'As soon as it is published', (d) => setState(() => _startsAt = d)),
                    _dateTile('Ends', _endsAt, 'When you close it', (d) => setState(() => _endsAt = d)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _autoSubmit,
                      title: const Text('Submit automatically when time runs out'),
                      subtitle: const Text('Saved answers are submitted for the student'),
                      onChanged: (v) => setState(() => _autoSubmit = v),
                    ),
                    if (_error != null) ...[const SizedBox(height: AppSpacing.md), MessageBanner(message: _error!)],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_editing ? 'Save changes' : 'Create and add questions'),
                    ),
                  ]),
                ),
    );
  }

  Widget _dateTile(String label, DateTime? value, String empty, ValueChanged<DateTime?> set) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(label == 'Starts' ? Icons.event_available_outlined : Icons.event_busy_outlined),
      title: Text(label),
      subtitle: Text(value == null ? empty : fmtDate(value.toIso8601String())),
      trailing: value == null ? null : IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: () => set(null)),
      onTap: () async {
        final d = await _pick(value);
        if (d != null) set(d);
      },
    );
  }
}
