import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final String? token;
  final UserModel? user;
  final SchoolModel? activeSchool;
  final String? activeRole;
  final List<MembershipModel> memberships;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
    this.token,
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
      user: user ?? this.user,
      activeSchool: activeSchool ?? this.activeSchool,
      activeRole: activeRole ?? this.activeRole,
      memberships: memberships ?? this.memberships,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final _api = ApiClient();

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
      final userData = data['user'];
      final user = UserModel.fromJson(userData);
      final activeSchool = SchoolModel.fromJson(userData['activeSchool']);
      final memberships = (userData['memberships'] as List? ?? [])
          .map((m) => MembershipModel.fromJson(m))
          .toList();

      _api.setAuth(token, activeSchool.id);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        token: token,
        user: user,
        activeSchool: activeSchool,
        activeRole: user.activeRole,
        memberships: memberships,
      );

      return true;
    } catch (e) {
      String msg = 'Login failed. Please check credentials.';
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
      final school = SchoolModel.fromJson(data['activeSchool']);
      final newRole = data['activeRole'] as String;

      _api.setAuth(token, school.id);

      state = state.copyWith(
        isLoading: false,
        token: token,
        activeSchool: school,
        activeRole: newRole,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to switch school.');
      return false;
    }
  }

  void logout() {
    _api.clearAuth();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
