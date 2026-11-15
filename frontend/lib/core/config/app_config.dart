import 'package:flutter/foundation.dart';

/// Where the mobile/web client should look for the Ark-ERP API.
///
/// Selected at build time with `--dart-define=API_ENV=<value>`:
///  * `emulator`   – Android emulator; the host machine is `10.0.2.2`.
///  * `device`     – Physical phone on the same Wi-Fi; needs `API_HOST=<PC LAN IP>`.
///  * `local`      – Desktop/web/iOS simulator on the same machine (`localhost`).
///  * `production` – Hosted API; needs `API_BASE_URL=https://...`.
///
/// `--dart-define=API_BASE_URL=...` always wins over the environment defaults.
/// In debug/profile builds the user can also override the address at runtime
/// from the login screen (stored by [ServerConfigStore]).
enum ApiEnvironment { local, emulator, device, production }

class AppConfig {
  AppConfig._();

  static const String apiPath = '/api/v1';
  static const int defaultPort = int.fromEnvironment('API_PORT', defaultValue: 3000);

  static const String _envName = String.fromEnvironment('API_ENV');
  static const String _baseUrlDefine = String.fromEnvironment('API_BASE_URL');
  static const String _hostDefine = String.fromEnvironment('API_HOST');

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  /// Release builds must talk to an HTTPS API; plain HTTP is a development-only convenience.
  static bool get requiresHttps => kReleaseMode;

  /// Whether the user may change the server address from the login screen.
  static bool get allowsRuntimeOverride => !kReleaseMode;

  static ApiEnvironment get environment => parseEnvironment(
        _envName,
        isWeb: kIsWeb,
        platform: defaultTargetPlatform,
        isRelease: kReleaseMode,
      );

  static ApiEnvironment parseEnvironment(
    String name, {
    required bool isWeb,
    required TargetPlatform platform,
    required bool isRelease,
  }) {
    switch (name.trim().toLowerCase()) {
      case 'emulator':
        return ApiEnvironment.emulator;
      case 'device':
        return ApiEnvironment.device;
      case 'local':
      case 'dev':
      case 'development':
        return ApiEnvironment.local;
      case 'production':
      case 'prod':
        return ApiEnvironment.production;
    }
    if (isRelease) return ApiEnvironment.production;
    if (!isWeb && platform == TargetPlatform.android) return ApiEnvironment.emulator;
    return ApiEnvironment.local;
  }

  /// The base URL compiled into this build, or `null` when the build cannot
  /// know it (physical device without API_HOST, production without API_BASE_URL).
  static String? get buildTimeBaseUrl => resolveBuildTimeBaseUrl(
        environment: environment,
        baseUrlDefine: _baseUrlDefine,
        hostDefine: _hostDefine,
        port: defaultPort,
        webHost: kIsWeb ? Uri.base.host : null,
      );

  static String? resolveBuildTimeBaseUrl({
    required ApiEnvironment environment,
    String baseUrlDefine = '',
    String hostDefine = '',
    int port = 3000,
    String? webHost,
  }) {
    if (baseUrlDefine.trim().isNotEmpty) return normalizeBaseUrl(baseUrlDefine);
    switch (environment) {
      case ApiEnvironment.emulator:
        return 'http://10.0.2.2:$port$apiPath';
      case ApiEnvironment.device:
        if (hostDefine.trim().isEmpty) return null;
        return normalizeBaseUrl(hostDefine, defaultPort: port);
      case ApiEnvironment.local:
        final host = (webHost != null && webHost.isNotEmpty) ? webHost : 'localhost';
        return 'http://$host:$port$apiPath';
      case ApiEnvironment.production:
        return null;
    }
  }

  /// Accepts `192.168.1.20`, `192.168.1.20:3000`, `http://host:3000` or a full
  /// `.../api/v1` URL and returns a canonical `scheme://host:port/api/v1`.
  static String normalizeBaseUrl(String input, {int defaultPort = 3000}) {
    var value = input.trim();
    if (value.isEmpty) throw const FormatException('Enter the server address.');
    if (!value.contains('://')) value = 'http://$value';

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const FormatException('Enter a valid address, for example 192.168.1.20:3000.');
    }

    final hasExplicitPort = RegExp(r'^[a-z]+://[^/]+:\d+', caseSensitive: false).hasMatch(value);
    final port = hasExplicitPort ? uri.port : (uri.scheme == 'https' ? 443 : defaultPort);
    final isDefaultPort = (uri.scheme == 'https' && port == 443) || (uri.scheme == 'http' && port == 80);

    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (!path.endsWith(apiPath)) path = '$path$apiPath';

    final hostPart = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    return '${uri.scheme}://$hostPart${isDefaultPort ? '' : ':$port'}$path';
  }

  /// Returns a user-facing problem with [baseUrl] for this build, or `null` if it is usable.
  static String? validateBaseUrl(String baseUrl, {bool? requireHttps}) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return 'The server address is not a valid URL.';
    if ((requireHttps ?? requiresHttps) && uri.scheme != 'https') {
      return 'Release builds must use an HTTPS server address.';
    }
    return null;
  }

  static String describeEnvironment(ApiEnvironment env) {
    switch (env) {
      case ApiEnvironment.emulator:
        return 'Android emulator';
      case ApiEnvironment.device:
        return 'Physical device (LAN)';
      case ApiEnvironment.local:
        return 'Local development';
      case ApiEnvironment.production:
        return 'Production';
    }
  }
}
