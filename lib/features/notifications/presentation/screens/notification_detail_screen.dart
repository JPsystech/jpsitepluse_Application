import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sitepulse_engineer/core/router/notification_router.dart';
import 'package:sitepulse_engineer/features/notifications/data/models/engineer_notification_model.dart';

class NotificationDetailScreen extends StatelessWidget {
  final EngineerNotificationModel? notification;
  final Map<String, dynamic>? rawPayload;

  const NotificationDetailScreen({
    super.key,
    this.notification,
    this.rawPayload,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve notification fields from either EngineerNotificationModel or rawPayload Map
    final notif = notification;
    final payload = rawPayload ?? notif?.data ?? {};

    final String title = notif?.title ??
        (payload['title']?.toString() ?? 'Notice / Circular');
    final String body = notif?.body ??
        (payload['body']?.toString() ?? '');
    final String type = (notif?.notificationType ??
            payload['type'] ??
            payload['notification_type'] ??
            'GENERAL')
        .toString()
        .toUpperCase();

    DateTime? createdAt = notif?.createdAt;
    if (createdAt == null && payload['created_at'] != null) {
      createdAt = DateTime.tryParse(payload['created_at'].toString())?.toLocal();
    }

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Visual attributes
    final (IconData icon, Color color, String label) = _getCategoryDetails(type);

    final String formattedDate = createdAt != null
        ? DateFormat('EEEE, MMMM d, yyyy • hh:mm a').format(createdAt)
        : 'Notice received';

    final String? actionType = (payload['action_type'] ?? payload['actionType'])?.toString().trim();
    final bool hasAction = actionType != null && actionType.isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text(
          'Notice Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copy Message',
            onPressed: () {
              final copyText = '$title\n\n$body';
              Clipboard.setData(ClipboardData(text: copyText));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Circular text copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Category Badge & Issuer Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  label.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Official Office Circular • Site Administration',
                            style: textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Main Content Card
              Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Row
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 15, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Full Title
                      SelectableText(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: cs.onSurface,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 16),
                      Divider(color: cs.outlineVariant.withValues(alpha: 0.4), height: 1),
                      const SizedBox(height: 16),

                      // Full Body Content
                      SelectableText(
                        body.isEmpty ? '(No message body provided)' : body,
                        style: textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface,
                          height: 1.55,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 3. Action Buttons
              if (hasAction) ...[
                FilledButton.icon(
                  onPressed: () {
                    NotificationRouter.handleNotificationClick(payload);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(_getActionLabel(actionType)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to Notifications'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color, String) _getCategoryDetails(String type) {
    switch (type) {
      case 'ANNOUNCEMENT':
      case 'CIRCULAR':
        return (Icons.campaign_rounded, const Color(0xFF6366F1), 'Announcement');
      case 'URGENT':
      case 'URGENT_ALERT':
        return (Icons.warning_amber_rounded, const Color(0xFFDC2626), 'Urgent Alert');
      case 'SAFETY':
      case 'SAFETY_ALERT':
        return (Icons.health_and_safety_rounded, const Color(0xFFEA580C), 'Safety Alert');
      case 'PROJECT':
      case 'PROJECT_UPDATE':
        return (Icons.business_center_rounded, const Color(0xFF0D9488), 'Project Update');
      case 'ASSIGNMENT':
        return (Icons.assignment_outlined, const Color(0xFF2563EB), 'Assignment');
      case 'DOCUMENT':
      case 'DOCUMENT_VERIFICATION':
        return (Icons.description_outlined, const Color(0xFFD97706), 'Document Notice');
      case 'TIMESHEET':
      case 'WORK_SUBMISSION':
      case 'SUBMISSION':
        return (Icons.access_time_rounded, const Color(0xFF0D9488), 'Work Submission');
      case 'ATTENDANCE':
      case 'SHIFT_REMINDER':
      case 'OVERDUE_PUNCH_OUT':
        return (Icons.touch_app_rounded, const Color(0xFF7C3AED), 'Attendance Notice');
      case 'SECURITY':
        return (Icons.security_rounded, const Color(0xFFDC2626), 'Security Notice');
      case 'GENERAL':
      default:
        return (Icons.info_outline_rounded, const Color(0xFF2563EB), 'General Notice');
    }
  }

  String _getActionLabel(String actionType) {
    switch (actionType.toUpperCase()) {
      case 'ASSIGNMENT':
      case 'TODAY_ASSIGNMENT':
        return 'View Assignment';
      case 'DOCUMENT':
      case 'DOCUMENTS':
      case 'UPLOAD_DOCUMENT':
        return 'View Documents';
      case 'TIMESHEET':
      case 'SUBMISSION':
        return 'View Timesheets';
      case 'ATTENDANCE':
        return 'View Attendance';
      default:
        return 'Open Related Page';
    }
  }
}
