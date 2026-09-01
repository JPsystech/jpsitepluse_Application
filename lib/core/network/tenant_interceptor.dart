import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

class TenantInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final session = SessionStore.current;
    if (session != null && session.token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${session.token}';

      // Optionally, if the backend expects a specific tenant header directly:
      // options.headers['X-Tenant-ID'] = session.tenantId;
    }

    if (kDebugMode) {
      debugPrint("API Request: ${options.method} ${options.uri}");
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      if (err.response != null) {
        debugPrint("API Error: ${err.requestOptions.method} ${err.requestOptions.uri} returned ${err.response?.statusCode}");
        debugPrint("API Response: ${err.response?.data}");
      } else {
        debugPrint("API Network Error: ${err.message}");
      }
    }
    return handler.next(err);
  }
}
