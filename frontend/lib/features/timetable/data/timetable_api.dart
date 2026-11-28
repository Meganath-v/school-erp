import '../../../core/network/api_client.dart';

/// Bell schedule, class timetable, daily substitutions and period attendance.
/// Every call returns the envelope's `data`.
class TimetableApi {
  TimetableApi([ApiClient? client]) : _api = client ?? ApiClient();
  final ApiClient _api;

  Future<dynamic> _get(String p, [Map<String, dynamic>? q]) async => (await _api.dio.get(p, queryParameters: q)).data['data'];
  Future<dynamic> _put(String p, Object b) async => (await _api.dio.put(p, data: b)).data['data'];
  Future<dynamic> _post(String p, Object b) async => (await _api.dio.post(p, data: b)).data['data'];
  Future<dynamic> _delete(String p, Map<String, dynamic> q) async => (await _api.dio.delete(p, queryParameters: q)).data['data'];

  static List<Map<String, dynamic>> list(dynamic v) =>
      (v as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  static Map<String, dynamic> map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  /// Classes with their sections, for the office's section picker.
  Future<List<Map<String, dynamic>>> classes() async => list(await _get('/schools/classes'));

  Future<Map<String, dynamic>> periods() async => map(await _get('/timetable/periods'));
  Future<Map<String, dynamic>> savePeriods(List<Map<String, dynamic>> periods, {bool removeAssignedSlots = false}) async =>
      map(await _put('/timetable/periods', {'periods': periods, if (removeAssignedSlots) 'removeAssignedSlots': true}));

  Future<Map<String, dynamic>> classTimetable(String sectionId) async => map(await _get('/timetable/class/$sectionId'));
  Future<Map<String, dynamic>> setSlot(String sectionId, Map<String, dynamic> body) async =>
      map(await _put('/timetable/class/$sectionId/slot', body));
  Future<Map<String, dynamic>> clearSlot(String sectionId, int dayOfWeek, int periodNumber) async =>
      map(await _delete('/timetable/class/$sectionId/slot', {'dayOfWeek': dayOfWeek, 'periodNumber': periodNumber}));

  Future<Map<String, dynamic>> daily(String sectionId, String date) async => map(await _get('/timetable/daily/$sectionId', {'date': date}));
  Future<Map<String, dynamic>> substitute(String sectionId, Map<String, dynamic> body) async =>
      map(await _put('/timetable/daily/$sectionId/substitution', body));
  Future<Map<String, dynamic>> clearSubstitution(String sectionId, String date, int periodNumber) async =>
      map(await _delete('/timetable/daily/$sectionId/substitution', {'date': date, 'periodNumber': periodNumber}));

  Future<Map<String, dynamic>> myDay(String date) async => map(await _get('/timetable/my-day', {'date': date}));

  Future<Map<String, dynamic>> periodAttendance(String sectionId, String date, int periodNumber) async =>
      map(await _get('/attendance/periods', {'sectionId': sectionId, 'date': date, 'periodNumber': periodNumber}));
  Future<Map<String, dynamic>> savePeriodAttendance(Map<String, dynamic> body) async => map(await _post('/attendance/periods', body));

  /// The class teacher's own section (null if not a class teacher).
  Future<Map<String, dynamic>?> myClassSection() async {
    final r = map(await _get('/teacher/my-classes'));
    final sections = list(r['assignedSections']);
    for (final s in sections) {
      if (s['isClassTeacher'] == true) return s;
    }
    return null;
  }
}

const dayNames = {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday'};
const dayShort = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

String dateText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String niceDate(String text) {
  final d = DateTime.tryParse(text);
  if (d == null) return text;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dayShort[d.weekday]} ${d.day} ${months[d.month - 1]} ${d.year}';
}
