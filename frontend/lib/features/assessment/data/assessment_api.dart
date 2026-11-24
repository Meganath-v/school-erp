import '../../../core/network/api_client.dart';

/// `/internal-assessment` and `/quizzes` endpoints (envelope `data` returned).
class AssessmentApi {
  AssessmentApi([ApiClient? client]) : _api = client ?? ApiClient();
  final ApiClient _api;

  Future<dynamic> _get(String p, [Map<String, dynamic>? q]) async => (await _api.dio.get(p, queryParameters: q)).data['data'];
  Future<dynamic> _post(String p, [Object? b]) async => (await _api.dio.post(p, data: b)).data['data'];
  Future<dynamic> _put(String p, Object b) async => (await _api.dio.put(p, data: b)).data['data'];
  Future<dynamic> _delete(String p) async => (await _api.dio.delete(p)).data['data'];

  static List<Map<String, dynamic>> list(dynamic v) =>
      (v as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  static Map<String, dynamic> map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  // ---------------------------------------------------------------- internal marks
  Future<List<Map<String, dynamic>>> schemes(String subjectId) async => list(await _get('/internal-assessment/subjects/$subjectId/schemes'));
  Future<Map<String, dynamic>> createScheme(String subjectId, Map<String, dynamic> body) async =>
      map(await _post('/internal-assessment/subjects/$subjectId/schemes', body));
  Future<Map<String, dynamic>> updateScheme(String id, Map<String, dynamic> body) async => map(await _put('/internal-assessment/schemes/$id', body));
  Future<void> deleteScheme(String id) => _delete('/internal-assessment/schemes/$id');
  Future<Map<String, dynamic>> sheet(String schemeId, {String? classId}) async =>
      map(await _get('/internal-assessment/schemes/$schemeId/sheet', {'classId': ?classId}));
  Future<void> saveManualMarks(String componentId, List<Map<String, dynamic>> entries) =>
      _put('/internal-assessment/components/$componentId/manual-marks', {'entries': entries});
  Future<Map<String, dynamic>> weakStudents({String? examSubjectId, String? schemeId, String? classId, double? threshold}) async =>
      map(await _get('/internal-assessment/weak-students', {
        'examSubjectId': ?examSubjectId,
        'schemeId': ?schemeId,
        'classId': ?classId,
        'threshold': ?threshold,
      }));

  // ---------------------------------------------------------------- quizzes (staff)
  Future<List<Map<String, dynamic>>> quizzes(String subjectId) async => list(await _get('/quizzes', {'subjectId': subjectId}));
  Future<Map<String, dynamic>> quiz(String id) async => map(await _get('/quizzes/$id'));
  Future<Map<String, dynamic>> createQuiz(Map<String, dynamic> body) async => map(await _post('/quizzes', body));
  Future<Map<String, dynamic>> updateQuiz(String id, Map<String, dynamic> body) async => map(await _put('/quizzes/$id', body));
  Future<Map<String, dynamic>> setQuizQuestions(String id, List<Map<String, dynamic>> questions) async =>
      map(await _put('/quizzes/$id/questions', {'questions': questions}));
  Future<Map<String, dynamic>> publishQuiz(String id) async => map(await _post('/quizzes/$id/publish'));
  Future<Map<String, dynamic>> closeQuiz(String id) async => map(await _post('/quizzes/$id/close'));
  Future<void> deleteQuiz(String id) => _delete('/quizzes/$id');
  Future<Map<String, dynamic>> quizResults(String id) async => map(await _get('/quizzes/$id/results'));

  // ---------------------------------------------------------------- quizzes (students)
  Future<List<Map<String, dynamic>>> myQuizzes() async => list(await _get('/quizzes/mine'));
  Future<Map<String, dynamic>> startQuiz(String id) async => map(await _post('/quizzes/$id/start'));
  Future<Map<String, dynamic>> submitQuiz(String id, Map<String, int> answers) async =>
      map(await _post('/quizzes/$id/submit', {'answers': answers}));
}
