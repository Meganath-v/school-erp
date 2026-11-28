import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/roles.dart';
import '../data/timetable_api.dart';
import 'bell_schedule_view.dart';
import 'class_timetable_view.dart';
import 'daily_periods_view.dart';
import 'my_day_view.dart';
import 'schedule_widgets.dart';
import 'timetable_management_screen.dart';

/// Timetable section. What each role sees:
///  - office / admin / principal: class timetables of any class, daily periods (substitutions), the bell schedule
///  - class teacher: their periods, their class's timetable and daily periods, the bell schedule (read-only)
///  - subject teacher: their periods and the bell schedule (read-only)
/// The earlier weekly matrix stays available as "Overview".
class TimetableHubScreen extends ConsumerStatefulWidget {
  final TimetableApi? api;
  const TimetableHubScreen({super.key, this.api});

  @override
  ConsumerState<TimetableHubScreen> createState() => _TimetableHubScreenState();
}

class _TimetableHubScreenState extends ConsumerState<TimetableHubScreen> {
  late final TimetableApi _api = widget.api ?? TimetableApi();

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).activeRole;
    final office = role == AppRoles.office || role == AppRoles.schoolAdmin || role == AppRoles.principal;
    final classTeacher = role == AppRoles.classTeacher;

    final tabs = <(String, IconData, Widget)>[
      if (!office) ('My periods', Icons.today_outlined, MyDayView(api: _api)),
      if (office || classTeacher)
        ('Class timetable', Icons.grid_view_outlined, SectionScope(api: _api, pickAny: office, builder: (id) => ClassTimetableView(api: _api, sectionId: id))),
      if (office || classTeacher)
        ('Daily periods', Icons.swap_horiz, SectionScope(api: _api, pickAny: office, builder: (id) => DailyPeriodsView(api: _api, sectionId: id, officeView: office))),
      ('Periods', Icons.schedule_outlined, BellScheduleView(api: _api, canEdit: office)),
      if (role != AppRoles.office) ('Overview', Icons.table_chart_outlined, const TimetableManagementScreen()),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(icon: Icon(t.$2, size: 18), text: t.$1)],
          ),
        ),
        Expanded(child: TabBarView(children: [for (final t in tabs) t.$3])),
      ]),
    );
  }
}
