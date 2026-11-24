import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../outcomes/data/outcomes_api.dart';
import '../../outcomes/presentation/outcomes_screen.dart' show confirmDelete, showApiError, showDone;
import '../data/assessment_api.dart';

const componentTypes = {'EXAM': 'Exams', 'ASSIGNMENT': 'Assignments', 'ATTENDANCE': 'Attendance', 'MANUAL': 'Entered by teacher'};

/// Internal mark schemes of a subject and their mark sheets.
class InternalMarksTab extends StatefulWidget {
  final Map<String, dynamic> subject;
  const InternalMarksTab({super.key, required this.subject});

  @override
  State<InternalMarksTab> createState() => _InternalMarksTabState();
}

class _InternalMarksTabState extends State<InternalMarksTab> with AutomaticKeepAliveClientMixin {
  final _api = AssessmentApi();
  late Future<List<Map<String, dynamic>>> _future = _api.schemes(widget.subject['id'] as String);
  bool get _canEdit => widget.subject['canEdit'] == true;

  @override
  bool get wantKeepAlive => true;

  Future<void> _reload() async {
    final f = _api.schemes(widget.subject['id'] as String);
    setState(() => _future = f);
    await f;
  }

  Future<void> _edit([Map<String, dynamic>? scheme]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => SchemeEditorScreen(subject: widget.subject, scheme: scheme),
    ));
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    if (!await confirmDelete(context, 'scheme "${s['name']}" and its entered marks')) return;
    try {
      await _api.deleteScheme(s['id']);
      if (mounted) _reload();
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
          ? FloatingActionButton.extended(heroTag: 'fab-scheme', onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Scheme'))
          : null,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading schemes...');
            if (snap.hasError) {
              return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload)]);
            }
            final schemes = snap.data!;
            if (schemes.isEmpty) {
              return ListView(children: const [
                EmptyStateView(
                  icon: Icons.calculate_outlined,
                  title: 'No internal mark scheme',
                  message: 'Create a scheme to combine class tests, assignments, attendance and teacher-entered marks into an internal mark.',
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
              children: [
                for (final s in schemes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: SectionCard(
                      title: '${s['name']}',
                      icon: Icons.calculate_outlined,
                      actionLabel: 'Open sheet',
                      onAction: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MarkSheetScreen(subject: widget.subject, scheme: s),
                      )),
                      children: [
                        for (final c in (s['components'] as List).cast<Map>())
                          InfoRow(
                            title: '${c['label']} · ${formatLevel(c['weight'] as num)} marks',
                            subtitle: '${componentTypes[c['type']]}${c['bestOf'] != null ? ' · best ${c['bestOf']}' : ''}'
                                '${(c['sourceIds'] as List).isNotEmpty ? ' · ${(c['sourceIds'] as List).length} selected' : ''}',
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.sm, AppSpacing.sm),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                'Total ${formatLevel((s['components'] as List).fold<num>(0, (a, c) => a + (c['weight'] as num)))} · pass ${formatLevel(s['passPercent'] as num)}%',
                                style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                            if (_canEdit) ...[
                              IconButton(tooltip: 'Edit scheme', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(s)),
                              IconButton(tooltip: 'Delete scheme', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(s)),
                            ],
                          ]),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ======================================================================== scheme editor

class _Comp {
  String? id;
  String label;
  String type;
  double weight;
  int? bestOf;
  Set<String> sources;
  _Comp({this.id, required this.label, required this.type, required this.weight, this.bestOf, Set<String>? sources}) : sources = sources ?? {};
}

class SchemeEditorScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final Map<String, dynamic>? scheme;
  const SchemeEditorScreen({super.key, required this.subject, this.scheme});

  @override
  State<SchemeEditorScreen> createState() => _SchemeEditorScreenState();
}

class _SchemeEditorScreenState extends State<SchemeEditorScreen> {
  final _api = AssessmentApi();
  late final _name = TextEditingController(text: widget.scheme?['name'] ?? 'Internal assessment');
  late final _pass = TextEditingController(text: formatLevel((widget.scheme?['passPercent'] as num?) ?? 40));
  late String? _classId = widget.scheme == null
      ? ((widget.subject['classes'] as List).isNotEmpty ? (widget.subject['classes'] as List).first['id'] as String : null)
      : widget.scheme!['classId'] as String?;
  late final List<_Comp> _comps = widget.scheme == null
      ? [_Comp(label: 'Class tests', type: 'EXAM', weight: 20), _Comp(label: 'Attendance', type: 'ATTENDANCE', weight: 5)]
      : [
          for (final c in (widget.scheme!['components'] as List).cast<Map>())
            _Comp(
              id: c['id'],
              label: '${c['label']}',
              type: '${c['type']}',
              weight: (c['weight'] as num).toDouble(),
              bestOf: c['bestOf'] as int?,
              sources: {...(c['sourceIds'] as List).cast<String>()},
            ),
        ];
  List<Map<String, dynamic>> _assessments = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    OutcomesApi().assessments(widget.subject['id'] as String).then((a) {
      if (mounted) setState(() => _assessments = a);
    }).catchError((_) {});
  }

  List<Map<String, dynamic>> _sourcesFor(String type) => _assessments
      .where((a) => a['kind'] == (type == 'EXAM' ? 'exam' : 'assignment'))
      .where((a) {
        if (_classId == null) return true;
        final cls = (widget.subject['classes'] as List).cast<Map>().where((c) => c['id'] == _classId);
        return cls.isEmpty || '${a['subtitle']}'.startsWith('${cls.first['name']}');
      })
      .toList();

  Future<void> _save() async {
    final pass = double.tryParse(_pass.text);
    if (_name.text.trim().isEmpty || pass == null || pass < 0 || pass > 100) {
      setState(() => _error = 'Enter a name and a pass percentage between 0 and 100.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'name': _name.text.trim(),
      'classId': _classId,
      'passPercent': pass,
      'components': [
        for (final c in _comps)
          {
            'id': ?c.id,
            'label': c.label,
            'type': c.type,
            'weight': c.weight,
            if (c.type == 'EXAM' || c.type == 'ASSIGNMENT') 'bestOf': c.bestOf,
            if (c.type == 'EXAM' || c.type == 'ASSIGNMENT') 'sourceIds': c.sources.toList(),
          },
      ],
    };
    try {
      widget.scheme == null
          ? await _api.createScheme(widget.subject['id'] as String, body)
          : await _api.updateScheme(widget.scheme!['id'] as String, body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _comps.fold<double>(0, (a, c) => a + c.weight);
    final classes = (widget.subject['classes'] as List).cast<Map>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.scheme == null ? 'New scheme' : 'Edit scheme')),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String?>(
          initialValue: _classId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Class'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Every class of this subject')),
            for (final c in classes) DropdownMenuItem<String?>(value: c['id'] as String, child: Text('${c['name']}')),
          ],
          onChanged: (v) => setState(() => _classId = v),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _pass,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Pass percentage', helperText: 'Students below this are listed as weak'),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final c in _comps) ...[_componentCard(c), const SizedBox(height: AppSpacing.md)],
        OutlinedButton.icon(
          onPressed: () => setState(() => _comps.add(_Comp(label: 'Component ${_comps.length + 1}', type: 'MANUAL', weight: 5))),
          icon: const Icon(Icons.add),
          label: const Text('Add component'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (_error != null) ...[const SizedBox(height: AppSpacing.md), MessageBanner(message: _error!)],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _saving || _comps.isEmpty ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Save · internal mark out of ${formatLevel(total)}'),
        ),
      ]),
    );
  }

  Widget _componentCard(_Comp c) {
    final selectable = _sourcesFor(c.type);
    return SectionCard(
      title: c.label,
      icon: Icons.tune,
      actionLabel: 'Remove',
      onAction: () => setState(() => _comps.remove(c)),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(initialValue: c.label, decoration: const InputDecoration(labelText: 'Label'), onChanged: (v) => c.label = v),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: c.type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Source'),
              items: [for (final e in componentTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() {
                c.type = v ?? c.type;
                c.sources.clear();
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              initialValue: formatLevel(c.weight),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Marks'),
              onChanged: (v) => setState(() => c.weight = double.tryParse(v) ?? c.weight),
            ),
            if (c.type == 'EXAM' || c.type == 'ASSIGNMENT') ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                initialValue: c.bestOf?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Count only the best (optional)', hintText: 'e.g. 2'),
                onChanged: (v) => c.bestOf = int.tryParse(v),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (selectable.isEmpty)
                Text('No ${c.type == 'EXAM' ? 'exams' : 'assignments'} for this subject yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted))
              else
                for (final a in selectable)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: c.sources.contains(a['id']),
                    title: Text('${a['title']}'),
                    subtitle: Text('${a['subtitle']} · max ${a['maxMarks']}'),
                    onChanged: (v) => setState(() => v == true ? c.sources.add(a['id'] as String) : c.sources.remove(a['id'])),
                  ),
            ],
          ]),
        ),
      ],
    );
  }
}

// ======================================================================== mark sheet

class MarkSheetScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final Map<String, dynamic> scheme;
  const MarkSheetScreen({super.key, required this.subject, required this.scheme});

  @override
  State<MarkSheetScreen> createState() => _MarkSheetScreenState();
}

class _MarkSheetScreenState extends State<MarkSheetScreen> {
  final _api = AssessmentApi();
  late String? _classId = widget.scheme['classId'] as String? ??
      ((widget.subject['classes'] as List).isNotEmpty ? (widget.subject['classes'] as List).first['id'] as String : null);
  late Future<Map<String, dynamic>> _future = _fetch();

  Future<Map<String, dynamic>> _fetch() => _api.sheet(widget.scheme['id'] as String, classId: _classId);

  Future<void> _reload() async {
    final f = _fetch();
    setState(() => _future = f);
    await f;
  }

  Future<void> _enterManual(Map component, List<Map> students) async {
    final ctl = {
      for (final s in students)
        s['studentId'] as String: TextEditingController(
          text: (() {
            final c = (s['components'] as List).cast<Map>().firstWhere((x) => x['componentId'] == component['id']);
            return c['score'] == null ? '' : formatLevel(c['score'] as num);
          })(),
        ),
    };
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (ctx) {
      var busy = false;
      return StatefulBuilder(builder: (ctx, setLocal) {
        return Scaffold(
          appBar: AppBar(title: Text('${component['label']} (out of ${formatLevel(component['weight'] as num)})')),
          body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
            for (final s in students)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: TextField(
                  controller: ctl[s['studentId']],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: '${s['name']}', helperText: '${s['admissionNo'] ?? ''} · ${s['section']}'),
                ),
              ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: busy
                  ? null
                  : () async {
                      final max = (component['weight'] as num).toDouble();
                      final entries = <Map<String, dynamic>>[];
                      for (final s in students) {
                        final t = ctl[s['studentId']]!.text.trim();
                        final v = t.isEmpty ? null : double.tryParse(t);
                        if (t.isNotEmpty && (v == null || v < 0 || v > max)) {
                          showDone(ctx, 'Marks for ${s['name']} must be between 0 and ${formatLevel(max)}');
                          return;
                        }
                        entries.add({'studentId': s['studentId'], 'marks': v});
                      }
                      setLocal(() => busy = true);
                      try {
                        await _api.saveManualMarks(component['id'] as String, entries);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setLocal(() => busy = false);
                        if (ctx.mounted) showApiError(ctx, e);
                      }
                    },
              child: const Text('Save marks'),
            ),
          ]),
        );
      });
    }));
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final classes = (widget.subject['classes'] as List).cast<Map>();
    return Scaffold(
      appBar: AppBar(title: Text('${widget.scheme['name']}', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Calculating internal marks...');
            if (snap.hasError) {
              return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload)]);
            }
            final d = snap.data!;
            final scheme = d['scheme'] as Map;
            final students = (d['students'] as List).cast<Map>();
            final summary = d['summary'] as Map;
            final manual = (scheme['components'] as List).cast<Map>().where((c) => c['type'] == 'MANUAL').toList();
            return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
              if (widget.scheme['classId'] == null && classes.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DropdownButtonFormField<String>(
                    initialValue: _classId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: [for (final c in classes) DropdownMenuItem(value: c['id'] as String, child: Text('${c['name']}'))],
                    onChanged: (v) {
                      _classId = v;
                      _reload();
                    },
                  ),
                ),
              KpiGrid(tiles: [
                KpiTile(label: 'Students', value: '${summary['students']}', icon: Icons.groups_outlined),
                KpiTile(label: 'Average', value: summary['average'] == null ? '—' : '${formatLevel(summary['average'] as num)}%', icon: Icons.percent, color: AppColors.secondary),
                KpiTile(label: 'Below ${formatLevel(scheme['passPercent'] as num)}%', value: '${summary['weak']}', icon: Icons.trending_down, color: AppColors.error),
                KpiTile(label: 'Incomplete data', value: '${summary['incomplete']}', icon: Icons.hourglass_empty, color: AppColors.warning),
              ]),
              if (widget.subject['canEdit'] == true)
                for (final c in manual)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: OutlinedButton.icon(
                      onPressed: () => _enterManual(c, students),
                      icon: const Icon(Icons.edit_note),
                      label: Text('Enter "${c['label']}" marks'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                title: 'Students',
                icon: Icons.list_alt,
                empty: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('No students enrolled.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ),
                children: [
                  for (final s in students)
                    ExpansionTile(
                      title: Text('${s['name']}'),
                      subtitle: Text('${s['admissionNo'] ?? ''} · ${s['section']}${s['complete'] == true ? '' : ' · incomplete'}'),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${formatLevel(s['total'] as num)}/${formatLevel(s['max'] as num)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${formatLevel(s['percent'] as num)}%',
                            style: TextStyle(color: s['isWeak'] == true ? AppColors.error : AppColors.success, fontSize: 12)),
                      ]),
                      children: [
                        for (final c in (s['components'] as List).cast<Map>())
                          ListTile(
                            dense: true,
                            title: Text('${c['label']}'),
                            trailing: Text(c['score'] == null ? 'no data' : '${formatLevel(c['score'] as num)} / ${formatLevel(c['max'] as num)}'),
                          ),
                      ],
                    ),
                ],
              ),
            ]);
          },
        ),
      ),
    );
  }
}
