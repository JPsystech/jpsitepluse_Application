import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:sitepulse_engineer/core/config/app_environment.dart";

void _log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

String? _inMemoryStore;
const String _prefsKey = "sitepulse_engineer_api_base_url";

const String productionApiBaseUrl = AppEnvironment.productionBaseUrl;

Future<String?> getStoredApiBaseUrl() async {
  if (_inMemoryStore != null && _inMemoryStore!.trim().isNotEmpty) {
    return _inMemoryStore!.trim();
  }
  final prefs = await SharedPreferences.getInstance();
  final raw = (prefs.getString(_prefsKey) ?? "").trim();
  if (raw.isEmpty) return null;
  _inMemoryStore = raw;
  return raw;
}

Future<void> setStoredApiBaseUrl(String value) async {
  final cleaned = normalizeApiBaseUrlInput(value);
  _inMemoryStore = cleaned;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, cleaned);
  _resolvedApiBaseUrl = null;
  _syncBaseUrl = null;
}

const String _apiBaseUrlOverride =
    String.fromEnvironment("API_BASE_URL", defaultValue: "");
const String _pcIpOverride = String.fromEnvironment("PC_IP", defaultValue: "");

Future<String>? _resolvedApiBaseUrl;
String? _syncBaseUrl;

Future<String> resolveApiBaseUrl() async {
  if (_syncBaseUrl != null) return _syncBaseUrl!;
  _resolvedApiBaseUrl ??= _resolveApiBaseUrlInner();
  _syncBaseUrl = await _resolvedApiBaseUrl!;
  return _syncBaseUrl!;
}

String get syncApiBaseUrl => _syncBaseUrl ?? productionApiBaseUrl;

String resolveMaybeRelativeUrl(String url) {
  final u = url.trim();
  if (u.isEmpty) return "";
  if (u.startsWith("http://") || u.startsWith("https://")) return u;
  final base = syncApiBaseUrl;
  if (u.startsWith("/")) {
    return "$base$u";
  }
  return "$base/$u";
}

class ApiConfigException implements Exception {
  final String message;
  ApiConfigException(this.message);
  @override
  String toString() => message;
}

String normalizeApiBaseUrlInput(String input) {
  final v = input.trim().replaceAll("`", "");
  if (v.isEmpty) {
    throw ApiConfigException("Server URL/IP is required");
  }

  if (v.startsWith("http://") || v.startsWith("https://")) {
    return v.endsWith("/") ? v.substring(0, v.length - 1) : v;
  }

  final hasPort = v.contains(":");
  final url = hasPort ? "http://$v" : "http://$v:8011";
  return url.endsWith("/") ? url.substring(0, url.length - 1) : url;
}

Future<String> _resolveApiBaseUrlInner() async {
  // 1. Check dart-define override (--dart-define=API_BASE_URL=...)
  final override = _apiBaseUrlOverride.trim();
  if (override.isNotEmpty) {
    return normalizeApiBaseUrlInput(override);
  }

  // 2. In release mode, always use production API
  if (kReleaseMode) {
    return normalizeApiBaseUrlInput(productionApiBaseUrl);
  }

  // 3. In debug mode, ALWAYS prioritize AppEnvironment.localDevBaseUrl, 
  // preventing old cached 127.0.0.1 values in SharedPreferences from overriding it.
  if (kDebugMode) {
    return normalizeApiBaseUrlInput(AppEnvironment.localDevBaseUrl);
  }

  // 4. Check stored user preference in SharedPreferences
  final stored = await getStoredApiBaseUrl();
  if (stored != null && stored.isNotEmpty) {
    return normalizeApiBaseUrlInput(stored);
  }

  // 5. Check PC_IP override if provided
  final pcIp = _pcIpOverride.trim();
  if (pcIp.isNotEmpty) {
    return normalizeApiBaseUrlInput(pcIp);
  }

  return normalizeApiBaseUrlInput(productionApiBaseUrl);
}

Future<bool> _canConnect(
    {required String host,
    required int port,
    required Duration timeout}) async {
  Socket? socket;
  try {
    socket = await Socket.connect(host, port, timeout: timeout);
    return true;
  } catch (_) {
    return false;
  } finally {
    try {
      socket?.destroy();
    } catch (_) {}
  }
}
