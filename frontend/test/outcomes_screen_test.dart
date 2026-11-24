import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_provider.dart';
import 'package:frontend/core/auth/session_storage.dart';
import 'package:frontend/core/navigation/role_navigation.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/outcomes/presentation/attainment_tab.dart';
import 'package:frontend/features/outcomes/presentation/outcomes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/fake_adapter.dart';

Map<String, dynamic> _envelope(Object data) => {'data': data};

final _subjects = [
  {
    'id': 's1',
    'name': 'Science',
    'code': 'SCI',
    'canEdit': true,
    'courseOutcomeCount': 1,
    'questionCount': 1,
    'classes': [
      {'id': 'c1', 'name': 'Grade 10'},
    ],
  },
];
final _programs = [
  {
    'id': 'p1',
    'code': 'BSC',
    'name': 'Bachelor of Science',
    'outcomes': [
      {'id': 'po1', 'type': 'PO', 'code': 'PO1', 'description': 'Scientific knowledge'},
      {'id': 'pso1', 'type': 'PSO', 'code': 'PSO1', 'description': 'Lab skills'},
    ],
    'classes': [
      {'id': 'c1', 'name': 'Grade 10'},
    ],
  },
];
final _cos = [
  {'id': 'co1', 'code': 'CO1', 'description': 'Explain motion', 'bloomLevel': 'UNDERSTAND', 'targetAttainment': 70, 'indirectLevel': 3, '_count': {'questions': 2}},
];
final _mapping = {
  'programIds': ['p1'],
  'courseOutcomes': _cos,
  'programOutcomes': [
    {'id': 'po1', 'code': 'PO1', 'type': 'PO', 'description': 'Scientific knowledge'},
    {'id': 'pso1', 'code': 'PSO1', 'type': 'PSO', 'description': 'Lab skills'},
  ],
  'entries': [
    {'courseOutcomeId': 'co1', 'programOutcomeId': 'po1', 'strength': 3},
  ],
};
final _attainment = {
  'subject': {'id': 's1', 'name': 'Science', 'code': 'SCI'},
  'rule': {
    'studentTargetPercent': 60, 'level1Percent': 40, 'level2Percent': 50, 'level3Percent': 60,
    'internalWeight': 40, 'externalWeight': 60, 'directWeight': 80, 'indirectWeight': 20, 'targetLevel': 2,
  },
  'ruleSource': 'DEFAULT',
  'courseOutcomes': [
    {
      'courseOutcomeId': 'co1', 'code': 'CO1', 'description': 'Explain motion',
      'internal': {'studentsAssessed': 4, 'studentsAttained': 3, 'percentAttained': 75, 'level': 3, 'questionsMapped': 2},
      'external': null, 'directLevel': 3, 'indirectLevel': 3, 'finalLevel': 3, 'meetsTarget': true,
    },
  ],
  'programOutcomes': [
    {'programOutcomeId': 'po1', 'code': 'PO1', 'type': 'PO', 'attainment': 3, 'contributingOutcomes': 1, 'totalStrength': 3},
    {'programOutcomeId': 'pso1', 'code': 'PSO1', 'type': 'PSO', 'attainment': null, 'contributingOutcomes': 0, 'totalStrength': 0},
  ],
  'summary': {'questionsAssessed': 2, 'unmappedQuestions': 1, 'marksEntries': 8, 'outcomesBelowTarget': 0, 'outcomesNotAssessed': 0},
};

void main() {
  final api = ApiClient();
  late FakeAdapter adapter;

  Future<void> pump(WidgetTester tester, {required String role}) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    api.clearAuth();
    api.setBaseUrl('http://test.local:3000/api/v1');
    adapter = FakeAdapter((o) {
      final p = o.uri.path.replaceFirst('/api/v1', '');
      if (p == '/auth/me') {
        return FakeResponse(200, _envelope({
          'id': 'u1', 'email': 'x@example.test', 'name': 'Alex Kim', 'firstName': 'Alex', 'lastName': 'Kim', 'activeRole': role,
          'activeSchool': {'id': 'sch', 'name': 'Test School', 'code': 'TST01'}, 'memberships': [],
        }));
      }
      if (p == '/outcomes/subjects') return FakeResponse(200, _envelope(_subjects));
      if (p == '/outcomes/programs') return FakeResponse(200, _envelope(_programs));
      if (p.endsWith('/course-outcomes')) return FakeResponse(200, _envelope(_cos));
      if (p.endsWith('/mapping')) return FakeResponse(200, _envelope(_mapping));
      if (p.endsWith('/attainment')) return FakeResponse(200, _envelope(_attainment));
      if (p.endsWith('/questions')) return FakeResponse(200, _envelope([]));
      if (p.endsWith('/assessments')) return FakeResponse(200, _envelope([]));
      return const FakeResponse(200, {'data': []});
    });
    api.debugSetAdapter(adapter);

    final storage = InMemorySessionStorage()
      ..session = StoredSession(
        accessToken: fakeJwt(),
        refreshToken: fakeJwt(expiresIn: const Duration(days: 7)),
        user: {'id': 'u1', 'email': 'x@example.test', 'name': 'Alex Kim', 'firstName': 'Alex', 'lastName': 'Kim', 'activeRole': role},
        school: {'id': 'sch', 'name': 'Test School', 'code': 'TST01', 'currency': 'INR'},
        role: role,
        memberships: const [],
      );
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage)],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: OutcomesScreen())),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('programs tab lists programs and outcomes; admins can add', (tester) async {
    await pump(tester, role: 'SCHOOL_ADMIN');
    expect(find.text('Bachelor of Science'), findsOneWidget);
    expect(find.textContaining('PO1'), findsWidgets);
    expect(find.textContaining('PSO1'), findsWidgets);
    expect(find.text('Grade 10'), findsWidgets);
    expect(find.widgetWithText(FloatingActionButton, 'Program'), findsOneWidget);
    expect(find.text('Add outcome'), findsOneWidget);
  });

  testWidgets('teachers see programs read-only', (tester) async {
    await pump(tester, role: 'SUBJECT_TEACHER');
    expect(find.text('Bachelor of Science'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Add outcome'), findsNothing);
  });

  testWidgets('course outcomes tab shows outcomes and the CO-PO mapping summary', (tester) async {
    await pump(tester, role: 'SUBJECT_TEACHER');
    await tester.tap(find.text('Course outcomes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CO1 · Understand'), findsOneWidget);
    expect(find.textContaining('Target 70%'), findsOneWidget);
    expect(find.text('PO1:H'), findsOneWidget, reason: 'existing high correlation is summarised');
    expect(find.text('Mapping saved'), findsOneWidget, reason: 'nothing changed yet');
  });

  testWidgets('attainment tab shows levels, rule and program outcomes', (tester) async {
    await pump(tester, role: 'SUBJECT_TEACHER');
    await tester.ensureVisible(find.text('Attainment')); // last tab is past the edge of the tab strip
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attainment'));
    await tester.pumpAndSettle();
    final list = find.descendant(of: find.byType(AttainmentTab), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.textContaining('not linked to a course outcome'), 200, scrollable: list);
    expect(find.textContaining('not linked to a course outcome'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Level 3'), 300, scrollable: list);
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.textContaining('Internal: 3/4 students (75%) → L3'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('3 / 3'), 300, scrollable: list);
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No course outcome mapped'), 300, scrollable: list);
    expect(find.text('No course outcome mapped'), findsOneWidget);
  });

  test('outcomes section is offered to academic staff only', () {
    for (final role in ['SCHOOL_ADMIN', 'PRINCIPAL', 'CLASS_TEACHER', 'SUBJECT_TEACHER']) {
      expect(RoleNavigation.forRole(role)!.indexOf('outcomes'), greaterThanOrEqualTo(0), reason: role);
    }
    for (final role in ['PLATFORM_OWNER', 'OFFICE', 'PARENT', 'STUDENT']) {
      expect(RoleNavigation.forRole(role)!.indexOf('outcomes'), -1, reason: role);
    }
  });
}
