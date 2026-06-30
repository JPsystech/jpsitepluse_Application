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
      debugPrint("API Error: ${err.message}");
    }
    return handler.next(err);
  }
}
