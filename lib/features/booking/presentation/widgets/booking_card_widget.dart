// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Booking Card Widget
//  Compact booking display for lists and dashboards
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/constants.dart';
import '../../data/models/booking_model.dart';

const _kOcean  = Color(0xFF1565C0);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);
const _kOrange = Color(0xFFFF6D00);

class BookingCardWidget extends StatelessWidget {
  final BookingModel booking;
  final bool showOwnerEarnings;
  final VoidCallback? onTap;

  const BookingCardWidget({
    super.key,
    required this.booking,
    this.showOwnerEarnings = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(booking.bookingDate);
    final statusColor = _statusColor(booking.status);
    final statusLabel = _statusLabel(booking.status);
    final typeEmoji = _typeEmoji(booking.bookingType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header: place + status
          Row(children: [
            Text(typeEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(booking.placeName,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.kText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(dateStr,
                    style: TextStyle(fontSize: 12, color: context.kSub)),
              ]),
            ),
            _statusBadge(statusLabel, statusColor),
          ]),
          const SizedBox(height: 12),

          // Info row
          Row(children: [
            _infoChip(context, '👥', '${booking.numberOfPeople}'),
            const SizedBox(width: 8),
            _infoChip(context, '🎫', booking.bookingCode),
            const Spacer(),
            Text(
              '${booking.finalPrice.toStringAsFixed(0)} جنيه',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: _kOcean),
            ),
          ]),

          // Owner earnings row
          if (showOwnerEarnings) ...[
            const SizedBox(height: 8),
            Row(children: [
              Text('أرباحك:',
                  style: TextStyle(fontSize: 12, color: context.kSub)),
              const SizedBox(width: 6),
              Text('${booking.ownerEarnings.toStringAsFixed(0)} جنيه',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kGreen)),
              const Spacer(),
              if (booking.promoCodeUsed.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('🏷️ ${booking.promoCodeUsed}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kOrange)),
                ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _infoChip(BuildContext context, String emoji, String text) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.kSand,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.kText)),
        ]),
      );

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return _kGreen;
      case 'cancelled':
        return _kRed;
      case 'completed':
        return _kOcean;
      default:
        return _kOrange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
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

  String _typeEmoji(String type) {
    switch (type) {
      case 'beach':
        return '🏖️';
      case 'aqua_park':
        return '🌊';
      case 'chalet':
        return '🏡';
      default:
        return '🎯';
    }
  }
}
