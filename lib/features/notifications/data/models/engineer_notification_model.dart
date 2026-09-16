import 'package:flutter/material.dart';
import 'package:sitepulse_engineer/core/utils/formatters.dart';

class EngineerNotificationModel {
  final String id;
  final String title;
  final String body;
  final String notificationType;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? readAt;

  const EngineerNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    required this.data,
    required this.isRead,
    this.createdAt,
    this.readAt,
  });

  factory EngineerNotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        String str = value.trim();
        if (str.isEmpty) return null;
        if (!str.endsWith('Z') &&
            !str.contains('+') &&
            !RegExp(r'-\d{2}:\d{2}$').hasMatch(str)) {
          str = '${str}Z';
        }
        return DateTime.tryParse(str)?.toLocal();
      }
      return null;
    }

    return EngineerNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      notificationType: (json['notification_type'] ?? json['type'] ?? 'GENERAL')
          .toString()
          .toUpperCase(),
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'])
          : {},
      isRead: json['is_read'] == true,
      createdAt: parseDate(json['created_at']),
      readAt: parseDate(json['read_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'notification_type': notificationType,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }

  EngineerNotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? notificationType,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return EngineerNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      notificationType: notificationType ?? this.notificationType,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  String get timeAgo {
    if (createdAt == null) return '';
    final local = createdAt!.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? "min" : "mins"} ago';
    } else if (difference.inHours < 24 && now.day == local.day) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? "hr" : "hrs"} ago';
    } else {
      final isYesterday = now.subtract(const Duration(days: 1)).day == local.day &&
          now.subtract(const Duration(days: 1)).month == local.month &&
          now.subtract(const Duration(days: 1)).year == local.year;
      final timeStr = AppFormatters.formatTime(local);
      if (isYesterday) {
        return 'Yesterday, $timeStr';
      }
      return '${local.day.toString().padLeft(2, "0")}/${local.month.toString().padLeft(2, "0")}/${local.year}';
    }
  }

  IconData get icon {
    switch (notificationType) {
      case 'ASSIGNMENT':
        return Icons.assignment_outlined;
      case 'TIMESHEET':
      case 'WORK_SUBMISSION':
      case 'SUBMISSION':
        return Icons.access_time_rounded;
      case 'DOCUMENT':
      case 'DOCUMENT_VERIFICATION':
        return Icons.description_outlined;
      case 'ATTENDANCE':
      case 'SHIFT_REMINDER':
      case 'OVERDUE_PUNCH_OUT':
        return Icons.touch_app_rounded;
      case 'SECURITY':
        return Icons.security_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color get categoryColor {
    switch (notificationType) {
      case 'ASSIGNMENT':
        return const Color(0xFF2563EB); // Blue
      case 'TIMESHEET':
      case 'WORK_SUBMISSION':
      case 'SUBMISSION':
        return const Color(0xFF0D9488); // Teal
      case 'DOCUMENT':
      case 'DOCUMENT_VERIFICATION':
        return const Color(0xFFD97706); // Amber / Orange
      case 'ATTENDANCE':
      case 'SHIFT_REMINDER':
      case 'OVERDUE_PUNCH_OUT':
        return const Color(0xFF7C3AED); // Purple
      case 'SECURITY':
        return const Color(0xFFDC2626); // Red
      default:
        return const Color(0xFF4B5563); // Gray
    }
  }
}

class EngineerNotificationListResponse {
  final bool success;
  final int unreadCount;
  final int totalCount;
  final int page;
  final int pageSize;
  final List<EngineerNotificationModel> items;

  const EngineerNotificationListResponse({
    required this.success,
    required this.unreadCount,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.items,
  });

  factory EngineerNotificationListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<EngineerNotificationModel> itemsList = [];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          itemsList.add(EngineerNotificationModel.fromJson(it));
        }
      }
    }

    return EngineerNotificationListResponse(
      success: json['success'] == true,
      unreadCount: json['unread_count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 30,
      items: itemsList,
    );
  }
}
