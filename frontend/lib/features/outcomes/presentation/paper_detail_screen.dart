import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../data/outcomes_api.dart';
import 'outcomes_screen.dart';

/// Question paper builder and question-wise marks entry for one exam subject or assignment.
class PaperDetailScreen extends StatefulWidget {
  final Map<String, dynamic> assessment; // from /outcomes/subjects/:id/assessments
  final Map<String, dynamic> subject;
  const PaperDetailScreen({super.key, required this.assessment, required this.subject});

  @override
  State<PaperDetailScreen> createState() => _PaperDetailScreenState();
}

class _PaperDetailScreenState extends State<PaperDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.assessment['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(tabs: [Tab(text: 'Question paper'), Tab(text: 'Marks entry')]),
        ),
        body: TabBarView(children: [
          _PaperBuilder(assessment: widget.assessment, subject: widget.subject),
          _MarksEntry(assessment: widget.assessment, canEdit: widget.subject['canEdit'] == true),
        ]),
      ),
    );
  }
}

// ======================================================================== paper builder

class _Item {
  String questionId;
  String label;
  double marks;
  String text;
  String? coCode;
  String bloom;
  _Item({required this.questionId, required this.label, required this.marks, required this.text, this.coCode, required this.bloom});
}

class _Section {
  String title;
  final List<_Item> items;
  _Section(this.title, [List<_Item>? items]) : items = items ?? [];
}

class _PaperBuilder extends StatefulWidget {
  final Map<String, dynamic> assessment;
  final Map<String, dynamic> subject;
  const _PaperBuilder({required this.assessment, required this.subject});

  @override
  State<_PaperBuilder> createState() => _PaperBuilderState();
}

class _PaperBuilderState extends State<_PaperBuilder> with AutomaticKeepAliveClientMixin {
  final _api = OutcomesApi();
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _exists = false;
  String? _error;
  final _title = TextEditingController();
  final _duration = TextEditingController();
  List<_Section> _sections = [];
  List<Map<String, dynamic>> _bank = [];

  String get _kind => widget.assessment['kind'] as String;
  String get _id => widget.assessment['id'] as String;
  bool get _canEdit => widget.subject['canEdit'] == true;
  num get _max => widget.assessment['maxMarks'] as num;
  double get _total => _sections.fold(0.0, (s, sec) => s + sec.items.fold(0.0, (a, i) => a + i.marks));

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([_api.paper(_kind, _id), _api.questions(widget.subject['id'] as String)]);
      final data = r[0] as Map<String, dynamic>;
      final paper = data['paper'] as Map?;
      if (!mounted) return;
      setState(() {
        _bank = r[1] as List<Map<String, dynamic>>;
        _exists = paper != null;
        _title.text = paper?['title'] ?? '${widget.assessment['title']}';
        _duration.text = paper?['durationMinutes']?.toString() ?? '';
        _sections = paper == null
            ? [_Section('Part A')]
            : [
                for (final s in (paper['sections'] as List))
                  _Section('${s['title']}', [
                    for (final i in (s['items'] as List))
                      _Item(
                        questionId: i['question']['id'],
                        label: '${i['label']}',
                        marks: (i['marks'] as num).toDouble(),
                        text: '${i['question']['text']}',
                        coCode: i['question']['courseOutcome']?['code'],
                        bloom: '${i['question']['bloomLevel']}',
                      ),
                  ]),
              ];
        _dirty = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  void _changed(VoidCallback fn) => setState(() {
        fn();
        _dirty = true;
      });

  String _nextLabel() => '${_sections.fold<int>(0, (n, s) => n + s.items.length) + 1}';

  Future<void> _addQuestion(_Section section) async {
    final used = {for (final s in _sections) ...s.items.map((i) => i.questionId)};
    final available = _bank.where((q) => !used.contains(q['id'])).toList();
    if (available.isEmpty) {
      showDone(context, _bank.isEmpty ? 'The question bank is empty. Add questions first.' : 'Every bank question is already in this paper.');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: ListView(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Text('Add a question from the bank', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ),
          for (final q in available)
            ListTile(
              title: Text('${q['text']}', maxLines: 3, overflow: TextOverflow.ellipsis),
              subtitle: Text('${formatLevel(q['marks'] as num)} marks · ${q['courseOutcome']?['code'] ?? 'No CO'} · ${bloomLabel(q['bloomLevel'])}'),
              onTap: () => Navigator.pop(ctx, q),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    _changed(() => section.items.add(_Item(
          questionId: picked['id'],
          label: _nextLabel(),
          marks: (picked['marks'] as num).toDouble(),
          text: '${picked['text']}',
          coCode: picked['courseOutcome']?['code'],
          bloom: '${picked['bloomLevel']}',
        )));
  }

  Future<void> _editItem(_Item item) async {
    final formKey = GlobalKey<FormState>();
    final label = TextEditingController(text: item.label);
    final marks = TextEditingController(text: formatLevel(item.marks));
    await showFormDialog(
      context,
      title: 'Question ${item.label}',
      formKey: formKey,
      fields: (_) => [
        Text(item.text, maxLines: 4, overflow: TextOverflow.ellipsis),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: label, decoration: const InputDecoration(labelText: 'Label', hintText: 'e.g. 1a'), validator: requiredText),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: marks,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Marks in this paper'),
          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter marks greater than 0' : null,
        ),
      ],
      onSubmit: () async {
        _changed(() {
          item.label = label.text.trim();
          item.marks = double.parse(marks.text);
        });
        return null;
      },
      submitLabel: 'Apply',
    );
  }

  Future<void> _renameSection(_Section s) async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController(text: s.title);
    await showFormDialog(
      context,
      title: 'Section title',
      formKey: formKey,
      fields: (_) => [TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Title'), validator: requiredText)],
      onSubmit: () async {
        _changed(() => s.title = title.text.trim());
        return null;
      },
      submitLabel: 'Apply',
    );
  }

  Future<void> _save() async {
    if (_total > _max) {
      showDone(context, 'The paper totals ${formatLevel(_total)} marks; the maximum is $_max.');
      return;
    }
    if (_sections.every((s) => s.items.isEmpty)) {
      showDone(context, 'Add at least one question.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.savePaper(_kind, _id, {
        'title': _title.text.trim().isEmpty ? '${widget.assessment['title']}' : _title.text.trim(),
        if (int.tryParse(_duration.text) != null) 'durationMinutes': int.parse(_duration.text),
        'sections': [
          for (final s in _sections.where((s) => s.items.isNotEmpty))
            {
              'title': s.title,
              'items': [for (final i in s.items) {'questionId': i.questionId, 'label': i.label, 'marks': i.marks}],
            },
        ],
      });
      if (!mounted) return;
      showDone(context, 'Question paper saved');
      await _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const LoadingStateView(message: 'Loading question paper...');
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: _error!, onRetry: _load)]);
    }
    final text = Theme.of(context).textTheme;
    final over = _total > _max;

    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (!_canEdit)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: MessageBanner(isError: false, message: 'View only: you do not teach this subject.'),
              ),
            TextField(controller: _title, enabled: _canEdit, decoration: const InputDecoration(labelText: 'Paper title'), onChanged: (_) => _dirty = true),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _duration,
              enabled: _canEdit,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Duration (minutes, optional)'),
              onChanged: (_) => _dirty = true,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final s in _sections) ...[
              SectionCard(
                title: s.title,
                icon: Icons.segment,
                actionLabel: _canEdit ? 'Rename' : null,
                onAction: _canEdit ? () => _renameSection(s) : null,
                empty: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('No questions in this section.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ),
                children: [
                  for (final i in s.items)
                    InfoRow(
                      title: 'Q${i.label} · ${formatLevel(i.marks)} marks',
                      subtitle: '${i.text}\n${i.coCode ?? 'No CO'} · ${bloomLabel(i.bloom)}',
                      onTap: _canEdit ? () => _editItem(i) : null,
                      trailing: _canEdit
                          ? IconButton(
                              tooltip: 'Remove question',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _changed(() => s.items.remove(i)),
                            )
                          : null,
                    ),
                  if (_canEdit)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(onPressed: () => _addQuestion(s), icon: const Icon(Icons.add), label: const Text('Add question')),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_canEdit)
              OutlinedButton.icon(
                onPressed: () => _changed(() => _sections.add(_Section('Part ${String.fromCharCode(65 + _sections.length)}'))),
                icon: const Icon(Icons.add),
                label: const Text('Add section'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
          ],
        ),
      ),
      Material(
        elevation: 8,
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(children: [
              Expanded(
                child: Text(
                  'Total ${formatLevel(_total)} / $_max marks',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: over ? AppColors.error : AppColors.textDark),
                ),
              ),
              if (_canEdit)
                FilledButton(
                  onPressed: _saving || (!_dirty && _exists) ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_exists ? (_dirty ? 'Save changes' : 'Saved') : 'Create paper'),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ======================================================================== marks entry

class _MarksEntry extends StatefulWidget {
  final Map<String, dynamic> assessment;
  final bool canEdit;
  const _MarksEntry({required this.assessment, required this.canEdit});

  @override
  State<_MarksEntry> createState() => _MarksEntryState();
}

class _MarksEntryState extends State<_MarksEntry> with AutomaticKeepAliveClientMixin {
  final _api = OutcomesApi();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  String get _kind => widget.assessment['kind'] as String;
  String get _id => widget.assessment['id'] as String;

  @override
  bool get wantKeepAlive => true;

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
      final d = await _api.marks(_kind, _id);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  Future<void> _openStudent(int index) async {
    final students = (_data!['students'] as List).cast<Map>();
    final items = (_data!['items'] as List).cast<Map>();
    var i = index;
    while (mounted) {
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _StudentMarksSheet(
          student: Map<String, dynamic>.from(students[i]),
          items: items.map((m) => Map<String, dynamic>.from(m)).toList(),
          canEdit: widget.canEdit,
          hasNext: i < students.length - 1,
          onSave: (entries) async {
            final updated = await _api.saveMarks(_kind, _id, entries);
            if (mounted) setState(() => _data = updated);
          },
        ),
      );
      if (result == 'next' && i < students.length - 1) {
        i++;
        continue;
      }
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const LoadingStateView(message: 'Loading marks...');
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: _error!, onRetry: _load)]);
    }
    final d = _data!;
    final items = (d['items'] as List).cast<Map>();
    final students = (d['students'] as List).cast<Map>();
    final paperMax = items.fold<double>(0, (s, i) => s + (i['marks'] as num).toDouble());
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
        children: [
          Text('${items.length} questions · ${formatLevel(paperMax)} marks · ${students.length} students',
              style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          if (students.isEmpty)
            const EmptyStateView(icon: Icons.groups_outlined, title: 'No students', message: 'No active students are enrolled for this assessment.')
          else
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.xlBorderRadius, border: Border.all(color: AppColors.border)),
              child: Column(children: [
                for (var idx = 0; idx < students.length; idx++) ...[
                  if (idx > 0) const Divider(height: 1),
                  _studentRow(students[idx], items.length, paperMax, idx),
                ],
              ]),
            ),
        ],
      ),
    );
  }

  Widget _studentRow(Map s, int itemCount, double paperMax, int idx) {
    final entered = (s['marks'] as Map).length;
    final done = entered == itemCount && itemCount > 0;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: () => _openStudent(idx),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryAccentSubtle,
          child: Text('${s['rollNo'] ?? idx + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryAccent)),
        ),
        title: Text('${s['name']}'),
        subtitle: Text('${s['admissionNo'] ?? ''} · $entered/$itemCount questions'),
        trailing: Text(
          s['total'] == null ? '—' : '${formatLevel(s['total'] as num)}/${formatLevel(paperMax)}',
          style: TextStyle(fontWeight: FontWeight.w700, color: done ? AppColors.success : AppColors.textDark),
        ),
      ),
    );
  }
}

class _StudentMarksSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final List<Map<String, dynamic>> items;
  final bool canEdit;
  final bool hasNext;
  final Future<void> Function(List<Map<String, dynamic>> entries) onSave;
  const _StudentMarksSheet({required this.student, required this.items, required this.canEdit, required this.hasNext, required this.onSave});

  @override
  State<_StudentMarksSheet> createState() => _StudentMarksSheetState();
}

class _StudentMarksSheetState extends State<_StudentMarksSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctl = {
    for (final i in widget.items)
      i['id'] as String: TextEditingController(
        text: (widget.student['marks'] as Map)[i['id']] == null ? '' : formatLevel((widget.student['marks'] as Map)[i['id']] as num),
      ),
  };
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(String then) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave([
        for (final i in widget.items)
          {
            'studentId': widget.student['studentId'],
            'itemId': i['id'],
            'marks': _ctl[i['id']]!.text.trim().isEmpty ? null : double.parse(_ctl[i['id']]!.text.trim()),
          },
      ]);
      if (mounted) Navigator.pop(context, then);
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              children: [
                Text('${widget.student['name']}', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text('Roll ${widget.student['rollNo'] ?? '—'} · ${widget.student['admissionNo'] ?? ''}',
                    style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.lg),
                for (final i in widget.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: TextFormField(
                      controller: _ctl[i['id']],
                      enabled: widget.canEdit && !_saving,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Q${i['label']} · ${i['courseOutcome']?['code'] ?? 'No CO'}',
                        suffixText: '/ ${formatLevel(i['marks'] as num)}',
                        helperText: '${i['section']}',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null; // blank = not marked
                        final n = double.tryParse(v.trim());
                        if (n == null || n < 0) return 'Enter a number';
                        if (n > (i['marks'] as num)) return 'Max ${formatLevel(i['marks'] as num)}';
                        return null;
                      },
                    ),
                  ),
                if (_error != null) ...[MessageBanner(message: _error!), const SizedBox(height: AppSpacing.md)],
                if (widget.canEdit)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save('close'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        child: const Text('Save'),
                      ),
                    ),
                    if (widget.hasNext) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : () => _save('next'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          child: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save & next'),
                        ),
                      ),
                    ],
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
