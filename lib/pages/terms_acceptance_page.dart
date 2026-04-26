// ═══════════════════════════════════════════════════════════════
//  TALAA — Terms Acceptance Gate
//  Bilingual acceptance screen shown on first launch.  Highlights
//  the seven most consequential clauses of the full policy (neutral
//  platform role, eligibility, host/guest duties, payments,
//  cancellation, liability, privacy) before allowing the user into
//  the app.  The screen listens to `appSettings` so language flips
//  apply instantly.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show appSettings;
import '../widgets/constants.dart';
import 'terms_page.dart';
import 'home_page.dart';

// Unified brand accent.
const _kBrand = Color(0xFFFF6B35);
const _kBrandDark = Color(0xFFE85A24);
const _kGreen = Color(0xFF4CAF50);

class TermsAcceptancePage extends StatefulWidget {
  const TermsAcceptancePage({super.key});

  /// Check if user has already accepted.
  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('terms_accepted') ?? false;
  }

  /// Mark terms as accepted.
  static Future<void> markAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted', true);
  }

  @override
  State<TermsAcceptancePage> createState() => _TermsAcceptancePageState();
}

class _TermsAcceptancePageState extends State<TermsAcceptancePage> {
  bool _accepted = false;

  void _proceed() async {
    await TermsAcceptancePage.markAccepted();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, _) {
        final ar = appSettings.arabic;
        return Scaffold(
          backgroundColor: context.kSand,
          body: SafeArea(
            child: Column(children: [
              // ── Header ─────────────────────────────────────────
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kBrandDark, _kBrand],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _kBrand.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(children: [
                  const Icon(Icons.gavel_rounded,
                      color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    ar
                        ? 'سياسة الاستخدام والخصوصية'
                        : 'Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ar
                        ? 'يرجى قراءة الملخص والموافقة للمتابعة. هذه الشروط ملزمة قانونياً.'
                        : 'Please review the summary and accept to continue. These Terms are legally binding.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Scrollable summary ─────────────────────────────
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.kBorder),
                  ),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _summaryItem(
                        Icons.hub_rounded,
                        ar ? 'دور المنصة' : 'Our Role',
                        ar
                            ? 'Talaa Trip وسيط تقني فقط، وليست طرفاً في عقد الإيجار ولا تملك العقارات أو تديرها.'
                            : 'Talaa Trip is a technology intermediary only — not a party to the rental contract, nor the owner or operator of any property.',
                      ),
                      _summaryItem(
                        Icons.badge_rounded,
                        ar ? 'الأهلية والتحقق' : 'Eligibility & Verification',
                        ar
                            ? 'يجب ألا يقل عمرك عن 18 عاماً وأن تقدّم بيانات حقيقية. قد نطلب توثيق الهوية والملكية.'
                            : 'You must be 18+ and provide truthful data. We may request identity and ownership verification.',
                      ),
                      _summaryItem(
                        Icons.apartment_rounded,
                        ar ? 'التزامات المالك' : 'Host Obligations',
                        ar
                            ? 'تضمن ملكية العقار، وتدرج معلومات دقيقة وصوراً حقيقية، ولا تتعامل خارج المنصة، ولا تُميّز بين الضيوف.'
                            : 'You warrant ownership, provide accurate info and real photos, do not transact off-platform, and do not discriminate.',
                      ),
                      _summaryItem(
                        Icons.luggage_rounded,
                        ar ? 'التزامات الضيف' : 'Guest Obligations',
                        ar
                            ? 'استخدام سكني فقط، احترام قواعد المنزل والعدد، وتحمّل كامل قيمة أي ضرر تتسبب فيه.'
                            : 'Residential use only, respect house rules and occupancy, and full financial liability for any damage you cause.',
                      ),
                      _summaryItem(
                        Icons.payments_rounded,
                        ar ? 'الدفع والعمولة' : 'Payments & Commission',
                        ar
                            ? 'الدفع داخل المنصة فقط. عمولة 10% تُخصم من المالك. المعاملات الخارجية غير محمية.'
                            : 'Payment is on-platform only. A 10% commission is deducted from the Host. Off-platform deals are unprotected.',
                      ),
                      _summaryItem(
                        Icons.event_busy_rounded,
                        ar ? 'الإلغاء والاسترداد' : 'Cancellations',
                        ar
                            ? 'قبل 14 يوم: 100%. 7–13 يوم: 50%. 3–6 أيام: 25%. أقل من 48 ساعة أو عدم حضور: لا استرداد.'
                            : '≥14 days: 100%. 7–13 days: 50%. 3–6 days: 25%. <48h or no-show: no refund.',
                      ),
                      _summaryItem(
                        Icons.gavel_rounded,
                        ar ? 'تحديد المسؤولية' : 'Limitation of Liability',
                        ar
                            ? 'مسؤوليتنا التراكمية محدودة بإجمالي العمولات خلال 3 أشهر أو 1000 ج.م أيهما أقل. القانون الحاكم: مصري.'
                            : 'Our aggregate liability is capped at 3 months of commissions or EGP 1,000, whichever is lower. Governing law: Egyptian.',
                      ),
                      _summaryItem(
                        Icons.shield_rounded,
                        ar ? 'الخصوصية' : 'Privacy',
                        ar
                            ? 'نلتزم بقانون حماية البيانات المصري 151/2020. بياناتك مشفرة، لا تُباع، ولك حق الوصول والحذف.'
                            : 'We comply with Egyptian Data Protection Law 151/2020. Your data is encrypted, never sold; you may access or delete it.',
                      ),
                      const SizedBox(height: 8),
                      // View full terms link
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TermsPage())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: _kBrand.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.description_rounded,
                                    color: _kBrand, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  ar
                                      ? 'قراءة السياسة كاملة (25 بند)'
                                      : 'Read full policy (25 clauses)',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _kBrand),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Checkbox + Accept ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: GestureDetector(
                  onTap: () => setState(() => _accepted = !_accepted),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _accepted ? _kGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: _accepted ? _kGreen : context.kBorder,
                            width: 2),
                      ),
                      child: _accepted
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ar
                            ? 'قرأت ووافقت على الشروط وسياسة الخصوصية وأقرّ بأن عمري 18 عاماً أو أكثر.'
                            : 'I have read and agree to the Terms & Privacy Policy and confirm I am 18 years or older.',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.kText),
                      ),
                    ),
                  ]),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: GestureDetector(
                  onTap: _accepted ? _proceed : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _accepted ? _kBrand : context.kBorder,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        ar ? 'موافق ومتابعة' : 'Agree & Continue',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color:
                                _accepted ? Colors.white : context.kSub),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _summaryItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _kBrand.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _kBrand, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.kText)),
              const SizedBox(height: 3),
              Text(desc,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: context.kSub,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ]),
    );
  }
}
