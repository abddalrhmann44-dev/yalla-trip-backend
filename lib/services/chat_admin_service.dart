// ═══════════════════════════════════════════════════════════════
//  TALAA — Chat Admin Service (chat-monitor page)
//  Wraps the admin endpoints under ``/admin/chat/messages``.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

class ChatMessageRow {
  final int id;
  final int conversationId;
  final int senderId;
  final String? senderName;
  final String body;
  final String kind;
  final bool isFlagged;
  final bool isHidden;
  final String? flagReason;
  final DateTime createdAt;

  ChatMessageRow({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.kind,
    required this.isFlagged,
    required this.isHidden,
    required this.flagReason,
    required this.createdAt,
  });

  factory ChatMessageRow.fromJson(Map<String, dynamic> j) {
    DateTime p(Object? v) =>
        v == null ? DateTime.now() : DateTime.tryParse(v as String) ?? DateTime.now();
    return ChatMessageRow(
      id: (j['id'] as num).toInt(),
      conversationId: (j['conversation_id'] as num).toInt(),
      senderId: (j['sender_id'] as num).toInt(),
      senderName: j['sender_name'] as String?,
      body: j['body'] as String? ?? '',
      kind: j['kind'] as String? ?? 'text',
      isFlagged: j['is_flagged'] as bool? ?? false,
      isHidden: j['is_hidden'] as bool? ?? false,
      flagReason: j['flag_reason'] as String?,
      createdAt: p(j['created_at']),
    );
  }
}

class ChatConversationRow {
  final int id;
  final int guestId;
  final String? guestName;
  final int ownerId;
  final String? ownerName;
  final int? propertyId;
  final String? propertyName;
  final String status;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int messageCount;
  final int flaggedCount;
  final int hiddenCount;

  ChatConversationRow({
    required this.id,
    required this.guestId,
    required this.guestName,
    required this.ownerId,
    required this.ownerName,
    required this.propertyId,
    required this.propertyName,
    required this.status,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.messageCount,
    required this.flaggedCount,
    required this.hiddenCount,
  });

  factory ChatConversationRow.fromJson(Map<String, dynamic> j) {
    DateTime? p(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);
    return ChatConversationRow(
      id: (j['id'] as num).toInt(),
      guestId: (j['guest_id'] as num).toInt(),
      guestName: j['guest_name'] as String?,
      ownerId: (j['owner_id'] as num).toInt(),
      ownerName: j['owner_name'] as String?,
      propertyId: (j['property_id'] as num?)?.toInt(),
      propertyName: j['property_name'] as String?,
      status: j['status'] as String? ?? 'open',
      lastMessageAt: p(j['last_message_at']),
      lastMessagePreview: j['last_message_preview'] as String?,
      messageCount: (j['message_count'] as num?)?.toInt() ?? 0,
      flaggedCount: (j['flagged_count'] as num?)?.toInt() ?? 0,
      hiddenCount: (j['hidden_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatAdminService {
  static final _api = ApiClient();

  static Future<List<ChatConversationRow>> listConversations({
    bool flaggedOnly = false,
    bool hiddenOnly = false,
    int limit = 200,
  }) async {
    final params = [
      'limit=$limit',
      if (flaggedOnly) 'flagged_only=true',
      if (hiddenOnly) 'hidden_only=true',
    ].join('&');
    final res = await _api.get('/admin/chat/conversations?$params');
    return (res as List)
        .map((e) => ChatConversationRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ChatMessageRow>> list({
    bool flaggedOnly = false,
    bool hiddenOnly = false,
    int? conversationId,
    int limit = 100,
  }) async {
    final params = [
      'limit=$limit',
      if (flaggedOnly) 'flagged_only=true',
      if (hiddenOnly) 'hidden_only=true',
      if (conversationId != null) 'conversation_id=$conversationId',
    ].join('&');
    final res = await _api.get('/admin/chat/messages?$params');
    return (res as List)
        .map((e) => ChatMessageRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ChatMessageRow> hide(int id, {String? note}) async {
    final res = await _api.post(
      '/admin/chat/messages/$id/hide',
      {if (note != null && note.isNotEmpty) 'note': note},
    );
    return ChatMessageRow.fromJson(res as Map<String, dynamic>);
  }

  static Future<ChatMessageRow> unhide(int id) async {
    final res = await _api.post('/admin/chat/messages/$id/unhide', {});
    return ChatMessageRow.fromJson(res as Map<String, dynamic>);
  }

  static Future<ChatMessageRow> clearFlag(int id) async {
    final res = await _api.post('/admin/chat/messages/$id/clear-flag', {});
    return ChatMessageRow.fromJson(res as Map<String, dynamic>);
  }
}
