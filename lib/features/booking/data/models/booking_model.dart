// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Booking Model
//  Full financial breakdown for every booking
// ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String bookingId;
  final String bookingCode;
  final String userId;
  final String userName;
  final String ownerId;
  final String placeId;
  final String placeName;
  final String bookingType; // beach | aqua_park | chalet
  final int numberOfPeople;
  final double basePrice;
  final double discountApplied;
  final String promoCodeUsed;
  final double finalPrice;
  final double appFeePercent;
  final double appFeeAmount;
  final double ownerEarnings;
  final String paymentMethod;
  final DateTime bookingDate;
  final DateTime createdAt;
  final String status; // confirmed | cancelled | completed

  const BookingModel({
    required this.bookingId,
    required this.bookingCode,
    required this.userId,
    required this.userName,
    required this.ownerId,
    required this.placeId,
    required this.placeName,
    required this.bookingType,
    required this.numberOfPeople,
    required this.basePrice,
    required this.discountApplied,
    required this.promoCodeUsed,
    required this.finalPrice,
    required this.appFeePercent,
    required this.appFeeAmount,
    required this.ownerEarnings,
    required this.paymentMethod,
    required this.bookingDate,
    required this.createdAt,
    this.status = 'confirmed',
  });

  // ── From Firestore ─────────────────────────────────────────
  factory BookingModel.fromFirestore(String docId, Map<String, dynamic> d) {
    return BookingModel(
      bookingId: docId,
      bookingCode: d['bookingCode'] ?? '',
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      ownerId: d['ownerId'] ?? '',
      placeId: d['placeId'] ?? '',
      placeName: d['placeName'] ?? '',
      bookingType: d['bookingType'] ?? '',
      numberOfPeople: (d['numberOfPeople'] ?? 1).toInt(),
      basePrice: (d['basePrice'] ?? 0).toDouble(),
      discountApplied: (d['discountApplied'] ?? 0).toDouble(),
      promoCodeUsed: d['promoCodeUsed'] ?? '',
      finalPrice: (d['finalPrice'] ?? 0).toDouble(),
      appFeePercent: (d['appFeePercent'] ?? 0).toDouble(),
      appFeeAmount: (d['appFeeAmount'] ?? 0).toDouble(),
      ownerEarnings: (d['ownerEarnings'] ?? 0).toDouble(),
      paymentMethod: d['paymentMethod'] ?? '',
      bookingDate: (d['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] ?? 'confirmed',
    );
  }

  // ── To Firestore ───────────────────────────────────────────
  Map<String, dynamic> toFirestore() => {
        'bookingCode': bookingCode,
        'userId': userId,
        'userName': userName,
        'ownerId': ownerId,
        'placeId': placeId,
        'placeName': placeName,
        'bookingType': bookingType,
        'numberOfPeople': numberOfPeople,
        'basePrice': basePrice,
        'discountApplied': discountApplied,
        'promoCodeUsed': promoCodeUsed,
        'finalPrice': finalPrice,
        'appFeePercent': appFeePercent,
        'appFeeAmount': appFeeAmount,
        'ownerEarnings': ownerEarnings,
        'paymentMethod': paymentMethod,
        'bookingDate': Timestamp.fromDate(bookingDate),
        'createdAt': FieldValue.serverTimestamp(),
        'status': status,
      };

  BookingModel copyWith({String? status}) => BookingModel(
        bookingId: bookingId,
        bookingCode: bookingCode,
        userId: userId,
        userName: userName,
        ownerId: ownerId,
        placeId: placeId,
        placeName: placeName,
        bookingType: bookingType,
        numberOfPeople: numberOfPeople,
        basePrice: basePrice,
        discountApplied: discountApplied,
        promoCodeUsed: promoCodeUsed,
        finalPrice: finalPrice,
        appFeePercent: appFeePercent,
        appFeeAmount: appFeeAmount,
        ownerEarnings: ownerEarnings,
        paymentMethod: paymentMethod,
        bookingDate: bookingDate,
        createdAt: createdAt,
        status: status ?? this.status,
      );
}
