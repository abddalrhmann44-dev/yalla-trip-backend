// ═══════════════════════════════════════════════════════════════
//  TALAA — Notification API Service
//  CRUD for user notifications via REST API
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String? ?? 'system',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationApiService {
  static final _api = ApiClient();

  static Future<List<NotificationItem>> getNotifications({
    int page = 1,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final params = '?page=$page&limit=$limit${unreadOnly ? '&unread_only=true' : ''}';
    final data = await _api.get('/notifications$params');
    final items = (data['items'] as List?) ?? [];
    return items.map((e) => NotificationItem.fromJson(e)).toList();
  }

  static Future<int> getUnreadCount() async {
    final data = await _api.get('/notifications/unread-count');
    return data['unread_count'] as int? ?? 0;
  }

  static Future<void> markAllRead() async {
    await _api.put('/notifications/mark-all-read', {});
  }

  static Future<void> markRead(int id) async {
    await _api.put('/notifications/$id/read', {});
  }

  static Future<void> delete(int id) async {
    await _api.delete('/notifications/$id');
  }
}
