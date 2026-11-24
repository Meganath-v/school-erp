import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../outcomes/data/outcomes_api.dart';
import '../data/assessment_api.dart';

/// Students below a pass threshold, from an exam or an internal mark scheme.
class WeakStudentsTab extends StatefulWidget {
  final Map<String, dynamic> subject;
  const WeakStudentsTab({super.key, required this.subject});

  @override
  State<WeakStudentsTab> createState() => _WeakStudentsTabState();
}

class _WeakStudentsTabState extends State<WeakStudentsTab> with AutomaticKeepAliveClientMixin {
  final _api = AssessmentApi();
  final _threshold = TextEditingController();
  List<Map<String, String>> _sources = [];
  String? _source; // "exam:<id>" or "scheme:<id>"
  bool _loadingSources = true;
  String? _error;
  Future<Map<String, dynamic>>? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    setState(() {
      _loadingSources = true;
      _error = null;
    });
    try {
      final id = widget.subject['id'] as String;
      final res = await Future.wait([_api.schemes(id), OutcomesApi().assessments(id)]);
      if (!mounted) return;
      setState(() {
        _sources = [
          for (final s in res[0]) {'key': 'scheme:${s['id']}', 'label': 'Internal: ${s['name']}'},
          for (final a in res[1].where((a) => a['kind'] == 'exam')) {'key': 'exam:${a['id']}', 'label': '${a['title']} · ${a['subtitle']}'},
        ];
        _source = _sources.isNotEmpty ? _sources.first['key'] : null;
        _loadingSources = false;
      });
      _run();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSources = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  void _run() {
    if (_source == null) return;
    final [kind, id] = _source!.split(':');
    final t = double.tryParse(_threshold.text.trim());
    setState(() {
      _result = kind == 'exam' ? _api.weakStudents(examSubjectId: id, threshold: t) : _api.weakStudents(schemeId: id, threshold: t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    if (_loadingSources) return const LoadingStateView(message: 'Loading assessments...');
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: _error!, onRetry: _loadSources)]);
    }
    if (_sources.isEmpty) {
      return const EmptyStateView(
        icon: Icons.trending_down,
        title: 'Nothing to analyse yet',
        message: 'Create an exam or an internal mark scheme for this subject first.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _run(),
      child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        DropdownButtonFormField<String>(
          initialValue: _source,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Based on'),
          items: [
            for (final s in _sources) DropdownMenuItem(value: s['key'], child: Text(s['label']!, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            _source = v;
            _run();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _threshold,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Below %', hintText: 'Default: pass mark'),
              onSubmitted: (_) => _run(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton(onPressed: _run, child: const Text('Apply')),
        ]),
        const SizedBox(height: AppSpacing.lg),
        if (_result != null)
          FutureBuilder<Map<String, dynamic>>(
            future: _result,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Finding students...');
              if (snap.hasError) return MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _run);
              final d = snap.data!;
              final students = (d['students'] as List).cast<Map>();
              return SectionCard(
                title: '${students.length} below ${formatLevel(d['threshold'] as num)}%',
                icon: Icons.trending_down,
                empty: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('Every student is at or above the threshold.', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ),
                children: [
                  for (final s in students)
                    InfoRow(
                      icon: Icons.person_outline,
                      title: '${s['name']}',
                      subtitle: '${s['admissionNo'] ?? ''} · ${s['section']} · ${s['reason']}',
                      trailing: Text(
                        s['percent'] == null ? '—' : '${formatLevel(s['percent'] as num)}%',
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              );
            },
          ),
      ]),
    );
  }
}
