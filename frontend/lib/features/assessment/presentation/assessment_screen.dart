import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../outcomes/data/outcomes_api.dart';
import 'internal_marks_tab.dart';
import 'quizzes_tab.dart';
import 'weak_students_tab.dart';

/// Internal marks, weak-student identification and quizzes for one subject.
class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> with SingleTickerProviderStateMixin {
  final _api = OutcomesApi();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  List<Map<String, dynamic>> _subjects = [];
  String? _subjectId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _api.subjects();
      if (!mounted) return;
      setState(() {
        _subjects = s;
        _subjectId ??= s.isNotEmpty ? s.first['id'] as String : null;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingStateView(message: 'Loading subjects...');
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: _error!, onRetry: _load)]);
    }
    if (_subjects.isEmpty) {
      return const EmptyStateView(icon: Icons.menu_book_outlined, title: 'No subjects', message: 'You are not assigned to any subject yet.');
    }
    final subject = _subjects.firstWhere((s) => s['id'] == _subjectId);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        child: DropdownButtonFormField<String>(
          initialValue: _subjectId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.menu_book_outlined)),
          items: [
            for (final s in _subjects)
              DropdownMenuItem(
                value: s['id'] as String,
                child: Text('${s['name']} (${s['code']})${s['canEdit'] == true ? '' : ' · view only'}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _subjectId = v),
        ),
      ),
      TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [Tab(text: 'Internal marks'), Tab(text: 'Weak students'), Tab(text: 'Quizzes')],
      ),
      const Divider(height: 1),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          InternalMarksTab(key: ValueKey('im-$_subjectId'), subject: subject),
          WeakStudentsTab(key: ValueKey('ws-$_subjectId'), subject: subject),
          QuizzesTab(key: ValueKey('qz-$_subjectId'), subject: subject),
        ]),
      ),
    ]);
  }
}
