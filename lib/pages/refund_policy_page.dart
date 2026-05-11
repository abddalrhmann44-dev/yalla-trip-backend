// ═══════════════════════════════════════════════════════════════
//  TALAA — Refund / Cancellation Policy (standalone)
//
//  Mirrors Section 9 of `terms_page.dart` exactly so there is no
//  divergence between this page and the unified Terms document.
//  Per product decision (May 2026): keep wording identical, only
//  rephrase the headline to make the policy explicit on the App
//  Store / Play Store listing.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../widgets/policy_page_scaffold.dart';

class RefundPolicyPage extends StatelessWidget {
  const RefundPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyPageScaffold(
      titleAr: 'سياسة الإلغاء والاسترداد',
      titleEn: 'Cancellation & Refund Policy',
      subtitleAr: 'الشروط الكاملة للإلغاء واسترداد المبالغ',
      subtitleEn: 'Full cancellation and refund terms',
      icon: Icons.account_balance_wallet_rounded,
      lastUpdatedAr: 'آخر تحديث: مايو 2026',
      lastUpdatedEn: 'Last updated: May 2026',
      sections: _sections,
    );
  }
}

const _sections = <PolicySection>[
  // 1. Guest cancellation (mirrors Terms §9) ─────────────────
  PolicySection(
    numAr: '١', numEn: '1',
    titleAr: 'إلغاء الحجز من قِبَل الضيف',
    titleEn: 'Cancellation by the Guest',
    itemsAr: [
      'إلغاء قبل 14 يوماً أو أكثر من تاريخ الوصول: استرداد 100% من المبلغ المدفوع.',
      'إلغاء قبل 7 إلى 13 يوماً من الوصول: استرداد 50% من المبلغ المدفوع.',
      'إلغاء قبل أقل من 7 أيام من الوصول أو بعد الوصول: لا يوجد استرداد.',
      'يبدأ احتساب المدة من الساعة 12:00 ظهراً بتوقيت القاهرة في تاريخ الإلغاء وحتى 12:00 ظهراً في تاريخ الوصول.',
    ],
    itemsEn: [
      'Cancellation 14+ days before arrival: 100% refund of the amount paid.',
      'Cancellation 7–13 days before arrival: 50% refund of the amount paid.',
      'Cancellation less than 7 days before arrival, or after arrival: no refund.',
      'The countdown is measured from 12:00 noon Cairo time on the cancellation date until 12:00 noon on the arrival date.',
    ],
  ),

  // 2. Owner cancellation ────────────────────────────────────
  PolicySection(
    numAr: '٢', numEn: '2',
    titleAr: 'إلغاء الحجز من قِبَل المالك',
    titleEn: 'Cancellation by the Host',
    itemsAr: [
      'إذا ألغى المالك حجزاً مؤكَّداً، يُعاد للضيف 100% من المبلغ المدفوع تلقائياً.',
      'يحق للضيف الحصول على رصيد محفظة إضافي بقيمة 10% من قيمة الحجز كتعويض عن الإزعاج.',
      'الإلغاء المتكرر من نفس المالك يعرّض حسابه للتعليق أو الإغلاق وفقاً لشروط الاستخدام.',
    ],
    itemsEn: [
      'If the host cancels a confirmed booking, the guest is automatically refunded 100% of the amount paid.',
      'The guest is also entitled to an extra wallet credit equal to 10% of the booking value as compensation.',
      'Repeated cancellations by the same host may result in account suspension or termination per the Terms.',
    ],
  ),

  // 3. Force majeure ─────────────────────────────────────────
  PolicySection(
    numAr: '٣', numEn: '3',
    titleAr: 'القوة القاهرة',
    titleEn: 'Force Majeure',
    itemsAr: [
      'في حالات القوة القاهرة (أوبئة، كوارث طبيعية، قرارات حكومية، انقطاع نقل) يُسمح بالإلغاء بدون غرامة لأي طرف.',
      'تُراجع المنصة كل حالة على حدة وقد تطلب وثائق رسمية لإثبات القوة القاهرة.',
      'يُعاد كامل المبلغ المدفوع بعد خصم رسوم بوابة الدفع غير المستردة فقط.',
    ],
    itemsEn: [
      'In force-majeure events (epidemics, natural disasters, government orders, transport disruptions) cancellation is allowed for either party without penalty.',
      'The Platform reviews each case individually and may request official documentation.',
      'The full amount is refunded except for non-refundable payment-gateway fees.',
    ],
  ),

  // 4. Refund processing ─────────────────────────────────────
  PolicySection(
    numAr: '٤', numEn: '4',
    titleAr: 'مدة معالجة الاسترداد',
    titleEn: 'Refund Processing Time',
    itemsAr: [
      'يبدأ تنفيذ الاسترداد فور تأكيد الإلغاء على المنصة.',
      'الاسترداد عبر المحفظة الداخلية: فوري.',
      'الاسترداد على البطاقة البنكية: من 5 إلى 14 يوم عمل تبعاً للبنك المُصدر.',
      'الاسترداد عبر فوري / محفظة محمول: من 1 إلى 5 أيام عمل.',
      'تُحتسب أيام العمل من الأحد إلى الخميس باستثناء العطلات الرسمية في مصر.',
    ],
    itemsEn: [
      'Refund execution starts immediately upon cancellation confirmation on the Platform.',
      'In-app wallet refund: instant.',
      'Bank-card refund: 5–14 working days depending on the issuing bank.',
      'Fawry / mobile-wallet refund: 1–5 working days.',
      'Working days are Sunday through Thursday excluding Egyptian public holidays.',
    ],
  ),

  // 5. Non-refundable items ──────────────────────────────────
  PolicySection(
    numAr: '٥', numEn: '5',
    titleAr: 'عناصر غير قابلة للاسترداد',
    titleEn: 'Non-Refundable Items',
    itemsAr: [
      'رسوم بوابة الدفع (إن طُبِّقت من البنك أو فوري) — تخصمها الجهة المُصدرة وليست المنصة.',
      'رسوم الخدمة المدفوعة على نشرات أو ترويج العقار من قبل المالك.',
      'أي خصومات مكتسبة كرصيد مكافآت لا تُحوَّل إلى نقد.',
    ],
    itemsEn: [
      'Payment-gateway fees (if any) charged by the bank / Fawry — withheld by the issuer, not the Platform.',
      'Service fees paid by the host for listing promotions.',
      'Any earned reward credits cannot be converted to cash.',
    ],
  ),

  // 6. Disputes ──────────────────────────────────────────────
  PolicySection(
    numAr: '٦', numEn: '6',
    titleAr: 'النزاعات والشكاوى',
    titleEn: 'Disputes & Complaints',
    itemsAr: [
      'إذا اعتقدت أن استرداداً مستحقاً لم يُنفّذ، تواصل مع الدعم خلال 30 يوماً من تاريخ الاستحقاق.',
      'يستلم الفريق الشكوى ويردّ خلال 5 أيام عمل بأقصى تقدير.',
      'إذا استمر النزاع، يُتّبع مسار التحكيم المنصوص عليه في شروط الاستخدام.',
    ],
    itemsEn: [
      'If you believe a due refund was not processed, contact support within 30 days from the due date.',
      'The team acknowledges the complaint and responds within 5 working days at most.',
      'If the dispute persists, the arbitration path defined in the Terms applies.',
    ],
  ),
];
