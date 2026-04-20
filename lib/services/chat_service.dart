// ═══════════════════════════════════════════════════════════════
//  TALAA — Chat Service
//  Thin wrapper around the backend /chats endpoints.
// ═══════════════════════════════════════════════════════════════

import '../models/chat_model.dart';
import '../utils/api_client.dart';

class ChatService {
  static final _api = ApiClient();

  // ── Inbox ─────────────────────────────────────────────────
  static Future<List<Conversation>> listConversations() async {
    final data = await _api.get('/chats');
    return (data as List)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Start / fetch conversation about a property ──────────
  /// Starts a price-negotiation thread (Wave 23).  ``checkIn``,
  /// ``checkOut`` and ``guests`` are required so both sides know the
  /// scope of the trip they are haggling over.
  static Future<Conversation> startConversation(
    int propertyId, {
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
  }) async {
    final data = await _api.post('/chats', {
      'property_id': propertyId,
      'check_in': _dateOnly(checkIn),
      'check_out': _dateOnly(checkOut),
      'guests': guests,
    });
    return Conversation.fromJson(data as Map<String, dynamic>);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── Single conversation meta ─────────────────────────────
  static Future<Conversation> getConversation(int id) async {
    final data = await _api.get('/chats/$id');
    return Conversation.fromJson(data as Map<String, dynamic>);
  }

  // ── Messages ─────────────────────────────────────────────
  /// Returns ``(messages, hasMore)``.  Messages arrive chronologically
  /// (oldest first) so the client can just append to the bottom.
  static Future<(List<ChatMessage>, bool)> listMessages(
    int conversationId, {
    DateTime? before,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (before != null) params['before'] = before.toUtc().toIso8601String();
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final data = await _api.get('/chats/$conversationId/messages?$qs');
    final items = (data['items'] as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    final hasMore = data['has_more'] ?? false;
    return (items, hasMore as bool);
  }

  static Future<ChatMessage> sendMessage(int conversationId, String body) async {
    final data = await _api.post(
      '/chats/$conversationId/messages',
      {'body': body},
    );
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  static Future<Conversation> markRead(int conversationId) async {
    final data = await _api.patch('/chats/$conversationId/read', {});
    return Conversation.fromJson(data as Map<String, dynamic>);
  }

  // ── Negotiation (Wave 23) ────────────────────────────────

  /// Post a new offer (or counter-offer).  Amount is in EGP per
  /// night for chalets, per hour for boats.
  static Future<ChatMessage> postOffer(
    int conversationId,
    double amount,
  ) async {
    final data = await _api.post(
      '/chats/$conversationId/offer',
      {'amount': amount},
    );
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  /// Decline the counter-party's latest offer.  Thread stays open so
  /// a fresh counter-offer can be made.
  static Future<ChatMessage> declineOffer(int conversationId) async {
    final data = await _api.post('/chats/$conversationId/decline', {});
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  /// Accept the counter-party's latest offer → booking is auto-created.
  static Future<ConversationAccepted> acceptOffer(int conversationId) async {
    final data = await _api.post('/chats/$conversationId/accept', {});
    return ConversationAccepted.fromJson(data as Map<String, dynamic>);
  }
}

/// Thin wrapper around the booking contact-reveal endpoint (Wave 23).
class BookingContactService {
  static final _api = ApiClient();

  /// Fetch the counter-party's name + phone for a *confirmed* booking.
  /// Throws [ApiException] with `409` while the booking is still pending.
  static Future<BookingContact> getContact(int bookingId) async {
    final data = await _api.get('/bookings/$bookingId/contact');
    return BookingContact.fromJson(data as Map<String, dynamic>);
  }
}

class BookingContact {
  final String name;
  final String? phone;
  final String role; // "owner" or "guest"
  const BookingContact({required this.name, required this.role, this.phone});

  factory BookingContact.fromJson(Map<String, dynamic> j) => BookingContact(
        name: (j['name'] ?? '') as String,
        phone: j['phone'] as String?,
        role: (j['role'] ?? 'owner') as String,
      );
}

/// Phone-OTP flow for owner verification (Wave 23).
class PhoneOtpService {
  static final _api = ApiClient();

  /// Request a 6-digit SMS code.  Returns the normalised E.164 phone.
  static Future<String> startOtp(String rawPhone) async {
    final data = await _api.post(
      '/me/phone/start-otp',
      {'phone': rawPhone},
    );
    return (data['phone'] ?? rawPhone) as String;
  }

  /// Verify the code.  Throws [ApiException] on wrong/expired code.
  static Future<String> verifyOtp(String rawPhone, String code) async {
    final data = await _api.post(
      '/me/phone/verify-otp',
      {'phone': rawPhone, 'code': code},
    );
    return (data['phone'] ?? rawPhone) as String;
  }
}
