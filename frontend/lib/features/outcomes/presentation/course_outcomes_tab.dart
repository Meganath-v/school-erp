import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../data/outcomes_api.dart';
import 'outcomes_screen.dart';

/// Course outcomes of one subject, their mapping to program outcomes, and the
/// course exit survey (indirect) level per outcome.
class CourseOutcomesTab extends StatefulWidget {
  final Map<String, dynamic> subject;
  const CourseOutcomesTab({super.key, required this.subject});

  @override
  State<CourseOutcomesTab> createState() => _CourseOutcomesTabState();
}

class _CourseOutcomesTabState extends State<CourseOutcomesTab> with AutomaticKeepAliveClientMixin {
  final _api = OutcomesApi();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cos = [];
  List<Map<String, dynamic>> _pos = [];
  List<Map<String, dynamic>> _programs = [];
  String? _programId; // explicit program when the subject's classes are not linked to one
  final Map<String, int> _strength = {}; // "coId|poId" -> 0..3 (edited)
  Map<String, int> _savedStrength = {};
  final Map<String, double?> _indirect = {};
  bool _savingMap = false;
  bool _savingIndirect = false;

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
      final results = await Future.wait([
        _api.courseOutcomes(_subjectId),
        _api.mapping(_subjectId, programId: _programId),
        _api.programs(),
      ]);
      final cos = results[0] as List<Map<String, dynamic>>;
      final mapping = results[1] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _cos = cos;
        _pos = (mapping['programOutcomes'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _programs = results[2] as List<Map<String, dynamic>>;
        _savedStrength = {
          for (final e in (mapping['entries'] as List? ?? []).whereType<Map>())
            '${e['courseOutcomeId']}|${e['programOutcomeId']}': (e['strength'] as num).toInt(),
        };
        _strength
          ..clear()
          ..addAll(_savedStrength);
        _indirect
          ..clear()
          ..addAll({for (final c in cos) c['id'] as String: (c['indirectLevel'] as num?)?.toDouble()});
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

  bool get _mappingDirty {
    final keys = {..._strength.keys, ..._savedStrength.keys};
    return keys.any((k) => (_strength[k] ?? 0) != (_savedStrength[k] ?? 0));
  }

  Future<void> _saveMapping() async {
    final keys = {..._strength.keys, ..._savedStrength.keys};
    final entries = [
      for (final k in keys)
        if ((_strength[k] ?? 0) != (_savedStrength[k] ?? 0))
          {'courseOutcomeId': k.split('|')[0], 'programOutcomeId': k.split('|')[1], 'strength': _strength[k] ?? 0},
    ];
    setState(() => _savingMap = true);
    try {
      await _api.saveMapping(_subjectId, entries);
      if (!mounted) return;
      showDone(context, 'Mapping saved');
      await _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _savingMap = false);
    }
  }

  Future<void> _saveIndirect() async {
    setState(() => _savingIndirect = true);
    try {
      await _api.saveIndirect(_subjectId, [
        for (final c in _cos) {'courseOutcomeId': c['id'], 'level': _indirect[c['id']]},
      ]);
      if (mounted) showDone(context, 'Survey levels saved');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _savingIndirect = false);
    }
  }

  Future<void> _editCo([Map<String, dynamic>? co]) async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(text: co?['code'] ?? 'CO${_cos.length + 1}');
    final desc = TextEditingController(text: co?['description'] ?? '');
    final target = TextEditingController(text: '${co?['targetAttainment'] ?? 70}');
    var bloom = (co?['bloomLevel'] as String?) ?? 'UNDERSTAND';
    final saved = await showFormDialog(
      context,
      title: co == null ? 'New course outcome' : 'Edit ${co['code']}',
      formKey: formKey,
      fields: (setLocal) => [
        TextFormField(controller: code, decoration: const InputDecoration(labelText: 'Code'), validator: requiredText),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: desc,
          decoration: const InputDecoration(labelText: 'Outcome statement', hintText: 'Students will be able to...'),
          maxLines: 3,
          validator: requiredText,
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: bloom,
          decoration: const InputDecoration(labelText: "Bloom's level"),
          items: [for (final b in bloomLevels) DropdownMenuItem(value: b, child: Text(bloomLabel(b)))],
          onChanged: (v) => setLocal(() => bloom = v ?? bloom),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: target,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Target attainment (%)'),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            return n == null || n < 0 || n > 100 ? 'Enter 0–100' : null;
          },
        ),
      ],
      onSubmit: () => tryApi(() async {
        final body = {
          'code': code.text.trim(),
          'description': desc.text.trim(),
          'bloomLevel': bloom,
          'targetAttainment': int.parse(target.text),
          'orderIndex': co?['orderIndex'] ?? _cos.length + 1,
        };
        co == null ? await _api.createCourseOutcome(_subjectId, body) : await _api.updateCourseOutcome(co['id'], body);
      }),
    );
    if (saved && mounted) _load();
  }

  Future<void> _deleteCo(Map<String, dynamic> co) async {
    if (!await confirmDelete(context, '${co['code']} (its questions stay in the bank, unmapped)')) return;
    try {
      await _api.deleteCourseOutcome(co['id']);
      if (mounted) _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const LoadingStateView(message: 'Loading course outcomes...');
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: _error!, onRetry: _load)]);
    }
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
        children: [
          if (!_canEdit)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: MessageBanner(isError: false, message: 'View only: you do not teach this subject.'),
            ),
          SectionCard(
            title: 'Course outcomes (${_cos.length})',
            icon: Icons.flag_outlined,
            actionLabel: _canEdit ? 'Add' : null,
            onAction: _canEdit ? () => _editCo() : null,
            empty: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('No course outcomes yet. Add what students should be able to do after this course.',
                  style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
            ),
            children: [
              for (final c in _cos)
                InfoRow(
                  title: '${c['code']} · ${bloomLabel(c['bloomLevel'])}',
                  subtitle: '${c['description']}\nTarget ${c['targetAttainment']}% · ${c['_count']?['questions'] ?? 0} questions',
                  trailing: _canEdit
                      ? PopupMenuButton<String>(
                          tooltip: 'Outcome actions',
                          onSelected: (v) => v == 'edit' ? _editCo(c) : _deleteCo(c),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        )
                      : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _mappingSection(text),
          const SizedBox(height: AppSpacing.lg),
          _indirectSection(text),
        ],
      ),
    );
  }

  Widget _mappingSection(TextTheme text) {
    final programPicker = DropdownButtonFormField<String?>(
      initialValue: _programId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Program', prefixIcon: Icon(Icons.account_tree_outlined)),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Programs of this subject’s classes')),
        for (final p in _programs) DropdownMenuItem<String?>(value: p['id'] as String, child: Text('${p['code']} · ${p['name']}')),
      ],
      onChanged: (v) {
        setState(() => _programId = v);
        _load();
      },
    );

    return SectionCard(
      title: 'CO–PO mapping',
      icon: Icons.grid_on_outlined,
      empty: const SizedBox.shrink(),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0), child: programPicker),
        if (_cos.isEmpty || _pos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              _cos.isEmpty
                  ? 'Add course outcomes first.'
                  : 'No program outcomes found. Link this subject’s classes to a program (Programs tab) or pick a program above.',
              style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: Text('Correlation: – none · L low (1) · M medium (2) · H high (3)',
                style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
          ),
          for (final co in _cos)
            ExpansionTile(
              title: Text('${co['code']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                _pos.where((p) => (_strength['${co['id']}|${p['id']}'] ?? 0) > 0).map((p) {
                  final s = _strength['${co['id']}|${p['id']}']!;
                  return '${p['code']}:${strengthLabel(s)[0]}';
                }).join('  ').ifEmpty('Not mapped'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
              children: [
                for (final po in _pos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${po['code']} · ${po['title'] ?? po['description']}',
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                        const SizedBox(height: 4),
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 0, label: Text('–')),
                            ButtonSegment(value: 1, label: Text('L')),
                            ButtonSegment(value: 2, label: Text('M')),
                            ButtonSegment(value: 3, label: Text('H')),
                          ],
                          selected: {_strength['${co['id']}|${po['id']}'] ?? 0},
                          onSelectionChanged: _canEdit
                              ? (s) => setState(() => _strength['${co['id']}|${po['id']}'] = s.first)
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (_canEdit)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton.icon(
                onPressed: _mappingDirty && !_savingMap ? _saveMapping : null,
                icon: _savingMap
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_mappingDirty ? 'Save mapping' : 'Mapping saved'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _indirectSection(TextTheme text) {
    return SectionCard(
      title: 'Course exit survey (indirect)',
      icon: Icons.poll_outlined,
      empty: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('Add course outcomes first.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
      ),
      children: _cos.isEmpty
          ? []
          : [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Text('Average student self-rating per outcome on a 0–3 scale. Leave blank if no survey was run.',
                    style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
              ),
              for (final c in _cos)
                ListTile(
                  title: Text('${c['code']}'),
                  trailing: SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<double?>(
                      initialValue: _indirect[c['id']],
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        const DropdownMenuItem<double?>(value: null, child: Text('No survey')),
                        for (final v in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0])
                          DropdownMenuItem<double?>(value: v, child: Text(formatLevel(v))),
                      ],
                      onChanged: _canEdit ? (v) => setState(() => _indirect[c['id'] as String] = v) : null,
                    ),
                  ),
                ),
              if (_canEdit)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: OutlinedButton.icon(
                    onPressed: _savingIndirect ? null : _saveIndirect,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save survey levels'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ),
            ],
    );
  }
}

extension _IfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
