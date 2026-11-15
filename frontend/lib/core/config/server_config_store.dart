import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

/// Persists a server address chosen on the device (debug/profile builds only).
/// The address is not a secret, so plain preferences are fine here.
class ServerConfigStore {
  static const _key = 'erp_api_base_url_override';

  Future<String?> readOverride() async {
    if (!AppConfig.allowsRuntimeOverride) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveOverride(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, baseUrl);
  }

  Future<void> clearOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
