import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/roles.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../data/outcomes_api.dart';
import 'assessments_tab.dart';
import 'attainment_tab.dart';
import 'course_outcomes_tab.dart';
import 'programs_tab.dart';
import 'question_bank_tab.dart';

/// Outcome-based education: programs and outcomes, course outcomes and mapping,
/// question bank, question papers with question-wise marks, and attainment.
class OutcomesScreen extends ConsumerStatefulWidget {
  const OutcomesScreen({super.key});

  @override
  ConsumerState<OutcomesScreen> createState() => _OutcomesScreenState();
}

class _OutcomesScreenState extends ConsumerState<OutcomesScreen> with SingleTickerProviderStateMixin {
  final _api = OutcomesApi();
  late final TabController _tabs = TabController(length: 5, vsync: this);
  List<Map<String, dynamic>> _subjects = [];
  String? _subjectId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.subjects();
      if (!mounted) return;
      setState(() {
        _subjects = list;
        _subjectId = list.any((s) => s['id'] == _subjectId) ? _subjectId : (list.isNotEmpty ? list.first['id'] as String : null);
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

  Map<String, dynamic>? get _subject => _subjects.where((s) => s['id'] == _subjectId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).activeRole;
    final isAdmin = role == AppRoles.schoolAdmin || role == AppRoles.principal;

    return Column(
      children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Programs'),
              Tab(text: 'Course outcomes'),
              Tab(text: 'Question bank'),
              Tab(text: 'Papers & marks'),
              Tab(text: 'Attainment'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              ProgramsTab(isAdmin: isAdmin),
              _subjectScoped((s) => CourseOutcomesTab(key: ValueKey('co-${s['id']}'), subject: s)),
              _subjectScoped((s) => QuestionBankTab(key: ValueKey('qb-${s['id']}'), subject: s)),
              _subjectScoped((s) => AssessmentsTab(key: ValueKey('as-${s['id']}'), subject: s)),
              _subjectScoped((s) => AttainmentTab(key: ValueKey('at-${s['id']}'), subject: s, isAdmin: isAdmin)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subjectScoped(Widget Function(Map<String, dynamic> subject) builder) {
    if (_loading) return const LoadingStateView(message: 'Loading subjects...');
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        MessageBanner(message: _error!, onRetry: _loadSubjects),
      ]);
    }
    if (_subjects.isEmpty) {
      return const EmptyStateView(
        icon: Icons.menu_book_outlined,
        title: 'No subjects',
        message: 'You are not assigned to any subject yet. Ask your school administrator to assign you.',
      );
    }
    final subject = _subject!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: DropdownButtonFormField<String>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.menu_book_outlined)),
            items: [
              for (final s in _subjects)
                DropdownMenuItem(
                  value: s['id'] as String,
                  child: Text('${s['name']} (${s['code']})${s['canEdit'] == true ? '' : ' · view only'}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _subjectId = v),
          ),
        ),
        Expanded(child: builder(subject)),
      ],
    );
  }
}

// ---------------------------------------------------------------- shared helpers

/// Shows a SnackBar with the error message of [e].
void showApiError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
}

void showDone(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $what?'),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// A scrollable dialog with a form; [onSubmit] returns an error message or null.
Future<bool> showFormDialog(
  BuildContext context, {
  required String title,
  required List<Widget> Function(void Function(VoidCallback) setState) fields,
  required GlobalKey<FormState> formKey,
  required Future<String?> Function() onSubmit,
  String submitLabel = 'Save',
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      var busy = false;
      String? error;
      return StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...fields(setLocal),
                    if (error != null) ...[const SizedBox(height: AppSpacing.md), MessageBanner(message: error!)],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setLocal(() {
                        busy = true;
                        error = null;
                      });
                      final problem = await onSubmit();
                      if (!ctx.mounted) return;
                      if (problem == null) {
                        Navigator.pop(ctx, true);
                      } else {
                        setLocal(() {
                          busy = false;
                          error = problem;
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(submitLabel),
            ),
          ],
        );
      });
    },
  );
  return saved == true;
}

/// Runs [action]; returns null on success or the API error message.
Future<String?> tryApi(Future<void> Function() action) async {
  try {
    await action();
    return null;
  } catch (e) {
    return apiErrorMessage(e);
  }
}

String? requiredText(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

/// Level chip coloured by how it compares to the target.
class LevelBadge extends StatelessWidget {
  final num? level;
  final num target;
  final bool large;
  const LevelBadge({super.key, required this.level, this.target = 2, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = level == null
        ? AppColors.textMuted
        : (level! >= target ? AppColors.success : (level! >= target - 1 ? AppColors.warning : AppColors.error));
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 8, vertical: large ? 8 : 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadius.pillBorderRadius),
      child: Text(
        level == null ? 'Not assessed' : 'Level ${formatLevel(level)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: large ? 16 : 12),
      ),
    );
  }
}
