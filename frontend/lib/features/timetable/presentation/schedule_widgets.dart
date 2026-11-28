import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../data/timetable_api.dart';

/// Resolves which section a screen works on: the class teacher's own section,
/// or a section the office picks. Renders [builder] with the chosen section id.
class SectionScope extends StatefulWidget {
  final TimetableApi api;
  final bool pickAny;
  final Widget Function(String sectionId) builder;
  const SectionScope({super.key, required this.api, required this.pickAny, required this.builder});

  @override
  State<SectionScope> createState() => _SectionScopeState();
}

class _SectionScopeState extends State<SectionScope> {
  bool _loading = true;
  String? _error;
  String? _sectionId;
  List<Map<String, dynamic>> _sections = [];

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
      if (widget.pickAny) {
        final classes = await widget.api.classes();
        _sections = [
          for (final c in classes)
            for (final s in TimetableApi.list(c['sections']))
              {'id': s['id'], 'label': '${c['name']} ${s['name']}'},
        ];
        _sectionId ??= _sections.isEmpty ? null : _sections.first['id'] as String;
      } else {
        final mine = await widget.api.myClassSection();
        _sectionId = mine?['sectionId'] as String?;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingStateView(message: 'Loading class…');
    if (_error != null) return ErrorStateView(title: 'Could not load', errorMessage: _error!, onRetry: _load);
    if (_sectionId == null) {
      return EmptyStateView(
        icon: Icons.groups_outlined,
        title: widget.pickAny ? 'No classes yet' : 'You are not a class teacher',
        message: widget.pickAny ? 'Add classes and sections first.' : 'Only the class teacher of a class can manage its timetable.',
      );
    }
    final child = widget.builder(_sectionId!);
    if (!widget.pickAny) return child;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        child: DropdownButtonFormField<String>(
          key: const ValueKey('section-picker'),
          initialValue: _sectionId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Class', isDense: true, border: OutlineInputBorder()),
          items: [for (final s in _sections) DropdownMenuItem(value: s['id'] as String, child: Text(s['label'] as String))],
          onChanged: (v) => setState(() => _sectionId = v),
        ),
      ),
      Expanded(child: KeyedSubtree(key: ValueKey(_sectionId), child: child)),
    ]);
  }
}

/// "‹  Sat 28 Nov 2026  ›" with a date picker on tap.
class DateStepper extends StatelessWidget {
  final String date;
  final ValueChanged<String> onChanged;
  final String? badge;
  const DateStepper({super.key, required this.date, required this.onChanged, this.badge});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse(date);
    return Row(children: [
      IconButton(
        tooltip: 'Previous day',
        icon: const Icon(Icons.chevron_left),
        onPressed: () => onChanged(dateText(d.subtract(const Duration(days: 1)))),
      ),
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: d,
              firstDate: DateTime(d.year - 1),
              lastDate: DateTime(d.year + 1, 12, 31),
            );
            if (picked != null) onChanged(dateText(picked));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(children: [
              Text(niceDate(date), style: const TextStyle(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              if (badge != null) Text(badge!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Next day',
        icon: const Icon(Icons.chevron_right),
        onPressed: () => onChanged(dateText(d.add(const Duration(days: 1)))),
      ),
    ]);
  }
}

String periodTitle(Map<String, dynamic> p) {
  final label = (p['label'] as String?)?.trim();
  final name = (label != null && label.isNotEmpty) ? label : 'Period ${p['periodNumber']}';
  final start = p['startTime'] as String? ?? '';
  final end = p['endTime'] as String? ?? '';
  return start.isEmpty ? name : '$name · $start–$end';
}

String teacherName(dynamic t) => t is Map ? (t['name'] as String? ?? '') : '';

String teacherLogin(dynamic t) {
  if (t is! Map) return '';
  final u = t['username'] as String?;
  if (u != null && u.isNotEmpty) return u;
  return t['email'] as String? ?? '';
}
