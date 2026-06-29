import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

import "../core/api_config.dart";
import "../core/session_store.dart";

void _log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class ApiClient {
  final http.Client client;
  final String? baseUrl;
  Future<String>? _resolvedBaseUrl;

  ApiClient({this.baseUrl, http.Client? client}) : client = client ?? http.Client();

  Future<Uri> url(String path) async {
    final base = await _ensureBaseUrl();
    return Uri.parse("$base$path");
  }

  Future<String> _ensureBaseUrl() async {
    if (baseUrl != null && baseUrl!.trim().isNotEmpty) {
      return baseUrl!.trim();
    }
    _resolvedBaseUrl ??= resolveApiBaseUrl();
    String resolved;
    try {
      resolved = await _resolvedBaseUrl!;
    } catch (e) {
      throw ApiException(e.toString());
    }
    _log("[ApiClient] Resolved baseUrl: $resolved");
    return resolved;
  }

  Future<Map<String, dynamic>?> getJson(Uri uri, {Map<String, String>? headers}) async {
    _log("[ApiClient] GET $uri");
    final resp = await _safeRequest(() => client.get(uri, headers: headers));
    return _handleJson(uri, resp);
  }

  Future<Map<String, dynamic>?> postJson(Uri uri, {Map<String, String>? headers, Object? body}) async {
    _log("[ApiClient] POST $uri");
    _log("[ApiClient] Headers: $headers");
    _log("[ApiClient] Body: $body");
    final resp = await _safeRequest(() => client.post(uri, headers: headers, body: body));
    return _handleJson(uri, resp);
  }

  Future<({Uint8List bytes, Map<String, String> headers})> getBytes(Uri uri, {Map<String, String>? headers}) async {
    _log("[ApiClient] GET (bytes) $uri");
    final resp = await _safeRequest(() => client.get(uri, headers: headers));
    _log("[ApiClient] Response ${resp.statusCode} from $uri");
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final ct = (resp.headers["content-type"] ?? "").toLowerCase();
      Map<String, dynamic>? json;
      if (ct.contains("application/json") || ct.contains("text/json") || resp.body.trimLeft().startsWith("{")) {
        json = _decodeJson(resp.body);
      }
      throw ApiException(_extractErrorMessage(json, fallback: "Request failed"), statusCode: resp.statusCode);
    }
    return (bytes: resp.bodyBytes, headers: resp.headers);
  }

  Future<Map<String, dynamic>?> postMultipart(
    Uri uri, {
    required Map<String, String> fields,
    required http.MultipartFile file,
    Map<String, String>? headers,
  }) async {
    _log("[ApiClient] POST (multipart) $uri");
    try {
      final req = http.MultipartRequest("POST", uri);
      if (headers != null) {
        req.headers.addAll(headers);
      }
      req.fields.addAll(fields);
      req.files.add(file);
      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      final resp = http.Response(body, streamed.statusCode, headers: streamed.headers, request: streamed.request);
      return _handleJson(uri, resp);
    } on HandshakeException catch (e) {
      _log("[ApiClient] HandshakeException: $e");
      throw ApiException("Network error (TLS/cleartext)");
    } on http.ClientException catch (e) {
      _log("[ApiClient] ClientException: $e");
      throw ApiException("Network error");
    } on SocketException {
      _log("[ApiClient] SocketException: backend unreachable");
      throw ApiException("Backend is unreachable");
    }
  }

  Future<http.Response> _safeRequest(Future<http.Response> Function() action) async {
    try {
      return await action();
    } on HandshakeException catch (e) {
      _log("[ApiClient] HandshakeException: $e");
      throw ApiException("Network error (TLS/cleartext): $e");
    } on http.ClientException catch (e) {
      _log("[ApiClient] ClientException: $e");
      throw ApiException("Network error: $e");
    } on SocketException catch (e) {
      _log("[ApiClient] SocketException: $e");
      throw ApiException("Backend unreachable. Check if server is on same WiFi: $e");
    } catch (e) {
      _log("[ApiClient] Unexpected error: $e");
      throw ApiException("Unexpected network error: $e");
    }
  }

  Map<String, dynamic>? _handleJson(Uri uri, http.Response resp) {
    _log("[ApiClient] Response ${resp.statusCode} from $uri");
    _log("[ApiClient] Response Body: ${resp.body}");
    final json = _decodeJson(resp.body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      if (resp.statusCode == 401) {
        SessionStore.clear();
      }
      final parsed = _extractApiError(json);
      throw ApiException(
        _extractErrorMessage(json, fallback: "Request failed (Status: ${resp.statusCode})"),
        statusCode: resp.statusCode,
        code: parsed.code,
        details: parsed.details,
      );
    }
    return json;
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? details;

  ApiException(this.message, {this.statusCode, this.code, this.details});

  @override
  String toString() => message;
}

Map<String, dynamic>? _decodeJson(String body) {
  if (body.trim().isEmpty) return null;
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  return null;
}

String _extractErrorMessage(Map<String, dynamic>? json, {required String fallback}) {
  final detail = json?["detail"];
  if (detail is String && detail.trim().isNotEmpty) {
    return detail;
  }

  final error = json?["error"];
  if (error is Map<String, dynamic>) {
    final message = error["message"];
    if (message is String && message.trim().isNotEmpty) {
      final details = error["details"];
      if (details is List && details.isNotEmpty) {
        final first = details.first;
        if (first is Map<String, dynamic>) {
          final msg = first["msg"];
          if (msg is String && msg.trim().isNotEmpty) {
            final cleaned = msg.trim().replaceFirst(RegExp(r"^Value error,\s*"), "");
            return cleaned;
          }
        }
      }
      return message;
    }
  }

  return fallback;
}

({String? code, Map<String, dynamic>? details}) _extractApiError(Map<String, dynamic>? json) {
  if (json == null) {
    return (code: null, details: null);
  }

  final code = json["code"];
  final error = json["error"];

  String? parsedCode;
  Map<String, dynamic>? parsedDetails;

  if (code is String && code.trim().isNotEmpty) {
    parsedCode = code.trim();
    final d = <String, dynamic>{};
    for (final k in ["distance_m", "allowed_radius_m"]) {
      if (json.containsKey(k)) {
        d[k] = json[k];
      }
    }
    parsedDetails = d.isNotEmpty ? d : null;
    return (code: parsedCode, details: parsedDetails);
  }

  if (error is Map<String, dynamic>) {
    final ec = error["code"];
    if (ec is String && ec.trim().isNotEmpty) {
      parsedCode = ec.trim();
    }
    final ed = error["details"];
    if (ed is Map<String, dynamic>) {
      parsedDetails = ed;
    }
  }

  return (code: parsedCode, details: parsedDetails);
}
