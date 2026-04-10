// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Property Model
//  Single source of truth for all property data
// ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PropertyModel {
  final String id;
  final String name;
  final String area;
  final String location;
  final String address;
  final String description;
  final String category;
  final String ownerId;
  final String ownerName;
  final int price;
  final int weekendPrice;
  final int cleaningFee;
  final double rating;
  final int reviewCount;
  final int bedrooms;
  final int beds;
  final int bathrooms;
  final int maxGuests;
  final List<String> images;
  final List<String> amenities;
  final List<String> facilities;
  final List<String> nearby;
  final bool instant;
  final bool online;
  final bool featured;
  final bool available;
  final bool autoConfirm;
  final bool requireId;
  final int minNights;
  final int maxNights;
  final int totalRooms;
  final int availableRooms;
  final List<String> blockedDates;
  final String bookingMode;
  final String currency;
  final String checkinTime;
  final String checkoutTime;
  final DateTime createdAt;
  final bool approved;
  final String status; // pending | approved | rejected | needs_edit
  final String ownerEmail;

  // ── Time-limited offer fields ──────────────────────────────
  final bool     isOfferActive;
  final DateTime? offerStart;
  final DateTime? offerEnd;
  final double?   offerPrice;

  const PropertyModel({
    required this.id,
    required this.name,
    required this.area,
    required this.location,
    required this.address,
    required this.description,
    required this.category,
    required this.ownerId,
    required this.ownerName,
    required this.price,
    required this.weekendPrice,
    required this.cleaningFee,
    required this.rating,
    required this.reviewCount,
    required this.bedrooms,
    required this.beds,
    required this.bathrooms,
    required this.maxGuests,
    required this.images,
    required this.amenities,
    required this.facilities,
    required this.nearby,
    required this.instant,
    required this.online,
    required this.featured,
    required this.available,
    required this.autoConfirm,
    required this.requireId,
    required this.minNights,
    required this.maxNights,
    this.totalRooms = 0,
    this.availableRooms = 0,
    this.blockedDates = const [],
    required this.bookingMode,
    required this.currency,
    this.checkinTime = '14:00',
    this.checkoutTime = '12:00',
    required this.createdAt,
    this.approved = false,
    this.status = 'pending',
    this.ownerEmail = '',
    this.isOfferActive = false,
    this.offerStart,
    this.offerEnd,
    this.offerPrice,
  });

  // ── From Firestore ─────────────────────────────────────────
  factory PropertyModel.fromFirestore(String docId, Map<String, dynamic> d) {
    return PropertyModel(
      id: docId,
      name: d['name'] ?? '',
      area: d['area'] ?? '',
      location: d['location'] ?? '',
      address: d['address'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? '',
      ownerId: d['ownerId'] ?? '',
      ownerName: d['ownerName'] ?? '',
      price: (d['price'] ?? 0).toInt(),
      weekendPrice: (d['weekendPrice'] ?? 0).toInt(),
      cleaningFee: (d['cleaningFee'] ?? 0).toInt(),
      rating: (d['rating'] ?? 0.0).toDouble(),
      reviewCount: (d['reviewCount'] ?? 0).toInt(),
      bedrooms: (d['bedrooms'] ?? 1).toInt(),
      beds: (d['beds'] ?? 1).toInt(),
      bathrooms: (d['bathrooms'] ?? 1).toInt(),
      maxGuests: (d['maxGuests'] ?? 2).toInt(),
      images: List<String>.from(d['images'] ?? []),
      amenities: List<String>.from(d['amenities'] ?? []),
      facilities: List<String>.from(d['facilities'] ?? []),
      nearby: List<String>.from(d['nearby'] ?? []),
      instant: d['instant'] ?? false,
      online: d['online'] ?? true,
      featured: d['featured'] ?? false,
      available: d['available'] ?? true,
      autoConfirm: d['autoConfirm'] ?? true,
      requireId: d['requireId'] ?? false,
      minNights: (d['minNights'] ?? 1).toInt(),
      maxNights: (d['maxNights'] ?? 30).toInt(),
      totalRooms: (d['totalRooms'] ?? 0).toInt(),
      availableRooms: (d['availableRooms'] ?? 0).toInt(),
      blockedDates: List<String>.from(d['blockedDates'] ?? const []),
      bookingMode: d['bookingMode'] ?? 'instant',
      currency: d['currency'] ?? 'EGP',
      checkinTime: d['checkinTime'] ?? '14:00',
      checkoutTime: d['checkoutTime'] ?? '12:00',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approved: d['approved'] ?? false,
      status: d['status'] ?? 'pending',
      ownerEmail: d['ownerEmail'] ?? '',
      isOfferActive: d['isOfferActive'] ?? false,
      offerStart: (d['offerStart'] as Timestamp?)?.toDate(),
      offerEnd:   (d['offerEnd']   as Timestamp?)?.toDate(),
      offerPrice: (d['offerPrice'] as num?)?.toDouble(),
    );
  }

  // ── To Firestore Map ───────────────────────────────────────
  Map<String, dynamic> toFirestore() => {
        'name': name,
        'area': area,
        'location': location,
        'address': address,
        'description': description,
        'category': category,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'price': price,
        'weekendPrice': weekendPrice,
        'cleaningFee': cleaningFee,
        'rating': rating,
        'reviewCount': reviewCount,
        'bedrooms': bedrooms,
        'beds': beds,
        'bathrooms': bathrooms,
        'maxGuests': maxGuests,
        'images': images,
        'amenities': amenities,
        'facilities': facilities,
        'nearby': nearby,
        'instant': instant,
        'online': online,
        'featured': featured,
        'available': available,
        'autoConfirm': autoConfirm,
        'requireId': requireId,
        'minNights': minNights,
        'maxNights': maxNights,
        'totalRooms': totalRooms,
        'availableRooms': availableRooms,
        'blockedDates': blockedDates,
        'bookingMode': bookingMode,
        'currency': currency,
        'checkinTime': checkinTime,
        'checkoutTime': checkoutTime,
        'createdAt': FieldValue.serverTimestamp(),
        'approved': approved,
        'status': status,
        'ownerEmail': ownerEmail,
        'isOfferActive': isOfferActive,
        if (offerStart != null) 'offerStart': Timestamp.fromDate(offerStart!),
        if (offerEnd   != null) 'offerEnd':   Timestamp.fromDate(offerEnd!),
        if (offerPrice != null) 'offerPrice': offerPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  // ── Helpers ────────────────────────────────────────────────
  String get firstImage => images.isNotEmpty ? images.first : '';

  /// Alias for maxGuests — used across pages
  int get guests => maxGuests;

  Color get areaColor {
    switch (area) {
      case 'عين السخنة':
        return const Color(0xFF0288D1);
      case 'الساحل الشمالي':
        return const Color(0xFF1976D2);
      case 'الجونة':
        return const Color(0xFFE65100);
      case 'الغردقة':
        return const Color(0xFF00695C);
      case 'شرم الشيخ':
        return const Color(0xFF6A1B9A);
      case 'رأس سدر':
        return const Color(0xFF00897B);
      default:
        return const Color(0xFF1565C0);
    }
  }

  String get categoryEmoji {
    switch (category) {
      case 'شاليه':
        return '🏡';
      case 'فيلا':
        return '🏖️';
      case 'فندق':
        return '🏨';
      case 'منتجع':
        return '🌺';
      case 'أكوا بارك':
        return '🌊';
      case 'بيت شاطئ':
        return '🏄';
      default:
        return '🏠';
    }
  }

  String get formattedPrice =>
      '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} $currency';

  // ── Offer helpers ───────────────────────────────────────────

  /// True when the listing has a valid, currently-running offer.
  bool get hasActiveOffer {
    if (!isOfferActive || offerStart == null || offerEnd == null) return false;
    final now = DateTime.now();
    return offerStart!.isBefore(now) && offerEnd!.isAfter(now);
  }

  /// Effective price: offer price when active, otherwise regular price.
  int get displayPrice =>
      hasActiveOffer && offerPrice != null ? offerPrice!.toInt() : price;

  /// Whole-number discount percentage (0 when no active offer).
  int get discountPercent {
    if (!hasActiveOffer || offerPrice == null || price == 0) return 0;
    return (((price - offerPrice!) / price) * 100).round();
  }
}
