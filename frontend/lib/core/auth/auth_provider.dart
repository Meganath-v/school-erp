import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

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

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final String? token;
  final String? refreshToken;
  final UserModel? user;
  final SchoolModel? activeSchool;
  final String? activeRole;
  final List<MembershipModel> memberships;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
    this.token,
    this.refreshToken,
    this.user,
    this.activeSchool,
    this.activeRole,
    this.memberships = const [],
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    String? token,
    String? refreshToken,
    UserModel? user,
    SchoolModel? activeSchool,
    String? activeRole,
    List<MembershipModel>? memberships,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      activeSchool: activeSchool ?? this.activeSchool,
      activeRole: activeRole ?? this.activeRole,
      memberships: memberships ?? this.memberships,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _api.onSessionExpired = () async {
      logout();
      return false;
    };
    tryRestoreSession();
  }

  final _api = ApiClient();

  static const _keyToken = 'erp_access_token';
  static const _keyRefresh = 'erp_refresh_token';
  static const _keyUser = 'erp_user_data';
  static const _keySchool = 'erp_school_data';
  static const _keyRole = 'erp_active_role';
  static const _keyMemberships = 'erp_memberships';

  Future<void> tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyToken);
      final refreshToken = prefs.getString(_keyRefresh);
      final userStr = prefs.getString(_keyUser);
      final schoolStr = prefs.getString(_keySchool);
      final role = prefs.getString(_keyRole);
      final membershipsStr = prefs.getString(_keyMemberships);

      if (token != null && schoolStr != null && userStr != null) {
        final school = SchoolModel.fromJson(jsonDecode(schoolStr));
        final user = UserModel.fromJson(jsonDecode(userStr));
        final memberships = membershipsStr != null
            ? (jsonDecode(membershipsStr) as List)
                .map((m) => MembershipModel.fromJson(m))
                .toList()
            : <MembershipModel>[];

        _api.setAuth(token, school.id, refreshToken: refreshToken);

        state = state.copyWith(
          isAuthenticated: true,
          token: token,
          refreshToken: refreshToken,
          user: user,
          activeSchool: school,
          activeRole: role ?? user.activeRole,
          memberships: memberships,
        );

        // Background verification
        _verifySessionWithServer();
      }
    } catch (_) {}
  }

  Future<void> _verifySessionWithServer() async {
    try {
      final res = await _api.dio.get('/auth/me');
      final data = res.data['data'];
      final user = UserModel.fromJson(data);
      final school = SchoolModel.fromJson(data['activeSchool']);
      final memberships = (data['memberships'] as List? ?? [])
          .map((m) => MembershipModel.fromJson(m))
          .toList();

      state = state.copyWith(
        user: user,
        activeSchool: school,
        activeRole: user.activeRole,
        memberships: memberships,
      );
    } catch (_) {}
  }

  Future<bool> login({
    required String login,
    required String password,
    String? schoolCode,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _api.dio.post('/auth/login', data: {
        'login': login,
        'password': password,
        if (schoolCode != null && schoolCode.isNotEmpty) 'schoolCode': schoolCode,
      });

      final data = response.data['data'];
      final token = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String?;
      final userData = data['user'];
      final user = UserModel.fromJson(userData);
      final activeSchool = SchoolModel.fromJson(userData['activeSchool']);
      final memberships = (userData['memberships'] as List? ?? [])
          .map((m) => MembershipModel.fromJson(m))
          .toList();

      _api.setAuth(token, activeSchool.id, refreshToken: refreshToken);

      // Persist in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
      if (refreshToken != null) await prefs.setString(_keyRefresh, refreshToken);
      await prefs.setString(_keyUser, jsonEncode(user.toJson()));
      await prefs.setString(_keySchool, jsonEncode(activeSchool.toJson()));
      await prefs.setString(_keyRole, user.activeRole);
      await prefs.setString(
          _keyMemberships, jsonEncode(memberships.map((m) => m.toJson()).toList()));

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        token: token,
        refreshToken: refreshToken,
        user: user,
        activeSchool: activeSchool,
        activeRole: user.activeRole,
        memberships: memberships,
      );

      return true;
    } catch (e) {
      String msg = e.toString();
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> switchSchool(String schoolId) async {
    state = state.copyWith(isLoading: true);

    try {
      final response = await _api.dio.post('/auth/switch-school', data: {
        'schoolId': schoolId,
      });

      final data = response.data['data'];
      final token = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String?;
      final school = SchoolModel.fromJson(data['activeSchool']);
      final newRole = data['activeRole'] as String;

      _api.setAuth(token, school.id, refreshToken: refreshToken);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
      if (refreshToken != null) await prefs.setString(_keyRefresh, refreshToken);
      await prefs.setString(_keySchool, jsonEncode(school.toJson()));
      await prefs.setString(_keyRole, newRole);

      state = state.copyWith(
        isLoading: false,
        token: token,
        refreshToken: refreshToken,
        activeSchool: school,
        activeRole: newRole,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to switch school.');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/auth/logout');
    } catch (_) {}

    _api.clearAuth();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyRefresh);
      await prefs.remove(_keyUser);
      await prefs.remove(_keySchool);
      await prefs.remove(_keyRole);
      await prefs.remove(_keyMemberships);
    } catch (_) {}

    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
