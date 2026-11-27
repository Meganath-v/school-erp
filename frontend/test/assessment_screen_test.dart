import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/navigation/role_navigation.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/assessment/presentation/assessment_screen.dart';
import 'package:frontend/features/assessment/presentation/student_quizzes_screen.dart';
import 'helpers/fake_adapter.dart';

Map<String, dynamic> _env(Object data) => {'data': data};

final _subjects = [
  {
    'id': 's1', 'name': 'Science', 'code': 'SCI', 'canEdit': true,
    'classes': [
      {'id': 'c1', 'name': 'Grade 10'},
    ],
  },
];
final _scheme = {
  'id': 'sc1', 'name': 'Term 1 internals', 'classId': 'c1', 'passPercent': 50,
  'components': [
    {'id': 'k1', 'label': 'Class tests', 'type': 'EXAM', 'weight': 20, 'bestOf': 2, 'sourceIds': ['e1', 'e2', 'e3']},
    {'id': 'k2', 'label': 'Attendance', 'type': 'ATTENDANCE', 'weight': 5, 'bestOf': null, 'sourceIds': []},
    {'id': 'k3', 'label': 'Seminar', 'type': 'MANUAL', 'weight': 5, 'bestOf': null, 'sourceIds': []},
  ],
};
final _sheet = {
  'scheme': _scheme,
  'students': [
    {
      'studentId': 'st1', 'name': 'Asha Rao', 'admissionNo': 'A1', 'section': 'A', 'total': 24.5, 'max': 30, 'percent': 81.67,
      'complete': true, 'isWeak': false,
      'components': [
        {'componentId': 'k1', 'label': 'Class tests', 'score': 16, 'max': 20},
        {'componentId': 'k2', 'label': 'Attendance', 'score': 4.5, 'max': 5},
        {'componentId': 'k3', 'label': 'Seminar', 'score': 4, 'max': 5},
      ],
    },
    {
      'studentId': 'st2', 'name': 'Ravi Das', 'admissionNo': 'A2', 'section': 'A', 'total': 9, 'max': 30, 'percent': 30,
      'complete': false, 'isWeak': true,
      'components': [
        {'componentId': 'k1', 'label': 'Class tests', 'score': 6, 'max': 20},
        {'componentId': 'k2', 'label': 'Attendance', 'score': 3, 'max': 5},
        {'componentId': 'k3', 'label': 'Seminar', 'score': null, 'max': 5},
      ],
    },
  ],
  'summary': {'students': 2, 'average': 55.83, 'weak': 1, 'incomplete': 1},
};
final _quiz = {
  'id': 'q1', 'title': 'Motion quiz', 'status': 'PUBLISHED', 'classId': 'c1', 'durationMinutes': 15, 'closesAt': null, 'opensAt': null,
  'instructions': '', 'showAnswers': true,
  '_count': {'questions': 1, 'attempts': 1},
  'questions': [
    {'questionId': 'qq1', 'marks': 2, 'question': {'id': 'qq1', 'text': 'Unit of force?', 'options': ['Newton', 'Joule'], 'correctOption': 0}},
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

  FakeResponse staff(RequestOptions o) {
    final p = o.uri.path.replaceFirst('/api/v1', '');
    if (p == '/outcomes/subjects') return FakeResponse(200, _env(_subjects));
    if (p.endsWith('/schemes')) return FakeResponse(200, _env([_scheme]));
    if (p.endsWith('/sheet')) return FakeResponse(200, _env(_sheet));
    if (p.endsWith('/assessments')) {
      return FakeResponse(200, _env([
        {'kind': 'exam', 'id': 'e1', 'title': 'Unit test 1', 'subtitle': 'Grade 10 · Term 1', 'maxMarks': 25},
      ]));
    }
    if (p == '/internal-assessment/weak-students') {
      return FakeResponse(200, _env({
        'source': 'Term 1 internals', 'threshold': 50,
        'students': [
          {'studentId': 'st2', 'name': 'Ravi Das', 'admissionNo': 'A2', 'section': 'A', 'percent': 30, 'reason': '9/30 (30%)'},
        ],
      }));
    }
    if (p == '/quizzes') return FakeResponse(200, _env([_quiz]));
    if (p == '/quizzes/q1') return FakeResponse(200, _env(_quiz));
    if (p == '/quizzes/q1/results') {
      return FakeResponse(200, _env({
        'quiz': {'id': 'q1', 'title': 'Motion quiz', 'status': 'PUBLISHED', 'maxScore': 2},
        'students': [
          {'studentId': 'st1', 'name': 'Asha Rao', 'status': 'SUBMITTED', 'score': 2, 'late': false, 'submittedAt': '2026-11-20T10:00:00Z'},
          {'studentId': 'st2', 'name': 'Ravi Das', 'status': 'NOT_STARTED', 'score': null, 'late': false, 'submittedAt': null},
        ],
        'summary': {'students': 2, 'submitted': 1, 'average': 2},
      }));
    }
    return const FakeResponse(200, {'data': []});
  }

  testWidgets('internal marks tab lists the scheme and opens the mark sheet', (tester) async {
    await pump(tester, const AssessmentScreen(), staff);
    expect(find.text('Term 1 internals'), findsOneWidget);
    expect(find.text('Class tests · 20 marks'), findsOneWidget);
    expect(find.textContaining('best 2 · 3 selected'), findsOneWidget);
    expect(find.textContaining('Total 30 · pass 50%'), findsOneWidget);

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('24.50/30'), findsOneWidget);
    expect(find.text('9/30'), findsOneWidget);
    expect(find.textContaining('incomplete'), findsOneWidget);
    expect(find.text('Enter "Seminar" marks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weak students tab lists students below the pass mark', (tester) async {
    await pump(tester, const AssessmentScreen(), staff);
    await tester.tap(find.text('Weak students'));
    await tester.pumpAndSettle();
    expect(find.text('1 below 50%'), findsOneWidget);
    expect(find.text('Ravi Das'), findsOneWidget);
    expect(adapter.requests.last.uri.queryParameters['schemeId'], 'sc1');
  });

  testWidgets('quizzes tab opens a quiz with its results', (tester) async {
    await pump(tester, const AssessmentScreen(), staff);
    await tester.ensureVisible(find.text('Quizzes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quizzes'));
    await tester.pumpAndSettle();
    expect(find.text('Motion quiz'), findsOneWidget);
    await tester.tap(find.text('Motion quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Close quiz'), findsOneWidget);
    expect(find.text('Choose questions'), findsNothing, reason: 'questions are locked once someone attempted');
    expect(find.text('1/2'), findsOneWidget);
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Not started'), 200, scrollable: list);
    expect(find.text('Not started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student takes a quiz and sees the graded review', (tester) async {
    Object? submitted;
    await pump(tester, const StudentQuizzesScreen(), (o) {
      final p = o.uri.path.replaceFirst('/api/v1', '');
      if (p == '/quizzes/mine') {
        return FakeResponse(200, _env([
          {'id': 'q1', 'title': 'Motion quiz', 'subject': 'Science', 'durationMinutes': 15, 'opensAt': null, 'closesAt': null,
            'questions': 1, 'maxScore': 2, 'open': true, 'attempt': null},
        ]));
      }
      if (p == '/quizzes/q1/start') {
        return FakeResponse(200, _env({
          'attemptId': 'a1', 'status': 'IN_PROGRESS', 'title': 'Motion quiz', 'instructions': 'Choose one answer.',
          'startedAt': DateTime.now().toUtc().toIso8601String(),
          'deadline': DateTime.now().add(const Duration(minutes: 15)).toUtc().toIso8601String(),
          'questions': [
            {'questionId': 'qq1', 'text': 'Unit of force?', 'options': ['Newton', 'Joule'], 'marks': 2},
          ],
        }));
      }
      if (p == '/quizzes/q1/submit') {
        submitted = o.data is String ? jsonDecode(o.data as String) : o.data;
        return FakeResponse(200, _env({
          'attemptId': 'a1', 'status': 'SUBMITTED', 'title': 'Motion quiz', 'score': 2, 'maxScore': 2, 'late': false,
          'submittedAt': DateTime.now().toUtc().toIso8601String(),
          'questions': [
            {'questionId': 'qq1', 'text': 'Unit of force?', 'options': ['Newton', 'Joule'], 'marks': 2, 'chosen': 0, 'correctOption': 0},
          ],
        }));
      }
      return const FakeResponse(200, {'data': []});
    });
    expect(find.text('Open'), findsOneWidget);
    await tester.tap(find.text('Motion quiz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Unit of force?'), findsOneWidget);
    expect(find.textContaining(RegExp(r'(14|15):[0-5][0-9]')), findsOneWidget, reason: 'countdown shows');
    await tester.tap(find.text('A. Newton'));
    await tester.pump();
    expect(find.text('1 of 1 answered'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect((submitted as Map)['answers'], {'qq1': 0});
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Your answer'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  test('assessment section for academic staff, quizzes for students', () {
    for (final role in ['SCHOOL_ADMIN', 'PRINCIPAL', 'CLASS_TEACHER', 'SUBJECT_TEACHER']) {
      expect(RoleNavigation.forRole(role)!.indexOf('assessment'), greaterThanOrEqualTo(0), reason: role);
    }
    for (final role in ['PLATFORM_OWNER', 'OFFICE', 'PARENT', 'STUDENT']) {
      expect(RoleNavigation.forRole(role)!.indexOf('assessment'), -1, reason: role);
    }
    expect(RoleNavigation.forRole('STUDENT')!.indexOf('quizzes'), greaterThanOrEqualTo(0));
  });
}
