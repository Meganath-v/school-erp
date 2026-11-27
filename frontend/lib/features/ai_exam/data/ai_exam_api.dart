import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

/// AI Examination endpoints. Every call returns the envelope's `data`
/// (paged lists return `{data, meta}` as-is).
class AiExamApi {
  AiExamApi([ApiClient? client]) : _api = client ?? ApiClient();
  final ApiClient _api;

  Future<dynamic> _get(String p, [Map<String, dynamic>? q]) async => (await _api.dio.get(p, queryParameters: q)).data['data'];
  Future<dynamic> _post(String p, [Object? b]) async => (await _api.dio.post(p, data: b ?? const {})).data['data'];
  Future<dynamic> _put(String p, Object b) async => (await _api.dio.put(p, data: b)).data['data'];
  Future<dynamic> _delete(String p) async => (await _api.dio.delete(p)).data['data'];

  static List<Map<String, dynamic>> list(dynamic v) =>
      (v as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  static Map<String, dynamic> map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  /// Server origin (images are served from /uploads, outside /api/v1).
  String imageUrl(String path) {
    final base = Uri.tryParse(_api.dio.options.baseUrl);
    if (base == null || path.startsWith('http')) return path;
    return base.replace(path: path, query: null).toString();
  }

  // ---------------------------------------------------------------- teachers
  Future<Map<String, dynamic>> options() async => map(await _get('/ai-exams/options'));
  Future<Map<String, dynamic>> dashboard() async => map(await _get('/ai-exams/dashboard'));
  Future<List<Map<String, dynamic>>> tests({String? status, String? classId, String? subjectId}) async {
    final r = await _api.dio.get('/ai-exams', queryParameters: {'status': ?status, 'classId': ?classId, 'subjectId': ?subjectId, 'pageSize': 100});
    return list(r.data['data']);
  }

  Future<Map<String, dynamic>> test(String id) async => map(await _get('/ai-exams/$id'));
  Future<Map<String, dynamic>> createTest(Map<String, dynamic> body) async => map(await _post('/ai-exams', body));
  Future<Map<String, dynamic>> updateTest(String id, Map<String, dynamic> body) async => map(await _put('/ai-exams/$id', body));
  Future<void> deleteTest(String id) => _delete('/ai-exams/$id');
  Future<Map<String, dynamic>> saveQuestions(String id, List<Map<String, dynamic>> questions) async =>
      map(await _post('/ai-exams/$id/questions', {'questions': questions}));
  Future<Map<String, dynamic>> publish(String id) async => map(await _post('/ai-exams/$id/publish'));
  Future<Map<String, dynamic>> close(String id) async => map(await _post('/ai-exams/$id/close'));
  /// [startsAt]/[endsAt]: omit a key to keep it, null to clear it.
  Future<Map<String, dynamic>> reschedule(String id, Map<String, dynamic> body) async => map(await _post('/ai-exams/$id/reschedule', body));
  Future<Map<String, dynamic>> archive(String id) async => map(await _post('/ai-exams/$id/archive'));
  Future<Map<String, dynamic>> publishResults(String id) async => map(await _post('/ai-exams/$id/publish-results'));
  Future<List<Map<String, dynamic>>> candidates(String classId, {String? sectionId}) async =>
      list(await _get('/ai-exams/candidates', {'classId': classId, 'sectionId': ?sectionId}));
  Future<List<Map<String, dynamic>>> submissions(String id) async {
    final r = await _api.dio.get('/ai-exams/$id/submissions', queryParameters: {'pageSize': 200});
    return list(r.data['data']);
  }

  Future<Map<String, dynamic>> submission(String testId, String submissionId) async => map(await _get('/ai-exams/$testId/submissions/$submissionId'));
  Future<void> overrideMarks(String evaluationId, double marks, String reason) =>
      _put('/ai-exams/evaluations/$evaluationId/override', {'marks': marks, 'reason': reason});
  Future<void> acceptEvaluation(String evaluationId) => _post('/ai-exams/evaluations/$evaluationId/accept');
  Future<Map<String, dynamic>> runEvaluation({String? testId, String? submissionId}) async =>
      map(await _post('/ai-evaluation/evaluate', {'testId': ?testId, 'submissionId': ?submissionId}));
  Future<Map<String, dynamic>> classAnalytics(Map<String, String?> filters) async =>
      map(await _get('/ai-exams/analytics', {for (final e in filters.entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value}));
  Future<Map<String, dynamic>> studentAnalytics(String studentId) async => map(await _get('/ai-exams/analytics/students/$studentId'));

  /// Uploads a question image through the existing file upload endpoint; returns its /uploads path.
  Future<String> uploadImage(List<int> bytes, String filename) async {
    final r = await _api.dio.post('/files/upload', data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)}));
    final d = map(r.data['data']);
    return '${d['url'] ?? d['path'] ?? d['relativeUrl'] ?? ''}';
  }

  // ---------------------------------------------------------------- students
  Future<Map<String, dynamic>> myTests() async => map(await _get('/student/ai-exams'));
  Future<Map<String, dynamic>> myTest(String id) async => map(await _get('/student/ai-exams/$id'));
  Future<Map<String, dynamic>> start(String id) async => map(await _post('/student/ai-exams/$id/start'));
  Future<Map<String, dynamic>> saveAnswers(String id, List<Map<String, dynamic>> answers) async =>
      map(await _put('/student/ai-exams/$id/answers', {'answers': answers}));
  Future<Map<String, dynamic>> submit(String id, List<Map<String, dynamic>> answers) async =>
      map(await _post('/student/ai-exams/$id/submit', {'answers': answers}));
  Future<Map<String, dynamic>> result(String id) async => map(await _get('/student/ai-exams/$id/result'));
  Future<Map<String, dynamic>> performance() async => map(await _get('/student/ai-exams/performance'));
  Future<Map<String, dynamic>> plan({bool refresh = false}) async => map(await _get('/student/ai-exams/improvement-plan', {if (refresh) 'refresh': '1'}));

  // ---------------------------------------------------------------- administrators
  Future<Map<String, dynamic>> adminOverview() async => map(await _get('/admin/ai-exams/overview'));
  Future<Map<String, dynamic>> adminAnalytics(Map<String, String?> filters) async =>
      map(await _get('/admin/ai-exams/analytics', {for (final e in filters.entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value}));
  Future<List<Map<String, dynamic>>> adminTests() async {
    final r = await _api.dio.get('/admin/ai-exams/tests', queryParameters: {'pageSize': 100});
    return list(r.data['data']);
  }

  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) async => map(await _put('/admin/ai-exams/settings', body));
}

// ---------------------------------------------------------------- labels

const questionTypeLabels = {
  'MCQ': 'Multiple choice',
  'SHORT': 'Short answer',
  'LONG': 'Long answer',
  'FILL_BLANK': 'Fill in the blank',
  'TRUE_FALSE': 'True / False',
  'NUMERICAL': 'Numerical / problem',
};

const evaluationLabels = {
  'PENDING': 'Pending',
  'PROCESSING': 'Evaluating',
  'EVALUATED': 'Evaluated',
  'FAILED': 'Failed',
  'REVIEW': 'Needs review',
  'NOT_SUBMITTED': 'Not submitted',
};

const phaseLabels = {
  'DRAFT': 'Draft',
  'SCHEDULED': 'Scheduled',
  'ACTIVE': 'Active',
  'ENDED': 'Ended',
  'CLOSED': 'Closed',
  'ARCHIVED': 'Archived',
};

String fmtNum(num? v) {
  if (v == null) return '—';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
}

String fmtDate(dynamic v, {bool time = true}) {
  if (v == null) return '—';
  final d = DateTime.tryParse('$v')?.toLocal();
  if (d == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String two(int n) => n.toString().padLeft(2, '0');
  final day = '${d.day} ${months[d.month - 1]} ${d.year}';
  return time ? '$day, ${two(d.hour)}:${two(d.minute)}' : day;
}
