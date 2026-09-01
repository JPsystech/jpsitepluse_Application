import 'package:dio/dio.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

class UnauthorizedInterceptor extends Interceptor {
  static bool _isHandlingUnauthorized = false;

  /// Resets the unauthorized lock. Must be called when a new authenticated session begins.
  static void reset() {
    _isHandlingUnauthorized = false;
  }

  /// Paths whose 401 responses must NEVER trigger session expiry.
  ///
  /// These endpoints use 401 for domain reasons (wrong MPIN, wrong password),
  /// not because the bearer token is expired or invalid.
  static const _excludedPaths = {
    '/api/v1/engineer/verify-mpin',
    '/api/v1/engineer/set-mpin',
    '/api/v1/engineer/change-password',
    '/api/v1/engineer/reset-mpin',
    '/api/v1/engineer/login',
  };

  static bool _isExcluded(RequestOptions options) {
    final path = options.path;
    return _excludedPaths.any((excluded) => path.endsWith(excluded));
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Do not destroy the session for endpoints that use 401 for domain
      // errors (wrong MPIN, wrong password, etc.).
      if (!_isExcluded(err.requestOptions)) {
        final token = SessionStore.current?.token;
        final hasActiveSession = token != null && token.trim().isNotEmpty;

        if (hasActiveSession && !_isHandlingUnauthorized) {
          _isHandlingUnauthorized = true;
          SessionStore.expireSession();
        }
      }
    }

    // Always pass the error down the chain to preserve local/fallback handling
    handler.next(err);
  }
}

