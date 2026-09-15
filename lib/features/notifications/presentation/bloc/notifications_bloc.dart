import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sitepulse_engineer/core/error/error_handler.dart';
import 'package:sitepulse_engineer/features/notifications/data/models/engineer_notification_model.dart';
import 'package:sitepulse_engineer/features/notifications/data/services/notification_center_service.dart';

// --- Events ---
abstract class NotificationsEvent {
  const NotificationsEvent();
}

class LoadNotificationsRequested extends NotificationsEvent {
  final bool isRefresh;
  final bool silent;

  const LoadNotificationsRequested({
    this.isRefresh = false,
    this.silent = false,
  });
}

class MarkNotificationReadRequested extends NotificationsEvent {
  final String id;
  const MarkNotificationReadRequested(this.id);
}

class MarkAllNotificationsReadRequested extends NotificationsEvent {
  const MarkAllNotificationsReadRequested();
}

class ClearAllNotificationsRequested extends NotificationsEvent {
  const ClearAllNotificationsRequested();
}

class DeleteNotificationRequested extends NotificationsEvent {
  final String id;
  const DeleteNotificationRequested(this.id);
}

class ForegroundNotificationReceived extends NotificationsEvent {
  final String id;
  final String title;
  final String body;
  final String notificationType;
  final Map<String, dynamic> data;

  const ForegroundNotificationReceived({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    required this.data,
  });
}

// --- States ---
abstract class NotificationsState {
  const NotificationsState();
}

class NotificationsInitial extends NotificationsState {}

class NotificationsLoading extends NotificationsState {}

class NotificationsLoaded extends NotificationsState {
  final List<EngineerNotificationModel> notifications;
  final int unreadCount;
  final int totalCount;

  const NotificationsLoaded({
    required this.notifications,
    required this.unreadCount,
    required this.totalCount,
  });

  NotificationsLoaded copyWith({
    List<EngineerNotificationModel>? notifications,
    int? unreadCount,
    int? totalCount,
  }) {
    return NotificationsLoaded(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class NotificationsError extends NotificationsState {
  final String message;
  const NotificationsError(this.message);
}

// --- BLoC ---
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationCenterService _service;

  NotificationsBloc({NotificationCenterService? service})
      : _service = service ?? NotificationCenterService(),
        super(NotificationsInitial()) {
    on<LoadNotificationsRequested>(_onLoadNotifications);
    on<MarkNotificationReadRequested>(_onMarkNotificationRead);
    on<MarkAllNotificationsReadRequested>(_onMarkAllNotificationsRead);
    on<ClearAllNotificationsRequested>(_onClearAllNotifications);
    on<DeleteNotificationRequested>(_onDeleteNotification);
    on<ForegroundNotificationReceived>(_onForegroundNotificationReceived);
  }

  Future<void> _onLoadNotifications(
    LoadNotificationsRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (!event.silent && !event.isRefresh && state is! NotificationsLoaded) {
      emit(NotificationsLoading());
    }

    try {
      final response = await _service.getNotifications();
      emit(NotificationsLoaded(
        notifications: response.items,
        unreadCount: response.unreadCount,
        totalCount: response.totalCount,
      ));
    } catch (e) {
      if (state is! NotificationsLoaded) {
        final appError = ErrorHandler.handle(e);
        emit(NotificationsError(appError.userMessage));
      }
    }
  }

  Future<void> _onMarkNotificationRead(
    MarkNotificationReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is NotificationsLoaded) {
      final currentState = state as NotificationsLoaded;
      final updatedList = currentState.notifications.map((item) {
        if (item.id == event.id && !item.isRead) {
          return item.copyWith(isRead: true, readAt: DateTime.now());
        }
        return item;
      }).toList();

      final newUnread = (currentState.unreadCount > 0)
          ? currentState.unreadCount - 1
          : 0;

      emit(currentState.copyWith(
        notifications: updatedList,
        unreadCount: newUnread,
      ));

      try {
        final serverUnread = await _service.markAsRead(event.id);
        if (state is NotificationsLoaded) {
          emit((state as NotificationsLoaded).copyWith(unreadCount: serverUnread));
        }
      } catch (_) {}
    }
  }

  Future<void> _onMarkAllNotificationsRead(
    MarkAllNotificationsReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is NotificationsLoaded) {
      final currentState = state as NotificationsLoaded;
      final updatedList = currentState.notifications.map((item) {
        return item.copyWith(isRead: true, readAt: DateTime.now());
      }).toList();

      emit(currentState.copyWith(
        notifications: updatedList,
        unreadCount: 0,
      ));

      try {
        await _service.markAllAsRead();
      } catch (_) {}
    }
  }

  Future<void> _onClearAllNotifications(
    ClearAllNotificationsRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(const NotificationsLoaded(
      notifications: [],
      unreadCount: 0,
      totalCount: 0,
    ));

    try {
      await _service.clearAll();
    } catch (_) {}
  }

  Future<void> _onDeleteNotification(
    DeleteNotificationRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is NotificationsLoaded) {
      final currentState = state as NotificationsLoaded;
      final itemToDelete = currentState.notifications
          .where((i) => i.id == event.id)
          .firstOrNull;

      final updatedList = currentState.notifications
          .where((i) => i.id != event.id)
          .toList();

      final wasUnread = itemToDelete?.isRead == false;
      final newUnread = (wasUnread && currentState.unreadCount > 0)
          ? currentState.unreadCount - 1
          : currentState.unreadCount;

      emit(currentState.copyWith(
        notifications: updatedList,
        unreadCount: newUnread,
        totalCount: (currentState.totalCount > 0)
            ? currentState.totalCount - 1
            : 0,
      ));

      try {
        final serverUnread = await _service.deleteNotification(event.id);
        if (state is NotificationsLoaded) {
          emit((state as NotificationsLoaded).copyWith(unreadCount: serverUnread));
        }
      } catch (_) {}
    }
  }

  void _onForegroundNotificationReceived(
    ForegroundNotificationReceived event,
    Emitter<NotificationsState> emit,
  ) {
    final newNotif = EngineerNotificationModel(
      id: event.id,
      title: event.title,
      body: event.body,
      notificationType: event.notificationType,
      data: event.data,
      isRead: false,
      createdAt: DateTime.now(),
    );

    if (state is NotificationsLoaded) {
      final currentState = state as NotificationsLoaded;
      final updatedList = [newNotif, ...currentState.notifications];
      emit(currentState.copyWith(
        notifications: updatedList,
        unreadCount: currentState.unreadCount + 1,
        totalCount: currentState.totalCount + 1,
      ));
    } else {
      emit(NotificationsLoaded(
        notifications: [newNotif],
        unreadCount: 1,
        totalCount: 1,
      ));
    }
  }
}
