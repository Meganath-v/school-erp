@Tags(['live'])
library;

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_provider.dart';
import 'package:frontend/core/auth/roles.dart';
import 'package:frontend/core/auth/session_storage.dart';
import 'package:frontend/core/navigation/role_navigation.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/home/presentation/role_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders every screen of every role at phone width with live API data and the
/// real Roboto font, and fails listing each layout overflow with its source line.
///
///   LIVE_TEST_PASSWORD=... LIVE_TEST_ACCOUNTS="ROLE=login,..." \
///     flutter test --tags live --run-skipped test/live/phone_layout_audit_test.dart
///
/// Optional: LAYOUT_AUDIT_WIDTH (logical px, default 360), LAYOUT_AUDIT_ROLES.
void main() {
  final env = Platform.environment;
  final baseUrl = env['LIVE_API_BASE_URL'] ?? 'http://localhost:3000/api/v1';
  final password = env['LIVE_TEST_PASSWORD'];
  final width = double.tryParse(env['LAYOUT_AUDIT_WIDTH'] ?? '') ?? 360;
  final onlyRoles = (env['LAYOUT_AUDIT_ROLES'] ?? '').split(',').where((r) => r.isNotEmpty).toSet();
  final accounts = <String, String>{
    for (final pair in (env['LIVE_TEST_ACCOUNTS'] ?? '').split(','))
      if (pair.contains('=')) pair.split('=')[0].trim(): pair.split('=')[1].trim(),
  };
  final flutterRoot = env['FLUTTER_ROOT'] ?? 'D:/src/flutter';

  Future<void> loadFonts() async {
    final dir = '$flutterRoot/bin/cache/artifacts/material_fonts';
    Future<void> family(String name, List<String> files) async {
      final loader = FontLoader(name);
      for (final f in files) {
        final bytes = File('$dir/$f').readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
    }

    const roboto = ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf', 'roboto-light.ttf'];
    // The app asks for Inter/Outfit and falls back to Roboto on Android, so measure with Roboto.
    for (final name in ['Roboto', 'Inter', 'Outfit']) {
      await family(name, roboto);
    }
    await family('MaterialIcons', ['materialicons-regular.otf']);
  }

  final findings = <String, Set<String>>{}; // source location -> screens

  String locate(FlutterErrorDetails d) {
    final text = d.toString();
    final isOverflow = text.contains('overflowed');
    final kind = isOverflow ? 'overflow' : d.exceptionAsString().split('\n').first;
    // Runtime errors: first stack frame in our own code. Overflows: the widget's creation site.
    if (!isOverflow && d.stack != null) {
      final f = RegExp(r'package:frontend/([^\s:]+\.dart)[ :](\d+)').firstMatch(d.stack.toString());
      if (f != null) return '${f.group(1)}:${f.group(2)}  [$kind]';
    }
    final m = RegExp(r'file:///[^\s]*?/lib/([^\s:]+\.dart):(\d+)').firstMatch(text);
    return m == null ? kind : '${m.group(1)}:${m.group(2)}  [$kind]';
  }

  var inFlight = 0;
  final tracker = InterceptorsWrapper(
    onRequest: (o, h) {
      inFlight++;
      h.next(o);
    },
    onResponse: (r, h) {
      inFlight--;
      h.next(r);
    },
    onError: (e, h) {
      inFlight--;
      h.next(e);
    },
  );

  // Pump until every API call the screen started has finished (max ~30 s).
  Future<void> settle(WidgetTester tester) async {
    var idleRounds = 0;
    for (var i = 0; i < 60 && idleRounds < 2; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(milliseconds: 100));
      idleRounds = inFlight == 0 ? idleRounds + 1 : 0;
    }
  }

  for (final role in AppRoles.all) {
    if (onlyRoles.isNotEmpty && !onlyRoles.contains(role)) continue;

    testWidgets('$role screens fit a ${width.toInt()}px-wide phone', (tester) async {
      final login = accounts[role];
      if (password == null || login == null) {
        markTestSkipped('Set LIVE_TEST_PASSWORD and LIVE_TEST_ACCOUNTS');
        return;
      }
      HttpOverrides.global = null; // allow real HTTP to the live backend
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(loadFonts);

      tester.view.physicalSize = Size(width * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final api = ApiClient()..setBaseUrl(baseUrl);
      if (!api.dio.interceptors.contains(tracker)) api.dio.interceptors.insert(0, tracker);
      inFlight = 0;
      final storage = InMemorySessionStorage();
      final ok = await tester.runAsync(
        () => AuthNotifier(api: api, storage: storage, restoreOnCreate: false).login(login: login, password: password),
      );
      expect(ok, isTrue, reason: 'login failed for $role');

      final nav = RoleNavigation.forRole(role)!;
      final screens = <String, WidgetBuilder>{
        'Home': (_) => RoleHomeScreen(navigation: nav, onOpenSection: (_) {}),
        for (final s in nav.sections) s.label: s.builder,
      };

      final original = FlutterError.onError;
      String current = '';
      FlutterError.onError = (details) {
        findings.putIfAbsent(locate(details), () => <String>{}).add('$role › $current');
      };

      try {
        for (final entry in screens.entries) {
          current = entry.key;
          await tester.pumpWidget(ProviderScope(
            overrides: [sessionStorageProvider.overrideWithValue(storage)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(body: Builder(builder: entry.value)),
            ),
          ));
          await settle(tester);

          // Visit every tab of tabbed screens (re-find tabs after each switch).
          final tabCount = find.byType(Tab).evaluate().length;
          for (var i = 1; i < tabCount; i++) {
            final tabs = find.byType(Tab);
            if (i >= tabs.evaluate().length) break;
            current = '${entry.key} › tab ${i + 1}';
            await tester.ensureVisible(tabs.at(i)); // tabs past the edge of a scrollable tab strip
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(tabs.at(i), warnIfMissed: false);
            await settle(tester);
          }
        }
        // Unmount before restoring the handler so late errors are still attributed.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          try {
            await api.dio.post('/auth/logout');
          } catch (_) {}
        });
        // Let the HTTP client's idle-connection timers fire before the test ends.
        await tester.pump(const Duration(seconds: 20));
      } finally {
        FlutterError.onError = original;
        api.clearAuth();
      }
    });
  }

  tearDownAll(() {
    if (findings.isEmpty) {
      // ignore: avoid_print
      print('LAYOUT AUDIT: no layout errors found at ${width.toInt()}px');
      return;
    }
    final lines = findings.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    // ignore: avoid_print
    print('LAYOUT AUDIT: ${lines.length} problem locations at ${width.toInt()}px');
    for (final l in lines) {
      // ignore: avoid_print
      print('  ${l.key}\n      seen in: ${l.value.take(4).join(' | ')}${l.value.length > 4 ? ' (+${l.value.length - 4})' : ''}');
    }
  });
}
