// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Owner Verification Service
//  Verify booking codes entered by property owners
// ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class OwnerVerificationService {
  final FirebaseFirestore _db;
  OwnerVerificationService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Verify a booking code ─────────────────────────────────
  /// Returns the booking if found, null otherwise.
  /// Optionally restrict to ownerId for security.
  Future<BookingModel?> verifyBookingCode(
    String code, {
    String? ownerId,
  }) async {
    if (code.trim().isEmpty) return null;

    Query q = _db
        .collection('bookings')
        .where('bookingCode', isEqualTo: code.trim().toUpperCase())
        .limit(1);

    // If ownerId provided, restrict query to owner's bookings
    if (ownerId != null && ownerId.isNotEmpty) {
      q = _db
          .collection('bookings')
          .where('bookingCode', isEqualTo: code.trim().toUpperCase())
          .where('ownerId', isEqualTo: ownerId)
          .limit(1);
    }

    final snap = await q.get();
    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    return BookingModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
  }
}
