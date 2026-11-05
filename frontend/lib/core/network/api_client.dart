import 'package:dio/dio.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  String? _token;
  String? _schoolId;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:3000/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          if (_schoolId != null && _schoolId!.isNotEmpty) {
            options.headers['x-school-id'] = _schoolId;
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Print non-sensitive error summary
          // ignore: avoid_print
          print('API Error [${e.response?.statusCode}]: ${e.requestOptions.path}');
          return handler.next(e);
        },
      ),
    );
  }

  void setAuth(String? token, String? schoolId) {
    _token = token;
    _schoolId = schoolId;
  }

  void setSchoolId(String? schoolId) {
    _schoolId = schoolId;
  }

  void clearAuth() {
    _token = null;
    _schoolId = null;
  }
}
