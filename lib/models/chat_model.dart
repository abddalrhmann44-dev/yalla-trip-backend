// ═══════════════════════════════════════════════════════════════
//  TALAA — Chat models (matches backend /chats API)
// ═══════════════════════════════════════════════════════════════

class ChatUserBrief {
  final int id;
  final String name;
  final String? avatarUrl;
  final bool isVerified;

  const ChatUserBrief({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isVerified = false,
  });

  factory ChatUserBrief.fromJson(Map<String, dynamic> j) => ChatUserBrief(
        id: j['id'] ?? 0,
        name: (j['name'] ?? '') as String,
        avatarUrl: j['avatar_url'] as String?,
        isVerified: j['is_verified'] ?? false,
      );
}

class ChatPropertyBrief {
  final int id;
  final String name;
  final String? firstImage;

  const ChatPropertyBrief({
    required this.id,
    required this.name,
    this.firstImage,
  });

  factory ChatPropertyBrief.fromJson(Map<String, dynamic> j) =>
      ChatPropertyBrief(
        id: j['id'] ?? 0,
        name: (j['name'] ?? '') as String,
        firstImage: j['first_image'] as String?,
      );
}

/// Lifecycle of a price-negotiation thread (Wave 23).
enum ConversationStatus { open, accepted, declined, expired }

/// Semantic role of a chat message (Wave 23).
enum MessageKind { text, offer, accept, decline, system }

ConversationStatus _parseConvStatus(dynamic v) {
  switch (v) {
    case 'accepted':
      return ConversationStatus.accepted;
    case 'declined':
      return ConversationStatus.declined;
    case 'expired':
      return ConversationStatus.expired;
    default:
      return ConversationStatus.open;
  }
}

MessageKind _parseMessageKind(dynamic v) {
  switch (v) {
    case 'offer':
      return MessageKind.offer;
    case 'accept':
      return MessageKind.accept;
    case 'decline':
      return MessageKind.decline;
    case 'system':
      return MessageKind.system;
    default:
      return MessageKind.text;
  }
}

class Conversation {
  final int id;
  final ChatUserBrief guest;
  final ChatUserBrief owner;
  final ChatPropertyBrief? property;

  // ── Booking intent (Wave 23) ───────────────────────────
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? guests;

  // ── Negotiation state ──────────────────────────────────
  final ConversationStatus status;
  final double? latestOfferAmount;

  /// "guest" | "owner" | null
  final String? latestOfferBy;
  final int? bookingId;

  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.guest,
    required this.owner,
    required this.createdAt,
    required this.updatedAt,
    this.property,
    this.checkIn,
    this.checkOut,
    this.guests,
    this.status = ConversationStatus.open,
    this.latestOfferAmount,
    this.latestOfferBy,
    this.bookingId,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'],
        guest: ChatUserBrief.fromJson(j['guest']),
        owner: ChatUserBrief.fromJson(j['owner']),
        property: j['property'] == null
            ? null
            : ChatPropertyBrief.fromJson(j['property']),
        checkIn: _parseDate(j['check_in']),
        checkOut: _parseDate(j['check_out']),
        guests: j['guests'] as int?,
        status: _parseConvStatus(j['status']),
        latestOfferAmount: (j['latest_offer_amount'] as num?)?.toDouble(),
        latestOfferBy: j['latest_offer_by'] as String?,
        bookingId: j['booking_id'] as int?,
        lastMessageAt: _parse(j['last_message_at']),
        lastMessagePreview: j['last_message_preview'] as String?,
        unreadCount: j['unread_count'] ?? 0,
        createdAt: _parse(j['created_at']) ?? DateTime.now(),
        updatedAt: _parse(j['updated_at']) ?? DateTime.now(),
      );

  bool get isOpen => status == ConversationStatus.open;
  bool get isAccepted => status == ConversationStatus.accepted;

  /// True when the *current user* is the side that posted the last
  /// offer — used by the UI to disable the "Accept" button on their
  /// own offer.
  bool latestOfferIsMine(int currentUserId) {
    if (latestOfferBy == null) return false;
    final myRole = currentUserId == guest.id ? 'guest' : 'owner';
    return latestOfferBy == myRole;
  }

  /// True when there is a pending offer from the *other* side that the
  /// current user can accept.
  bool canAccept(int currentUserId) =>
      isOpen && latestOfferAmount != null && !latestOfferIsMine(currentUserId);

  /// Return the participant that is **not** the current user.
  ChatUserBrief otherParticipant(int currentUserId) =>
      guest.id == currentUserId ? owner : guest;
}

class ChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final MessageKind kind;
  final String body;
  final double? offerAmount;
  final int? bookingId;
  final DateTime? readAt;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.kind = MessageKind.text,
    this.offerAmount,
    this.bookingId,
    this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'],
        conversationId: j['conversation_id'],
        senderId: j['sender_id'],
        kind: _parseMessageKind(j['kind']),
        body: (j['body'] ?? '') as String,
        offerAmount: (j['offer_amount'] as num?)?.toDouble(),
        bookingId: j['booking_id'] as int?,
        readAt: _parse(j['read_at']),
        createdAt: _parse(j['created_at']) ?? DateTime.now(),
      );

  bool get isRead => readAt != null;
  bool get isOffer => kind == MessageKind.offer;
  bool get isAccept => kind == MessageKind.accept;
  bool get isDecline => kind == MessageKind.decline;
  bool get isSystem => kind == MessageKind.system;
}

/// Response of ``POST /chats/{id}/accept`` — an accepted offer with a
/// freshly minted booking.
class ConversationAccepted {
  final Conversation conversation;
  final int bookingId;
  final String bookingCode;
  final double totalPrice;

  const ConversationAccepted({
    required this.conversation,
    required this.bookingId,
    required this.bookingCode,
    required this.totalPrice,
  });

  factory ConversationAccepted.fromJson(Map<String, dynamic> j) =>
      ConversationAccepted(
        conversation: Conversation.fromJson(j['conversation']),
        bookingId: j['booking_id'] as int,
        bookingCode: (j['booking_code'] ?? '') as String,
        totalPrice: (j['total_price'] as num).toDouble(),
      );
}

DateTime? _parseDate(dynamic v) {
  if (v is String && v.isNotEmpty) {
    final d = DateTime.tryParse(v);
    if (d != null) return DateTime(d.year, d.month, d.day);
  }
  return null;
}

DateTime? _parse(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}
