import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitepulse_engineer/core/error/error_handler.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/features/notifications/data/models/engineer_notification_model.dart';

class NotificationCenterService {
  static const String _cacheKey = 'sitepulse_cached_notifications_v1';

  Future<EngineerNotificationListResponse> getNotifications({
    int page = 1,
    int pageSize = 30,
    bool unreadOnly = false,
  }) async {
    final client = await ApiClient.instance.dio;

    try {
      final response = await client.get(
        '/api/v1/engineer/notifications',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          'unread_only': unreadOnly,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        // Cache latest response locally for offline access
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, jsonEncode(response.data));
        } catch (_) {}

        return EngineerNotificationListResponse.fromJson(
          Map<String, dynamic>.from(response.data),
        );
      } else {
        throw Exception(
          response.data['detail'] ?? 'Failed to load notifications',
        );
      }
    } catch (e) {
      // If offline or network error, fallback to locally cached notifications
      if (ErrorHandler.isOfflineError(e)) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString(_cacheKey);
          if (cached != null && cached.trim().isNotEmpty) {
            final decoded = jsonDecode(cached);
            if (decoded is Map<String, dynamic>) {
              return EngineerNotificationListResponse.fromJson(decoded);
            }
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<int> markAsRead(String id) async {
    final client = await ApiClient.instance.dio;
    try {
      final response = await client.patch(
        '/api/v1/engineer/notifications/$id/read',
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data['unread_count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('[NotificationCenterService] markAsRead error: $e');
      return 0;
    }
  }

  Future<void> markAllAsRead() async {
    final client = await ApiClient.instance.dio;
    try {
      await client.post('/api/v1/engineer/notifications/mark-all-read');
    } catch (e) {
      debugPrint('[NotificationCenterService] markAllAsRead error: $e');
      rethrow;
    }
  }

  Future<void> clearAll() async {
    final client = await ApiClient.instance.dio;
    try {
      await client.delete('/api/v1/engineer/notifications/clear');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (e) {
      debugPrint('[NotificationCenterService] clearAll error: $e');
      rethrow;
    }
  }

  Future<int> deleteNotification(String id) async {
    final client = await ApiClient.instance.dio;
    try {
      final response = await client.delete(
        '/api/v1/engineer/notifications/$id',
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data['unread_count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('[NotificationCenterService] deleteNotification error: $e');
      return 0;
    }
  }
}
