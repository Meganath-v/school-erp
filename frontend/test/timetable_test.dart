import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/navigation/role_navigation.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/class_teacher/presentation/add_student_dialog.dart';
import 'package:frontend/features/timetable/data/timetable_api.dart';
import 'package:frontend/features/timetable/presentation/bell_schedule_view.dart';
import 'package:frontend/features/timetable/presentation/class_timetable_view.dart';
import 'package:frontend/features/timetable/presentation/daily_periods_view.dart';
import 'package:frontend/features/timetable/presentation/my_day_view.dart';
import 'package:frontend/features/timetable/presentation/period_attendance_screen.dart';
import 'helpers/fake_adapter.dart';

Map<String, dynamic> _env(Object data) => {'data': data};
Object? _body(RequestOptions o) => o.data is String ? jsonDecode(o.data as String) : o.data;
String _path(RequestOptions o) => o.uri.path.replaceFirst('/api/v1', '');

final _today = dateText(DateTime.now());
const _jones = {'staffId': 'st-j', 'name': 'David Jones', 'email': 'teacher.jones@oakridge.edu', 'username': 'teacherjones'};
const _smith = {'staffId': 'st-s', 'name': 'Sarah Smith', 'email': 'teacher.smith@oakridge.edu', 'username': 'teachersmith'};

Map<String, dynamic> _classTimetable({bool canEdit = true, List<Map<String, dynamic>> entries = const []}) => {
      'section': {'id': 'sec-a', 'name': 'Section A', 'classId': 'c10', 'className': 'Grade 10'},
      'canEdit': canEdit,
      'periods': [
        for (final d in [1, 2, 3, 4, 5, 6]) ...[
          {'dayOfWeek': d, 'periodNumber': 1, 'startTime': '09:00', 'endTime': '09:45', 'label': null},
          {'dayOfWeek': d, 'periodNumber': 2, 'startTime': '09:45', 'endTime': '10:30', 'label': null},
        ],
      ],
      'entries': entries,
      'subjects': [
        {'id': 'sub-m', 'name': 'Mathematics', 'code': 'M'},
        {'id': 'sub-e', 'name': 'English Literature', 'code': 'E'},
      ],
    };

void main() {
  final api = ApiClient();
  late FakeAdapter adapter;

  Future<void> pump(WidgetTester tester, Widget home, FakeHandler handler) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    api.clearAuth();
    api.setBaseUrl('http://test.local:3000/api/v1');
    adapter = FakeAdapter(handler);
    api.debugSetAdapter(adapter);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: home)));
    await tester.pumpAndSettle();
  }

  testWidgets('office: empty bell schedule → standard 8 periods for Monday–Saturday', (tester) async {
    Object? sent;
    await pump(tester, BellScheduleView(api: TimetableApi(), canEdit: true), (o) {
      if (o.method == 'PUT' && _path(o) == '/timetable/periods') {
        sent = _body(o);
        return FakeResponse(200, _env({'periods': (sent as Map)['periods']}));
      }
      return FakeResponse(200, _env({'periods': []}));
    });
    expect(find.text('No periods yet'), findsOneWidget);
    await tester.tap(find.text('Use standard 8 periods'));
    await tester.pumpAndSettle();
    final periods = (sent as Map)['periods'] as List;
    expect(periods.length, 48);
    expect(periods.first, {'dayOfWeek': 1, 'periodNumber': 1, 'startTime': '09:00', 'endTime': '09:45'});
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Period 1 · 09:00–09:45'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teachers see the bell schedule read-only', (tester) async {
    await pump(tester, BellScheduleView(api: TimetableApi(), canEdit: false), (o) {
      return FakeResponse(200, _env({
        'periods': [
          {'dayOfWeek': 1, 'periodNumber': 1, 'startTime': '09:00', 'endTime': '09:45', 'label': 'Assembly + P1'},
        ],
      }));
    });
    expect(find.text('Assembly + P1 · 09:00–09:45'), findsOneWidget);
    expect(find.text('Add period'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.textContaining('The office sets the periods'), findsOneWidget);
  });

  testWidgets('class teacher sets subject and teacher (username or email) for a period', (tester) async {
    Object? sent;
    await pump(tester, ClassTimetableView(api: TimetableApi(), sectionId: 'sec-a'), (o) {
      if (o.method == 'PUT') {
        sent = _body(o);
        return FakeResponse(200, _env(_classTimetable(entries: [
          {
            'id': 'e1', 'dayOfWeek': (sent as Map)['dayOfWeek'], 'periodNumber': 1, 'startTime': '09:00', 'endTime': '09:45',
            'subject': {'id': 'sub-e', 'name': 'English Literature', 'code': 'E'}, 'teacher': _jones, 'outsideSchedule': false,
          },
        ])));
      }
      return FakeResponse(200, _env(_classTimetable()));
    });
    expect(find.text('0 of 12 periods filled'), findsOneWidget);
    await tester.tap(find.text('Period 1 · 09:00–09:45'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Choose a subject'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English Literature').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Teacher username or email'), 'teacherjones');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((sent as Map)['teacher'], 'teacherjones');
    expect((sent as Map)['subjectId'], 'sub-e');
    expect((sent as Map)['periodNumber'], 1);
    expect(find.text('English Literature · David Jones'), findsOneWidget);
    expect(find.text('Period saved'), findsOneWidget);
  });

  testWidgets('subject teacher sees the class timetable read-only', (tester) async {
    await pump(tester, ClassTimetableView(api: TimetableApi(), sectionId: 'sec-a'), (o) => FakeResponse(200, _env(_classTimetable(canEdit: false))));
    await tester.tap(find.text('Period 1 · 09:00–09:45'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Tap a period'), findsNothing);
  });

  Map<String, dynamic> daily({bool taken = false, Map<String, dynamic>? sub}) => {
        'section': {'id': 'sec-a', 'name': 'Section A', 'className': 'Grade 10'},
        'date': _today,
        'dayOfWeek': 1,
        'dayName': 'Monday',
        'isToday': true,
        'canEdit': true,
        'periods': [
          {
            'dayOfWeek': 1, 'periodNumber': 1, 'startTime': '09:00', 'endTime': '09:45', 'label': null,
            'subject': {'id': 'sub-m', 'name': 'Mathematics'}, 'teacher': _smith,
            'substitution': sub,
            'effectiveTeacher': sub == null ? _smith : sub['teacher'],
            'effectiveSubject': {'id': 'sub-m', 'name': 'Mathematics'},
            'attendanceTaken': taken, 'canTakeAttendance': sub == null, 'canChange': !taken,
          },
        ],
      };

  testWidgets('class teacher gives a period to a substitute for the day', (tester) async {
    Object? sent;
    await pump(tester, DailyPeriodsView(api: TimetableApi(), sectionId: 'sec-a'), (o) {
      if (o.method == 'PUT') {
        sent = _body(o);
        return FakeResponse(200, _env(daily(sub: {'id': 'x', 'teacher': _jones, 'subject': null, 'reason': 'On leave'})));
      }
      if (_path(o).startsWith('/timetable/class/')) return FakeResponse(200, _env(_classTimetable()));
      return FakeResponse(200, _env(daily()));
    });
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Mathematics · Sarah Smith'), findsOneWidget);
    await tester.tap(find.text('Period 1 · 09:00–09:45'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give this period to another teacher'));
    await tester.pumpAndSettle();
    expect(find.text('Timetable teacher: Sarah Smith'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Substitute username or email'), 'teacher.jones@oakridge.edu');
    await tester.enterText(find.widgetWithText(TextField, 'Reason (optional)'), 'On leave');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((sent as Map)['teacher'], 'teacher.jones@oakridge.edu');
    expect((sent as Map)['date'], _today);
    expect((sent as Map)['periodNumber'], 1);
    expect((sent as Map).containsKey('subjectId'), isFalse);
    expect(find.text('Mathematics · David Jones\nInstead of Sarah Smith — On leave'), findsOneWidget);
    expect(find.text('Substitute'), findsOneWidget);
  });

  testWidgets('teacher cannot be changed once attendance is taken', (tester) async {
    await pump(tester, DailyPeriodsView(api: TimetableApi(), sectionId: 'sec-a'), (o) => FakeResponse(200, _env(daily(taken: true))));
    expect(find.text('Taken'), findsOneWidget);
    await tester.tap(find.text('Period 1 · 09:00–09:45'));
    await tester.pumpAndSettle();
    expect(find.text('Give this period to another teacher'), findsNothing);
    expect(find.text('Attendance is taken, so the teacher cannot be changed'), findsOneWidget);
  });

  Map<String, dynamic> roster({required bool canMark, String? reason, bool taken = false}) => {
        'section': {'id': 'sec-a', 'name': 'Section A', 'className': 'Grade 10'},
        'date': _today, 'isToday': true, 'periodNumber': 2, 'startTime': '09:45', 'endTime': '10:30',
        'subject': {'id': 'sub-e', 'name': 'English Literature'}, 'teacher': _jones, 'isSubstitution': false,
        'taken': taken, 'canMark': canMark, 'reason': reason,
        'students': [
          {'studentId': 'p1', 'name': 'John Doe', 'admissionNo': 'A1', 'rollNo': 1, 'status': taken ? 'PRESENT' : null},
          {'studentId': 'p2', 'name': 'Priya Sharma', 'admissionNo': 'A2', 'rollNo': 2, 'status': taken ? 'ABSENT' : null},
        ],
      };

  testWidgets('period teacher marks attendance; everyone defaults to present', (tester) async {
    Object? sent;
    await pump(tester, PeriodAttendanceScreen(api: TimetableApi(), sectionId: 'sec-a', date: _today, periodNumber: 2), (o) {
      if (o.method == 'POST') {
        sent = _body(o);
        return FakeResponse(201, _env(roster(canMark: true, taken: true)));
      }
      return FakeResponse(200, _env(roster(canMark: true)));
    });
    expect(find.text('2 students · 0 absent'), findsOneWidget);
    await tester.tap(find.text('A').last);
    await tester.pump();
    expect(find.text('2 students · 1 absent'), findsOneWidget);
    await tester.tap(find.text('Save attendance'));
    await tester.pumpAndSettle();
    final body = sent as Map;
    expect(body['periodNumber'], 2);
    expect(body['date'], _today);
    expect(body['records'], containsAll([
      {'studentId': 'p1', 'status': 'PRESENT'},
      {'studentId': 'p2', 'status': 'ABSENT'},
    ]));
    expect(find.text('Attendance saved'), findsOneWidget);
    expect(find.text('Update attendance'), findsOneWidget);
  });

  testWidgets('other teachers see the reason and cannot save', (tester) async {
    await pump(
      tester,
      PeriodAttendanceScreen(api: TimetableApi(), sectionId: 'sec-a', date: _today, periodNumber: 2),
      (o) => FakeResponse(200, _env(roster(canMark: false, taken: true, reason: 'Attendance can only be changed on the day. Ask the office to correct it.'))),
    );
    expect(find.textContaining('Ask the office to correct it'), findsOneWidget);
    expect(find.text('Save attendance'), findsNothing);
    expect(find.text('Update attendance'), findsNothing);
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.text('ABSENT'), findsOneWidget);
  });

  testWidgets('my periods lists today’s periods including substitutions and hand-overs', (tester) async {
    await pump(tester, MyDayView(api: TimetableApi()), (o) {
      return FakeResponse(200, _env({
        'date': _today, 'dayOfWeek': 1, 'dayName': 'Monday', 'isToday': true,
        'periods': [
          {
            'sectionId': 'sec-a', 'className': 'Grade 10', 'sectionName': 'Section A', 'periodNumber': 1, 'startTime': '09:00', 'endTime': '09:45',
            'subject': {'id': 'sub-m', 'name': 'Mathematics'}, 'isSubstitution': false, 'handedOverTo': _jones, 'attendanceTaken': false, 'canTakeAttendance': false,
          },
          {
            'sectionId': 'sec-b', 'className': 'Grade 9', 'sectionName': 'Section A', 'periodNumber': 3, 'startTime': '10:45', 'endTime': '11:30',
            'subject': {'id': 'sub-s', 'name': 'Science'}, 'isSubstitution': true, 'handedOverTo': null, 'attendanceTaken': false, 'canTakeAttendance': true,
          },
        ],
      }));
    });
    expect(find.text('Today · 1 to take'), findsOneWidget);
    expect(find.text('Mathematics · Given to David Jones today'), findsOneWidget);
    expect(find.text('Covered'), findsOneWidget);
    expect(find.text('Science · You are the substitute'), findsOneWidget);
    expect(find.text('Take'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('class teacher adds a student (the server places them in their class)', (tester) async {
    Object? sent;
    await pump(
      tester,
      Builder(builder: (context) => Center(child: FilledButton(onPressed: () => showAddStudentDialog(context, className: 'Grade 10 Section A'), child: const Text('open')))),
      (o) {
        sent = _body(o);
        return FakeResponse(201, _env({'id': 'new'}));
      },
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Add student to Grade 10 Section A'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add student'));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(2));
    await tester.enterText(find.widgetWithText(TextFormField, 'First name'), 'Meera');
    await tester.enterText(find.widgetWithText(TextFormField, 'Last name'), 'Iyer');
    await tester.enterText(find.widgetWithText(TextFormField, 'Roll no.'), '7');
    await tester.tap(find.widgetWithText(FilledButton, 'Add student'));
    await tester.pumpAndSettle();
    final body = sent as Map;
    expect(body['firstName'], 'Meera');
    expect(body['rollNo'], 7);
    expect(body.containsKey('classId'), isFalse);
    expect(body.containsKey('sectionId'), isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  test('office has timetable and attendance; teachers keep timetable', () {
    for (final role in ['OFFICE', 'SCHOOL_ADMIN', 'PRINCIPAL', 'CLASS_TEACHER', 'SUBJECT_TEACHER']) {
      expect(RoleNavigation.forRole(role)!.indexOf('timetable'), greaterThanOrEqualTo(0), reason: role);
    }
    expect(RoleNavigation.forRole('OFFICE')!.indexOf('attendance'), greaterThanOrEqualTo(0));
    expect(RoleNavigation.forRole('STUDENT')!.indexOf('timetable'), -1);
  });
}
