// ═══════════════════════════════════════════════════════════════
//  TALAA — Terms Acceptance Gate
//  Must accept terms on first login before accessing the app
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/constants.dart';
import 'terms_page.dart';
import 'home_page.dart';

const _kOcean = Color(0xFF1565C0);
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
                colors: [Color(0xFF0D47A1), _kOcean],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(children: [
              const Icon(Icons.gavel_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              const Text('سياسة الاستخدام والخصوصية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Text('يُرجى قراءة السياسة بعناية والموافقة عليها للمتابعة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8))),
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
                    Icons.person_rounded,
                    'الأهلية',
                    'يجب ألا يقل عمرك عن 18 عاماً وتلتزم بتقديم بيانات صحيحة.',
                  ),
                  _summaryItem(
                    Icons.apartment_rounded,
                    'مسؤوليات المالك',
                    'تقديم معلومات دقيقة وصور حقيقية، والالتزام بمواعيد التسليم.',
                  ),
                  _summaryItem(
                    Icons.luggage_rounded,
                    'مسؤوليات الضيف',
                    'الاستخدام السكني فقط وتحمل مسؤولية أي تلفيات.',
                  ),
                  _summaryItem(
                    Icons.payments_rounded,
                    'المدفوعات',
                    'الدفع فقط عبر التطبيق. عمولة المنصة 8%. المعاملات الخارجية غير مضمونة.',
                  ),
                  _summaryItem(
                    Icons.event_busy_rounded,
                    'الإلغاء',
                    'قبل 14 يوم: 100% استرداد. قبل 7 أيام: 50%. أقل من 48 ساعة: لا استرداد.',
                  ),
                  _summaryItem(
                    Icons.shield_rounded,
                    'الخصوصية',
                    'بياناتك محمية ومشفرة. لا نشارك بياناتك مع أطراف خارجية.',
                  ),
                  const SizedBox(height: 8),
                  // View full terms link
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const TermsPage())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _kOcean.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.description_rounded,
                                color: _kOcean, size: 16),
                            const SizedBox(width: 6),
                            const Text('قراءة السياسة كاملة',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kOcean)),
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
                    color: _accepted
                        ? _kGreen
                        : Colors.transparent,
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
                    'قرأت ووافقت على سياسة الاستخدام والخصوصية',
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
                  color: _accepted
                      ? _kOcean
                      : context.kBorder,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text('موافق ومتابعة',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _accepted
                              ? Colors.white
                              : context.kSub)),
                ),
              ),
            ),
          ),
        ]),
      ),
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
            color: _kOcean.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _kOcean, size: 18),
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
