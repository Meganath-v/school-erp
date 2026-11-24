import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../data/outcomes_api.dart';
import 'outcomes_screen.dart';

/// Programs with their outcomes (PO / PSO / PEO) and the classes that belong to them.
class ProgramsTab extends StatefulWidget {
  final bool isAdmin;
  const ProgramsTab({super.key, required this.isAdmin});

  @override
  State<ProgramsTab> createState() => _ProgramsTabState();
}

class _ProgramsTabState extends State<ProgramsTab> with AutomaticKeepAliveClientMixin {
  final _api = OutcomesApi();
  late Future<List<Map<String, dynamic>>> _future = _api.programs();

  @override
  bool get wantKeepAlive => true;

  Future<void> _reload() async {
    final f = _api.programs();
    setState(() => _future = f);
    await f;
  }

  Future<void> _editProgram([Map<String, dynamic>? program]) async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(text: program?['code'] ?? '');
    final name = TextEditingController(text: program?['name'] ?? '');
    final desc = TextEditingController(text: program?['description'] ?? '');
    final saved = await showFormDialog(
      context,
      title: program == null ? 'New program' : 'Edit program',
      formKey: formKey,
      fields: (_) => [
        TextFormField(controller: code, decoration: const InputDecoration(labelText: 'Code', hintText: 'e.g. BCOM'), validator: requiredText),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name'), validator: requiredText),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 3),
      ],
      onSubmit: () => tryApi(() async {
        final body = {'code': code.text.trim(), 'name': name.text.trim(), if (desc.text.trim().isNotEmpty) 'description': desc.text.trim()};
        program == null ? await _api.createProgram(body) : await _api.updateProgram(program['id'], body);
      }),
    );
    if (saved && mounted) _reload();
  }

  Future<void> _deleteProgram(Map<String, dynamic> program) async {
    if (!await confirmDelete(context, 'program ${program['code']} and its outcomes')) return;
    try {
      await _api.deleteProgram(program['id']);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _editOutcome(Map<String, dynamic> program, [Map<String, dynamic>? outcome]) async {
    final formKey = GlobalKey<FormState>();
    var type = (outcome?['type'] as String?) ?? 'PO';
    final code = TextEditingController(text: outcome?['code'] ?? '');
    final title = TextEditingController(text: outcome?['title'] ?? '');
    final desc = TextEditingController(text: outcome?['description'] ?? '');
    final saved = await showFormDialog(
      context,
      title: outcome == null ? 'New outcome for ${program['code']}' : 'Edit ${outcome['code']}',
      formKey: formKey,
      fields: (setLocal) => [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'PO', label: Text('PO')),
            ButtonSegment(value: 'PSO', label: Text('PSO')),
            ButtonSegment(value: 'PEO', label: Text('PEO')),
          ],
          selected: {type},
          onSelectionChanged: (s) => setLocal(() => type = s.first),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          type == 'PO' ? 'Program outcome' : type == 'PSO' ? 'Program-specific outcome' : 'Program educational objective',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: code, decoration: const InputDecoration(labelText: 'Code', hintText: 'e.g. PO1'), validator: requiredText),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Short title (optional)')),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3, validator: requiredText),
      ],
      onSubmit: () => tryApi(() async {
        final body = {
          'type': type,
          'code': code.text.trim(),
          'description': desc.text.trim(),
          if (title.text.trim().isNotEmpty) 'title': title.text.trim(),
        };
        outcome == null
            ? await _api.createProgramOutcome(program['id'], body)
            : await _api.updateProgramOutcome(outcome['id'], body);
      }),
    );
    if (saved && mounted) _reload();
  }

  Future<void> _deleteOutcome(Map<String, dynamic> outcome) async {
    if (!await confirmDelete(context, '${outcome['code']} (its course-outcome mappings are removed too)')) return;
    try {
      await _api.deleteProgramOutcome(outcome['id']);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _editClasses(Map<String, dynamic> program) async {
    List<Map<String, dynamic>> classes;
    try {
      classes = await _api.schoolClasses();
    } catch (e) {
      if (mounted) showApiError(context, e);
      return;
    }
    if (!mounted) return;
    final selected = {for (final c in (program['classes'] as List? ?? [])) c['id'] as String};
    final saved = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Classes in ${program['code']}'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in classes)
                  CheckboxListTile(
                    value: selected.contains(c['id']),
                    title: Text('${c['name']}'),
                    onChanged: (v) => setLocal(() => v == true ? selected.add(c['id']) : selected.remove(c['id'])),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved == null) return;
    try {
      await _api.setProgramClasses(program['id'], saved.toList());
      if (mounted) _reload();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(onPressed: _editProgram, icon: const Icon(Icons.add), label: const Text('Program'))
          : null,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingStateView(message: 'Loading programs...');
            if (snap.hasError) {
              return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
                MessageBanner(message: apiErrorMessage(snap.error!), onRetry: _reload),
              ]);
            }
            final programs = snap.data!;
            if (programs.isEmpty) {
              return ListView(children: [
                EmptyStateView(
                  icon: Icons.account_tree_outlined,
                  title: 'No programs yet',
                  message: widget.isAdmin
                      ? 'Create a program (for example a degree or stream), add its outcomes, then link its classes.'
                      : 'Your school has not defined any programs yet.',
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
              children: [for (final p in programs) _programCard(p)],
            );
          },
        ),
      ),
    );
  }

  Widget _programCard(Map<String, dynamic> p) {
    final text = Theme.of(context).textTheme;
    final outcomes = (p['outcomes'] as List? ?? []).cast<Map>();
    final classes = (p['classes'] as List? ?? []).cast<Map>();
    final groups = {
      for (final t in ['PO', 'PSO', 'PEO']) t: outcomes.where((o) => o['type'] == t).toList(),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.xlBorderRadius, border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text('${p['name']}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text('${p['code']} · ${outcomes.length} outcomes'),
              trailing: widget.isAdmin
                  ? PopupMenuButton<String>(
                      tooltip: 'Program actions',
                      onSelected: (v) {
                        if (v == 'edit') _editProgram(Map<String, dynamic>.from(p));
                        if (v == 'classes') _editClasses(Map<String, dynamic>.from(p));
                        if (v == 'delete') _deleteProgram(Map<String, dynamic>.from(p));
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit program')),
                        PopupMenuItem(value: 'classes', child: Text('Choose classes')),
                        PopupMenuItem(value: 'delete', child: Text('Delete program')),
                      ],
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: classes.isEmpty
                    ? [Text('No classes linked', style: text.bodySmall?.copyWith(color: AppColors.textMuted))]
                    : [for (final c in classes) Chip(label: Text('${c['name']}'), visualDensity: VisualDensity.compact)],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            for (final entry in groups.entries)
              if (entry.value.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: Text(
                    entry.key == 'PO' ? 'Program outcomes' : entry.key == 'PSO' ? 'Program-specific outcomes' : 'Educational objectives',
                    style: text.labelLarge?.copyWith(color: AppColors.textMuted),
                  ),
                ),
                for (final o in entry.value)
                  InfoRow(
                    title: '${o['code']}${(o['title'] ?? '').toString().isNotEmpty ? ' · ${o['title']}' : ''}',
                    subtitle: '${o['description']}',
                    trailing: widget.isAdmin
                        ? PopupMenuButton<String>(
                            tooltip: 'Outcome actions',
                            onSelected: (v) => v == 'edit'
                                ? _editOutcome(Map<String, dynamic>.from(p), Map<String, dynamic>.from(o))
                                : _deleteOutcome(Map<String, dynamic>.from(o)),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          )
                        : null,
                  ),
              ],
            if (widget.isAdmin)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _editOutcome(Map<String, dynamic>.from(p)),
                    icon: const Icon(Icons.add),
                    label: const Text('Add outcome'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
