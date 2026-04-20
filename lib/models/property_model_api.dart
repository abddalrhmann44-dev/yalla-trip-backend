// ═══════════════════════════════════════════════════════════════
//  TALAA — Property API Model
//  Maps to backend PropertyOut schema (FastAPI / PostgreSQL)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// A single owner-configurable service (parking, entry fee, etc.)
class PropertyServiceItem {
  final String name;
  final bool isFree;
  final double price;

  const PropertyServiceItem({
    required this.name,
    this.isFree = true,
    this.price = 0.0,
  });

  factory PropertyServiceItem.fromJson(Map<String, dynamic> j) {
    return PropertyServiceItem(
      name: j['name'] ?? '',
      isFree: j['is_free'] ?? true,
      price: (j['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'is_free': isFree,
        'price': price,
      };

  String get displayPrice => isFree ? 'مجاني' : '${price.toStringAsFixed(0)} ج.م';
}

/// Brief owner info embedded in property responses.
class OwnerBrief {
  final int id;
  final String name;
  final String? avatarUrl;
  final bool isVerified;

  const OwnerBrief({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isVerified = false,
  });

  factory OwnerBrief.fromJson(Map<String, dynamic> j) {
    return OwnerBrief(
      id: j['id'] ?? 0,
      name: j['name'] ?? '',
      avatarUrl: j['avatar_url'],
      isVerified: j['is_verified'] ?? false,
    );
  }
}

/// Full property model matching the backend [PropertyOut] schema.
class PropertyApi {
  final int id;
  final int ownerId;
  final OwnerBrief? owner;
  final String name;
  final String description;
  final String area;
  final String category;
  final double pricePerNight;
  final double? weekendPrice;
  final double cleaningFee;
  final double electricityFee;
  final double waterFee;
  final double securityDeposit;
  final int totalRooms;
  final String? closingTime;
  final int? tripDurationHours;
  final int bedrooms;
  final int bathrooms;
  final int maxGuests;
  final List<String> images;
  final List<String> amenities;
  final List<PropertyServiceItem> services;
  final double rating;
  final int reviewCount;
  final bool isAvailable;
  final bool isFeatured;
  final bool instantBooking;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PropertyApi({
    required this.id,
    required this.ownerId,
    this.owner,
    required this.name,
    this.description = '',
    required this.area,
    required this.category,
    required this.pricePerNight,
    this.weekendPrice,
    this.cleaningFee = 0,
    this.electricityFee = 0,
    this.waterFee = 0,
    this.securityDeposit = 0,
    this.totalRooms = 1,
    this.closingTime,
    this.tripDurationHours,
    this.bedrooms = 1,
    this.bathrooms = 1,
    this.maxGuests = 4,
    this.images = const [],
    this.amenities = const [],
    this.services = const [],
    this.rating = 0,
    this.reviewCount = 0,
    this.isAvailable = true,
    this.isFeatured = false,
    this.instantBooking = false,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PropertyApi.fromJson(Map<String, dynamic> j) {
    return PropertyApi(
      id: j['id'] ?? 0,
      ownerId: j['owner_id'] ?? 0,
      owner: j['owner'] != null ? OwnerBrief.fromJson(j['owner']) : null,
      name: j['name'] ?? '',
      description: j['description'] ?? '',
      area: j['area'] ?? '',
      category: j['category'] ?? '',
      pricePerNight: (j['price_per_night'] ?? 0).toDouble(),
      weekendPrice: j['weekend_price']?.toDouble(),
      cleaningFee: (j['cleaning_fee'] ?? 0).toDouble(),
      electricityFee: (j['electricity_fee'] ?? 0).toDouble(),
      waterFee: (j['water_fee'] ?? 0).toDouble(),
      securityDeposit: (j['security_deposit'] ?? 0).toDouble(),
      totalRooms: j['total_rooms'] ?? 1,
      closingTime: j['closing_time'],
      tripDurationHours: j['trip_duration_hours'],
      bedrooms: j['bedrooms'] ?? 1,
      bathrooms: j['bathrooms'] ?? 1,
      maxGuests: j['max_guests'] ?? 4,
      images: List<String>.from(j['images'] ?? []),
      amenities: List<String>.from(j['amenities'] ?? []),
      services: (j['services'] as List<dynamic>?)
              ?.map((s) => PropertyServiceItem.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      rating: (j['rating'] ?? 0).toDouble(),
      reviewCount: j['review_count'] ?? 0,
      isAvailable: j['is_available'] ?? true,
      isFeatured: j['is_featured'] ?? false,
      instantBooking: j['instant_booking'] ?? false,
      latitude: j['latitude']?.toDouble(),
      longitude: j['longitude']?.toDouble(),
      createdAt: DateTime.parse(j['created_at']),
      updatedAt: DateTime.parse(j['updated_at']),
    );
  }

  // ── Helpers ────────────────────────────────────────────────
  String get firstImage => images.isNotEmpty ? images.first : '';
  int get guests => maxGuests;

  /// true when this is a beach / aqua park with unlimited capacity
  bool get isUnlimited => totalRooms == 0;

  /// true when this is a multi-room property (hotel / resort)
  bool get isMultiRoom => totalRooms > 1;

  /// true when this listing is a boat / yacht (billed per hour)
  bool get isBoat => category == 'مركب';

  /// true when category has utility fees (chalet only)
  bool get hasUtilityFees => category == 'شاليه';

  /// true when category has cleaning fee
  bool get hasCleaningFee =>
      category == 'شاليه' || category == 'فيلا' || category == 'بيت شاطئ';

  /// Paid services only
  List<PropertyServiceItem> get paidServices =>
      services.where((s) => !s.isFree).toList();

  /// Free services only
  List<PropertyServiceItem> get freeServices =>
      services.where((s) => s.isFree).toList();

  String get formattedPrice =>
      '${pricePerNight.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ج.م';

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
      case 'مركب':
        return '⛵';
      default:
        return '🏠';
    }
  }
}
