import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../data/outcomes_api.dart';
import 'outcomes_screen.dart';

/// Course-outcome and program-outcome attainment for a subject, plus the rule used.
class AttainmentTab extends StatefulWidget {
  final Map<String, dynamic> subject;
  final bool isAdmin;
  const AttainmentTab({super.key, required this.subject, required this.isAdmin});

  @override
  State<AttainmentTab> createState() => _AttainmentTabState();
}

class _AttainmentTabState extends State<AttainmentTab> with AutomaticKeepAliveClientMixin {
  final _api = OutcomesApi();
  String? _classId;
  late Future<Map<String, dynamic>> _future = _fetch();

  bool get _canEdit => widget.subject['canEdit'] == true;
  String get _subjectId => widget.subject['id'] as String;
  List<Map> get _classes => (widget.subject['classes'] as List? ?? []).cast<Map>();

  @override
  bool get wantKeepAlive => true;

  Future<Map<String, dynamic>> _fetch() => _api.attainment(_subjectId, classId: _classId);

  Future<void> _reload() async {
    final f = _fetch();
    setState(() => _future = f);
    await f;
  }

  static const _fields = [
    ('studentTargetPercent', 'Student target (%)', 'Score a student needs on an outcome’s questions'),
    ('level1Percent', 'Level 1 at (% of students)', ''),
    ('level2Percent', 'Level 2 at (% of students)', ''),
    ('level3Percent', 'Level 3 at (% of students)', ''),
    ('internalWeight', 'Internal weight', 'Within direct attainment'),
    ('externalWeight', 'External weight', ''),
    ('directWeight', 'Direct weight', 'Versus course exit survey'),
    ('indirectWeight', 'Indirect (survey) weight', ''),
    ('targetLevel', 'Target level (0–3)', 'Outcomes below this are flagged'),
  ];

  Future<void> _editRule(Map<String, dynamic> rule, {required bool schoolDefault}) async {
    final formKey = GlobalKey<FormState>();
    final ctl = {for (final f in _fields) f.$1: TextEditingController(text: formatLevel(rule[f.$1] as num))};
    final saved = await showFormDialog(
      context,
      title: schoolDefault ? 'School default rule' : 'Rule for ${widget.subject['name']}',
      formKey: formKey,
      fields: (_) => [
        for (final f in _fields) ...[
          TextFormField(
            controller: ctl[f.$1],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: f.$2, helperText: f.$3.isEmpty ? null : f.$3),
            validator: (v) => double.tryParse(v ?? '') == null ? 'Enter a number' : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
      onSubmit: () => tryApi(() async {
        final body = {for (final f in _fields) f.$1: double.parse(ctl[f.$1]!.text)};
        schoolDefault ? await _api.saveSchoolRule(body) : await _api.saveSubjectRule(_subjectId, body);
      }),
    );
    if (saved && mounted) _reload();
  }

  Future<void> _resetRule() async {
    try {
      await _api.resetSubjectRule(_subjectId);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Calculating attainment...');
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
              MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload),
            ]);
          }
          return _report(snap.data!);
        },
      ),
    );
  }

  Widget _report(Map<String, dynamic> d) {
    final text = Theme.of(context).textTheme;
    final rule = Map<String, dynamic>.from(d['rule'] as Map);
    final target = rule['targetLevel'] as num;
    final summary = d['summary'] as Map;
    final cos = (d['courseOutcomes'] as List).cast<Map>();
    final pos = (d['programOutcomes'] as List).cast<Map>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xxl),
      children: [
        if (_classes.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: DropdownButtonFormField<String?>(
              initialValue: _classId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Class', prefixIcon: Icon(Icons.groups_outlined)),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All classes')),
                for (final c in _classes) DropdownMenuItem<String?>(value: c['id'] as String, child: Text('${c['name']}')),
              ],
              onChanged: (v) {
                setState(() => _classId = v);
                _reload();
              },
            ),
          ),
        KpiGrid(tiles: [
          KpiTile(label: 'Course outcomes', value: '${cos.length}', icon: Icons.flag_outlined),
          KpiTile(
            label: 'Below target level ${formatLevel(target)}',
            value: '${summary['outcomesBelowTarget']}',
            icon: Icons.trending_down,
            color: (summary['outcomesBelowTarget'] as num) > 0 ? AppColors.error : AppColors.success,
          ),
          KpiTile(label: 'Questions assessed', value: '${summary['questionsAssessed']}', icon: Icons.quiz_outlined, color: AppColors.secondary),
          KpiTile(label: 'Marks entries', value: '${summary['marksEntries']}', icon: Icons.edit_note, color: AppColors.warning),
        ]),
        if ((summary['unmappedQuestions'] as num) > 0) ...[
          const SizedBox(height: AppSpacing.md),
          MessageBanner(
            isError: false,
            message: '${summary['unmappedQuestions']} assessed question(s) are not linked to a course outcome and are left out. Tag them in the question bank.',
          ),
        ],
        if ((summary['questionsAssessed'] as num) == 0) ...[
          const SizedBox(height: AppSpacing.md),
          const MessageBanner(
            isError: false,
            message: 'No question-wise marks yet. Build a question paper for an exam or assignment (Papers & marks) and enter marks per question.',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ruleCard(rule, d['ruleSource'] as String),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Course outcome attainment',
          icon: Icons.flag_outlined,
          empty: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('No course outcomes defined.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
          ),
          children: [for (final c in cos) _coTile(c, target)],
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Program outcome attainment',
          icon: Icons.account_tree_outlined,
          empty: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('No program outcomes: link this subject’s classes to a program and map its course outcomes.',
                style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
          ),
          children: [for (final p in pos) _poTile(p, target)],
        ),
      ],
    );
  }

  Widget _ruleCard(Map<String, dynamic> rule, String source) {
    final text = Theme.of(context).textTheme;
    final sourceLabel = switch (source) { 'SUBJECT' => 'Subject rule', 'SCHOOL' => 'School default', _ => 'Built-in default' };
    return SectionCard(
      title: 'Rule used · $sourceLabel',
      icon: Icons.rule,
      actionLabel: _canEdit ? 'Edit' : null,
      onAction: _canEdit ? () => _editRule(rule, schoolDefault: false) : null,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'A student attains an outcome by scoring ≥ ${formatLevel(rule['studentTargetPercent'])}% on its questions. '
            'Level 1/2/3 when ≥ ${formatLevel(rule['level1Percent'])}% / ${formatLevel(rule['level2Percent'])}% / ${formatLevel(rule['level3Percent'])}% of students attain it. '
            'Direct = internal ${formatLevel(rule['internalWeight'])} : external ${formatLevel(rule['externalWeight'])}; '
            'final = direct ${formatLevel(rule['directWeight'])} : survey ${formatLevel(rule['indirectWeight'])}. Target level ${formatLevel(rule['targetLevel'])}.',
            style: text.bodyMedium?.copyWith(height: 1.4),
          ),
        ),
        if (_canEdit || widget.isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
            child: Wrap(spacing: AppSpacing.sm, children: [
              if (_canEdit && source == 'SUBJECT') TextButton(onPressed: _resetRule, child: const Text('Use school default')),
              if (widget.isAdmin) TextButton(onPressed: () => _editRule(rule, schoolDefault: true), child: const Text('Edit school default')),
            ]),
          ),
      ],
    );
  }

  Widget _coTile(Map c, num target) {
    final text = Theme.of(context).textTheme;
    String part(String label, Map? r) => r == null
        ? '$label: not assessed'
        : '$label: ${r['studentsAttained']}/${r['studentsAssessed']} students (${formatLevel(r['percentAttained'])}%) → L${r['level']}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c['code']}', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          LevelBadge(level: c['finalLevel'] as num?, target: target),
        ]),
        if ((c['description'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('${c['description']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(part('Internal', c['internal'] as Map?), style: text.bodySmall),
        Text(part('External', c['external'] as Map?), style: text.bodySmall),
        Text('Direct ${formatLevel(c['directLevel'] as num?)} · Survey ${formatLevel(c['indirectLevel'] as num?)}', style: text.bodySmall),
      ]),
    );
  }

  Widget _poTile(Map p, num target) {
    final text = Theme.of(context).textTheme;
    final value = p['attainment'] as num?;
    final color = value == null ? AppColors.textMuted : (value >= target ? AppColors.success : AppColors.warning);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${p['code']} · ${p['type']}', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          Text(value == null ? '—' : '${formatLevel(value)} / 3', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: AppRadius.pillBorderRadius,
          child: LinearProgressIndicator(
            value: value == null ? 0 : (value / 3).clamp(0, 1).toDouble(),
            minHeight: 8,
            color: color,
            backgroundColor: AppColors.surfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value == null
              ? (p['totalStrength'] == 0 ? 'No course outcome mapped' : 'Mapped outcomes not assessed yet')
              : 'From ${p['contributingOutcomes']} course outcome(s), total correlation ${p['totalStrength']}',
          style: text.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ]),
    );
  }
}
