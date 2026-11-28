import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../ai_exam/presentation/widgets/ai_widgets.dart' show Pill;
import '../data/timetable_api.dart';
import 'period_attendance_screen.dart';
import 'schedule_widgets.dart';

/// The signed-in teacher's periods for a day (including periods they cover as a substitute).
/// Tapping a period opens its attendance.
class MyDayView extends StatefulWidget {
  final TimetableApi api;
  const MyDayView({super.key, required this.api});

  @override
  State<MyDayView> createState() => _MyDayViewState();
}

class _MyDayViewState extends State<MyDayView> {
  bool _loading = true;
  String? _error;
  String _date = dateText(DateTime.now());
  Map<String, dynamic> _data = {};

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
      final r = await widget.api.myDay(_date);
      if (!mounted) return;
      setState(() {
        _data = r;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e);
        });
      }
    }
  }

  Future<void> _open(Map<String, dynamic> p) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PeriodAttendanceScreen(
        api: widget.api,
        sectionId: p['sectionId'] as String,
        date: _date,
        periodNumber: p['periodNumber'] as int,
      ),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final periods = TimetableApi.list(_data['periods']);
    final toTake = periods.where((p) => p['canTakeAttendance'] == true && p['attendanceTaken'] != true).length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: DateStepper(
          date: _date,
          badge: _data['isToday'] == true ? (toTake > 0 ? 'Today · $toTake to take' : 'Today') : null,
          onChanged: (d) {
            _date = d;
            _load();
          },
        ),
      ),
      Expanded(
        child: _loading
            ? const LoadingStateView(message: 'Loading your periods…')
            : _error != null
                ? ErrorStateView(title: 'Could not load', errorMessage: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                      children: [
                        if (_data['isToday'] != true)
                          const Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.md),
                            child: MessageBanner(message: 'Attendance can be taken or changed only on the day.', isError: false),
                          ),
                        if (periods.isEmpty)
                          EmptyStateView(
                            icon: Icons.free_breakfast_outlined,
                            title: 'No periods',
                            message: 'You have no periods on ${_data['dayName'] ?? 'this day'}.',
                          )
                        else
                          SectionCard(
                            title: 'My periods',
                            icon: Icons.view_agenda_outlined,
                            children: [for (final p in periods) _row(p)],
                          ),
                      ],
                    ),
                  ),
      ),
    ]);
  }

  Widget _row(Map<String, dynamic> p) {
    final subject = TimetableApi.map(p['subject'])['name'] as String?;
    final handed = p['handedOverTo'];
    final time = (p['startTime'] as String?)?.isNotEmpty == true ? '${p['startTime']}–${p['endTime']}' : '';
    return InfoRow(
      icon: p['isSubstitution'] == true ? Icons.swap_horiz : Icons.class_outlined,
      title: 'P${p['periodNumber']}${time.isEmpty ? '' : ' · $time'} · ${p['className']} ${p['sectionName']}',
      subtitle: [
        ?subject,
        if (p['isSubstitution'] == true) 'You are the substitute',
        if (handed != null) 'Given to ${teacherName(handed)} today',
      ].join(' · '),
      trailing: handed != null
          ? const Pill(label: 'Covered', color: AppColors.textMuted)
          : p['attendanceTaken'] == true
              ? const Pill(label: 'Taken', color: AppColors.success, icon: Icons.check)
              : p['canTakeAttendance'] == true
                  ? const Pill(label: 'Take', color: AppColors.primaryAccent)
                  : null,
      onTap: handed != null ? null : () => _open(p),
    );
  }
}
