import 'dart:convert';

import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MobilePolicy {
  const MobilePolicy({
    this.trackingMinMovementM = 10,
    this.trackingUpdateIntervalSeconds = 15,
    this.trackingStationaryHeartbeatSeconds = 180,
    this.trackingMaxAccuracyM = 200,
    this.trackingMaxSpeedMps = 70,
    this.documentMaxBytes = 15 * 1024 * 1024,
    this.offlinePunchQueueMaxItems = 60,
    this.offlineTimesheetQueueMaxItems = 30,
  });

  final int trackingMinMovementM;
  final int trackingUpdateIntervalSeconds;
  final int trackingStationaryHeartbeatSeconds;
  final int trackingMaxAccuracyM;
  final int trackingMaxSpeedMps;
  final int documentMaxBytes;
  final int offlinePunchQueueMaxItems;
  final int offlineTimesheetQueueMaxItems;

  factory MobilePolicy.fromJson(Map<String, dynamic> json) => MobilePolicy(
        trackingMinMovementM: (json['tracking_min_movement_m'] as num?)?.toInt() ?? 10,
        trackingUpdateIntervalSeconds: (json['tracking_update_interval_seconds'] as num?)?.toInt() ?? 15,
        trackingStationaryHeartbeatSeconds:
            (json['tracking_stationary_heartbeat_seconds'] as num?)?.toInt() ?? 180,
        trackingMaxAccuracyM: (json['tracking_max_accuracy_m'] as num?)?.toInt() ?? 200,
        trackingMaxSpeedMps: (json['tracking_max_speed_mps'] as num?)?.toInt() ?? 70,
        documentMaxBytes: (json['document_max_bytes'] as num?)?.toInt() ?? 15 * 1024 * 1024,
        offlinePunchQueueMaxItems:
            (json['offline_punch_queue_max_items'] as num?)?.toInt() ?? 60,
        offlineTimesheetQueueMaxItems:
            (json['offline_timesheet_queue_max_items'] as num?)?.toInt() ?? 30,
      );

  Map<String, dynamic> toJson() => {
        'tracking_min_movement_m': trackingMinMovementM,
        'tracking_update_interval_seconds': trackingUpdateIntervalSeconds,
        'tracking_stationary_heartbeat_seconds': trackingStationaryHeartbeatSeconds,
        'tracking_max_accuracy_m': trackingMaxAccuracyM,
        'tracking_max_speed_mps': trackingMaxSpeedMps,
        'document_max_bytes': documentMaxBytes,
        'offline_punch_queue_max_items': offlinePunchQueueMaxItems,
        'offline_timesheet_queue_max_items': offlineTimesheetQueueMaxItems,
      };
}

/// A cached policy makes the settings available to the background isolate too.
class MobilePolicyService {
  MobilePolicyService._();

  static const _cacheKey = 'sitepulse_mobile_policy_v1';
  static MobilePolicy current = const MobilePolicy();

  static Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw);
      if (json is Map) current = MobilePolicy.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {}
  }

  static Future<void> refresh() async {
    try {
      final client = await ApiClient.instance.dio;
      final response = await client.get('/api/v1/engineer/mobile-policy');
      if (response.data is! Map) return;
      current = MobilePolicy.fromJson(Map<String, dynamic>.from(response.data as Map));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(current.toJson()));
    } catch (_) {
      // The cached policy remains valid when the device is offline.
    }
  }
}
