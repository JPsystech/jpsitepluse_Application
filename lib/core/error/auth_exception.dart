/// A typed exception for authentication errors that carries the exact
/// backend message. Used by [AuthService] and handled by [ErrorHandler]
/// to show user-friendly messages without generic fallbacks.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
