import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import 'session_storage.dart';

class SchoolModel {
  final String id;
  final String name;
  final String code;
  final String? logoUrl;
  final String currency;

  SchoolModel({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
    required this.currency,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      logoUrl: json['logoUrl'],
      currency: json['currency'] ?? 'INR',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'logoUrl': logoUrl,
        'currency': currency,
      };
}

class MembershipModel {
  final String schoolId;
  final String schoolName;
  final String schoolCode;
  final String role;

  MembershipModel({
    required this.schoolId,
    required this.schoolName,
    required this.schoolCode,
    required this.role,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipModel(
      schoolId: json['schoolId'] ?? '',
      schoolName: json['schoolName'] ?? '',
      schoolCode: json['schoolCode'] ?? '',
      role: json['role'] ?? 'GUEST',
    );
  }

  Map<String, dynamic> toJson() => {
        'schoolId': schoolId,
        'schoolName': schoolName,
        'schoolCode': schoolCode,
        'role': role,
      };
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String activeRole;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.activeRole,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      avatarUrl: json['avatarUrl'],
      activeRole: json['activeRole'] ?? 'GUEST',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'firstName': firstName,
        'lastName': lastName,
        'avatarUrl': avatarUrl,
        'activeRole': activeRole,
      };
}

enum AuthStatus { restoring, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final String? errorMessage;

  /// Informational message for the sign-in screen (for example "session expired").
  final String? noticeMessage;
  final String? token;
  final String? refreshToken;
  final UserModel? user;
  final SchoolModel? activeSchool;
  final String? activeRole;
  final List<MembershipModel> memberships;

  const AuthState({
    this.status = AuthStatus.restoring,
    this.isLoading = false,
    this.errorMessage,
    this.noticeMessage,
    this.token,
    this.refreshToken,
    this.user,
    this.activeSchool,
    this.activeRole,
    this.memberships = const [],
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isRestoring => status == AuthStatus.restoring;

  /// `errorMessage` and `noticeMessage` are cleared unless passed explicitly.
  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? errorMessage,
    String? noticeMessage,
    String? token,
    String? refreshToken,
    UserModel? user,
    SchoolModel? activeSchool,
    String? activeRole,
    List<MembershipModel>? memberships,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      noticeMessage: noticeMessage,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      activeSchool: activeSchool ?? this.activeSchool,
      activeRole: activeRole ?? this.activeRole,
      memberships: memberships ?? this.memberships,
    );
  }
}

/// Reads the `exp` claim of a JWT without verifying it (the server verifies).
DateTime? jwtExpiry(String? token) {
  if (token == null) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final exp = payload is Map ? payload['exp'] : null;
    if (exp is num) return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  } catch (_) {}
  return null;
}

bool isJwtExpired(String? token, {DateTime? now}) {
  final exp = jwtExpiry(token);
  if (exp == null) return true;
  return !exp.isAfter((now ?? DateTime.now()).toUtc());
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    ApiClient? api,
    SessionStorage? storage,
    bool restoreOnCreate = true,
  })  : _api = api ?? ApiClient(),
        _storage = storage ?? SecureSessionStorage(),
        super(const AuthState()) {
    _api.onSessionExpired = () => _endSession(
          notice: 'Your session has expired or was signed out on another device. Please sign in again.',
        );
    _api.onTokensRefreshed = (access, refresh) async {
      await _storage.updateTokens(access, refresh);
      if (mounted) {
        state = state.copyWith(token: access, refreshToken: refresh);
      }
    };
    if (restoreOnCreate) restoreSession();
  }

  final ApiClient _api;
  final SessionStorage _storage;
  bool _verifying = false;

  /// Restores a saved session at app start. Shows the dashboard from cache straight
  /// away and verifies it with `/auth/me` once in the background.
  Future<void> restoreSession() async {
    await _api.loadServerOverride();

    StoredSession? saved;
    try {
      saved = await _storage.read();
    } catch (_) {
      saved = null;
    }

    if (saved == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    // Both tokens expired: nothing to renew, go straight to sign-in without a request.
    if (isJwtExpired(saved.accessToken) && isJwtExpired(saved.refreshToken)) {
      await _storage.clear();
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        noticeMessage: 'Your session has expired. Please sign in again.',
      );
      return;
    }

    final school = SchoolModel.fromJson(saved.school);
    final user = UserModel.fromJson(saved.user);
    _api.setAuth(saved.accessToken, school.id, refreshToken: saved.refreshToken);

    state = AuthState(
      status: AuthStatus.authenticated,
      token: saved.accessToken,
      refreshToken: saved.refreshToken,
      user: user,
      activeSchool: school,
      activeRole: saved.role.isNotEmpty ? saved.role : user.activeRole,
      memberships: saved.memberships.map(MembershipModel.fromJson).toList(),
    );

    await verifySession();
  }

  /// Re-reads the profile from the server. A rejected session ends via
  /// [ApiClient.onSessionExpired]; network failures keep the cached session.
  Future<void> verifySession() async {
    if (_verifying || !state.isAuthenticated) return;
    _verifying = true;
    try {
      final res = await _api.dio.get('/auth/me');
      final data = res.data['data'];
      if (data is! Map<String, dynamic> || !mounted || !state.isAuthenticated) return;
      final user = UserModel.fromJson(data);
      final schoolJson = data['activeSchool'];
      final school = schoolJson is Map<String, dynamic> ? SchoolModel.fromJson(schoolJson) : state.activeSchool;
      final memberships = (data['memberships'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MembershipModel.fromJson)
          .toList();

      state = state.copyWith(
        user: user,
        activeSchool: school,
        activeRole: user.activeRole,
        memberships: memberships,
      );
      await _persist();
    } catch (_) {
      // Offline or server down: keep the cached session.
    } finally {
      _verifying = false;
    }
  }

  Future<bool> login({
    required String login,
    required String password,
    String? schoolCode,
  }) async {
    if (state.isLoading) return false; // ignore duplicate submissions

    final identifier = login.trim();
    if (identifier.isEmpty || password.isEmpty) {
      state = state.copyWith(errorMessage: 'Enter your email or username and your password.');
      return false;
    }

    state = state.copyWith(isLoading: true);

    try {
      final response = await _api.dio.post('/auth/login', data: {
        'login': identifier,
        'password': password,
        if (schoolCode != null && schoolCode.trim().isNotEmpty) 'schoolCode': schoolCode.trim(),
      });

      final data = response.data is Map ? response.data['data'] : null;
      final token = data is Map ? data['accessToken'] : null;
      final userData = data is Map ? data['user'] : null;
      if (token is! String || userData is! Map<String, dynamic> || userData['activeSchool'] is! Map) {
        throw ApiException(
          message: 'The server sent an unexpected sign-in response. Check that the app points to the Ark-ERP API.',
          kind: ApiErrorKind.invalidResponse,
          code: 'INVALID_LOGIN_RESPONSE',
        );
      }

      final refreshToken = data['refreshToken'] as String?;
      final user = UserModel.fromJson(userData);
      final activeSchool = SchoolModel.fromJson(Map<String, dynamic>.from(userData['activeSchool']));
      final memberships = (userData['memberships'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MembershipModel.fromJson)
          .toList();

      _api.setAuth(token, activeSchool.id, refreshToken: refreshToken);

      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        refreshToken: refreshToken,
        user: user,
        activeSchool: activeSchool,
        activeRole: user.activeRole,
        memberships: memberships,
      );
      await _persist();
      return true;
    } catch (e) {
      _api.clearAuth();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: loginErrorMessage(e),
      );
      return false;
    }
  }

  /// Turns a sign-in failure into a message that tells the user what to do.
  static String loginErrorMessage(Object error) {
    final ex = toApiException(error);
    final msg = ex.message.toLowerCase();
    if (ex.kind == ApiErrorKind.unauthorized) {
      if (msg.contains('invalid credentials')) {
        return 'Incorrect email/username or password.';
      }
      if (msg.contains('membership in this school')) {
        return 'This account is not registered at the selected school. Choose a different school or clear the selection.';
      }
      if (msg.contains('no active school')) {
        return 'This account is not linked to any active school. Contact your school administrator.';
      }
      if (msg.contains('suspended')) {
        return 'This account has been suspended. Contact your school administrator.';
      }
    }
    if (ex.kind == ApiErrorKind.validation && msg.contains('password')) {
      return 'Password must be at least 6 characters.';
    }
    return ex.message;
  }

  Future<bool> switchSchool(String schoolId) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true);

    try {
      final response = await _api.dio.post('/auth/switch-school', data: {'schoolId': schoolId});
      final data = response.data['data'];
      final token = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String?;
      final school = SchoolModel.fromJson(data['activeSchool']);
      final newRole = data['activeRole'] as String;

      _api.setAuth(token, school.id, refreshToken: refreshToken);

      state = state.copyWith(
        isLoading: false,
        token: token,
        refreshToken: refreshToken,
        activeSchool: school,
        activeRole: newRole,
      );
      await _persist();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Could not switch school: ${apiErrorMessage(e)}');
      return false;
    }
  }

  /// Changes the signed-in user's password. The server revokes all other sessions and
  /// returns fresh tokens, which replace the current ones so this device stays signed in.
  /// Returns null on success, or a message describing the problem.
  Future<String?> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      final res = await _api.dio.post('/auth/change-password', data: {
        'oldPassword': currentPassword,
        'newPassword': newPassword,
      });
      final data = res.data is Map ? res.data['data'] : null;
      final token = data is Map ? data['accessToken'] as String? : null;
      final refresh = data is Map ? data['refreshToken'] as String? : null;
      if (token != null) {
        _api.setAuth(token, state.activeSchool?.id, refreshToken: refresh);
        state = state.copyWith(token: token, refreshToken: refresh);
        await _persist();
      }
      return null;
    } catch (e) {
      final ex = toApiException(e);
      if (ex.message.toLowerCase().contains('current password does not match')) {
        return 'Your current password is incorrect.';
      }
      return ex.message;
    }
  }

  /// Signs out: revokes the session on the server (best effort) and wipes local tokens.
  Future<void> logout() async {
    if (_api.token != null) {
      try {
        await _api.dio.post('/auth/logout').timeout(const Duration(seconds: 5));
      } catch (_) {
        // Local sign-out must succeed even when the server is unreachable.
      }
    }
    await _endSession();
  }

  Future<void> _endSession({String? notice}) async {
    _api.clearAuth();
    try {
      await _storage.clear();
    } catch (_) {}
    if (mounted) {
      state = AuthState(status: AuthStatus.unauthenticated, noticeMessage: notice);
    }
  }

  void clearMessages() {
    if (state.errorMessage != null || state.noticeMessage != null) {
      state = state.copyWith();
    }
  }

  Future<void> _persist() async {
    final token = state.token;
    final user = state.user;
    final school = state.activeSchool;
    if (token == null || user == null || school == null) return;
    await _storage.write(StoredSession(
      accessToken: token,
      refreshToken: state.refreshToken,
      user: user.toJson(),
      school: school.toJson(),
      role: state.activeRole ?? user.activeRole,
      memberships: state.memberships.map((m) => m.toJson()).toList(),
    ));
  }
}

final sessionStorageProvider = Provider<SessionStorage>((ref) => SecureSessionStorage());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(storage: ref.watch(sessionStorageProvider));
});
