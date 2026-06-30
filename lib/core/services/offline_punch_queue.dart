import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

enum OfflinePunchType { inPunch, outPunch }

class OfflinePunch {
  OfflinePunch({
    required this.clientPunchId,
    required this.type,
    required this.clientPunchTimeIso,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    this.projectId,
    this.remarks,
    this.exceptionReason,
  });

  final String clientPunchId;
  final OfflinePunchType type;
  final String clientPunchTimeIso;
  final double lat;
  final double lng;
  final double accuracyM;
  final String? projectId;
  final String? remarks;
  final String? exceptionReason;

  Map<String, dynamic> toJson() => {
        "client_punch_id": clientPunchId,
        "type": type == OfflinePunchType.inPunch ? "IN" : "OUT",
        "client_punch_time": clientPunchTimeIso,
        "lat": lat,
        "lng": lng,
        "accuracy_m": accuracyM,
        "project_id": projectId,
        "remarks": remarks,
        "exception_reason": exceptionReason,
      };

  static OfflinePunch? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = (raw["client_punch_id"] as String?)?.trim();
    final typeRaw = (raw["type"] as String?)?.trim().toUpperCase();
    final timeIso = (raw["client_punch_time"] as String?)?.trim();
    final lat = raw["lat"];
    final lng = raw["lng"];
    final acc = raw["accuracy_m"];
    if (id == null || id.isEmpty) return null;
    if (typeRaw != "IN" && typeRaw != "OUT") return null;
    if (timeIso == null || timeIso.isEmpty) return null;
    if (lat is! num || lng is! num || acc is! num) return null;
    return OfflinePunch(
      clientPunchId: id,
      type: typeRaw == "IN"
          ? OfflinePunchType.inPunch
          : OfflinePunchType.outPunch,
      clientPunchTimeIso: timeIso,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      accuracyM: acc.toDouble(),
      projectId: (raw["project_id"] as String?)?.trim(),
      remarks: (raw["remarks"] as String?)?.trim(),
      exceptionReason: (raw["exception_reason"] as String?)?.trim(),
    );
  }
}

class OfflinePunchQueue {
  static const String _key = "offline_punch_queue_v1";
  static const int _maxItems = 60;

  Future<List<OfflinePunch>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    final items = <OfflinePunch>[];
    for (final v in decoded) {
      final punch = OfflinePunch.fromJson(v);
      if (punch != null) items.add(punch);
    }
    items.sort((a, b) {
      final c = a.clientPunchTimeIso.compareTo(b.clientPunchTimeIso);
      if (c != 0) return c;
      if (a.type == b.type) return 0;
      return a.type == OfflinePunchType.inPunch ? -1 : 1;
    });
    return items;
  }

  Future<int> count() async {
    final items = await list();
    return items.length;
  }

  Future<bool> hasPendingIn() async {
    final items = await list();
    return items.any((p) => p.type == OfflinePunchType.inPunch);
  }

  Future<bool> hasPendingOut() async {
    final items = await list();
    return items.any((p) => p.type == OfflinePunchType.outPunch);
  }

  Future<void> add(OfflinePunch punch) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await list();
    final exists = items.any(
        (p) => p.clientPunchId == punch.clientPunchId && p.type == punch.type);
    if (exists) return;
    items.add(punch);
    items.sort((a, b) => a.clientPunchTimeIso.compareTo(b.clientPunchTimeIso));
    final trimmed = items.length > _maxItems
        ? items.sublist(items.length - _maxItems)
        : items;
    await prefs.setString(
        _key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  Future<void> remove(
      {required String clientPunchId, required OfflinePunchType type}) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await list();
    final next = items
        .where((p) => !(p.clientPunchId == clientPunchId && p.type == type))
        .toList();
    await prefs.setString(
        _key, jsonEncode(next.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
