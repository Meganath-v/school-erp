import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

typedef FakeHandler = FutureOr<FakeResponse> Function(RequestOptions options);

class FakeResponse {
  final int status;
  final Object? body;
  final DioExceptionType? throwType;
  final Object? error;

  const FakeResponse(this.status, this.body) : throwType = null, error = null;
  const FakeResponse.fail(this.throwType, [this.error]) : status = 0, body = null;
}

/// Routes requests to [handler]; records every request for assertions.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  FakeHandler handler;
  final List<RequestOptions> requests = [];

  int count(String pathPart) => requests.where((r) => r.uri.path.contains(pathPart)).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final res = await handler(options);
    if (res.throwType != null) {
      throw DioException(requestOptions: options, type: res.throwType!, error: res.error);
    }
    return ResponseBody.fromString(
      jsonEncode(res.body),
      res.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Builds an unsigned JWT whose `exp` is [expiresIn] from now (the app only reads `exp`).
String fakeJwt({Duration expiresIn = const Duration(hours: 1), String sub = 'u1'}) {
  String enc(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': sub, 'exp': exp})}.sig';
}

Map<String, dynamic> loginBody({
  String role = 'SCHOOL_ADMIN',
  String? access,
  String? refresh,
  List<Map<String, dynamic>>? memberships,
}) =>
    {
      'data': {
        'accessToken': access ?? fakeJwt(),
        'refreshToken': refresh ?? fakeJwt(expiresIn: const Duration(days: 7)),
        'user': {
          'id': 'u1',
          'email': 'user@example.test',
          'name': 'Test User',
          'firstName': 'Test',
          'lastName': 'User',
          'activeRole': role,
          'activeSchool': {'id': 's1', 'name': 'Test School', 'code': 'TST01', 'currency': 'INR'},
          'memberships': memberships ??
              [
                {'schoolId': 's1', 'schoolName': 'Test School', 'schoolCode': 'TST01', 'role': role},
              ],
        },
      },
    };

Map<String, dynamic> errorBody(int status, String message, [String code = 'Unauthorized']) => {
      'error': {'code': code, 'message': message, 'statusCode': status},
    };

