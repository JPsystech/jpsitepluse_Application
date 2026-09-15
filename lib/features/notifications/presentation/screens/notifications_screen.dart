import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sitepulse_engineer/core/router/notification_router.dart';
import 'package:sitepulse_engineer/features/notifications/data/models/engineer_notification_model.dart';
import 'package:sitepulse_engineer/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:sitepulse_engineer/shared/widgets/error_state_view.dart';
import 'package:sitepulse_engineer/shared/widgets/shimmer_box.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsBloc>().add(
          const LoadNotificationsRequested(isRefresh: true),
        );
  }

  Future<void> _onRefresh() async {
    context.read<NotificationsBloc>().add(
          const LoadNotificationsRequested(isRefresh: true),
        );
  }

  void _onNotificationTapped(EngineerNotificationModel notification) {
    // 1. Mark as read immediately
    if (!notification.isRead) {
      context
          .read<NotificationsBloc>()
          .add(MarkNotificationReadRequested(notification.id));
    }

    // 2. Route using the notification data payload
    if (notification.data.isNotEmpty) {
      NotificationRouter.handleNotificationClick(notification.data);
    }
  }

  void _showClearAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Notifications?'),
        content: const Text(
          'This will remove all notification history from your account. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context
                  .read<NotificationsBloc>()
                  .add(const ClearAllNotificationsRequested());
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: BlocBuilder<NotificationsBloc, NotificationsState>(
          builder: (context, state) {
            final unreadCount =
                (state is NotificationsLoaded) ? state.unreadCount : 0;

            return Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          BlocBuilder<NotificationsBloc, NotificationsState>(
            builder: (context, state) {
              if (state is! NotificationsLoaded ||
                  state.notifications.isEmpty) {
                return const SizedBox.shrink();
              }

              final hasUnread = state.unreadCount > 0;

              return Row(
                children: [
                  if (hasUnread)
                    IconButton(
                      icon: const Icon(Icons.done_all_rounded),
                      tooltip: 'Mark all as read',
                      onPressed: () {
                        context
                            .read<NotificationsBloc>()
                            .add(const MarkAllNotificationsReadRequested());
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear all',
                    onPressed: () => _showClearAllConfirmation(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: BlocBuilder<NotificationsBloc, NotificationsState>(
          builder: (context, state) {
            if (state is NotificationsLoading) {
              return _buildShimmerList();
            }

            if (state is NotificationsError) {
              return ErrorStateView(
                message: state.message,
                onRetry: _onRefresh,
              );
            }

            if (state is NotificationsLoaded) {
              if (state.notifications.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: state.notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = state.notifications[index];
                  return _NotificationCard(
                    notification: item,
                    onTap: () => _onNotificationTapped(item),
                    onDismissed: () {
                      context
                          .read<NotificationsBloc>()
                          .add(DeleteNotificationRequested(item.id));
                    },
                  );
                },
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const ShimmerBox(
        width: double.infinity,
        height: 84,
        borderRadius: 16,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 56,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Notifications Yet",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "When you receive assignments, project updates, timesheet approvals, or attendance reminders, you'll see them here.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final EngineerNotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUnread = !notification.isRead;
    final categoryColor = notification.categoryColor;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.onError,
          size: 26,
        ),
      ),
      child: Material(
        color: isUnread
            ? colorScheme.primaryContainer.withValues(alpha: 0.25)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: isUnread ? 1.2 : 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    notification.icon,
                    color: categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (notification.timeAgo.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              notification.timeAgo,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isUnread
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isUnread
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Unread Indicator Dot
                if (isUnread) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
