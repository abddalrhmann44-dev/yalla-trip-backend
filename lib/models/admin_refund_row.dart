// ═══════════════════════════════════════════════════════════════
//  TALAA — AdminRefundRow
//  DTO mirroring backend ``_AdminRefundRow`` in admin.py.  One row
//  per booking that owes the guest money back: cancelled paid
//  bookings (``state=pending``) or already-refunded bookings.
// ═══════════════════════════════════════════════════════════════

class AdminRefundRow {
  final int bookingId;
  final String bookingStatus;
  final String paymentStatus;
  final double totalPrice;
  final double? refundAmount;
  final DateTime? cancelledAt;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int guestId;
  final String? guestName;
  final String? guestPhone;
  final int propertyId;
  final String? propertyName;
  final String? propertyImage;
  final String? paymentProvider;
  final String? paymentProviderRef;
  final String? paymentState;

  const AdminRefundRow({
    required this.bookingId,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.totalPrice,
    required this.guestId,
    required this.propertyId,
    this.refundAmount,
    this.cancelledAt,
    this.checkIn,
    this.checkOut,
    this.guestName,
    this.guestPhone,
    this.propertyName,
    this.propertyImage,
    this.paymentProvider,
    this.paymentProviderRef,
    this.paymentState,
  });

  factory AdminRefundRow.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse(v as String);
    }

    return AdminRefundRow(
      bookingId: (j['booking_id'] as num).toInt(),
      bookingStatus: j['booking_status'] as String? ?? 'unknown',
      paymentStatus: j['payment_status'] as String? ?? 'unknown',
      totalPrice: (j['total_price'] as num?)?.toDouble() ?? 0.0,
      refundAmount: (j['refund_amount'] as num?)?.toDouble(),
      cancelledAt: parseDate(j['cancelled_at']),
      checkIn: parseDate(j['check_in']),
      checkOut: parseDate(j['check_out']),
      guestId: (j['guest_id'] as num).toInt(),
      guestName: j['guest_name'] as String?,
      guestPhone: j['guest_phone'] as String?,
      propertyId: (j['property_id'] as num).toInt(),
      propertyName: j['property_name'] as String?,
      propertyImage: j['property_image'] as String?,
      paymentProvider: j['payment_provider'] as String?,
      paymentProviderRef: j['payment_provider_ref'] as String?,
      paymentState: j['payment_state'] as String?,
    );
  }

  bool get isProcessed =>
      paymentStatus == 'refunded' || paymentStatus == 'partially_refunded';
}
