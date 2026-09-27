import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_endpoints.dart';
import '../models/notification.dart';
import 'auth_provider.dart';

class NotificationsState {
  final List<NotificationModel> items;
  final int unreadCount;
  final bool isLoading;

  NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationsState copyWith({
    List<NotificationModel>? items,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final Ref ref;

  NotificationsNotifier(this.ref) : super(NotificationsState()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    state = state.copyWith(isLoading: true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.dio.get(ApiEndpoints.notifications);
      if (res.statusCode == 200 && res.data != null) {
        final rawItems = res.data['items'] as List? ?? [];
        final items = rawItems.map((e) => NotificationModel.fromJson(e)).toList();
        final unread = (res.data['unreadCount'] as num?)?.toInt() ?? 0;
        state = NotificationsState(items: items, unreadCount: unread, isLoading: false);
        return;
      }
    } catch (_) {}

    state = state.copyWith(isLoading: false);
  }

  Future<void> markAsRead(String id) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.dio.patch(ApiEndpoints.notificationRead(id));
      final updated = state.items.map((n) {
        if (n.id == id) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            metadata: n.metadata,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();

      final newUnread = state.unreadCount > 0 ? state.unreadCount - 1 : 0;
      state = state.copyWith(items: updated, unreadCount: newUnread);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.dio.post(ApiEndpoints.notificationsReadAll);
      final updated = state.items.map((n) {
        return NotificationModel(
          id: n.id,
          userId: n.userId,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true,
          metadata: n.metadata,
          createdAt: n.createdAt,
        );
      }).toList();
      state = state.copyWith(items: updated, unreadCount: 0);
    } catch (_) {}
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref);
});
