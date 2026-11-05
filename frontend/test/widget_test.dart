import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_provider.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  test('App theme configuration test', () {
    final theme = AppTheme.lightTheme;
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, AppTheme.primary);
    expect(theme.scaffoldBackgroundColor, AppTheme.background);
  });

  test('Auth state default initialization test', () {
    const authState = AuthState();
    expect(authState.isAuthenticated, isFalse);
    expect(authState.user, isNull);
    expect(authState.activeRole, isNull);
  });
}
