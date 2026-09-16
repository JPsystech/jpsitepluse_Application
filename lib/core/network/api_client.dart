import 'package:dio/dio.dart';
import 'package:sitepulse_engineer/core/config/api_config.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'tenant_interceptor.dart';
import 'unauthorized_interceptor.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio();
    _dio.interceptors.add(TenantInterceptor());
    _dio.interceptors.add(UnauthorizedInterceptor());
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final deviceId = await SessionStore.getDeviceId();
            options.headers['X-Device-ID'] = deviceId;
          } catch (_) {}
          return handler.next(options);
        },
      ),
    );
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
