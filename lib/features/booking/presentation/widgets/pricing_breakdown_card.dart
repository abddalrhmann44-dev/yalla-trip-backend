// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Pricing Breakdown Card Widget
//  Reusable financial summary for booking + summary pages
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../../widgets/constants.dart';

const _kOcean = Color(0xFF1565C0);
const _kGreen = Color(0xFF4CAF50);
const _kRed   = Color(0xFFEF5350);

class PricingBreakdownCard extends StatelessWidget {
  final double basePrice;
  final double discount;
  final double subtotal;
  final double appFee;
  final double ownerEarnings;
  final double appFeePercent;
  final String promoCode;
  final bool showOwnerEarnings;

  const PricingBreakdownCard({
    super.key,
    required this.basePrice,
    required this.discount,
    required this.subtotal,
    required this.appFee,
    required this.ownerEarnings,
    required this.appFeePercent,
    this.promoCode = '',
    this.showOwnerEarnings = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تفاصيل السعر',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        const SizedBox(height: 14),
        _row(context, 'السعر الأساسي', basePrice),
        if (discount > 0) ...[
          const SizedBox(height: 8),
          _row(context, 'خصم${promoCode.isNotEmpty ? " ($promoCode)" : ""}',
              -discount, color: _kGreen),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        _row(context, 'الإجمالي', subtotal, bold: true),
        if (showOwnerEarnings) ...[
          const SizedBox(height: 8),
          _row(context, 'رسوم المنصة (${appFeePercent.toStringAsFixed(0)}%)',
              appFee, color: _kRed, fontSize: 12),
          const SizedBox(height: 4),
          _row(context, 'أرباحك', ownerEarnings,
              color: _kGreen, bold: true),
        ],
      ]),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double amount, {
    Color? color,
    bool bold = false,
    double fontSize = 14,
  }) {
    return Row(children: [
      Text(label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: color ?? context.kSub,
          )),
      const Spacer(),
      Text(
        '${amount < 0 ? "-" : ""}${amount.abs().toStringAsFixed(0)} جنيه',
        style: TextStyle(
          fontSize: bold ? 16 : fontSize,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          color: color ?? (bold ? _kOcean : context.kText),
        ),
      ),
    ]);
  }
}
