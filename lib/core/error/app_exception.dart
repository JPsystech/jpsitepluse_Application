import 'error_type.dart';

class AppException implements Exception {
  final String userMessage;
  final String? technicalMessage;
  final int? statusCode;
  final String? code;
  final AppErrorType type;

  const AppException({
    required this.userMessage,
    this.technicalMessage,
    this.statusCode,
    this.code,
    required this.type,
  });

  @override
  String toString() => userMessage;
}
