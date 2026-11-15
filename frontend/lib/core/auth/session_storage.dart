import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything needed to restore a signed-in session after an app restart.
class StoredSession {
  final String accessToken;
  final String? refreshToken;
  final Map<String, dynamic> user;
  final Map<String, dynamic> school;
  final String role;
  final List<Map<String, dynamic>> memberships;

  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.school,
    required this.role,
    required this.memberships,
  });

  StoredSession copyWith({String? accessToken, String? refreshToken}) => StoredSession(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        user: user,
        school: school,
        role: role,
        memberships: memberships,
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'user': user,
        'school': school,
        'role': role,
        'memberships': memberships,
      };

  static StoredSession? fromJson(Map<String, dynamic> json) {
    final token = json['accessToken'];
    final user = json['user'];
    final school = json['school'];
    if (token is! String || token.isEmpty || user is! Map || school is! Map) return null;
    return StoredSession(
      accessToken: token,
      refreshToken: json['refreshToken'] as String?,
      user: Map<String, dynamic>.from(user),
      school: Map<String, dynamic>.from(school),
      role: (json['role'] as String?) ?? '',
      memberships: (json['memberships'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
    );
  }
}

abstract class SessionStorage {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> updateTokens(String accessToken, String? refreshToken);
  Future<void> clear();
}

/// Stores the session in the platform keystore (Android Keystore / iOS Keychain).
/// Also migrates sessions saved by older builds in plain SharedPreferences.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'erp_session_v2';

  static const _legacyKeys = [
    'erp_access_token',
    'erp_refresh_token',
    'erp_user_data',
    'erp_school_data',
    'erp_active_role',
    'erp_memberships',
  ];

  @override
  Future<StoredSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return StoredSession.fromJson(decoded);
      }
    } catch (_) {
      await clear();
      return null;
    }
    return _migrateLegacy();
  }

  @override
  Future<void> write(StoredSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> updateTokens(String accessToken, String? refreshToken) async {
    final current = await read();
    if (current == null) return;
    await write(current.copyWith(accessToken: accessToken, refreshToken: refreshToken));
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
    await _clearLegacy();
  }

  Future<StoredSession?> _migrateLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('erp_access_token');
      final user = prefs.getString('erp_user_data');
      final school = prefs.getString('erp_school_data');
      StoredSession? session;
      if (token != null && user != null && school != null) {
        session = StoredSession(
          accessToken: token,
          refreshToken: prefs.getString('erp_refresh_token'),
          user: Map<String, dynamic>.from(jsonDecode(user)),
          school: Map<String, dynamic>.from(jsonDecode(school)),
          role: prefs.getString('erp_active_role') ?? '',
          memberships: (jsonDecode(prefs.getString('erp_memberships') ?? '[]') as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList(),
        );
        await write(session);
      }
      await _clearLegacy();
      return session;
    } catch (_) {
      await _clearLegacy();
      return null;
    }
  }

  Future<void> _clearLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in _legacyKeys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}

/// Non-persistent storage for tests.
class InMemorySessionStorage implements SessionStorage {
  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession value) async => session = value;

  @override
  Future<void> updateTokens(String accessToken, String? refreshToken) async {
    session = session?.copyWith(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> clear() async => session = null;
}
