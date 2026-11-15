@Tags(['live'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_provider.dart';
import 'package:frontend/core/auth/roles.dart';
import 'package:frontend/core/auth/session_storage.dart';
import 'package:frontend/core/navigation/role_navigation.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the real client code against a running backend:
///
///   LIVE_API_BASE_URL=http://localhost:3000/api/v1 \
///   LIVE_TEST_PASSWORD=SEED_PASSWORD flutter test --tags live
///
/// Accounts come from LIVE_TEST_ACCOUNTS ("ROLE=login,ROLE=login,...");
/// nothing is hardcoded in the app itself. Skips when the server is unreachable
/// or no password is supplied.
void main() {
  final env = Platform.environment;
  final baseUrl = env['LIVE_API_BASE_URL'] ?? 'http://localhost:3000/api/v1';
  final password = env['LIVE_TEST_PASSWORD'];
  final accounts = <String, String>{
    for (final pair in (env['LIVE_TEST_ACCOUNTS'] ?? '').split(','))
      if (pair.contains('=')) pair.split('=')[0].trim(): pair.split('=')[1].trim(),
  };

  final api = ApiClient();
  String? skipReason;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    api.setBaseUrl(baseUrl);
    final problem = await api.checkConnection();
    if (problem != null) {
      skipReason = 'Backend not reachable at $baseUrl: ${problem.message}';
    } else if (password == null || password.isEmpty) {
      skipReason = 'Set LIVE_TEST_PASSWORD to run live login tests';
    }
  });

  setUp(() => api.clearAuth());

  AuthNotifier notifier() => AuthNotifier(api: api, storage: InMemorySessionStorage(), restoreOnCreate: false);

  test('tenant discovery is reachable and searches case-insensitively', () async {
    if (skipReason != null && skipReason!.startsWith('Backend')) return markTestSkipped(skipReason!);
    final all = await api.dio.get('/tenant-discovery');
    final schools = all.data['data'] as List;
    expect(schools, isNotEmpty);
    final code = schools.first['code'] as String;
    final lower = await api.dio.get('/tenant-discovery', queryParameters: {'query': code.toLowerCase()});
    expect((lower.data['data'] as List).map((s) => s['code']), contains(code));
  });

  for (final role in AppRoles.all) {
    test('$role: login -> profile -> role navigation -> logout', () async {
      if (skipReason != null) return markTestSkipped(skipReason!);
      final login = accounts[role];
      if (login == null) return markTestSkipped('No LIVE_TEST_ACCOUNTS entry for $role');

      final storage = InMemorySessionStorage();
      final n = AuthNotifier(api: api, storage: storage, restoreOnCreate: false);
      final ok = await n.login(login: login, password: password!);
      expect(ok, isTrue, reason: n.state.errorMessage);
      expect(n.state.activeRole, role);
      expect(storage.session, isNotNull);
      expect(RoleNavigation.forRole(n.state.activeRole), isNotNull);

      final me = await api.dio.get('/auth/me');
      expect(me.data['data']['activeRole'], role);
      expect(me.data['data']['activeSchool']['id'], n.state.activeSchool!.id);

      // Restart: a new notifier restores from storage and verifies once.
      final restored = AuthNotifier(api: api, storage: storage, restoreOnCreate: false);
      await restored.restoreSession();
      expect(restored.state.isAuthenticated, isTrue);
      expect(restored.state.activeRole, role);

      await restored.logout();
      expect(storage.session, isNull);
      expect(api.token, isNull);
    });
  }

  test('invalid password is rejected with a clear message', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    final login = accounts.values.isEmpty ? null : accounts.values.first;
    if (login == null) return markTestSkipped('No LIVE_TEST_ACCOUNTS');
    final n = notifier();
    expect(await n.login(login: login, password: '${password!}-wrong'), isFalse);
    expect(n.state.errorMessage, 'Incorrect email/username or password.');
  });

  test('unknown user is rejected with the same message (no account enumeration)', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    final n = notifier();
    expect(await n.login(login: 'no-such-user-${DateTime.now().millisecondsSinceEpoch}@example.invalid', password: password!), isFalse);
    expect(n.state.errorMessage, 'Incorrect email/username or password.');
  });

  test('school the user does not belong to is rejected', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    final login = accounts[AppRoles.schoolAdmin];
    if (login == null) return markTestSkipped('No SCHOOL_ADMIN account');
    final n = notifier();
    expect(await n.login(login: login, password: password!, schoolCode: 'NO-SUCH-SCHOOL'), isFalse);
    expect(n.state.errorMessage, contains('not registered at the selected school'));
  });

  test('a revoked token is refused by the API and ends the session', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    final login = accounts[AppRoles.principal];
    if (login == null) return markTestSkipped('No PRINCIPAL account');
    final storage = InMemorySessionStorage();
    final n = AuthNotifier(api: api, storage: storage, restoreOnCreate: false);
    expect(await n.login(login: login, password: password!), isTrue);
    final saved = storage.session!;

    // Sign out elsewhere (bumps tokenVersion server-side), then reuse the old tokens.
    await n.logout();
    storage.session = saved;
    final restored = AuthNotifier(api: api, storage: storage, restoreOnCreate: false);
    await restored.restoreSession();
    expect(restored.state.status, AuthStatus.unauthenticated);
    expect(restored.state.noticeMessage, isNotNull);
    expect(storage.session, isNull);
  });

  test('role-protected endpoint returns a readable 403', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    final login = accounts[AppRoles.parent];
    if (login == null) return markTestSkipped('No PARENT account');
    final n = notifier();
    expect(await n.login(login: login, password: password!), isTrue);
    try {
      await api.dio.get('/students/me/profile');
      fail('parent must not read the student self-profile');
    } catch (e) {
      final ex = toApiException(e);
      expect(ex.kind, ApiErrorKind.forbidden);
      expect(ex.message, isNot(contains('DioException')));
    } finally {
      await n.logout();
    }
  });

  test('unreachable server gives a connection error, not a crash', () async {
    api.setBaseUrl('http://127.0.0.1:1/api/v1');
    final n = notifier();
    expect(await n.login(login: 'x@example.invalid', password: 'whatever1'), isFalse);
    expect(n.state.errorMessage, anyOf(contains('refused'), contains('reach'), contains('too long')));
    api.setBaseUrl(baseUrl);
  });
}
