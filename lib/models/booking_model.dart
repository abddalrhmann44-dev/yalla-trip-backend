// ═══════════════════════════════════════════════════════════════
//  TALAA — Booking API Model
//  Maps to backend BookingOut schema (FastAPI / PostgreSQL)
// ═══════════════════════════════════════════════════════════════

/// Brief property info embedded in booking responses.
class BookingPropertyBrief {
  final int id;
  final String name;
  final String area;
  final String category;
  final double pricePerNight;
  final List<String> images;
  final double rating;

  const BookingPropertyBrief({
    required this.id,
    required this.name,
    required this.area,
    required this.category,
    required this.pricePerNight,
    this.images = const [],
    this.rating = 0,
  });

  factory BookingPropertyBrief.fromJson(Map<String, dynamic> j) {
    return BookingPropertyBrief(
      id: j['id'] ?? 0,
      name: j['name'] ?? '',
      area: j['area'] ?? '',
      category: j['category'] ?? '',
      pricePerNight: (j['price_per_night'] ?? 0).toDouble(),
      images: List<String>.from(j['images'] ?? []),
      rating: (j['rating'] ?? 0).toDouble(),
    );
  }

  String get firstImage => images.isNotEmpty ? images.first : '';
}

/// Brief user info embedded in booking responses.
class BookingUserBrief {
  final int id;
  final String name;
  final String? avatarUrl;

  const BookingUserBrief({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory BookingUserBrief.fromJson(Map<String, dynamic> j) {
    return BookingUserBrief(
      id: j['id'] ?? 0,
      name: j['name'] ?? '',
      avatarUrl: j['avatar_url'],
    );
  }
}

/// Full booking model matching the backend [BookingOut] schema.
class BookingModel {
  final int id;
  final String bookingCode;
  final int propertyId;
  final BookingPropertyBrief? property;
  final int guestId;
  final BookingUserBrief? guest;
  final int ownerId;
  final BookingUserBrief? owner;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guestsCount;
  final double electricityFee;
  final double waterFee;
  final double securityDeposit;
  final String depositStatus;
  final double totalPrice;
  final double platformFee;
  final double ownerPayout;
  final String status;
  final String paymentStatus;
  final String? fawryRef;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookingModel({
    required this.id,
    required this.bookingCode,
    required this.propertyId,
    this.property,
    required this.guestId,
    this.guest,
    required this.ownerId,
    this.owner,
    required this.checkIn,
    required this.checkOut,
    this.guestsCount = 1,
    this.electricityFee = 0,
    this.waterFee = 0,
    this.securityDeposit = 0,
    this.depositStatus = 'held',
    required this.totalPrice,
    required this.platformFee,
    required this.ownerPayout,
    this.status = 'pending',
    this.paymentStatus = 'pending',
    this.fawryRef,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> j) {
    return BookingModel(
      id: j['id'] ?? 0,
      bookingCode: j['booking_code'] ?? '',
      propertyId: j['property_id'] ?? 0,
      property: j['property'] != null
          ? BookingPropertyBrief.fromJson(j['property'])
          : null,
      guestId: j['guest_id'] ?? 0,
      guest: j['guest'] != null
          ? BookingUserBrief.fromJson(j['guest'])
          : null,
      ownerId: j['owner_id'] ?? 0,
      owner: j['owner'] != null
          ? BookingUserBrief.fromJson(j['owner'])
          : null,
      checkIn: DateTime.parse(j['check_in']),
      checkOut: DateTime.parse(j['check_out']),
      guestsCount: j['guests_count'] ?? 1,
      electricityFee: (j['electricity_fee'] ?? 0).toDouble(),
      waterFee: (j['water_fee'] ?? 0).toDouble(),
      securityDeposit: (j['security_deposit'] ?? 0).toDouble(),
      depositStatus: j['deposit_status'] ?? 'held',
      totalPrice: (j['total_price'] ?? 0).toDouble(),
      platformFee: (j['platform_fee'] ?? 0).toDouble(),
      ownerPayout: (j['owner_payout'] ?? 0).toDouble(),
      status: j['status'] ?? 'pending',
      paymentStatus: j['payment_status'] ?? 'pending',
      fawryRef: j['fawry_ref'],
      createdAt: DateTime.parse(j['created_at']),
      updatedAt: DateTime.parse(j['updated_at']),
    );
  }

  // ── Helpers ────────────────────────────────────────────────
  int get nights => checkOut.difference(checkIn).inDays;

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  bool get isPaid => paymentStatus == 'paid';

  bool get hasDeposit => securityDeposit > 0;
  bool get isDepositRefunded => depositStatus == 'refunded';
  bool get isDepositDeducted => depositStatus == 'deducted';

  String get statusAr {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'confirmed':
        return 'مؤكد';
      case 'cancelled':
        return 'ملغي';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }

  String get paymentStatusAr {
    switch (paymentStatus) {
      case 'pending':
        return 'في انتظار الدفع';
      case 'paid':
        return 'مدفوع';
      case 'refunded':
        return 'مسترد';
      default:
        return paymentStatus;
    }
  }

  String get formattedTotal =>
      '${totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ج.م';

  String get propertyName => property?.name ?? '';
  String get propertyImage => property?.firstImage ?? '';
  String get propertyArea => property?.area ?? '';
}
