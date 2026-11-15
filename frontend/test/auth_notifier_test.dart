import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_provider.dart';
import 'package:frontend/core/auth/session_storage.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/fake_adapter.dart';

void main() {
  final api = ApiClient();
  late FakeAdapter adapter;
  late InMemorySessionStorage storage;

  AuthNotifier newNotifier() => AuthNotifier(api: api, storage: storage, restoreOnCreate: false);

  StoredSession savedSession({String? access, String? refresh, String role = 'PRINCIPAL'}) => StoredSession(
        accessToken: access ?? fakeJwt(),
        refreshToken: refresh ?? fakeJwt(expiresIn: const Duration(days: 7)),
        user: {'id': 'u1', 'email': 'p@example.test', 'name': 'Pat Doe', 'firstName': 'Pat', 'lastName': 'Doe', 'activeRole': role},
        school: {'id': 's1', 'name': 'Test School', 'code': 'TST01', 'currency': 'INR'},
        role: role,
        memberships: [
          {'schoolId': 's1', 'schoolName': 'Test School', 'schoolCode': 'TST01', 'role': role},
        ],
      );

  Map<String, dynamic> meBody(String role) => {
        'data': {
          'id': 'u1',
          'email': 'p@example.test',
          'name': 'Pat Doe',
          'firstName': 'Pat',
          'lastName': 'Doe',
          'activeRole': role,
          'activeSchool': {'id': 's1', 'name': 'Test School', 'code': 'TST01', 'currency': 'INR'},
          'memberships': [
            {'schoolId': 's1', 'schoolName': 'Test School', 'schoolCode': 'TST01', 'role': role},
          ],
        },
      };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = InMemorySessionStorage();
    api.clearAuth();
    api.setBaseUrl('http://test.local:3000/api/v1');
    adapter = FakeAdapter((_) => const FakeResponse(200, {'data': []}));
    api.debugSetAdapter(adapter);
  });

  group('login', () {
    test('valid login stores tokens, user, school and role', () async {
      adapter.handler = (o) => FakeResponse(200, loginBody(role: 'CLASS_TEACHER'));
      final n = newNotifier();
      final ok = await n.login(login: ' teacher@example.test ', password: 'secret123', schoolCode: 'TST01');

      expect(ok, isTrue);
      expect(n.state.isAuthenticated, isTrue);
      expect(n.state.activeRole, 'CLASS_TEACHER');
      expect(n.state.activeSchool!.code, 'TST01');
      expect(api.token, isNotNull);
      expect(api.schoolId, 's1');
      expect(storage.session!.role, 'CLASS_TEACHER');
      expect(storage.session!.refreshToken, isNotNull);

      final body = adapter.requests.single.data as Map;
      expect(body['login'], 'teacher@example.test');
      expect(body['password'], 'secret123');
      expect(body['schoolCode'], 'TST01');
    });

    test('schoolCode is omitted when no school is selected', () async {
      adapter.handler = (_) => FakeResponse(200, loginBody());
      await newNotifier().login(login: 'a@b.c', password: 'secret123');
      expect((adapter.requests.single.data as Map).containsKey('schoolCode'), isFalse);
    });

    test('invalid password / unknown user show a clear message and store nothing', () async {
      adapter.handler = (_) => FakeResponse(401, errorBody(401, 'Invalid credentials'));
      final n = newNotifier();
      expect(await n.login(login: 'a@b.c', password: 'wrongpass'), isFalse);
      expect(n.state.errorMessage, 'Incorrect email/username or password.');
      expect(n.state.isAuthenticated, isFalse);
      expect(n.state.isLoading, isFalse);
      expect(storage.session, isNull);
      expect(api.token, isNull);
    });

    test('wrong school selection explains the problem', () async {
      adapter.handler = (_) => FakeResponse(401, errorBody(401, 'You do not have an active membership in this school'));
      final n = newNotifier();
      await n.login(login: 'a@b.c', password: 'secret123', schoolCode: 'OTHER');
      expect(n.state.errorMessage, contains('not registered at the selected school'));
    });

    test('backend unavailable gives a connection message', () async {
      adapter.handler = (_) => const FakeResponse.fail(DioExceptionType.connectionError, 'Connection refused');
      final n = newNotifier();
      await n.login(login: 'a@b.c', password: 'secret123');
      expect(n.state.errorMessage, contains('refused the connection'));
    });

    test('unexpected response shape is reported, not crashed on', () async {
      adapter.handler = (_) => const FakeResponse(200, {'data': {'token': 'x'}});
      final n = newNotifier();
      expect(await n.login(login: 'a@b.c', password: 'secret123'), isFalse);
      expect(n.state.errorMessage, contains('unexpected sign-in response'));
    });

    test('empty fields are rejected without a request', () async {
      final n = newNotifier();
      expect(await n.login(login: '  ', password: ''), isFalse);
      expect(adapter.requests, isEmpty);
      expect(n.state.errorMessage, isNotNull);
    });

    test('duplicate submissions while loading send one request', () async {
      adapter.handler = (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return FakeResponse(200, loginBody());
      };
      final n = newNotifier();
      final first = n.login(login: 'a@b.c', password: 'secret123');
      final second = await n.login(login: 'a@b.c', password: 'secret123');
      expect(second, isFalse);
      expect(await first, isTrue);
      expect(adapter.count('/auth/login'), 1);
    });
  });

  group('session restore', () {
    test('no saved session -> unauthenticated, no network calls', () async {
      final n = newNotifier();
      await n.restoreSession();
      expect(n.state.status, AuthStatus.unauthenticated);
      expect(adapter.requests, isEmpty);
    });

    test('saved session -> authenticated and verified once with /auth/me', () async {
      storage.session = savedSession(role: 'PRINCIPAL');
      adapter.handler = (o) => o.path.endsWith('/auth/me') ? FakeResponse(200, meBody('PRINCIPAL')) : const FakeResponse(200, {'data': []});
      final n = newNotifier();
      await n.restoreSession();
      expect(n.state.isAuthenticated, isTrue);
      expect(n.state.activeRole, 'PRINCIPAL');
      expect(api.token, storage.session!.accessToken);
      expect(adapter.count('/auth/me'), 1);
    });

    test('server role change is picked up on restore', () async {
      storage.session = savedSession(role: 'SUBJECT_TEACHER');
      adapter.handler = (_) => FakeResponse(200, meBody('CLASS_TEACHER'));
      final n = newNotifier();
      await n.restoreSession();
      expect(n.state.activeRole, 'CLASS_TEACHER');
      expect(storage.session!.role, 'CLASS_TEACHER');
    });

    test('both tokens expired -> straight to sign-in without a request', () async {
      storage.session = savedSession(
        access: fakeJwt(expiresIn: const Duration(minutes: -5)),
        refresh: fakeJwt(expiresIn: const Duration(minutes: -1)),
      );
      final n = newNotifier();
      await n.restoreSession();
      expect(n.state.status, AuthStatus.unauthenticated);
      expect(n.state.noticeMessage, contains('expired'));
      expect(storage.session, isNull);
      expect(adapter.requests, isEmpty);
    });

    test('expired access token is refreshed and the new token persisted', () async {
      storage.session = savedSession(
        access: fakeJwt(expiresIn: const Duration(minutes: -5)),
        refresh: fakeJwt(expiresIn: const Duration(days: 3)),
      );
      final fresh = fakeJwt(expiresIn: const Duration(hours: 1), sub: 'fresh');
      adapter.handler = (o) {
        if (o.path.endsWith('/auth/refresh')) return FakeResponse(200, {'data': {'accessToken': fresh}});
        if (o.headers['Authorization'] == 'Bearer $fresh') return FakeResponse(200, meBody('PRINCIPAL'));
        return FakeResponse(401, errorBody(401, 'Unauthorized'));
      };
      final n = newNotifier();
      await n.restoreSession();
      expect(n.state.isAuthenticated, isTrue);
      expect(storage.session!.accessToken, fresh);
      expect(n.state.token, fresh);
    });

    test('revoked session (refresh rejected) -> automatic logout with a notice', () async {
      storage.session = savedSession();
      adapter.handler = (o) => FakeResponse(401, errorBody(401, 'Session has been revoked. Please sign in again.'));
      final n = newNotifier();
      await n.restoreSession();
      expect(n.state.status, AuthStatus.unauthenticated);
      expect(n.state.noticeMessage, contains('session has expired'));
      expect(storage.session, isNull);
      expect(api.token, isNull);
    });

    test('offline at startup keeps the cached session', () async {
      storage.session = savedSession();
      adapter.handler = (_) => const FakeResponse.fail(DioExceptionType.connectionError, 'Network is unreachable');
      final n = newNotifier();
      await n.restoreSession();
      expect(n.state.isAuthenticated, isTrue);
      expect(storage.session, isNotNull);
    });
  });

  group('logout', () {
    test('revokes on the server and wipes local tokens', () async {
      storage.session = savedSession();
      adapter.handler = (o) => o.path.endsWith('/auth/me') ? FakeResponse(200, meBody('PRINCIPAL')) : const FakeResponse(200, {'data': {}});
      final n = newNotifier();
      await n.restoreSession();
      await n.logout();
      expect(adapter.count('/auth/logout'), 1);
      expect(n.state.status, AuthStatus.unauthenticated);
      expect(storage.session, isNull);
      expect(api.token, isNull);
      expect(api.refreshToken, isNull);
    });

    test('still signs out locally when the server is unreachable', () async {
      storage.session = savedSession();
      final n = newNotifier();
      adapter.handler = (o) => o.path.endsWith('/auth/me') ? FakeResponse(200, meBody('PRINCIPAL')) : const FakeResponse(200, {'data': []});
      await n.restoreSession();
      adapter.handler = (_) => const FakeResponse.fail(DioExceptionType.connectionTimeout);
      await n.logout();
      expect(n.state.status, AuthStatus.unauthenticated);
      expect(storage.session, isNull);
    });
  });

  test('jwtExpiry reads exp and treats garbage as expired', () {
    expect(isJwtExpired(fakeJwt()), isFalse);
    expect(isJwtExpired(fakeJwt(expiresIn: const Duration(seconds: -1))), isTrue);
    expect(isJwtExpired('not-a-jwt'), isTrue);
    expect(isJwtExpired(null), isTrue);
  });
}
