import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_provider.dart';
import 'package:frontend/core/auth/roles.dart';
import 'package:frontend/core/auth/session_storage.dart';
import 'package:frontend/core/navigation/role_navigation.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/presentation/login_screen.dart';
import 'package:frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/fake_adapter.dart';

const expectedBottomBar = {
  AppRoles.platformOwner: ['Home', 'Schools', 'Audit', 'More'],
  AppRoles.schoolAdmin: ['Home', 'Students', 'Fees', 'Attendance', 'More'],
  AppRoles.principal: ['Home', 'Reports', 'Attendance', 'Marks', 'More'],
  AppRoles.office: ['Home', 'Fees', 'Students', 'Notices', 'More'],
  AppRoles.classTeacher: ['Home', 'My class', 'Attendance', 'Marks', 'More'],
  AppRoles.subjectTeacher: ['Home', 'Teaching', 'Marks', 'Timetable', 'More'],
  AppRoles.parent: ['Home', 'Children', 'More'],
  AppRoles.student: ['Home', 'Studies', 'More'],
};

void main() {
  group('RoleNavigation.forRole', () {
    test('all eight roles are supported and their bottom-bar ids exist', () {
      for (final role in AppRoles.all) {
        final nav = RoleNavigation.forRole(role);
        expect(nav, isNotNull, reason: role);
        expect(nav!.primaryIds.length, inInclusiveRange(1, 3), reason: role);
        for (final id in nav.primaryIds) {
          expect(nav.indexOf(id), greaterThanOrEqualTo(0), reason: '$role/$id');
        }
        expect(nav.sections.map((s) => s.id).toSet().length, nav.sections.length, reason: 'unique ids for $role');
      }
    });

    test('unknown or missing roles get no screens (no admin fallback)', () {
      expect(RoleNavigation.forRole('GUEST'), isNull);
      expect(RoleNavigation.forRole(null), isNull);
      expect(RoleNavigation.forRole('school_admin'), isNull);
    });

    test('sensitive sections are limited to the right roles', () {
      bool has(String role, String id) => RoleNavigation.forRole(role)!.indexOf(id) >= 0;
      for (final role in [AppRoles.parent, AppRoles.student, AppRoles.classTeacher, AppRoles.subjectTeacher]) {
        expect(has(role, 'audit'), isFalse, reason: role);
        expect(has(role, 'fees'), isFalse, reason: role);
        expect(has(role, 'staff'), isFalse, reason: role);
      }
      expect(has(AppRoles.schoolAdmin, 'staff'), isTrue);
      expect(has(AppRoles.office, 'fees'), isTrue);
      expect(has(AppRoles.principal, 'fees'), isFalse);
    });
  });

  group('phone shell per role', () {
    final api = ApiClient();
    late FakeAdapter adapter;

    StoredSession sessionFor(String role) => StoredSession(
          accessToken: fakeJwt(),
          refreshToken: fakeJwt(expiresIn: const Duration(days: 7)),
          user: {'id': 'u-$role', 'email': 'x@example.test', 'name': 'Alex Kim', 'firstName': 'Alex', 'lastName': 'Kim', 'activeRole': role},
          school: {'id': 's1', 'name': 'Test School', 'code': 'TST01', 'currency': 'INR'},
          role: role,
          memberships: [
            {'schoolId': 's1', 'schoolName': 'Test School', 'schoolCode': 'TST01', 'role': role},
          ],
        );

    Future<InMemorySessionStorage> pumpApp(WidgetTester tester, String role) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      api.clearAuth();
      api.setBaseUrl('http://test.local:3000/api/v1');
      adapter = FakeAdapter((o) {
        if (o.path.endsWith('/auth/me')) {
          return FakeResponse(200, {
            'data': {
              ...sessionFor(role).user,
              'activeRole': role,
              'activeSchool': sessionFor(role).school,
              'memberships': sessionFor(role).memberships,
            },
          });
        }
        return const FakeResponse(200, {'data': []});
      });
      api.debugSetAdapter(adapter);

      final storage = InMemorySessionStorage()..session = sessionFor(role);
      await tester.pumpWidget(ProviderScope(
        overrides: [sessionStorageProvider.overrideWithValue(storage)],
        child: const SchoolErpApp(),
      ));
      await tester.pumpAndSettle();
      return storage;
    }

    for (final role in AppRoles.all) {
      testWidgets('$role restores into its own phone home and bottom bar', (tester) async {
        await pumpApp(tester, role);
        final bar = find.byType(NavigationBar);
        expect(bar, findsOneWidget);
        for (final label in expectedBottomBar[role]!) {
          expect(find.descendant(of: bar, matching: find.text(label)), findsOneWidget, reason: '$role: $label');
        }
        expect(find.textContaining(AppRoles.label(role)), findsWidgets);
        expect(find.byType(LoginScreen), findsNothing);
        expect(adapter.count('/auth/me'), 1, reason: 'profile is verified once, not repeatedly');
      });
    }

    testWidgets('unknown role sees the no-access screen', (tester) async {
      await pumpApp(tester, 'GUEST');
      expect(find.text('No access in this app'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('logout returns to sign-in, clears storage, and Back cannot reopen the dashboard', (tester) async {
      final storage = await pumpApp(tester, AppRoles.schoolAdmin);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      final drawerSignOut = find.descendant(of: find.byType(Drawer), matching: find.text('Sign out'));
      await tester.ensureVisible(drawerSignOut);
      await tester.pumpAndSettle();
      await tester.tap(drawerSignOut);
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget, reason: 'sign-out asks for confirmation');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(storage.session, isNull);
      expect(api.token, isNull);
      expect(adapter.count('/auth/logout'), 1);

      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(popped, isFalse, reason: 'no authenticated route is left on the stack');
    });
  });
}
