import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

void _log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

String? _inMemoryStore;
const String _prefsKey = "sitepulse_engineer_api_base_url";

const String productionApiBaseUrl = "https://jpsitepluse-backend.onrender.com";

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
}

const String _apiBaseUrlOverride = String.fromEnvironment("API_BASE_URL", defaultValue: "");
const String _pcIpOverride = String.fromEnvironment("PC_IP", defaultValue: "");

const String emulatorApiBaseUrl = "http://10.0.2.2:8011";
const String iosSimulatorApiBaseUrl = "http://192.168.1.12:8011";

Future<String>? _resolvedApiBaseUrl;

Future<String> resolveApiBaseUrl() {
  return _resolvedApiBaseUrl ??= _resolveApiBaseUrlInner();
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
  final override = _apiBaseUrlOverride.trim();
  _log("[ApiConfig] _apiBaseUrlOverride: '$override'");
  if (override.isNotEmpty) {
    return normalizeApiBaseUrlInput(override);
  }

  final stored = await getStoredApiBaseUrl();
  _log("[ApiConfig] stored: '$stored'");
  if (stored != null && stored.isNotEmpty) {
    return normalizeApiBaseUrlInput(stored);
  }

  final pcIp = _pcIpOverride.trim();
  _log("[ApiConfig] _pcIpOverride: '$pcIp'");
  if (pcIp.isNotEmpty) {
    return normalizeApiBaseUrlInput(pcIp);
  }

  if (kReleaseMode) {
    return normalizeApiBaseUrlInput(productionApiBaseUrl);
  }

  if (Platform.isAndroid) {
    final ok = await _canConnect(host: "10.0.2.2", port: 8011, timeout: const Duration(milliseconds: 400));
    if (ok) {
      return emulatorApiBaseUrl;
    }
    throw ApiConfigException("Set server IP: use http://<PC_IP>:8011 (example: http://192.168.1.12:8011)");
  }

  if (Platform.isIOS) {
    final ok = await _canConnect(host: "127.0.0.1", port: 8011, timeout: const Duration(milliseconds: 400));
    if (ok) {
      return iosSimulatorApiBaseUrl;
    }
    throw ApiConfigException("Set server IP: use http://<PC_IP>:8011 (example: http://192.168.1.12:8011)");
  }

  throw ApiConfigException("API base URL is not configured");
}

Future<bool> _canConnect({required String host, required int port, required Duration timeout}) async {
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
