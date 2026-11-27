import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/navigation/role_navigation.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/ai_exam/data/ai_exam_api.dart';
import 'package:frontend/features/ai_exam/data/speech_input.dart';
import 'package:frontend/features/ai_exam/presentation/student/exam_screen.dart';
import 'package:frontend/features/ai_exam/presentation/student/result_screen.dart';
import 'package:frontend/features/ai_exam/presentation/student/student_home.dart';
import 'package:frontend/features/ai_exam/presentation/teacher/questions_editor_screen.dart';
import 'package:frontend/features/ai_exam/presentation/teacher/teacher_home.dart';
import 'package:frontend/features/ai_exam/presentation/teacher/test_detail_screen.dart';
import 'helpers/fake_adapter.dart';

Map<String, dynamic> _env(Object data) => {'data': data};
Object? _body(RequestOptions o) => o.data is String ? jsonDecode(o.data as String) : o.data;

/// Speech adapter double: emits the given transcript or reports unavailability.
class FakeSpeech implements SpeechInput {
  FakeSpeech({this.available = true, this.transcript = 'chlorophyll absorbs sunlight'});
  final bool available;
  final String transcript;
  bool listening = false;
  @override
  Future<bool> init() async => available;
  @override
  bool get isListening => listening;
  @override
  Future<void> start({required void Function(String, bool) onText, required void Function(String) onError, String? localeId}) async {
    listening = true;
    onText(transcript.split(' ').first, false);
    onText(transcript, true);
    listening = false;
  }

  @override
  Future<void> stop() async => listening = false;
  @override
  Future<void> cancel() async => listening = false;
}

final _test = {
  'id': 't1',
  'title': 'Photosynthesis unit test',
  'status': 'DRAFT',
  'phase': 'DRAFT',
  'class': {'id': 'c10', 'name': 'Grade 10'},
  'section': {'id': 's1', 'name': 'Section A'},
  'subject': {'id': 'sub1', 'name': 'Science', 'code': 'SCI10'},
  'academicYear': {'id': 'y1', 'name': '2026-2027'},
  'assignMode': 'SECTION',
  'chapter': 'Life processes',
  'topics': ['Photosynthesis'],
  'totalMarks': 6,
  'durationMinutes': 20,
  'startsAt': null,
  'endsAt': null,
  'resultsPublishedAt': null,
  'autoSubmit': true,
  'instructions': 'Answer all questions.',
  'assignees': [],
  'canEditQuestions': true,
  'stats': {'assigned': 2, 'started': 0, 'submitted': 0, 'needsReview': 0, 'pendingEvaluation': 0, 'failed': 0},
  'questions': [
    {
      'id': 'q1', 'type': 'MCQ', 'text': 'Which pigment absorbs light?', 'marks': 1, 'options': ['Keratin', 'Chlorophyll'], 'correctOption': 1, 'answerKey': null,
      'topic': 'Photosynthesis', 'difficulty': 'EASY', 'rubric': [],
    },
    {
      'id': 'q2', 'type': 'LONG', 'text': 'Explain photosynthesis.', 'marks': 5, 'options': null, 'correctOption': null, 'answerKey': 'Plants use sunlight...',
      'topic': 'Photosynthesis', 'difficulty': 'MEDIUM',
      'rubric': [
        {'description': 'Definition', 'marks': 2},
        {'description': 'Role of chlorophyll', 'marks': 3},
      ],
    },
  ],
};

void main() {
  final api = ApiClient();
  late FakeAdapter adapter;

  Future<void> pump(WidgetTester tester, Widget home, FakeHandler handler, {double width = 360}) async {
    tester.view.physicalSize = Size(width * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    api.clearAuth();
    api.setBaseUrl('http://test.local:3000/api/v1');
    adapter = FakeAdapter(handler);
    api.debugSetAdapter(adapter);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: home)));
    await tester.pumpAndSettle();
  }

  String path(RequestOptions o) => o.uri.path.replaceFirst('/api/v1', '');

  testWidgets('teacher dashboard shows counts, the AI status and active tests', (tester) async {
    await pump(tester, const TeacherAiExamHome(), (o) {
      if (path(o) == '/ai-exams/dashboard') {
        return FakeResponse(200, _env({
          'ai': {'configured': false, 'mock': false},
          'counts': {'active': 1, 'scheduled': 2, 'needsReview': 3, 'pendingEvaluation': 4, 'failed': 0},
          'activeTests': [{..._test, 'status': 'PUBLISHED', 'phase': 'ACTIVE'}],
          'scheduledTests': [],
          'recentSubmissions': [],
          'classPerformance': [{'label': 'Grade 10 · Science', 'tests': 2, 'percent': 64.5}],
        }));
      }
      return FakeResponse(200, _env([]));
    });
    expect(find.text('Create test'), findsOneWidget);
    expect(find.textContaining('AI evaluation is not configured'), findsOneWidget, reason: 'never implies AI marking without a key');
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Photosynthesis unit test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft test: publish, preview and the answer key with rubric', (tester) async {
    await pump(tester, TestDetailScreen(api: AiExamApi(), testId: 't1'), (o) {
      if (path(o) == '/ai-exams/t1') return FakeResponse(200, _env(_test));
      return FakeResponse(200, {'data': [], 'meta': {}});
    });
    expect(find.text('Publish'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Edit questions'), findsOneWidget);
    await tester.tap(find.text('Questions'));
    await tester.pumpAndSettle();
    expect(find.text('Plants use sunlight...'), findsOneWidget);
    expect(find.textContaining('Role of chlorophyll — 3'), findsOneWidget);
    expect(find.textContaining('Chlorophyll   ✓'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('question form refuses a rubric that does not add up', (tester) async {
    Map<String, dynamic>? result;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => QuestionFormScreen(api: AiExamApi(), question: _test['questions'] is List ? (_test['questions'] as List)[1] as Map<String, dynamic> : null))),
          child: const Text('open'),
        ),
      ),
      (o) => FakeResponse(200, _env([])),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Marks').first, '6');
    await tester.tap(find.text('Done').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('add up to 5'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Marks').first, '5');
    await tester.tap(find.text('Done').first);
    await tester.pumpAndSettle();
    expect(result?['marks'], 5);
    expect((result?['rubric'] as List).length, 2);
  });

  testWidgets('student exam: autosave, voice transcript is appended and editable, submit', (tester) async {
    speechInputFactory = () => FakeSpeech();
    final saves = <Object?>[];
    Object? submitted;
    await pump(tester, ExamScreen(api: AiExamApi(), testId: 't1'), (o) {
      final p = path(o);
      if (p == '/student/ai-exams/t1/start') {
        return FakeResponse(200, _env({
          'submissionId': 'sub1',
          'test': {'id': 't1', 'title': 'Photosynthesis unit test', 'subject': 'Science', 'totalMarks': 6, 'autoSubmit': true},
          'startedAt': DateTime.now().toUtc().toIso8601String(),
          'deadline': DateTime.now().add(const Duration(minutes: 20)).toUtc().toIso8601String(),
          'serverTime': DateTime.now().toUtc().toIso8601String(),
          'allowVoice': true,
          'questions': [
            {'id': 'q1', 'type': 'MCQ', 'text': 'Which pigment absorbs light?', 'marks': 1, 'options': ['Keratin', 'Chlorophyll']},
            {'id': 'q2', 'type': 'LONG', 'text': 'Explain photosynthesis.', 'marks': 5, 'options': null},
          ],
          'answers': [
            {'questionId': 'q2', 'text': 'Plants make food.', 'choice': null, 'inputMethod': 'TYPED'},
          ],
        }));
      }
      if (p == '/student/ai-exams/t1/answers') {
        saves.add(_body(o));
        return FakeResponse(200, _env({'saved': 1}));
      }
      if (p == '/student/ai-exams/t1/submit') {
        submitted = _body(o);
        return FakeResponse(200, _env({'status': 'SUBMITTED'}));
      }
      return FakeResponse(200, _env({}));
    });
    // Resumes at the first unanswered question, timer visible.
    expect(find.text('Which pigment absorbs light?'), findsOneWidget);
    expect(find.textContaining('19:'), findsOneWidget);
    await tester.tap(find.text('B. Chlorophyll'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect((saves.last as Map)['answers'], [
      {'questionId': 'q1', 'text': '', 'choice': 1, 'inputMethod': 'TYPED'},
    ]);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Explain photosynthesis.'), findsOneWidget);
    expect(find.text('Plants make food.'), findsOneWidget, reason: 'saved answer restored');
    await tester.tap(find.text('Speak answer'));
    await tester.pump();
    expect(find.text('Plants make food. chlorophyll absorbs sunlight'), findsOneWidget, reason: 'voice appends; typed text kept');
    await tester.enterText(find.byType(TextField), 'Plants make food. Chlorophyll absorbs sunlight to make glucose.');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    final last = ((saves.last as Map)['answers'] as List).first as Map;
    expect(last['text'], 'Plants make food. Chlorophyll absorbs sunlight to make glucose.');
    expect(last['inputMethod'], 'MIXED');

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(((submitted as Map)['answers'] as List).length, 2);
    expect(find.text('Submitted'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1)); // let the final save on leaving complete
  });

  testWidgets('voice unavailable: clear message, typing still works', (tester) async {
    speechInputFactory = () => FakeSpeech(available: false);
    await pump(tester, ExamScreen(api: AiExamApi(), testId: 't1'), (o) {
      if (path(o) == '/student/ai-exams/t1/start') {
        return FakeResponse(200, _env({
          'submissionId': 'sub1',
          'test': {'id': 't1', 'title': 'T', 'subject': 'Science', 'totalMarks': 5, 'autoSubmit': true},
          'deadline': null,
          'serverTime': DateTime.now().toUtc().toIso8601String(),
          'questions': [{'id': 'q2', 'type': 'LONG', 'text': 'Explain photosynthesis.', 'marks': 5, 'options': null}],
          'answers': [],
        }));
      }
      return FakeResponse(200, _env({'saved': 1}));
    });
    await tester.tap(find.text('Speak answer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Voice input is not available'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Typed instead');
    await tester.pump();
    expect(find.text('Typed instead'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1)); // let the final save on leaving complete
  });

  testWidgets('result shows question-wise feedback and the model answer', (tester) async {
    await pump(tester, ResultScreen(api: AiExamApi(), testId: 't1'), (o) {
      return FakeResponse(200, _env({
        'published': true,
        'test': {'id': 't1', 'title': 'Photosynthesis unit test', 'subject': 'Science', 'className': 'Grade 10', 'date': '2026-11-20T10:00:00Z'},
        'score': 4.5,
        'maxScore': 6,
        'percent': 75,
        'questions': [
          {
            'questionId': 'q2', 'type': 'LONG', 'text': 'Explain photosynthesis.', 'topic': 'Photosynthesis', 'options': null,
            'yourAnswer': 'Plants make food using sunlight.', 'marks': 3.5, 'maxMarks': 5, 'evaluatedBy': 'AI',
            'criteria': [{'description': 'Role of chlorophyll', 'awarded': 0, 'max': 1}],
            'feedback': {'overall': 'Partially correct', 'correctPoints': ['Role of sunlight'], 'missingPoints': ['Role of chlorophyll'], 'incorrectPoints': [], 'improvement': ['Mention chlorophyll']},
            'modelAnswer': 'Green plants use sunlight absorbed by chlorophyll...',
          },
        ],
      }));
    });
    expect(find.text('4.5 / 6'), findsOneWidget);
    expect(find.text('Missing points'), findsOneWidget);
    expect(find.text('• Role of chlorophyll'), findsOneWidget);
    expect(find.text('Model answer'), findsOneWidget);
    expect(find.textContaining('Evaluated by AI and released by your teacher'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('students outside Classes 10-12 see why the module is unavailable', (tester) async {
    await pump(tester, const StudentAiExamHome(), (o) => FakeResponse(200, _env({'eligible': false, 'student': {'className': 'Grade 9'}, 'available': [], 'upcoming': [], 'completed': []})));
    expect(find.text('Not available for your class'), findsOneWidget);
    expect(find.textContaining('Grade 9'), findsOneWidget);
  });

  testWidgets('student dashboard lists available tests and pending results', (tester) async {
    await pump(tester, const StudentAiExamHome(), (o) {
      final p = path(o);
      if (p == '/student/ai-exams') {
        return FakeResponse(200, _env({
          'eligible': true,
          'student': {'name': 'John Doe', 'className': 'Grade 10', 'sectionName': 'Section A'},
          'available': [{'id': 't1', 'title': 'Photosynthesis unit test', 'subject': 'Science', 'questions': 2, 'totalMarks': 6, 'durationMinutes': 20, 'phase': 'ACTIVE', 'attempt': null}],
          'upcoming': [],
          'completed': [{'id': 't0', 'title': 'Cells test', 'subject': 'Science', 'questions': 3, 'totalMarks': 10, 'phase': 'ENDED', 'attempt': {'status': 'SUBMITTED', 'submittedAt': '2026-11-01T10:00:00Z'}, 'resultPublished': false}],
        }));
      }
      return FakeResponse(200, _env({'hasData': false, 'enoughData': false, 'plan': null, 'message': 'x'}));
    });
    expect(find.text('Hello, John'), findsOneWidget);
    expect(find.text('Photosynthesis unit test'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Tests'));
    await tester.pumpAndSettle();
    expect(find.text('Awaiting result'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('AI Examination is offered to academic staff and students only', () {
    for (final role in ['SCHOOL_ADMIN', 'PRINCIPAL', 'CLASS_TEACHER', 'SUBJECT_TEACHER', 'STUDENT']) {
      expect(RoleNavigation.forRole(role)!.indexOf('ai-exam'), greaterThanOrEqualTo(0), reason: role);
    }
    for (final role in ['PLATFORM_OWNER', 'OFFICE', 'PARENT']) {
      expect(RoleNavigation.forRole(role)!.indexOf('ai-exam'), -1, reason: role);
    }
  });

  test('voice transcripts are appended, never replacing typed text', () {
    expect(appendTranscript('', ' hello '), 'hello');
    expect(appendTranscript('Typed part.', 'spoken part'), 'Typed part. spoken part');
    expect(appendTranscript('Keep me', '   '), 'Keep me');
  });
}
