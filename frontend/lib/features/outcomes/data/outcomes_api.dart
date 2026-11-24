import '../../../core/network/api_client.dart';

/// Thin wrapper over the `/outcomes` API. Responses are returned as plain maps/lists
/// (the `data` field of the envelope); errors surface as [ApiException] messages.
class OutcomesApi {
  OutcomesApi([ApiClient? client]) : _api = client ?? ApiClient();
  final ApiClient _api;

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async =>
      (await _api.dio.get(path, queryParameters: query)).data['data'];
  Future<dynamic> _post(String path, Object body) async => (await _api.dio.post(path, data: body)).data['data'];
  Future<dynamic> _put(String path, Object body) async => (await _api.dio.put(path, data: body)).data['data'];
  Future<dynamic> _patch(String path, Object body) async => (await _api.dio.patch(path, data: body)).data['data'];
  Future<dynamic> _delete(String path) async => (await _api.dio.delete(path)).data['data'];

  static List<Map<String, dynamic>> _list(dynamic v) =>
      (v as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  // ---------------------------------------------------------------- programs
  Future<List<Map<String, dynamic>>> programs() async => _list(await _get('/outcomes/programs'));
  Future<Map<String, dynamic>> createProgram(Map<String, dynamic> body) async => _map(await _post('/outcomes/programs', body));
  Future<Map<String, dynamic>> updateProgram(String id, Map<String, dynamic> body) async =>
      _map(await _patch('/outcomes/programs/$id', body));
  Future<void> deleteProgram(String id) => _delete('/outcomes/programs/$id');
  Future<Map<String, dynamic>> setProgramClasses(String id, List<String> classIds) async =>
      _map(await _put('/outcomes/programs/$id/classes', {'classIds': classIds}));
  Future<Map<String, dynamic>> createProgramOutcome(String programId, Map<String, dynamic> body) async =>
      _map(await _post('/outcomes/programs/$programId/outcomes', body));
  Future<Map<String, dynamic>> updateProgramOutcome(String id, Map<String, dynamic> body) async =>
      _map(await _patch('/outcomes/program-outcomes/$id', body));
  Future<void> deleteProgramOutcome(String id) => _delete('/outcomes/program-outcomes/$id');
  Future<Map<String, dynamic>> programAttainment(String id) async => _map(await _get('/outcomes/programs/$id/attainment'));
  Future<List<Map<String, dynamic>>> schoolClasses() async => _list(await _get('/schools/classes'));

  // ---------------------------------------------------------------- subjects & course outcomes
  Future<List<Map<String, dynamic>>> subjects() async => _list(await _get('/outcomes/subjects'));
  Future<List<Map<String, dynamic>>> courseOutcomes(String subjectId) async =>
      _list(await _get('/outcomes/subjects/$subjectId/course-outcomes'));
  Future<Map<String, dynamic>> createCourseOutcome(String subjectId, Map<String, dynamic> body) async =>
      _map(await _post('/outcomes/subjects/$subjectId/course-outcomes', body));
  Future<Map<String, dynamic>> updateCourseOutcome(String id, Map<String, dynamic> body) async =>
      _map(await _patch('/outcomes/course-outcomes/$id', body));
  Future<void> deleteCourseOutcome(String id) => _delete('/outcomes/course-outcomes/$id');
  Future<Map<String, dynamic>> mapping(String subjectId, {String? programId}) async =>
      _map(await _get('/outcomes/subjects/$subjectId/mapping', {'programId': ?programId}));
  Future<Map<String, dynamic>> saveMapping(String subjectId, List<Map<String, dynamic>> entries) async =>
      _map(await _put('/outcomes/subjects/$subjectId/mapping', {'entries': entries}));
  Future<void> saveIndirect(String subjectId, List<Map<String, dynamic>> entries) =>
      _put('/outcomes/subjects/$subjectId/indirect', {'entries': entries});

  // ---------------------------------------------------------------- rules & attainment
  Future<Map<String, dynamic>> subjectRule(String subjectId) async => _map(await _get('/outcomes/subjects/$subjectId/attainment-rule'));
  Future<Map<String, dynamic>> saveSubjectRule(String subjectId, Map<String, dynamic> rule) async =>
      _map(await _put('/outcomes/subjects/$subjectId/attainment-rule', rule));
  Future<Map<String, dynamic>> resetSubjectRule(String subjectId) async =>
      _map(await _delete('/outcomes/subjects/$subjectId/attainment-rule'));
  Future<Map<String, dynamic>> saveSchoolRule(Map<String, dynamic> rule) async => _map(await _put('/outcomes/attainment-rule', rule));
  Future<Map<String, dynamic>> attainment(String subjectId, {String? classId}) async =>
      _map(await _get('/outcomes/subjects/$subjectId/attainment', {'classId': ?classId}));

  // ---------------------------------------------------------------- question bank
  Future<List<Map<String, dynamic>>> questions(String subjectId, {String? courseOutcomeId}) async =>
      _list(await _get('/outcomes/subjects/$subjectId/questions', {'courseOutcomeId': ?courseOutcomeId}));
  Future<Map<String, dynamic>> createQuestion(String subjectId, Map<String, dynamic> body) async =>
      _map(await _post('/outcomes/subjects/$subjectId/questions', body));
  Future<Map<String, dynamic>> updateQuestion(String id, Map<String, dynamic> body) async =>
      _map(await _patch('/outcomes/questions/$id', body));
  Future<void> deleteQuestion(String id) => _delete('/outcomes/questions/$id');

  // ---------------------------------------------------------------- assessments, papers, marks
  Future<List<Map<String, dynamic>>> assessments(String subjectId) async =>
      _list(await _get('/outcomes/subjects/$subjectId/assessments'));
  Future<void> setAssessmentType(String examSubjectId, String type) =>
      _patch('/outcomes/exam-subjects/$examSubjectId/assessment-type', {'assessmentType': type});

  static String _base(String kind, String id) => kind == 'exam' ? '/outcomes/exam-subjects/$id' : '/outcomes/assignments/$id';
  Future<Map<String, dynamic>> paper(String kind, String id) async => _map(await _get('${_base(kind, id)}/paper'));
  Future<Map<String, dynamic>> savePaper(String kind, String id, Map<String, dynamic> body) async =>
      _map(await _put('${_base(kind, id)}/paper', body));
  Future<void> deletePaper(String kind, String id) => _delete('${_base(kind, id)}/paper');
  Future<Map<String, dynamic>> marks(String kind, String id) async => _map(await _get('${_base(kind, id)}/marks'));
  Future<Map<String, dynamic>> saveMarks(String kind, String id, List<Map<String, dynamic>> entries) async =>
      _map(await _put('${_base(kind, id)}/marks', {'entries': entries}));
}

const bloomLevels = ['REMEMBER', 'UNDERSTAND', 'APPLY', 'ANALYZE', 'EVALUATE', 'CREATE'];

String bloomLabel(String? level) {
  if (level == null || level.isEmpty) return '—';
  return level[0] + level.substring(1).toLowerCase();
}

String strengthLabel(int s) => switch (s) { 3 => 'High', 2 => 'Medium', 1 => 'Low', _ => '—' };

String formatLevel(num? v) => v == null ? '—' : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2));
