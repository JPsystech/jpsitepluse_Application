import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart' as import_shared_prefs;
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/core/storage/mpin_store.dart' as import_mpin_store;
import 'package:sitepulse_engineer/core/storage/credential_store.dart' as import_cred_store;

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

          // Parse the reason for the snackbar message.
          // The backend sends {"detail": "..."} but the mobile error-handling
          // layer may transform it to {"success": false, "error": {"message": "..."}}.
          // Try both formats.
          String? reason;
          try {
            final data = err.response?.data;
            if (data is Map) {
              reason = (data['detail'] as String?) ??
                  (data['error'] is Map
                      ? (data['error']['message'] as String?)
                      : null);
            }
          } catch (_) {}

          // Always wipe MPIN, saved credentials, and the vendor code from
          // SharedPreferences on ANY 401 for a non-excluded endpoint.
          // Do NOT gate this on parsing a specific message — the response
          // format can vary and any 401 here means the session is dead.
          try {
            await import_mpin_store.MpinStore.clearMpin();
            await import_cred_store.CredentialStore.clearCredentials();
            // Clear vendor code from SharedPreferences — this is a DIFFERENT
            // store than CredentialStore (which uses FlutterSecureStorage).
            // login_screen._loadSavedVendorCode() reads from SharedPreferences.
            // If this key exists, it triggers MPIN mode regardless of what
            // was wiped from secure storage.
            final prefs = await import_shared_prefs.SharedPreferences.getInstance();
            await prefs.remove('sitepulse_engineer_vendor_code');
          } catch (_) {}

          SessionStore.expireSession(reason);
        }
      }
    }

    // Always pass the error down the chain to preserve local/fallback handling
    handler.next(err);
  }
}

