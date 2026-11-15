import 'dart:async';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../config/server_config_store.dart';

/// Broad failure categories the UI can react to.
enum ApiErrorKind {
  notConfigured,
  networkUnavailable,
  serverUnreachable,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  rateLimited,
  server,
  invalidResponse,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final ApiErrorKind kind;
  final dynamic details;

  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.kind = ApiErrorKind.unknown,
    this.details,
  });

  bool get isConnectivity =>
      kind == ApiErrorKind.networkUnavailable ||
      kind == ApiErrorKind.serverUnreachable ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.notConfigured;

  @override
  String toString() => message;
}

/// Converts any error thrown by an API call into an [ApiException].
ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return inner;
    return ApiClient.parseDioError(error);
  }
  return ApiException(message: 'Something went wrong. Please try again.', kind: ApiErrorKind.unknown);
}

/// Readable message for any error thrown by an API call.
String apiErrorMessage(Object error) => toApiException(error).message;

typedef TokensRefreshedCallback = Future<void> Function(String accessToken, String? refreshToken);

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  late final Dio _plainDio; // no auth interceptor: refresh calls and post-refresh retries

  String? _token;
  String? _refreshToken;
  String? _schoolId;
  String? _baseUrl;

  /// Called once the session can no longer be renewed (refresh token invalid/revoked).
  Future<void> Function()? onSessionExpired;

  /// Called after a successful refresh so the new tokens can be persisted.
  TokensRefreshedCallback? onTokensRefreshed;

  Future<bool>? _refreshInFlight;
  final ServerConfigStore _serverConfigStore = ServerConfigStore();

  ApiClient._internal() {
    _baseUrl = AppConfig.buildTimeBaseUrl;

    final options = BaseOptions(
      baseUrl: _baseUrl ?? '',
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    dio = Dio(options);
    _plainDio = Dio(options);

    // Every `e.toString()` on a DioException in the app now yields a readable message.
    DioException.readableStringBuilder = (e) => toApiException(e).message;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if ((_baseUrl ?? '').isEmpty) {
            return handler.reject(DioException(
              requestOptions: options,
              type: DioExceptionType.unknown,
              error: ApiException(
                message: 'No server address is configured. Open Server settings on the sign-in screen.',
                kind: ApiErrorKind.notConfigured,
                code: 'NOT_CONFIGURED',
              ),
            ));
          }
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          if (_schoolId != null && _schoolId!.isNotEmpty) {
            options.headers['x-school-id'] = _schoolId;
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          if (err.error is ApiException) return handler.next(err);

          final status = err.response?.statusCode;
          final path = err.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login') ||
              path.contains('/auth/refresh') ||
              path.contains('/auth/logout');

          if (status == 401 && !isAuthEndpoint && _token != null) {
            if (_refreshToken != null && _refreshToken!.isNotEmpty) {
              final refreshed = await _refreshOnce();
              if (refreshed) {
                try {
                  final opts = err.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $_token';
                  final retried = await _plainDio.fetch(opts);
                  return handler.resolve(retried);
                } on DioException catch (retryErr) {
                  return handler.next(_wrap(retryErr));
                }
              }
              if (_token == null) {
                // Refresh was rejected: the session is over.
                return handler.next(_wrap(err, override: _sessionExpired()));
              }
            } else {
              await _expireSession();
              return handler.next(_wrap(err, override: _sessionExpired()));
            }
          }

          handler.next(_wrap(err));
        },
      ),
    );
  }

  ApiException _sessionExpired() => ApiException(
        message: 'Your session has expired. Please sign in again.',
        statusCode: 401,
        code: 'SESSION_EXPIRED',
        kind: ApiErrorKind.unauthorized,
      );

  DioException _wrap(DioException err, {ApiException? override}) {
    final parsed = override ?? parseDioError(err);
    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: parsed,
      message: parsed.message,
    );
  }

  /// Runs a single refresh at a time; concurrent 401s wait for the same result.
  /// Returns true when a new access token is available. When the server rejects
  /// the refresh token the session is cleared (and [onSessionExpired] fires);
  /// connectivity failures keep the session so the user is not logged out offline.
  Future<bool> _refreshOnce() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;
    try {
      final res = await _plainDio.post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = (res.data is Map) ? res.data['data'] : null;
      final newAccess = data is Map ? data['accessToken'] as String? : null;
      if (newAccess == null || newAccess.isEmpty) {
        await _expireSession();
        return false;
      }
      final newRefresh = data!['refreshToken'] as String?;
      _token = newAccess;
      if (newRefresh != null && newRefresh.isNotEmpty) _refreshToken = newRefresh;
      if (onTokensRefreshed != null) await onTokensRefreshed!(newAccess, _refreshToken);
      return true;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) await _expireSession();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _expireSession() async {
    final hadSession = _token != null;
    clearAuth();
    if (hadSession && onSessionExpired != null) await onSessionExpired!();
  }

  static ApiException parseDioError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'The server took too long to respond. Check your connection and try again.',
          statusCode: 408,
          code: 'TIMEOUT',
          kind: ApiErrorKind.timeout,
        );
      case DioExceptionType.connectionError:
        return _connectionError(err);
      case DioExceptionType.badCertificate:
        return ApiException(
          message: 'The server\'s security certificate is not trusted.',
          code: 'BAD_CERTIFICATE',
          kind: ApiErrorKind.serverUnreachable,
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'The request was cancelled.', code: 'CANCELLED');
      case DioExceptionType.unknown:
        if (err.response == null) return _connectionError(err);
        break;
      case DioExceptionType.badResponse:
        break;
      default:
        if (err.response == null) return _connectionError(err);
    }

    final status = err.response?.statusCode;
    final data = err.response?.data;
    String? serverMessage;
    String? serverCode;
    if (data is Map) {
      final errObj = data['error'];
      final raw = errObj is Map ? errObj['message'] : data['message'];
      if (raw is List) {
        serverMessage = raw.join(', ');
      } else if (raw != null) {
        serverMessage = raw.toString();
      }
      if (errObj is Map && errObj['code'] != null) serverCode = errObj['code'].toString();
    }

    final kind = _kindForStatus(status);
    return ApiException(
      message: (serverMessage != null && serverMessage.isNotEmpty) ? serverMessage : _defaultMessage(kind, status),
      statusCode: status,
      code: serverCode ?? 'HTTP_$status',
      kind: kind,
      details: data,
    );
  }

  static ApiException _connectionError(DioException err) {
    final text = '${err.error ?? ''} ${err.message ?? ''}'.toLowerCase();
    final offline = text.contains('network is unreachable') ||
        text.contains('failed host lookup') ||
        text.contains('no address associated') ||
        text.contains('errno = 7') ||
        text.contains('errno = 101');
    if (offline) {
      return ApiException(
        message: 'No network connection. Connect to Wi-Fi or mobile data and try again.',
        code: 'NETWORK_UNAVAILABLE',
        kind: ApiErrorKind.networkUnavailable,
      );
    }
    final refused = text.contains('connection refused') || text.contains('errno = 111');
    final host = err.requestOptions.uri.hasAuthority ? err.requestOptions.uri.authority : 'the server';
    return ApiException(
      message: refused
          ? 'The Ark-ERP server at $host refused the connection. Make sure the backend is running.'
          : 'Cannot reach the Ark-ERP server at $host. Check the server address and that this device is on the same network.',
      code: 'SERVER_UNREACHABLE',
      kind: ApiErrorKind.serverUnreachable,
    );
  }

  static ApiErrorKind _kindForStatus(int? status) {
    if (status == null) return ApiErrorKind.unknown;
    if (status == 400 || status == 422) return ApiErrorKind.validation;
    if (status == 401) return ApiErrorKind.unauthorized;
    if (status == 403) return ApiErrorKind.forbidden;
    if (status == 404) return ApiErrorKind.notFound;
    if (status == 429) return ApiErrorKind.rateLimited;
    if (status >= 500) return ApiErrorKind.server;
    return ApiErrorKind.unknown;
  }

  static String _defaultMessage(ApiErrorKind kind, int? status) {
    switch (kind) {
      case ApiErrorKind.unauthorized:
        return 'You need to sign in again.';
      case ApiErrorKind.forbidden:
        return 'You do not have permission to do this.';
      case ApiErrorKind.notFound:
        return 'The requested record was not found.';
      case ApiErrorKind.validation:
        return 'Some of the submitted details are invalid.';
      case ApiErrorKind.rateLimited:
        return 'Too many attempts. Wait a minute and try again.';
      case ApiErrorKind.server:
        return 'The server had a problem processing the request. Please try again.';
      default:
        return 'Request failed${status != null ? ' ($status)' : ''}.';
    }
  }

  // ---------------------------------------------------------------- server address

  /// Applies a saved runtime override (debug/profile builds only).
  Future<void> loadServerOverride() async {
    final saved = await _serverConfigStore.readOverride();
    if (saved != null) _applyBaseUrl(saved);
  }

  /// Validates, normalizes, stores and applies a server address typed by the user.
  Future<String> saveServerAddress(String input) async {
    final normalized = AppConfig.normalizeBaseUrl(input, defaultPort: AppConfig.defaultPort);
    final problem = AppConfig.validateBaseUrl(normalized);
    if (problem != null) throw FormatException(problem);
    await _serverConfigStore.saveOverride(normalized);
    _applyBaseUrl(normalized);
    return normalized;
  }

  Future<void> resetServerAddress() async {
    await _serverConfigStore.clearOverride();
    _baseUrl = AppConfig.buildTimeBaseUrl;
    dio.options.baseUrl = _baseUrl ?? '';
    _plainDio.options.baseUrl = _baseUrl ?? '';
  }

  void _applyBaseUrl(String url) {
    _baseUrl = url;
    dio.options.baseUrl = url;
    _plainDio.options.baseUrl = url;
  }

  /// Confirms that [baseUrl] (or the current one) answers like the Ark-ERP API.
  /// Returns null on success, or the reason it failed.
  Future<ApiException?> checkConnection([String? baseUrl]) async {
    final target = baseUrl ?? _baseUrl;
    if (target == null || target.isEmpty) {
      return ApiException(
        message: 'No server address is configured.',
        kind: ApiErrorKind.notConfigured,
        code: 'NOT_CONFIGURED',
      );
    }
    try {
      final res = await _plainDio.get(
        '$target/tenant-discovery',
        options: Options(receiveTimeout: AppConfig.connectTimeout),
      );
      if (res.data is Map && (res.data as Map).containsKey('data')) return null;
      return ApiException(
        message: 'The address responded, but it is not the Ark-ERP API. Check the port and path.',
        kind: ApiErrorKind.invalidResponse,
        code: 'NOT_ARK_ERP',
      );
    } on DioException catch (e) {
      return parseDioError(e);
    }
  }

  bool get isConfigured => (_baseUrl ?? '').isNotEmpty;
  String get baseUrl => _baseUrl ?? '';

  void setBaseUrl(String url) => _applyBaseUrl(url);

  // ---------------------------------------------------------------- credentials

  void setAuth(String? token, String? schoolId, {String? refreshToken}) {
    _token = token;
    _schoolId = schoolId;
    if (refreshToken != null) _refreshToken = refreshToken;
  }

  void setSchoolId(String? schoolId) => _schoolId = schoolId;

  void clearAuth() {
    _token = null;
    _refreshToken = null;
    _schoolId = null;
  }

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get schoolId => _schoolId;

  /// Test hook: lets unit tests drive the client with a fake HTTP adapter.
  void debugSetAdapter(HttpClientAdapter adapter) {
    dio.httpClientAdapter = adapter;
    _plainDio.httpClientAdapter = adapter;
  }
}
