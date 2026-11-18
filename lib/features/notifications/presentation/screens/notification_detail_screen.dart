import 'package:flutter/material.dart';
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
    DateTime? createdAt = notif?.createdAt;
    if (createdAt == null && payload['created_at'] != null) {
      createdAt = DateTime.tryParse(payload['created_at'].toString())?.toLocal();
    }

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final String formattedDate = createdAt != null
        ? DateFormat('EEEE, MMMM d, yyyy • hh:mm a').format(createdAt)
        : 'Notice received';

    final String? actionType = (payload['action_type'] ?? payload['actionType'])?.toString().trim();
    final bool hasAction = actionType != null && actionType.isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              formattedDate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /* Category badge intentionally omitted from notification details.
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

              */
              // Main Content Card
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

            ],
          ),
        ),
      ),
    );
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
