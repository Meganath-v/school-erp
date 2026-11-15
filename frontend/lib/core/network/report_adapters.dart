import 'api_client.dart';

/// Maps the backend report endpoints to the shapes the existing screens read.
/// (Several screens were reading fields at the wrong level or from the wrong
/// endpoint, so their cards always showed defaults.)

Map<String, dynamic> _data(dynamic body) =>
    body is Map && body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : <String, dynamic>{};

/// `/reports/attendance-defaulters` + `/reports/attendance` →
/// `{condonationShortageList, condonationThreshold, overallAttendanceRate}`.
Future<Map<String, dynamic>> fetchAttendanceCompliance() async {
  final api = ApiClient();
  final results = await Future.wait([
    api.dio.get('/reports/attendance-defaulters'),
    api.dio.get('/reports/attendance'),
  ]);
  final defaulters = _data(results[0].data);
  final attendance = _data(results[1].data);
  final dSummary = defaulters['summary'] is Map ? defaulters['summary'] as Map : const {};
  final aSummary = attendance['summary'] is Map ? attendance['summary'] as Map : const {};
  return {
    'condonationShortageList': defaulters['rows'] is List ? defaulters['rows'] : <dynamic>[],
    'condonationThreshold': dSummary['threshold'] ?? aSummary['condonationThreshold'] ?? 75,
    'overallAttendanceRate': aSummary['overallAttendanceRate'],
    'defaulterCount': dSummary['defaulterCount'],
    'totalStudentsEvaluated': dSummary['totalStudentsEvaluated'],
  };
}

/// `/reports/examinations` → summary fields flattened next to `rows`/`broadsheet`.
Future<Map<String, dynamic>> fetchExamSummary() async {
  final res = await ApiClient().dio.get('/reports/examinations');
  final d = _data(res.data);
  final summary = d['summary'] is Map ? Map<String, dynamic>.from(d['summary'] as Map) : <String, dynamic>{};
  return {
    ...d,
    ...summary,
    'passedCandidates': summary['totalPassed'],
  };
}

/// `/reports/outstanding-fees` → `{grandTotals: {invoiced, collected, collectionRate, outstanding}, defaulters: [...]}`.
Future<Map<String, dynamic>> fetchOutstandingFees() async {
  final res = await ApiClient().dio.get('/reports/outstanding-fees');
  final d = _data(res.data);
  final summary = d['summary'] is Map ? d['summary'] as Map : const {};
  final billed = (summary['totalBilled'] as num?) ?? 0;
  final collected = (summary['totalCollected'] as num?) ?? 0;
  final rows = d['rows'] is List ? d['rows'] as List : const [];
  return {
    'grandTotals': {
      'invoiced': billed,
      'collected': collected,
      'outstanding': summary['totalOutstandingDue'] ?? 0,
      'collectionRate': billed > 0 ? ((collected / billed) * 100).round() : 100,
    },
    'defaulters': [
      for (final r in rows)
        if (r is Map)
          {
            ...Map<String, dynamic>.from(r),
            'fullName': r['studentName'],
            'title': r['category'],
            'dueAmount': r['balanceDue'],
          },
    ],
  };
}
