import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  AppNotification({required this.id, required this.type, required this.title, required this.body, required this.isRead, required this.createdAt});
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num).toInt(),
        type: j['type']?.toString() ?? 'info',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now(),
      );
}

class NotificationsNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationsNotifier() : super(const AsyncValue.loading()) { refresh(); }
  int unread = 0;
  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance.notifications();
      final list = ((res['notifications'] as List?) ?? const []).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
      unread = (res['unread'] as num?)?.toInt() ?? list.where((n) => !n.isRead).length;
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  Future<void> markRead(int id) async {
    try { await ApiClient.instance.markNotificationRead(id); refresh(); } catch (_) {}
  }
  Future<void> markAllRead() async {
    try { await ApiClient.instance.markAllNotificationsRead(); refresh(); } catch (_) {}
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, AsyncValue<List<AppNotification>>>((ref) => NotificationsNotifier());
