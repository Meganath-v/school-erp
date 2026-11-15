import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/fake_adapter.dart';

void main() {
  final api = ApiClient();
  late FakeAdapter adapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.clearAuth();
    api.onSessionExpired = null;
    api.onTokensRefreshed = null;
    api.setBaseUrl('http://test.local:3000/api/v1');
    adapter = FakeAdapter((_) => const FakeResponse(200, {'data': []}));
    api.debugSetAdapter(adapter);
  });

  Future<ApiException> errorOf(Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      return toApiException(e);
    }
    fail('expected the call to throw');
  }

  group('error parsing', () {
    test('server error envelope message is surfaced', () async {
      adapter.handler = (_) => FakeResponse(401, errorBody(401, 'Invalid credentials'));
      final e = await errorOf(() => api.dio.post('/auth/login', data: {}));
      expect(e.message, 'Invalid credentials');
      expect(e.kind, ApiErrorKind.unauthorized);
      expect(e.statusCode, 401);
    });

    test('validation errors keep the server message', () async {
      adapter.handler = (_) => FakeResponse(400, errorBody(400, 'password must be longer than or equal to 6 characters', 'Bad Request'));
      final e = await errorOf(() => api.dio.post('/auth/login', data: {}));
      expect(e.kind, ApiErrorKind.validation);
      expect(e.message, contains('6 characters'));
    });

    test('timeouts become a TIMEOUT error', () async {
      adapter.handler = (_) => const FakeResponse.fail(DioExceptionType.connectionTimeout);
      final e = await errorOf(() => api.dio.get('/tenant-discovery'));
      expect(e.kind, ApiErrorKind.timeout);
      expect(e.isConnectivity, isTrue);
    });

    test('connection refused -> backend not running', () async {
      adapter.handler = (_) => const FakeResponse.fail(
          DioExceptionType.connectionError, SocketException('Connection refused', osError: OSError('Connection refused', 111)));
      final e = await errorOf(() => api.dio.get('/tenant-discovery'));
      expect(e.kind, ApiErrorKind.serverUnreachable);
      expect(e.message, contains('test.local:3000'));
      expect(e.message, contains('backend is running'));
    });

    test('no route / DNS failure -> network unavailable', () async {
      adapter.handler = (_) => const FakeResponse.fail(
          DioExceptionType.connectionError, SocketException('Failed host lookup: test.local'));
      final e = await errorOf(() => api.dio.get('/tenant-discovery'));
      expect(e.kind, ApiErrorKind.networkUnavailable);
    });

    test('DioException.toString is human readable everywhere', () async {
      adapter.handler = (_) => FakeResponse(403, errorBody(403, 'Your role is not permitted to perform this action', 'Forbidden'));
      try {
        await api.dio.get('/staff');
      } catch (e) {
        expect(e.toString(), 'Your role is not permitted to perform this action');
        return;
      }
      fail('expected error');
    });

    test('no configured server is reported before any request is sent', () async {
      api.setBaseUrl('');
      final e = await errorOf(() => api.dio.get('/tenant-discovery'));
      expect(e.kind, ApiErrorKind.notConfigured);
      expect(adapter.requests, isEmpty);
    });
  });

  group('token refresh', () {
    test('401 triggers one refresh, retries the request and reports the new tokens', () async {
      api.setAuth('old-access', 's1', refreshToken: 'refresh-1');
      String? persisted;
      api.onTokensRefreshed = (a, r) async => persisted = a;

      adapter.handler = (o) {
        if (o.path.endsWith('/auth/refresh')) return const FakeResponse(200, {'data': {'accessToken': 'new-access'}});
        final auth = o.headers['Authorization'];
        if (auth == 'Bearer new-access') return const FakeResponse(200, {'data': 'ok'});
        return FakeResponse(401, errorBody(401, 'Unauthorized'));
      };

      final res = await api.dio.get('/students');
      expect(res.data['data'], 'ok');
      expect(adapter.count('/auth/refresh'), 1);
      expect(api.token, 'new-access');
      expect(api.refreshToken, 'refresh-1');
      expect(persisted, 'new-access');
    });

    test('concurrent 401s share a single refresh', () async {
      api.setAuth('old-access', 's1', refreshToken: 'refresh-1');
      adapter.handler = (o) async {
        if (o.path.endsWith('/auth/refresh')) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return const FakeResponse(200, {'data': {'accessToken': 'new-access'}});
        }
        return o.headers['Authorization'] == 'Bearer new-access'
            ? const FakeResponse(200, {'data': 'ok'})
            : FakeResponse(401, errorBody(401, 'Unauthorized'));
      };

      final results = await Future.wait([api.dio.get('/a'), api.dio.get('/b'), api.dio.get('/c')]);
      expect(results.every((r) => r.data['data'] == 'ok'), isTrue);
      expect(adapter.count('/auth/refresh'), 1);
    });

    test('rejected refresh ends the session exactly once', () async {
      api.setAuth('old-access', 's1', refreshToken: 'revoked');
      var expired = 0;
      api.onSessionExpired = () async => expired++;
      adapter.handler = (o) => o.path.endsWith('/auth/refresh')
          ? FakeResponse(401, errorBody(401, 'Invalid or expired refresh token'))
          : FakeResponse(401, errorBody(401, 'Session has been revoked. Please sign in again.'));

      final e = await errorOf(() => api.dio.get('/students'));
      expect(e.code, 'SESSION_EXPIRED');
      expect(expired, 1);
      expect(api.token, isNull);
      expect(api.refreshToken, isNull);
    });

    test('refresh failing because the server is unreachable keeps the session', () async {
      api.setAuth('old-access', 's1', refreshToken: 'refresh-1');
      var expired = 0;
      api.onSessionExpired = () async => expired++;
      adapter.handler = (o) => o.path.endsWith('/auth/refresh')
          ? const FakeResponse.fail(DioExceptionType.connectionTimeout)
          : FakeResponse(401, errorBody(401, 'Unauthorized'));

      await errorOf(() => api.dio.get('/students'));
      expect(expired, 0);
      expect(api.token, 'old-access');
    });

    test('a 401 from /auth/login never triggers a refresh', () async {
      api.setAuth('stale', 's1', refreshToken: 'refresh-1');
      adapter.handler = (_) => FakeResponse(401, errorBody(401, 'Invalid credentials'));
      await errorOf(() => api.dio.post('/auth/login', data: {}));
      expect(adapter.count('/auth/refresh'), 0);
    });
  });

  test('checkConnection accepts the Ark-ERP discovery response and rejects others', () async {
    adapter.handler = (_) => const FakeResponse(200, {'data': []});
    expect(await api.checkConnection(), isNull);

    adapter.handler = (_) => const FakeResponse(200, {'hello': 'world'});
    expect((await api.checkConnection())!.kind, ApiErrorKind.invalidResponse);

    adapter.handler = (_) => const FakeResponse.fail(DioExceptionType.connectionTimeout);
    expect((await api.checkConnection())!.kind, ApiErrorKind.timeout);
  });

  test('attaches bearer token and school header', () async {
    api.setAuth('tok', 'school-9');
    await api.dio.get('/students');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok');
    expect(adapter.requests.single.headers['x-school-id'], 'school-9');
  });
}
