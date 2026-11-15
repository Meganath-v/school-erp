import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/roles.dart';
import '../../../core/navigation/role_navigation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import '../../../core/widgets/state_views.dart';

/// Phone home tab: a short, role-specific summary built from live API data,
/// with shortcuts into the role's full screens.
class RoleHomeScreen extends ConsumerStatefulWidget {
  final RoleNavigation navigation;
  final void Function(String sectionId) onOpenSection;

  const RoleHomeScreen({super.key, required this.navigation, required this.onOpenSection});

  @override
  ConsumerState<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _HomeData {
  final List<KpiSpec> kpis;
  final List<ListSpec> lists;
  final List<String> warnings;
  _HomeData(this.kpis, this.lists, this.warnings);
}

class KpiSpec {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sectionId;
  KpiSpec(this.label, this.value, this.icon, {this.color = AppColors.primaryAccent, this.sectionId});
}

class ListSpec {
  final String title;
  final IconData icon;
  final List<InfoRow> rows;
  final String? sectionId;
  final String emptyText;
  ListSpec(this.title, this.icon, this.rows, {this.sectionId, this.emptyText = 'Nothing here yet.'});
}

class _RoleHomeScreenState extends ConsumerState<RoleHomeScreen> {
  late Future<_HomeData> _future;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  // Fetches one endpoint; failures are collected so the rest of the page still renders.
  Future<dynamic> _get(String path, List<String> warnings, {Map<String, dynamic>? query}) async {
    try {
      final res = await _api.dio.get(path, queryParameters: query);
      return res.data is Map ? res.data['data'] : null;
    } catch (e) {
      final ex = toApiException(e);
      if (ex.isConnectivity || ex.kind == ApiErrorKind.unauthorized) rethrow;
      warnings.add(ex.message);
      return null;
    }
  }

  Future<_HomeData> _load() async {
    final role = widget.navigation.role;
    final warnings = <String>[];
    final currency = ref.read(authProvider).activeSchool?.currency ?? 'INR';
    final money = NumberFormat.compactSimpleCurrency(locale: 'en_IN', name: currency);
    String fmtMoney(dynamic v) => v is num ? money.format(v) : '—';
    String n(dynamic v) => v is num ? NumberFormat.decimalPattern('en_IN').format(v) : '—';

    switch (role) {
      case AppRoles.platformOwner:
        final results = await Future.wait([_get('/platform/stats', warnings), _get('/platform/schools', warnings)]);
        final stats = results[0] is Map ? results[0] as Map : const {};
        final schools = results[1] is List ? results[1] as List : const [];
        return _HomeData([
          KpiSpec('Schools', n(stats['totalSchools']), Icons.domain, sectionId: 'schools'),
          KpiSpec('Active schools', n(stats['activeSchools']), Icons.check_circle_outline, color: AppColors.success),
          KpiSpec('Students', n(stats['totalStudents']), Icons.school_outlined, color: AppColors.secondary),
          KpiSpec('Annual revenue', stats['estimatedArrMinor'] is num ? fmtMoney((stats['estimatedArrMinor'] as num) / 100) : '—',
              Icons.payments_outlined, color: AppColors.warning),
        ], [
          ListSpec('Schools', Icons.apartment_outlined, [
            for (final s in schools.take(5))
              InfoRow(
                icon: Icons.apartment_outlined,
                title: '${s['name']}',
                subtitle: '${s['code']} · ${s['studentCount'] ?? 0} students',
                trailing: StatusChip.forStatus('${s['status'] ?? ''}'),
              ),
          ], sectionId: 'schools', emptyText: 'No schools have been created yet.'),
        ], warnings);

      case AppRoles.schoolAdmin:
      case AppRoles.principal:
      case AppRoles.office:
        final results = await Future.wait([
          _get('/reports/overview', warnings),
          if (role == AppRoles.office) _get('/tasks', warnings) else _get('/leave-requests', warnings),
        ]);
        final overview = results[0] is Map ? results[0] as Map : const {};
        final stats = overview['stats'] is Map ? overview['stats'] as Map : const {};
        final announcements = overview['recentAnnouncements'] is List ? overview['recentAnnouncements'] as List : const [];
        final second = results[1] is List ? results[1] as List : const [];
        final rate = stats['todayAttendanceRate'];
        final attendance = rate is num
            ? '${rate.toStringAsFixed(0)}%'
            : (stats['isAttendanceMarkedToday'] == true ? 'Marked' : 'Not marked');

        final kpis = <KpiSpec>[
          KpiSpec('Students', n(stats['totalStudents']), Icons.school_outlined,
              sectionId: widget.navigation.indexOf('students') >= 0 ? 'students' : null),
          KpiSpec("Today's attendance", attendance, Icons.fact_check_outlined, color: AppColors.success,
              sectionId: widget.navigation.indexOf('attendance') >= 0 ? 'attendance' : null),
          KpiSpec('Fees collected', fmtMoney(stats['totalCollected']), Icons.payments_outlined, color: AppColors.secondary,
              sectionId: widget.navigation.indexOf('fees') >= 0 ? 'fees' : null),
          KpiSpec('Fees due', fmtMoney(stats['totalDue']), Icons.receipt_long_outlined, color: AppColors.warning,
              sectionId: widget.navigation.indexOf('fees') >= 0 ? 'fees' : null),
        ];
        if (role == AppRoles.principal) {
          kpis[2] = KpiSpec('Staff', n(stats['totalStaff']), Icons.badge_outlined, color: AppColors.secondary);
          kpis[3] = KpiSpec('Pending leave', n(stats['pendingLeavesCount']), Icons.event_busy_outlined,
              color: AppColors.warning, sectionId: 'dashboard');
        }

        final pendingSecond = second.where((x) => '${x['status']}'.toUpperCase() == 'PENDING').toList();
        return _HomeData(kpis, [
          if (role == AppRoles.office)
            ListSpec('Pending tasks', Icons.task_alt_outlined, [
              for (final t in pendingSecond.take(5))
                InfoRow(
                  icon: Icons.task_alt_outlined,
                  title: '${t['title']}',
                  subtitle: _dueText(t['dueDate']),
                  trailing: StatusChip.forStatus('${t['priority'] ?? 'NORMAL'}' == 'HIGH' ? 'OVERDUE' : 'PENDING'),
                ),
            ], sectionId: 'dashboard', emptyText: 'No pending tasks.')
          else
            ListSpec('Leave requests awaiting decision', Icons.event_busy_outlined, [
              for (final l in pendingSecond.take(5))
                InfoRow(
                  icon: Icons.person_outline,
                  title: '${l['studentName'] ?? l['applicantName'] ?? 'Leave request'}',
                  subtitle: '${l['className'] ?? ''} ${l['sectionName'] ?? ''} · ${_dateRange(l['startDate'], l['endDate'])}'.trim(),
                  trailing: StatusChip.forStatus('${l['status']}'),
                ),
            ], sectionId: 'dashboard', emptyText: 'No leave requests are waiting.'),
          ListSpec('Recent announcements', Icons.campaign_outlined, [
            for (final a in announcements.take(3))
              InfoRow(
                icon: Icons.campaign_outlined,
                title: '${a['title']}',
                subtitle: '${a['authorName'] ?? ''} · ${_date(a['publishedAt'])}',
              ),
          ], sectionId: widget.navigation.indexOf('circulars') >= 0 ? 'circulars' : null, emptyText: 'No announcements yet.'),
        ], warnings);

      case AppRoles.classTeacher:
        final results = await Future.wait([
          _get('/attendance/today', warnings),
          _get('/leave-requests', warnings),
          _get('/assignments', warnings),
        ]);
        final today = results[0] is Map ? results[0] as Map : const {};
        final section = today['section'] is Map ? today['section'] as Map : null;
        final students = today['students'] is List ? today['students'] as List : const [];
        final atRisk = students.where((s) => s['isShortageRisk'] == true).length;
        final leaves = (results[1] is List ? results[1] as List : const [])
            .where((x) => '${x['status']}'.toUpperCase() == 'PENDING')
            .toList();
        final assignments = results[2] is List ? results[2] as List : const [];
        return _HomeData([
          KpiSpec('My class', section == null ? 'Not assigned' : '${section['className']} ${section['name']}',
              Icons.groups_outlined, sectionId: 'myclass'),
          KpiSpec("Today's register", today['session'] == null ? 'Not marked' : 'Marked', Icons.fact_check_outlined,
              color: today['session'] == null ? AppColors.warning : AppColors.success, sectionId: 'myclass'),
          KpiSpec('Students', n(students.length), Icons.school_outlined, color: AppColors.secondary, sectionId: 'myclass'),
          KpiSpec('Attendance risk', n(atRisk), Icons.warning_amber_outlined, color: AppColors.error, sectionId: 'attendance'),
        ], [
          ListSpec('Leave requests', Icons.event_busy_outlined, [
            for (final l in leaves.take(5))
              InfoRow(
                icon: Icons.person_outline,
                title: '${l['studentName'] ?? 'Student'}',
                subtitle: '${l['leaveType'] ?? ''} · ${_dateRange(l['startDate'], l['endDate'])}',
                trailing: StatusChip.forStatus('${l['status']}'),
              ),
          ], sectionId: 'myclass', emptyText: 'No leave requests are waiting.'),
          _assignmentsList(assignments, sectionId: null),
        ], warnings);

      case AppRoles.subjectTeacher:
        final results = await Future.wait([_get('/timetable/entries', warnings), _get('/assignments', warnings)]);
        final entries = results[0] is List ? results[0] as List : const [];
        final assignments = results[1] is List ? results[1] as List : const [];
        final todays = _todaysPeriods(entries);
        return _HomeData([
          KpiSpec("Today's periods", n(todays.length), Icons.schedule_outlined, sectionId: 'timetable'),
          KpiSpec('Weekly periods', n(entries.length), Icons.calendar_view_week_outlined,
              color: AppColors.secondary, sectionId: 'timetable'),
          KpiSpec('Assignments', n(assignments.length), Icons.assignment_outlined,
              color: AppColors.warning, sectionId: 'teaching'),
          KpiSpec('Submissions', n(assignments.fold<num>(0, (s, a) => s + ((a['submissionsCount'] as num?) ?? 0))),
              Icons.upload_file_outlined, color: AppColors.success, sectionId: 'teaching'),
        ], [
          _periodsList(todays, sectionId: 'timetable', showClass: true),
          _assignmentsList(assignments, sectionId: 'teaching'),
        ], warnings);

      case AppRoles.parent:
        final results = await Future.wait([
          _get('/students', warnings),
          _get('/fees/invoices', warnings),
          _get('/circulars', warnings),
        ]);
        final children = results[0] is List ? results[0] as List : const [];
        final invoices = results[1] is List ? results[1] as List : const [];
        final circulars = results[2] is List ? results[2] as List : const [];
        final due = invoices.fold<num>(0, (s, i) => s + ((i['dueAmount'] as num?) ?? 0));
        final unpaid = invoices.where((i) => ((i['dueAmount'] as num?) ?? 0) > 0).toList();
        return _HomeData([
          KpiSpec('Children', n(children.length), Icons.family_restroom_outlined, sectionId: 'portal'),
          KpiSpec('Fees due', fmtMoney(due), Icons.receipt_long_outlined,
              color: due > 0 ? AppColors.warning : AppColors.success, sectionId: 'portal'),
        ], [
          ListSpec('My children', Icons.family_restroom_outlined, [
            for (final c in children)
              InfoRow(
                icon: Icons.child_care_outlined,
                title: '${c['fullName'] ?? '${c['firstName']} ${c['lastName']}'}',
                subtitle: '${c['currentClass'] ?? ''} ${c['currentSection'] ?? ''} · ${c['admissionNo'] ?? ''}'.trim(),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onOpenSection('portal'),
              ),
          ], sectionId: 'portal', emptyText: 'No children are linked to this account.'),
          ListSpec('Unpaid fees', Icons.receipt_long_outlined, [
            for (final i in unpaid.take(5))
              InfoRow(
                icon: Icons.receipt_long_outlined,
                title: '${i['title']}',
                subtitle: '${i['studentName'] ?? ''} · due ${_date(i['dueDate'])}',
                trailing: Text(fmtMoney(i['dueAmount']), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
          ], sectionId: 'portal', emptyText: 'All fees are paid.'),
          _circularsList(circulars),
        ], warnings);

      case AppRoles.student:
        final results = await Future.wait([
          _get('/students/me/profile', warnings),
          _get('/timetable/entries', warnings),
          _get('/assignments', warnings),
        ]);
        final profile = results[0] is Map ? results[0] as Map : const {};
        final entries = results[1] is List ? results[1] as List : const [];
        final assignments = results[2] is List ? results[2] as List : const [];
        final todays = _todaysPeriods(entries);
        return _HomeData([
          KpiSpec('Class', profile.isEmpty ? '—' : '${profile['className'] ?? ''} ${profile['sectionName'] ?? ''}'.trim(),
              Icons.class_outlined, sectionId: 'portal'),
          KpiSpec('Roll no.', '${profile['rollNo'] ?? '—'}', Icons.badge_outlined, color: AppColors.secondary),
          KpiSpec("Today's periods", n(todays.length), Icons.schedule_outlined, color: AppColors.success, sectionId: 'portal'),
          KpiSpec('Assignments', n(assignments.length), Icons.assignment_outlined, color: AppColors.warning, sectionId: 'portal'),
        ], [
          _periodsList(todays, sectionId: 'portal', showClass: false),
          _assignmentsList(assignments, sectionId: 'portal'),
        ], warnings);
    }
    return _HomeData(const [], const [], warnings);
  }

  List<dynamic> _todaysPeriods(List entries) {
    final today = DateTime.now().weekday; // 1 = Monday, matching the API's dayOfWeek
    final list = entries.where((e) => e['dayOfWeek'] == today).toList()
      ..sort((a, b) => ((a['periodNumber'] as num?) ?? 0).compareTo((b['periodNumber'] as num?) ?? 0));
    return list;
  }

  ListSpec _periodsList(List periods, {required String sectionId, required bool showClass}) {
    return ListSpec("Today's timetable", Icons.schedule_outlined, [
      for (final p in periods)
        InfoRow(
          icon: Icons.schedule_outlined,
          title: '${p['subjectName'] ?? 'Period'}',
          subtitle: [
            'Period ${p['periodNumber']} · ${p['startTime'] ?? ''}–${p['endTime'] ?? ''}',
            if (showClass) '${p['className'] ?? ''} ${p['sectionName'] ?? ''}'.trim() else '${p['teacherName'] ?? ''}',
            if ((p['room'] ?? '').toString().isNotEmpty) 'Room ${p['room']}',
          ].where((s) => s.isNotEmpty).join(' · '),
        ),
    ], sectionId: sectionId, emptyText: 'No classes scheduled today.');
  }

  ListSpec _assignmentsList(List assignments, {String? sectionId}) {
    final sorted = [...assignments]..sort((a, b) => '${a['dueDate']}'.compareTo('${b['dueDate']}'));
    return ListSpec('Assignments', Icons.assignment_outlined, [
      for (final a in sorted.take(5))
        InfoRow(
          icon: Icons.assignment_outlined,
          title: '${a['title']}',
          subtitle: '${a['subjectName'] ?? ''} · ${_dueText(a['dueDate'])}',
          trailing: a['status'] != null ? StatusChip.forStatus('${a['status']}') : null,
        ),
    ], sectionId: sectionId, emptyText: 'No assignments.');
  }

  ListSpec _circularsList(List circulars) {
    return ListSpec('Circulars', Icons.campaign_outlined, [
      for (final c in circulars.take(3))
        InfoRow(icon: Icons.campaign_outlined, title: '${c['title']}', subtitle: _date(c['publishedAt'] ?? c['createdAt'])),
    ], emptyText: 'No circulars yet.');
  }

  static String _date(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}');
    return d == null ? '' : DateFormat('d MMM y').format(d.toLocal());
  }

  static String _dateRange(dynamic a, dynamic b) {
    final s = _date(a), e = _date(b);
    if (s.isEmpty) return e;
    if (e.isEmpty || e == s) return s;
    return '$s – $e';
  }

  static String _dueText(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}');
    if (d == null) return 'No due date';
    final days = DateTime(d.year, d.month, d.day).difference(DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0)).inDays;
    if (days < 0) return 'Overdue since ${DateFormat('d MMM').format(d.toLocal())}';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due ${DateFormat('d MMM').format(d.toLocal())}';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final text = Theme.of(context).textTheme;
    final firstName = auth.user?.firstName.isNotEmpty == true ? auth.user!.firstName : (auth.user?.name ?? '');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snap) {
          final header = Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_greeting()}${firstName.isNotEmpty ? ', $firstName' : ''}',
                    style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(
                  '${AppRoles.label(auth.activeRole)} · ${auth.activeSchool?.name ?? ''}',
                  style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          );

          if (snap.connectionState != ConnectionState.done) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [header, const SizedBox(height: 120, child: LoadingStateView(message: 'Loading your summary...'))],
            );
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ErrorStateView(
                    title: 'Could not load your summary',
                    errorMessage: apiErrorMessage(snap.error!),
                    onRetry: _refresh,
                  ),
                ),
              ],
            );
          }

          final data = snap.data!;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              header,
              if (data.warnings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                  child: MessageBanner(message: 'Some information could not be loaded: ${data.warnings.toSet().join(' ')}'),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: KpiGrid(tiles: [
                  for (final k in data.kpis)
                    KpiTile(
                      label: k.label,
                      value: k.value,
                      icon: k.icon,
                      color: k.color,
                      onTap: k.sectionId == null ? null : () => widget.onOpenSection(k.sectionId!),
                    ),
                ]),
              ),
              for (final l in data.lists)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                  child: SectionCard(
                    title: l.title,
                    icon: l.icon,
                    actionLabel: l.sectionId != null ? 'View all' : null,
                    onAction: l.sectionId != null ? () => widget.onOpenSection(l.sectionId!) : null,
                    empty: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(l.emptyText, style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                    ),
                    children: l.rows,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
                child: Text('Quick access', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final s in widget.navigation.sections)
                      ActionChip(
                        avatar: Icon(s.icon, size: 18),
                        label: Text(s.label),
                        onPressed: () => widget.onOpenSection(s.id),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
