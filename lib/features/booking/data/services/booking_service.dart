// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Booking Service
//  Core booking logic: create, generate code, calculate pricing
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../models/app_config_model.dart';

class BookingService {
  final FirebaseFirestore _db;
  BookingService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _codeLength = 8;

  // ══════════════════════════════════════════════════════════
  //  GENERATE UNIQUE BOOKING CODE
  // ══════════════════════════════════════════════════════════
  /// Generates an 8-char alphanumeric code and retries on collision.
  Future<String> generateBookingCode() async {
    final rng = Random.secure();
    for (int attempt = 0; attempt < 10; attempt++) {
      final code = List.generate(
        _codeLength,
        (_) => _codeChars[rng.nextInt(_codeChars.length)],
      ).join();

      // Check uniqueness
      final snap = await _db
          .collection('bookings')
          .where('bookingCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return code;
    }
    // Fallback: timestamp-based code
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().padLeft(8, 'X').substring(0, 8);
  }

  // ══════════════════════════════════════════════════════════
  //  CALCULATE PRICING
  // ══════════════════════════════════════════════════════════
  /// Pure calculation with no side effects — easily testable.
  PricingResult calculatePricing({
    required double pricePerPerson,
    required int numberOfPeople,
    required double appFeePercent,
    double promoDiscountPercent = 0,
  }) {
    final basePrice = pricePerPerson * numberOfPeople;
    final discount = basePrice * (promoDiscountPercent / 100);
    final subtotal = basePrice - discount;
    final appFee = subtotal * (appFeePercent / 100);
    final ownerEarnings = subtotal - appFee;

    return PricingResult(
      basePrice: basePrice,
      discount: discount,
      subtotal: subtotal,
      appFee: appFee,
      ownerEarnings: ownerEarnings,
      appFeePercent: appFeePercent,
      promoPercent: promoDiscountPercent,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CREATE BOOKING
  // ══════════════════════════════════════════════════════════
  /// Creates a confirmed booking and returns the BookingModel.
  Future<BookingModel> createBooking({
    required String userId,
    required String userName,
    required String ownerId,
    required String placeId,
    required String placeName,
    required String bookingType,
    required int numberOfPeople,
    required double pricePerPerson,
    required double appFeePercent,
    required String paymentMethod,
    required DateTime bookingDate,
    double promoDiscountPercent = 0,
    String promoCode = '',
  }) async {
    // 1. Calculate pricing
    final pricing = calculatePricing(
      pricePerPerson: pricePerPerson,
      numberOfPeople: numberOfPeople,
      appFeePercent: appFeePercent,
      promoDiscountPercent: promoDiscountPercent,
    );

    // 2. Generate unique code
    final bookingCode = await generateBookingCode();

    // 3. Create document reference
    final docRef = _db.collection('bookings').doc();

    final booking = BookingModel(
      bookingId: docRef.id,
      bookingCode: bookingCode,
      userId: userId,
      userName: userName,
      ownerId: ownerId,
      placeId: placeId,
      placeName: placeName,
      bookingType: bookingType,
      numberOfPeople: numberOfPeople,
      basePrice: pricing.basePrice,
      discountApplied: pricing.discount,
      promoCodeUsed: promoCode,
      finalPrice: pricing.subtotal,
      appFeePercent: pricing.appFeePercent,
      appFeeAmount: pricing.appFee,
      ownerEarnings: pricing.ownerEarnings,
      paymentMethod: paymentMethod,
      bookingDate: bookingDate,
      createdAt: DateTime.now(),
      status: 'confirmed',
    );

    // 4. Save to Firestore
    await docRef.set(booking.toFirestore());

    // 5. If promo was used, increment usage count
    if (promoCode.isNotEmpty) {
      final promoSnap = await _db
          .collection('promoCodes')
          .where('code', isEqualTo: promoCode.toUpperCase())
          .limit(1)
          .get();
      if (promoSnap.docs.isNotEmpty) {
        await promoSnap.docs.first.reference.update({
          'usageCount': FieldValue.increment(1),
        });
      }
    }

    return booking;
  }

  // ══════════════════════════════════════════════════════════
  //  STREAMS
  // ══════════════════════════════════════════════════════════

  /// Real-time stream of bookings for the current user
  Stream<List<BookingModel>> userBookingsStream(String userId) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Real-time stream of bookings for a property owner
  Stream<List<BookingModel>> ownerBookingsStream(String ownerId) {
    return _db
        .collection('bookings')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// All bookings stream (admin)
  Stream<List<BookingModel>> allBookingsStream() {
    return _db
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Paginated fetch for owner dashboard
  Future<List<BookingModel>> fetchOwnerBookings(
    String ownerId, {
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query q = _db
        .collection('bookings')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDoc != null) q = q.startAfterDocument(lastDoc);

    final snap = await q.get();
    return snap.docs
        .map((d) => BookingModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }
}
