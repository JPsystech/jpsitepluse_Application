import 'package:dio/dio.dart';
import 'package:sitepulse_engineer/core/config/api_config.dart';
import 'tenant_interceptor.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio();
    _dio.interceptors.add(TenantInterceptor());
  }

  static final ApiClient _instance = ApiClient._internal();
  static ApiClient get instance => _instance;

  Future<Dio> get dio async {
    final baseUrl = await resolveApiBaseUrl();
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    return _dio;
  }
}
