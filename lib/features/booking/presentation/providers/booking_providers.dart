// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Riverpod Providers for Booking System
// ═══════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/booking_service.dart';
import '../../data/services/promo_code_service.dart';
import '../../data/services/payment_service.dart';
import '../../data/services/owner_verification_service.dart';
import '../../data/services/admin_configuration_service.dart';
import '../../data/models/booking_model.dart';

// ── Service Providers ───────────────────────────────────────
final bookingServiceProvider = Provider<BookingService>(
  (_) => BookingService(),
);

final promoCodeServiceProvider = Provider<PromoCodeService>(
  (_) => PromoCodeService(),
);

final paymentServiceProvider = Provider<PaymentService>(
  (_) => PaymentService(),
);

final ownerVerificationServiceProvider = Provider<OwnerVerificationService>(
  (_) => OwnerVerificationService(),
);

final adminConfigServiceProvider = Provider<AdminConfigurationService>(
  (_) => AdminConfigurationService(),
);

// ── Current User ────────────────────────────────────────────
final currentUserProvider = Provider<User?>(
  (_) => FirebaseAuth.instance.currentUser,
);

// ── App Fee Stream ──────────────────────────────────────────
final appFeeStreamProvider = StreamProvider<double>((ref) {
  return ref.read(adminConfigServiceProvider).appFeeStream();
});

// ── User Bookings Stream ────────────────────────────────────
final userBookingsStreamProvider = StreamProvider<List<BookingModel>>((ref) {
  final user = ref.read(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(bookingServiceProvider).userBookingsStream(user.uid);
});

// ── Owner Bookings Stream ───────────────────────────────────
final ownerBookingsStreamProvider = StreamProvider<List<BookingModel>>((ref) {
  final user = ref.read(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(bookingServiceProvider).ownerBookingsStream(user.uid);
});

// ── All Bookings Stream (Admin) ─────────────────────────────
final allBookingsStreamProvider = StreamProvider<List<BookingModel>>((ref) {
  return ref.read(bookingServiceProvider).allBookingsStream();
});

// ── Admin Check ─────────────────────────────────────────────
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null || user.email == null) return false;
  return ref.read(adminConfigServiceProvider).isAdmin(user.email!);
});

// ── Promo Codes Stream (Admin) ──────────────────────────────
final promoCodesStreamProvider = StreamProvider((ref) {
  return ref.read(promoCodeServiceProvider).allPromosStream();
});
