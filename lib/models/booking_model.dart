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
  // Wave 25 — hybrid deposit + cash-on-arrival.  For legacy 100 %
  // online bookings ``depositAmount == totalPrice`` and
  // ``remainingCashAmount == 0``, so the legacy UI keeps working.
  final double depositAmount;
  final double remainingCashAmount;
  /// Backend cash-collection state machine.  One of:
  /// `not_applicable`, `pending`, `owner_confirmed`, `guest_confirmed`,
  /// `confirmed`, `disputed`, `no_show`.
  final String cashCollectionStatus;
  final DateTime? ownerCashConfirmedAt;
  final DateTime? guestArrivalConfirmedAt;
  final DateTime? noShowReportedAt;
  final double promoDiscount;
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
    this.depositAmount = 0,
    this.remainingCashAmount = 0,
    this.cashCollectionStatus = 'not_applicable',
    this.ownerCashConfirmedAt,
    this.guestArrivalConfirmedAt,
    this.noShowReportedAt,
    this.promoDiscount = 0,
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
      depositAmount: (j['deposit_amount'] ?? 0).toDouble(),
      remainingCashAmount: (j['remaining_cash_amount'] ?? 0).toDouble(),
      cashCollectionStatus: j['cash_collection_status'] ?? 'not_applicable',
      ownerCashConfirmedAt: j['owner_cash_confirmed_at'] != null
          ? DateTime.parse(j['owner_cash_confirmed_at'])
          : null,
      guestArrivalConfirmedAt: j['guest_arrival_confirmed_at'] != null
          ? DateTime.parse(j['guest_arrival_confirmed_at'])
          : null,
      noShowReportedAt: j['no_show_reported_at'] != null
          ? DateTime.parse(j['no_show_reported_at'])
          : null,
      promoDiscount: (j['promo_discount'] ?? 0).toDouble(),
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

  // ── Wave 25 — cash-on-arrival helpers ────────────────────

  /// True when this booking uses the hybrid deposit + cash flow.
  /// Use this everywhere instead of comparing strings, so a future
  /// rename of the backend enum doesn't ripple through the UI.
  bool get isCashOnArrival => cashCollectionStatus != 'not_applicable';

  bool get cashOwnerConfirmed => ownerCashConfirmedAt != null;
  bool get cashGuestConfirmed => guestArrivalConfirmedAt != null;
  bool get cashFullyConfirmed => cashCollectionStatus == 'confirmed';
  bool get cashDisputed => cashCollectionStatus == 'disputed';
  bool get noShowReported => cashCollectionStatus == 'no_show';

  /// Human-readable Arabic label for the cash collection state —
  /// suitable for badge widgets in the booking details page.
  String get cashStatusAr {
    switch (cashCollectionStatus) {
      case 'pending':
        return 'فى انتظار التأكيد';
      case 'owner_confirmed':
        return 'المضيف أكد — فى انتظار الضيف';
      case 'guest_confirmed':
        return 'الضيف أكد — فى انتظار المضيف';
      case 'confirmed':
        return 'تم تأكيد الاستلام';
      case 'disputed':
        return 'فى المراجعة';
      case 'no_show':
        return 'لم يحضر الضيف';
      default:
        return '';
    }
  }
}
