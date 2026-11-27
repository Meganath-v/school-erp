import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/ai_exam_api.dart';
import '../widgets/ai_widgets.dart';

List<String> _lines(String s) => s.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
List<String> _commas(String s) => s.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

/// Edits all questions of a test (saved together). Pops true after saving.
class QuestionsEditorScreen extends StatefulWidget {
  final AiExamApi api;
  final Map<String, dynamic> test;
  const QuestionsEditorScreen({super.key, required this.api, required this.test});

  @override
  State<QuestionsEditorScreen> createState() => _QuestionsEditorScreenState();
}

class _QuestionsEditorScreenState extends State<QuestionsEditorScreen> {
  late final List<Map<String, dynamic>> _questions = [
    for (final q in AiExamApi.list(widget.test['questions']))
      {
        'type': q['type'],
        'text': q['text'],
        'imageUrl': q['imageUrl'],
        'marks': q['marks'],
        'chapter': q['chapter'],
        'topic': q['topic'],
        'difficulty': q['difficulty'],
        'options': q['options'],
        'correctOption': q['correctOption'],
        'answerKey': q['answerKey'],
        'acceptableAnswers': q['acceptableAnswers'],
        'keywords': q['keywords'],
        'concepts': q['concepts'],
        'explanation': q['explanation'],
        'partialCredit': q['partialCredit'],
        'tolerance': q['tolerance'],
        'rubric': q['rubric'],
      },
  ];
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  double get _total => _questions.fold<double>(0, (s, q) => s + ((q['marks'] as num?) ?? 0).toDouble());

  Future<void> _edit([int? index]) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(
      builder: (_) => QuestionFormScreen(api: widget.api, question: index == null ? null : _questions[index], defaultChapter: widget.test['chapter'] as String?, topics: ((widget.test['topics'] as List?) ?? const []).cast<String>()),
    ));
    if (result == null) return;
    setState(() {
      index == null ? _questions.add(result) : _questions[index] = result;
      _dirty = true;
    });
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _questions.length) return;
    setState(() {
      final q = _questions.removeAt(i);
      _questions.insert(j, q);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.saveQuestions(widget.test['id'] as String, _questions);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorMessage(e);
        });
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your question changes have not been saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Questions')),
        floatingActionButton: FloatingActionButton.extended(heroTag: 'fab-ai-q', onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Question')),
        body: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120), children: [
          Text('${widget.test['title']}', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${_questions.length} questions · ${fmtNum(_total)} marks', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.md),
          if (_questions.isEmpty)
            const EmptyStateView(icon: Icons.quiz_outlined, title: 'No questions yet', message: 'Add questions with answer keys. For descriptive answers, a marking rubric tells the evaluator how to award marks.'),
          for (final (i, q) in _questions.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SectionCard(
                title: 'Q${i + 1} · ${questionTypeLabels[q['type']] ?? q['type']} · ${fmtNum(q['marks'] as num?)} marks',
                icon: Icons.help_outline,
                actionLabel: 'Edit',
                onAction: () => _edit(i),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 0),
                    child: Text('${q['text']}', maxLines: 4, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
                    child: Row(children: [
                      Expanded(
                        child: Wrap(spacing: 6, runSpacing: 4, children: [
                          if ((q['topic'] ?? '').toString().isNotEmpty) Pill(label: '${q['topic']}', color: AppColors.info),
                          Pill(label: '${q['difficulty'] ?? 'MEDIUM'}'.toLowerCase(), color: AppColors.textMuted),
                          if (((q['rubric'] as List?) ?? const []).isNotEmpty) Pill(label: '${(q['rubric'] as List).length} rubric criteria', color: AppColors.success),
                          if (q['imageUrl'] != null) const Pill(label: 'image', color: AppColors.textMuted, icon: Icons.image_outlined),
                        ]),
                      ),
                      IconButton(tooltip: 'Move up', icon: const Icon(Icons.arrow_upward), onPressed: i == 0 ? null : () => _move(i, -1)),
                      IconButton(tooltip: 'Move down', icon: const Icon(Icons.arrow_downward), onPressed: i == _questions.length - 1 ? null : () => _move(i, 1)),
                      IconButton(
                        tooltip: 'Remove question',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() {
                          _questions.removeAt(i);
                          _dirty = true;
                        }),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          if (_error != null) ...[MessageBanner(message: _error!), const SizedBox(height: AppSpacing.md)],
          FilledButton(
            onPressed: _saving || _questions.isEmpty ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Save ${_questions.length} questions'),
          ),
        ]),
      ),
    );
  }
}

// ======================================================================== one question

class QuestionFormScreen extends StatefulWidget {
  final AiExamApi api;
  final Map<String, dynamic>? question;
  final String? defaultChapter;
  final List<String> topics;
  const QuestionFormScreen({super.key, required this.api, this.question, this.defaultChapter, this.topics = const []});

  @override
  State<QuestionFormScreen> createState() => _QuestionFormScreenState();
}

class _QuestionFormScreenState extends State<QuestionFormScreen> {
  final _form = GlobalKey<FormState>();
  Map<String, dynamic> get q => widget.question ?? const {};
  late String _type = q['type'] as String? ?? 'SHORT';
  late String _difficulty = q['difficulty'] as String? ?? 'MEDIUM';
  late final _text = TextEditingController(text: q['text'] as String? ?? '');
  late final _marks = TextEditingController(text: q['marks'] == null ? '' : fmtNum(q['marks'] as num));
  late final _chapter = TextEditingController(text: q['chapter'] as String? ?? widget.defaultChapter ?? '');
  late final _topic = TextEditingController(text: q['topic'] as String? ?? (widget.topics.length == 1 ? widget.topics.first : ''));
  late final _answerKey = TextEditingController(text: q['answerKey'] as String? ?? '');
  late final _acceptable = TextEditingController(text: ((q['acceptableAnswers'] as List?) ?? const []).join('\n'));
  late final _keywords = TextEditingController(text: ((q['keywords'] as List?) ?? const []).join(', '));
  late final _concepts = TextEditingController(text: ((q['concepts'] as List?) ?? const []).join('\n'));
  late final _explanation = TextEditingController(text: q['explanation'] as String? ?? '');
  late final _partial = TextEditingController(text: q['partialCredit'] as String? ?? '');
  late final _tolerance = TextEditingController(text: q['tolerance'] == null ? '' : fmtNum(q['tolerance'] as num));
  late final List<TextEditingController> _options = [
    for (final o in ((q['options'] as List?) ?? const ['', '', '', ''])) TextEditingController(text: '$o'),
  ];
  late int _correct = q['correctOption'] as int? ?? (_type == 'TRUE_FALSE' ? 1 : 0);
  late final List<(TextEditingController, TextEditingController)> _rubric = [
    for (final r in AiExamApi.list(q['rubric'])) (TextEditingController(text: '${r['description']}'), TextEditingController(text: fmtNum(r['marks'] as num))),
  ];
  late String? _imageUrl = q['imageUrl'] as String?;
  bool _uploading = false;
  String? _error;

  bool get _descriptive => _type == 'SHORT' || _type == 'LONG';
  double get _rubricTotal => _rubric.fold<double>(0, (s, r) => s + (double.tryParse(r.$2.text) ?? 0));

  Future<void> _pickImage() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) return setState(() => _error = 'Image must be smaller than 5 MB.');
      final name = f.name.toLowerCase();
      if (!RegExp(r'\.(png|jpe?g)$').hasMatch(name)) return setState(() => _error = 'Use a PNG or JPEG image.');
      setState(() => _uploading = true);
      final url = await widget.api.uploadImage(bytes, f.name);
      if (mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Errors show at the bottom of the form and as a snackbar (the form may be scrolled).
  void _fail(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _done() {
    if (!_form.currentState!.validate()) return _fail('Some fields need attention.');
    final marks = double.parse(_marks.text);
    if (_rubric.isNotEmpty && (_rubricTotal - marks).abs() > 0.01) {
      return _fail('Rubric criteria add up to ${fmtNum(_rubricTotal)}; the question is worth ${fmtNum(marks)}.');
    }
    if (_descriptive && _answerKey.text.trim().isEmpty && _rubric.isEmpty) return _fail('Add a model answer or a marking rubric.');
    final opts = _options.map((c) => c.text.trim()).toList();
    if (_type == 'MCQ') {
      while (opts.isNotEmpty && opts.last.isEmpty) {
        opts.removeLast();
      }
      if (opts.length < 2 || opts.any((o) => o.isEmpty)) return _fail('Fill in at least two options without gaps.');
      if (_correct >= opts.length) return _fail('Choose the correct option.');
    }
    Navigator.pop(context, {
      'type': _type,
      'text': _text.text.trim(),
      'imageUrl': _imageUrl,
      'marks': marks,
      'chapter': _chapter.text.trim(),
      'topic': _topic.text.trim(),
      'difficulty': _difficulty,
      if (_type == 'MCQ') 'options': opts,
      if (_type == 'MCQ' || _type == 'TRUE_FALSE') 'correctOption': _correct,
      if (_type != 'MCQ' && _type != 'TRUE_FALSE') 'answerKey': _answerKey.text.trim(),
      'acceptableAnswers': _lines(_acceptable.text),
      'keywords': _commas(_keywords.text),
      'concepts': _lines(_concepts.text),
      'explanation': _explanation.text.trim(),
      'partialCredit': _partial.text.trim(),
      if (_type == 'NUMERICAL') 'tolerance': double.tryParse(_tolerance.text.trim()) ?? 0,
      'rubric': [
        for (final r in _rubric)
          if (r.$1.text.trim().isNotEmpty) {'description': r.$1.text.trim(), 'marks': double.tryParse(r.$2.text) ?? 0},
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final answerLabel = switch (_type) {
      'FILL_BLANK' => 'Correct answer',
      'NUMERICAL' => 'Answer key (final value with unit, plus worked solution)',
      _ => 'Model answer',
    };
    return Scaffold(
      appBar: AppBar(title: Text(widget.question == null ? 'New question' : 'Edit question'), actions: [TextButton(onPressed: _done, child: const Text('Done'))]),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Question type'),
            items: [for (final e in questionTypeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() {
              _type = v ?? _type;
              if (_type == 'TRUE_FALSE' && _correct > 1) _correct = 1;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(controller: _text, maxLines: 5, minLines: 2, decoration: const InputDecoration(labelText: 'Question'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickImage,
              icon: _uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image_outlined),
              label: Text(_imageUrl == null ? 'Add image' : 'Replace image'),
            ),
            if (_imageUrl != null) TextButton(onPressed: () => setState(() => _imageUrl = null), child: const Text('Remove')),
          ]),
          if (_imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(widget.api.imageUrl(_imageUrl!), height: 160, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Text('Image preview unavailable')),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _marks,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Marks'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null || n < 0.25 || n > 100 ? '0.25 – 100' : null;
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _difficulty,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const [
                  DropdownMenuItem(value: 'EASY', child: Text('Easy')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                  DropdownMenuItem(value: 'HARD', child: Text('Hard')),
                ],
                onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          TextFormField(controller: _chapter, decoration: const InputDecoration(labelText: 'Chapter')),
          const SizedBox(height: AppSpacing.md),
          TextFormField(controller: _topic, decoration: InputDecoration(labelText: 'Topic', helperText: widget.topics.isEmpty ? 'Used for topic-wise analytics' : 'Test topics: ${widget.topics.join(', ')}')),
          const SectionTitle('Answer key'),
          if (_type == 'MCQ')
            RadioGroup<int>(
              groupValue: _correct,
              onChanged: (v) => setState(() => _correct = v ?? _correct),
              child: Column(children: [
                for (final (i, c) in _options.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(children: [
                      Radio<int>(value: i),
                      Expanded(child: TextFormField(controller: c, decoration: InputDecoration(labelText: 'Option ${String.fromCharCode(65 + i)}${_correct == i ? ' (correct)' : ''}'))),
                      if (_options.length > 2)
                        IconButton(
                          tooltip: 'Remove option',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _options.removeAt(i);
                            if (_correct >= _options.length) _correct = _options.length - 1;
                          }),
                        ),
                    ]),
                  ),
                if (_options.length < 6)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(onPressed: () => setState(() => _options.add(TextEditingController())), icon: const Icon(Icons.add), label: const Text('Add option')),
                  ),
              ]),
            )
          else if (_type == 'TRUE_FALSE')
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 1, label: Text('True')), ButtonSegment(value: 0, label: Text('False'))],
              selected: {_correct},
              onSelectionChanged: (s) => setState(() => _correct = s.first),
            )
          else ...[
            TextFormField(
              controller: _answerKey,
              maxLines: _descriptive ? 6 : 3,
              minLines: 1,
              decoration: InputDecoration(labelText: answerLabel),
              validator: (v) => !_descriptive && (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            if (_type == 'NUMERICAL') ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _tolerance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Allowed difference (±)', helperText: 'Final values within this range get full marks'),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(controller: _acceptable, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Alternative acceptable answers', helperText: 'One per line')),
          ],
          if (_type != 'MCQ' && _type != 'TRUE_FALSE') ...[
            const SizedBox(height: AppSpacing.md),
            TextFormField(controller: _concepts, maxLines: 4, minLines: 1, decoration: const InputDecoration(labelText: 'Essential concepts', helperText: 'One per line')),
            const SizedBox(height: AppSpacing.md),
            TextFormField(controller: _keywords, decoration: const InputDecoration(labelText: 'Expected keywords', helperText: 'Comma separated; helpful, not required word for word')),
            SectionTitle('Marking rubric', subtitle: _descriptive ? 'How marks are awarded. Criteria must add up to the question marks.' : 'Optional: partial credit for working'),
            for (final (i, r) in _rubric.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 4, child: TextFormField(controller: r.$1, maxLines: 2, minLines: 1, decoration: InputDecoration(labelText: 'Criterion ${i + 1}'))),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 72,
                    child: TextFormField(controller: r.$2, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Marks'), onChanged: (_) => setState(() {})),
                  ),
                  IconButton(tooltip: 'Remove criterion', icon: const Icon(Icons.close), onPressed: () => setState(() => _rubric.removeAt(i))),
                ]),
              ),
            Row(children: [
              TextButton.icon(
                onPressed: () => setState(() => _rubric.add((TextEditingController(), TextEditingController(text: '1')))),
                icon: const Icon(Icons.add),
                label: const Text('Add criterion'),
              ),
              const Spacer(),
              if (_rubric.isNotEmpty)
                Pill(
                  label: '${fmtNum(_rubricTotal)} / ${_marks.text.isEmpty ? '?' : _marks.text}',
                  color: (double.tryParse(_marks.text) ?? -1) == _rubricTotal ? AppColors.success : AppColors.warning,
                ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(controller: _partial, maxLines: 2, minLines: 1, decoration: const InputDecoration(labelText: 'Partial-credit rules (optional)')),
          ],
          const SizedBox(height: AppSpacing.md),
          TextFormField(controller: _explanation, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Explanation shown with results (optional)')),
          if (_error != null) ...[const SizedBox(height: AppSpacing.md), MessageBanner(message: _error!)],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _done, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Done')),
          const SizedBox(height: AppSpacing.sm),
          Text('Questions are saved when you tap "Save" on the question list.', textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}
