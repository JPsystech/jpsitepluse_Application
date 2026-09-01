import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import 'app_exception.dart';
import 'auth_exception.dart';
import 'error_type.dart';

class ErrorHandler {
  static AppException handle(dynamic error) {
    if (error is AppException) return error;

    // AuthException carries the exact backend message — pass it through directly.
    if (error is AuthException) {
      return AppException(
        userMessage: error.message,
        type: AppErrorType.server,
      );
    }

    if (error is DioException) {
      return _handleDioException(error);
    }

    if (error is SocketException ||
        error is HandshakeException ||
        error is http.ClientException) {
      return const AppException(
        userMessage: 'Unable to connect to the server. Please check your network.',
        type: AppErrorType.network,
      );
    }

    if (error is TimeoutException) {
      return const AppException(
        userMessage: 'Request timed out. Please try again.',
        type: AppErrorType.timeout,
      );
    }
    
    if (error is String) {
      return AppException(
        userMessage: error,
        type: AppErrorType.unknown,
      );
    }

    return AppException(
      userMessage: 'Something went wrong. Please try again.',
      technicalMessage: error.toString(),
      type: AppErrorType.unknown,
    );
  }

  static bool isOfflineError(dynamic error) {
    if (error is SocketException || error is HandshakeException || error is http.ClientException) {
      return true;
    }
    
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return true;
      }
      if (error.error is SocketException) {
        return true;
      }
    }

    // Fallback for legacy generic strings masking SocketException
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('connection failed') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable')) {
      return true;
    }

    return false;
  }

  static AppException _handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException(
          userMessage: 'Request timed out. Please try again.',
          technicalMessage: error.message,
          type: AppErrorType.timeout,
        );
      case DioExceptionType.connectionError:
        return AppException(
          userMessage: 'Unable to connect to the server. Please check your network.',
          technicalMessage: error.message,
          type: AppErrorType.network,
        );
      case DioExceptionType.badResponse:
        return _handleBadResponse(error);
      case DioExceptionType.cancel:
        return AppException(
          userMessage: 'Request was cancelled.',
          technicalMessage: error.message,
          type: AppErrorType.cancelled,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      default:
        if (error.error is SocketException ||
            error.error is http.ClientException ||
            error.error is HandshakeException) {
          return AppException(
            userMessage: 'Unable to connect to the server. Please check your network.',
            technicalMessage: error.message,
            type: AppErrorType.network,
          );
        }
        return AppException(
          userMessage: 'Something went wrong. Please try again.',
          technicalMessage: error.message,
          type: AppErrorType.unknown,
        );
    }
  }

  static AppException _handleBadResponse(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    // Sentinel — means the server gave no usable message.
    const noMessage = '\x00';
    String serverMessage = noMessage;
    String? code;
    AppErrorType type = AppErrorType.server;

    // --- Extract server-provided message (FastAPI / JP Site Pulse format) ---
    if (data is Map<String, dynamic>) {
      code = data['code'] as String?;
      final detail = data['detail'];

      if (detail is String && detail.trim().isNotEmpty) {
        serverMessage = detail.trim();
      } else if (detail is List && detail.isNotEmpty) {
        final firstError = detail.first;
        if (firstError is Map<String, dynamic> && firstError['msg'] != null) {
          serverMessage = firstError['msg']
              .toString()
              .replaceFirst(RegExp(r'^Value error,\s*'), '')
              .trim();
        }
      } else if (data['error'] is Map<String, dynamic> &&
          data['error']['message'] != null) {
        serverMessage = data['error']['message'].toString().trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      serverMessage = data.trim();
    }

    final bool hasServerMessage =
        serverMessage != noMessage && serverMessage.isNotEmpty;

    // --- Determine type and final user message ---
    // Core rule: always show the backend message when available.
    // Exceptions:
    //   401 → always show session-expired (security requirement).
    //   500/502/503/504 → always generic (hide internal server errors).
    String userMessage;

    switch (statusCode) {
      case 400:
        type = AppErrorType.validation;
        userMessage = hasServerMessage
            ? serverMessage
            : 'Invalid request. Please check your input.';
        break;

      case 401:
        userMessage = 'Your session has expired. Please login again.';
        type = AppErrorType.unauthorized;
        break;

      case 403:
        // e.g. "This account is bound to another device",
        // "Inactive engineer", "Vendor subscription has expired".
        type = AppErrorType.forbidden;
        userMessage = hasServerMessage
            ? serverMessage
            : 'You are not authorized to perform this action.';
        break;

      case 404:
        // e.g. "Vendor not found", "Project not found", "Invalid emp code".
        type = AppErrorType.notFound;
        userMessage = hasServerMessage
            ? serverMessage
            : 'Requested information was not found.';
        break;

      case 408:
        type = AppErrorType.timeout;
        userMessage = 'Request timed out. Please try again.';
        break;

      case 409:
        // e.g. "Already punched in. Punch out first."
        type = AppErrorType.conflict;
        userMessage = hasServerMessage
            ? serverMessage
            : 'This action conflicts with existing data.';
        break;

      case 422:
        type = AppErrorType.validation;
        userMessage = hasServerMessage
            ? serverMessage
            : 'Invalid data submitted. Please check your input.';
        break;

      case 429:
        type = AppErrorType.server;
        userMessage = hasServerMessage
            ? serverMessage
            : 'Too many attempts. Please try again shortly.';
        break;

      case 500:
        type = AppErrorType.server;
        userMessage =
            'Something went wrong on our server. Please try again later.';
        break;

      case 502:
      case 503:
      case 504:
        type = AppErrorType.server;
        userMessage =
            'Service is temporarily unavailable. Please try again later.';
        break;

      default:
        type = AppErrorType.server;
        userMessage = hasServerMessage
            ? serverMessage
            : 'Something went wrong. Please try again.';
        break;
    }

    return AppException(
      userMessage: userMessage,
      technicalMessage: error.message,
      statusCode: statusCode,
      code: code,
      type: type,
    );
  }
}
