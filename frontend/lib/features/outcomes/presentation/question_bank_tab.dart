import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../data/outcomes_api.dart';
import 'outcomes_screen.dart';

/// Question bank of a subject; each question is tagged with a course outcome and Bloom level.
class QuestionBankTab extends StatefulWidget {
  final Map<String, dynamic> subject;
  const QuestionBankTab({super.key, required this.subject});

  @override
  State<QuestionBankTab> createState() => _QuestionBankTabState();
}

class _QuestionBankTabState extends State<QuestionBankTab> with AutomaticKeepAliveClientMixin {
  final _api = OutcomesApi();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _cos = [];
  String? _filterCo;

  bool get _canEdit => widget.subject['canEdit'] == true;
  String get _subjectId => widget.subject['id'] as String;

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
      final r = await Future.wait([_api.questions(_subjectId, courseOutcomeId: _filterCo), _api.courseOutcomes(_subjectId)]);
      if (!mounted) return;
      setState(() {
        _questions = r[0];
        _cos = r[1];
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

  Future<void> _edit([Map<String, dynamic>? q]) async {
    final formKey = GlobalKey<FormState>();
    final textCtl = TextEditingController(text: q?['text'] ?? '');
    final marks = TextEditingController(text: q == null ? '' : formatLevel(q['marks'] as num));
    var bloom = (q?['bloomLevel'] as String?) ?? 'UNDERSTAND';
    String? co = q?['courseOutcome']?['id'] as String? ?? _filterCo;
    var type = (q?['type'] as String?) ?? 'DESCRIPTIVE';
    final options = [
      for (final o in (q?['options'] as List? ?? const ['', ''])) TextEditingController(text: '$o'),
    ];
    if (options.length < 2) options.addAll(List.generate(2 - options.length, (_) => TextEditingController()));
    var correct = (q?['correctOption'] as int?) ?? 0;
    final saved = await showFormDialog(
      context,
      title: q == null ? 'New question' : 'Edit question',
      formKey: formKey,
      fields: (setLocal) => [
        TextFormField(controller: textCtl, decoration: const InputDecoration(labelText: 'Question'), maxLines: 4, validator: requiredText),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: marks,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Marks'),
          validator: (v) {
            final n = double.tryParse(v ?? '');
            return n == null || n <= 0 ? 'Enter marks greater than 0' : null;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String?>(
          initialValue: co,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Course outcome'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Not mapped')),
            for (final c in _cos)
              DropdownMenuItem<String?>(value: c['id'] as String, child: Text('${c['code']} · ${c['description']}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setLocal(() => co = v),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: bloom,
          decoration: const InputDecoration(labelText: "Bloom's level"),
          items: [for (final b in bloomLevels) DropdownMenuItem(value: b, child: Text(bloomLabel(b)))],
          onChanged: (v) => setLocal(() => bloom = v ?? bloom),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: const [
            DropdownMenuItem(value: 'DESCRIPTIVE', child: Text('Descriptive')),
            DropdownMenuItem(value: 'SHORT_ANSWER', child: Text('Short answer')),
            DropdownMenuItem(value: 'MCQ', child: Text('Multiple choice')),
          ],
          onChanged: (v) => setLocal(() => type = v ?? type),
        ),
        if (type == 'MCQ') ...[
          const SizedBox(height: AppSpacing.md),
          RadioGroup<int>(
            groupValue: correct,
            onChanged: (v) => setLocal(() => correct = v ?? correct),
            child: Column(children: [
          for (final (i, ctl) in options.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(children: [
                Radio<int>(value: i),
                Expanded(
                  child: TextFormField(
                    controller: ctl,
                    decoration: InputDecoration(labelText: 'Option ${String.fromCharCode(65 + i)}${correct == i ? ' (correct)' : ''}'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the option or remove it' : null,
                  ),
                ),
                if (options.length > 2)
                  IconButton(
                    tooltip: 'Remove option',
                    icon: const Icon(Icons.close),
                    onPressed: () => setLocal(() {
                      options.removeAt(i);
                      if (correct > i || correct >= options.length) correct = (correct - 1).clamp(0, options.length - 1);
                    }),
                  ),
              ]),
            ),
            ]),
          ),
          if (options.length < 6)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setLocal(() => options.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('Add option'),
              ),
            ),
          Text('Select the circle next to the correct answer.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ],
      onSubmit: () => tryApi(() async {
        final body = {
          'text': textCtl.text.trim(),
          'marks': double.parse(marks.text),
          'bloomLevel': bloom,
          'courseOutcomeId': co,
          'type': type,
          if (type == 'MCQ') 'options': [for (final o in options) o.text.trim()],
          if (type == 'MCQ') 'correctOption': correct,
        };
        q == null ? await _api.createQuestion(_subjectId, body) : await _api.updateQuestion(q['id'], body);
      }),
    );
    if (saved && mounted) _load();
  }

  Future<void> _delete(Map<String, dynamic> q) async {
    if (!await confirmDelete(context, 'this question')) return;
    try {
      await _api.deleteQuestion(q['id']);
      if (mounted) _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Question'))
          : null,
      body: _loading
          ? const LoadingStateView(message: 'Loading question bank...')
          : _error != null
              ? ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: _error!, onRetry: _load)])
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 96),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _filterCo == null,
                            onSelected: (_) {
                              setState(() => _filterCo = null);
                              _load();
                            },
                          ),
                          for (final c in _cos) ...[
                            const SizedBox(width: AppSpacing.sm),
                            ChoiceChip(
                              label: Text('${c['code']}'),
                              selected: _filterCo == c['id'],
                              onSelected: (_) {
                                setState(() => _filterCo = c['id'] as String);
                                _load();
                              },
                            ),
                          ],
                        ]),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_questions.isEmpty)
                        EmptyStateView(
                          icon: Icons.quiz_outlined,
                          title: 'No questions',
                          message: _canEdit ? 'Add questions and tag each with a course outcome.' : 'No questions in this bank yet.',
                        )
                      else
                        for (final q in _questions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.xlBorderRadius,
                                border: Border.all(color: AppColors.border),
                              ),
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${q['text']}', style: text.bodyLarge),
                                    const SizedBox(height: AppSpacing.sm),
                                    Wrap(spacing: AppSpacing.sm, runSpacing: 4, children: [
                                      StatusChip(label: '${formatLevel(q['marks'] as num)} marks', color: AppColors.primaryAccent),
                                      StatusChip(
                                        label: q['courseOutcome'] == null ? 'No CO' : '${q['courseOutcome']['code']}',
                                        color: q['courseOutcome'] == null ? AppColors.warning : AppColors.success,
                                      ),
                                      StatusChip(label: bloomLabel(q['bloomLevel']), color: AppColors.secondary),
                                      if (((q['_count']?['paperItems']) ?? 0) > 0)
                                        StatusChip(label: 'Used in ${q['_count']['paperItems']} paper(s)', color: AppColors.textMuted),
                                    ]),
                                  ]),
                                ),
                                if (_canEdit)
                                  PopupMenuButton<String>(
                                    tooltip: 'Question actions',
                                    onSelected: (v) => v == 'edit' ? _edit(q) : _delete(q),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                              ]),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
