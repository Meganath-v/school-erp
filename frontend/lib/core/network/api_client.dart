import 'dart:async';
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final dynamic details;

  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  late final Dio _tokenRefreshDio;

  String? _token;
  String? _refreshToken;
  String? _schoolId;
  Future<bool> Function()? onSessionExpired;

  bool _isRefreshing = false;
  final List<Completer<void>> _refreshWaiters = [];

  ApiClient._internal() {
    const String defaultBaseUrl = 'http://localhost:3000/api/v1';

    final options = BaseOptions(
      baseUrl: defaultBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    dio = Dio(options);
    _tokenRefreshDio = Dio(options);

    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          if (_schoolId != null && _schoolId!.isNotEmpty) {
            options.headers['x-school-id'] = _schoolId;
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException err, handler) async {
          final statusCode = err.response?.statusCode;

          // Handle 401 Unauthorized by attempting token refresh
          if (statusCode == 401 && _refreshToken != null && _refreshToken!.isNotEmpty) {
            final requestPath = err.requestOptions.path;

            // Don't refresh if the error happened on login or refresh itself
            if (!requestPath.contains('/auth/login') && !requestPath.contains('/auth/refresh')) {
              try {
                final refreshed = await _attemptTokenRefresh();
                if (refreshed) {
                  // Retry the original request with new token
                  final opts = err.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $_token';
                  final cloneReq = await dio.fetch(opts);
                  return handler.resolve(cloneReq);
                }
              } catch (_) {
                // Refresh failed; notify session expiration
                clearAuth();
                if (onSessionExpired != null) {
                  await onSessionExpired!();
                }
              }
            }
          }

          // Format into human-readable ApiException
          final parsedException = _parseError(err);
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              response: err.response,
              type: err.type,
              error: parsedException,
              message: parsedException.message,
            ),
          );
        },
      ),
    );
  }

  Future<bool> _attemptTokenRefresh() async {
    if (_isRefreshing) {
      final completer = Completer<void>();
      _refreshWaiters.add(completer);
      await completer.future;
      return _token != null;
    }

    _isRefreshing = true;

    try {
      final res = await _tokenRefreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': _refreshToken},
      );

      final data = res.data['data'];
      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;

      if (newAccess != null) {
        _token = newAccess;
        if (newRefresh != null) _refreshToken = newRefresh;

        for (final waiter in _refreshWaiters) {
          waiter.complete();
        }
        _refreshWaiters.clear();
        return true;
      }
      return false;
    } catch (e) {
      for (final waiter in _refreshWaiters) {
        waiter.completeError(e);
      }
      _refreshWaiters.clear();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  ApiException _parseError(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return ApiException(
        message: 'Connection timed out. Please check your network and retry.',
        statusCode: 408,
        code: 'TIMEOUT',
      );
    }

    if (err.type == DioExceptionType.connectionError) {
      return ApiException(
        message: 'Unable to reach ERP server. Ensure the backend server is running.',
        statusCode: 503,
        code: 'SERVER_UNREACHABLE',
      );
    }

    final data = err.response?.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('error') && data['error'] is Map) {
        final errObj = data['error'] as Map;
        final msg = errObj['message'] ?? 'An error occurred';
        return ApiException(
          message: msg is List ? msg.join(', ') : msg.toString(),
          statusCode: errObj['statusCode'] ?? err.response?.statusCode,
          code: errObj['code']?.toString(),
          details: errObj,
        );
      }
      if (data.containsKey('message')) {
        final msg = data['message'];
        return ApiException(
          message: msg is List ? msg.join(', ') : msg.toString(),
          statusCode: err.response?.statusCode,
          details: data,
        );
      }
    }

    final status = err.response?.statusCode;
    return ApiException(
      message: err.message ?? 'Server error [$status]',
      statusCode: status,
      code: 'HTTP_$status',
    );
  }

  void setAuth(String? token, String? schoolId, {String? refreshToken}) {
    _token = token;
    _schoolId = schoolId;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
  }

  void setSchoolId(String? schoolId) {
    _schoolId = schoolId;
  }

  void clearAuth() {
    _token = null;
    _refreshToken = null;
    _schoolId = null;
  }

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get schoolId => _schoolId;
}
