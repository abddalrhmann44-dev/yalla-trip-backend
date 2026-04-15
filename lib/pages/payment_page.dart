// ═══════════════════════════════════════════════════════════════
//  TALAA — Payment Page  v2
//  إلكتروني بس: فيزا · ميزة · فوري Pay · فودافون كاش · اتصالات كاش
//  Escrow model: held → released 24h after check-in → paid to owner
//  Commission: 8% platform, 92% owner
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import 'package:flutter/services.dart';
import '../models/property_model_api.dart';
import '../services/booking_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import 'home_page.dart';

const _kOcean = Color(0xFF1565C0);
const _kGreen = Color(0xFF22C55E);

// ── Payment Method ─────────────────────────────────────────────
class _PayMethod {
  final String id, name, desc, logo;
  final Color color, bg;
  const _PayMethod(
      this.id, this.name, this.desc, this.logo, this.color, this.bg);
}

// Payment methods — use S. getters in display, keep Arabic keys for logic
List<_PayMethod> get _kMethods => [
      _PayMethod('visa', S.visaMaster, S.visaDesc, '💳',
          const Color(0xFF1565C0), const Color(0xFFEEF2FF)),
      _PayMethod('meeza', S.meeza, S.meezaDesc, '🇪🇬', const Color(0xFF006633),
          const Color(0xFFE8F5E9)),
      _PayMethod('fawry', S.fawry, S.fawryDesc, '🟡', const Color(0xFFFF6600),
          const Color(0xFFFFF3E0)),
      _PayMethod('vodafone', S.vodafone, S.vodafoneDesc, '🔴',
          const Color(0xFFE53935), const Color(0xFFFFEBEE)),
      _PayMethod(
          'etisalat',
          S.ar ? 'اتصالات كاش' : 'Etisalat Cash',
          S.ar ? 'ادفع عبر محفظة اتصالات' : 'Pay via Etisalat wallet',
          '🟢',
          const Color(0xFF2E7D32),
          const Color(0xFFE8F5E9)),
    ];

// ══════════════════════════════════════════════════════════════
//  PAGE
// ══════════════════════════════════════════════════════════════
class PaymentPage extends StatefulWidget {
  final PropertyApi property;
  final String checkIn, checkOut, guestNote;
  final int nights, guests, baseAmount, cleaningFee, totalAmount;

  const PaymentPage({
    super.key,
    required this.property,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.guests,
    required this.guestNote,
    required this.baseAmount,
    required this.cleaningFee,
    required this.totalAmount,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String? _sel;
  bool _loading = false;

  // Card fields
  final _numCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  void _onLangChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    _numCtrl.dispose();
    _expCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  PropertyApi get p => widget.property;

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.kText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('إتمام الدفع',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: context.kText)),
        centerTitle: true,
      ),
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _orderCard(),
              const SizedBox(height: 16),
              _escrowBanner(),
              const SizedBox(height: 24),
              Text('اختر طريقة الدفع',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.kText)),
              const SizedBox(height: 6),
              Text('مدفوعاتك مؤمّنة عبر Fawry Pay',
                  style: TextStyle(fontSize: 12, color: context.kSub)),
              const SizedBox(height: 14),
              ..._kMethods.map(_methodTile),
              if (_sel == 'visa' || _sel == 'meeza') ...[
                const SizedBox(height: 16),
                _cardForm(),
              ],
              if (_sel == 'fawry' ||
                  _sel == 'vodafone' ||
                  _sel == 'etisalat') ...[
                const SizedBox(height: 16),
                _walletSteps(),
              ],
              const SizedBox(height: 8),
              _secBadge(),
            ],
          ),
        ),
        _bottomBar(),
      ]),
    );
  }

  // ── Escrow Banner ─────────────────────────────────────────────
  Widget _escrowBanner() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.verified_user_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('حجزك محمي بضمان Talaa 🛡️',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text('فلوسك محجوزة لحد ما تدخل العقار وتتأكد',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            )),
          ]),
          const SizedBox(height: 12),
          // Timeline
          Row(children: [
            _timelineStep('💳', 'دفع', true),
            _timelineLine(),
            _timelineStep('🏠', 'وصول', false),
            _timelineLine(),
            _timelineStep('✅', 'تأكيد +24h', false),
            _timelineLine(),
            _timelineStep('💰', 'تحويل\nللمالك', false),
          ]),
        ]),
      );

  Widget _timelineStep(String emoji, String label, bool active) =>
      Column(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child:
              Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
        ),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: active ? Colors.white : Colors.white60,
                fontSize: 9,
                height: 1.2)),
      ]);

  Widget _timelineLine() => Expanded(
          child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: Colors.white.withValues(alpha: 0.3),
      ));

  // ── Order Card ────────────────────────────────────────────────
  Widget _orderCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: p.images.isEmpty
                  ? Container(
                      width: 56,
                      height: 56,
                      color: _kOcean.withValues(alpha: 0.1),
                      child: const Icon(Icons.villa_rounded, color: _kOcean))
                  : Image.network(p.images[0],
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: _kOcean.withValues(alpha: 0.1),
                          child:
                              const Icon(Icons.villa_rounded, color: _kOcean))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.kText)),
                Text(
                    '${p.area} · ${widget.nights} ليالي · '
                    '${widget.guests} ضيوف',
                    style: TextStyle(fontSize: 12, color: context.kSub)),
                Text('${widget.checkIn}  →  ${widget.checkOut}',
                    style: TextStyle(fontSize: 11, color: context.kSub)),
              ],
            )),
          ]),
          Divider(height: 18, color: context.kBorder),
          _row('${p.pricePerNight.toStringAsFixed(0)} × ${widget.nights} ليالي',
              '${widget.baseAmount} جنيه'),
          if (widget.cleaningFee > 0)
            _row(S.cleaningFee, '${widget.cleaningFee} جنيه'),
          Divider(height: 14, color: context.kBorder),
          _row(S.totalPrice, '${widget.totalAmount} جنيه', bold: true),
        ]),
      );

  Widget _row(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(l,
                  style: TextStyle(
                      fontSize: 13,
                      color: bold ? context.kText : context.kSub,
                      fontWeight: bold ? FontWeight.w900 : FontWeight.w400))),
          Text(v,
              style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  color: bold ? _kOcean : context.kText)),
        ]),
      );

  // ── Method Tile ───────────────────────────────────────────────
  Widget _methodTile(_PayMethod m) {
    final sel = _sel == m.id;
    return GestureDetector(
      onTap: () => setState(() => _sel = m.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? m.bg : context.kCard,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: sel ? m.color : context.kBorder, width: sel ? 2 : 1.5),
          boxShadow: [
            BoxShadow(
              color: sel
                  ? m.color.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: sel ? 14 : 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: sel
                  ? m.color.withValues(alpha: 0.15)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(m.logo, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: sel ? m.color : context.kText)),
              Text(m.desc, style: TextStyle(fontSize: 12, color: context.kSub)),
            ],
          )),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? m.color : Colors.transparent,
              border: Border.all(color: sel ? m.color : context.kBorder, width: 2),
            ),
            child: sel
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }

  // ── Card Form ─────────────────────────────────────────────────
  Widget _cardForm() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(children: [
          _cf(_numCtrl, 'رقم البطاقة', Icons.credit_card_rounded,
              TextInputType.number,
              fmt: FilteringTextInputFormatter.digitsOnly, max: 16),
          const SizedBox(height: 10),
          _cf(_nameCtrl, 'الاسم على البطاقة', Icons.person_outline_rounded,
              TextInputType.name),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _cf(_expCtrl, 'MM/YY', Icons.calendar_today_rounded,
                    TextInputType.number,
                    max: 5)),
            const SizedBox(width: 10),
            Expanded(
                child: _cf(_cvvCtrl, 'CVV', Icons.lock_outline_rounded,
                    TextInputType.number,
                    max: 3, obscure: true)),
          ]),
        ]),
      );

  Widget _cf(
          TextEditingController c, String hint, IconData icon, TextInputType kb,
          {TextInputFormatter? fmt, int? max, bool obscure = false}) =>
      Container(
        decoration: BoxDecoration(
            color: context.kSand,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.kBorder)),
        child: TextField(
          controller: c,
          keyboardType: kb,
          obscureText: obscure,
          maxLength: max,
          inputFormatters: fmt != null ? [fmt] : null,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: _kOcean),
            border: InputBorder.none,
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      );

  // ── Wallet Steps ──────────────────────────────────────────────
  Widget _walletSteps() {
    final info = {
      'fawry': {
        'logo': '🟡',
        'title': 'الدفع عبر فوري Pay',
        'color': const Color(0xFFFF6600),
        'bg': const Color(0xFFFFF3E0),
        'steps': [
          'افتح تطبيق فوري أو اذهب لأقرب نقطة فوري',
          'اختر "دفع الفواتير" ← "Talaa"',
          'أدخل رقم الطلب اللي هيوصلك على هاتفك',
          'ادفع ${widget.totalAmount} جنيه واحتفظ بالإيصال',
        ],
      },
      'vodafone': {
        'logo': '🔴',
        'title': 'الدفع عبر فودافون كاش',
        'color': const Color(0xFFE53935),
        'bg': const Color(0xFFFFEBEE),
        'steps': [
          'افتح تطبيق فودافون كاش أو اضغط *9#',
          'اختر "الدفع والسداد"',
          'ابحث عن "Talaa" في قائمة التجار',
          'أدخل ${widget.totalAmount} جنيه وأكّد برقمك السري',
        ],
      },
      'etisalat': {
        'logo': '🟢',
        'title': 'الدفع عبر اتصالات كاش',
        'color': const Color(0xFF2E7D32),
        'bg': const Color(0xFFE8F5E9),
        'steps': [
          'افتح تطبيق اتصالات كاش',
          'اختر "ادفع فاتورة"',
          'ابحث عن "Talaa"',
          'أدخل ${widget.totalAmount} جنيه وأكّد',
        ],
      },
    };
    final d = info[_sel]!;
    final color = d['color'] as Color;
    final steps = d['steps'] as List<String>;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: d['bg'] as Color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(d['logo'] as String, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(d['title'] as String,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ]),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: Center(
                        child: Text('${e.key + 1}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: color))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(e.value,
                          style: TextStyle(
                              fontSize: 13, color: color, height: 1.4))),
                ],
              ),
            )),
      ]),
    );
  }

  Widget _secBadge() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_rounded, size: 13, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Text('مدفوعاتك محمية بتشفير SSL 256-bit عبر Fawry Pay',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ]),
      );

  // ── Bottom Bar ────────────────────────────────────────────────
  Widget _bottomBar() => Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_sel != null && !_loading) ? _pay : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOcean,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('تأكيد الدفع',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('${widget.totalAmount} جنيه',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                      ),
                    ]),
            ),
          ),
        ),
      );

  // ═══════════════════════════════════════
  //  PAY — Create booking via REST API
  // ═══════════════════════════════════════
  Future<void> _pay() async {
    if (_sel == null) return;

    if (_sel == 'visa' || _sel == 'meeza') {
      if (_numCtrl.text.length < 16 ||
          _expCtrl.text.length < 5 ||
          _cvvCtrl.text.length < 3 ||
          _nameCtrl.text.trim().isEmpty) {
        _snack('يرجى إدخال بيانات البطاقة كاملة', isError: true);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      // ── Parse check-in / check-out to DateTime ─────
      final parts = widget.checkIn.split('/');
      final checkInDt = DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final coParts = widget.checkOut.split('/');
      final checkOutDt = DateTime(
          int.parse(coParts[2]), int.parse(coParts[1]), int.parse(coParts[0]));

      await BookingService.createBooking(
        propertyId: p.id,
        checkIn: checkInDt,
        checkOut: checkOutDt,
        guestsCount: widget.guests,
      );

      HapticFeedback.heavyImpact();
      if (mounted) _showSuccess();
    } on ApiException catch (e) {
      _snack(ErrorHandler.getMessage(e), isError: true);
    } catch (_) {
      _snack('حدث خطأ، حاول مرة أخرى', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? const Color(0xFFEF5350) : _kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccess() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, __) => Transform.scale(
              scale: v,
              child: Container(
                width: 80,
                height: 80,
                decoration:
                    const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 44),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('تم الحجز بنجاح! 🎉',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: context.kText)),
          const SizedBox(height: 8),
          Text('${p.name}\n${widget.checkIn}  →  ${widget.checkOut}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.kSub, height: 1.6)),
          const SizedBox(height: 16),

          // Escrow confirmation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kOcean.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kOcean.withValues(alpha: 0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.verified_user_rounded, color: _kOcean, size: 18),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                'فلوسك محجوزة عندنا — هتتأكد بعد ما تدخل العقار بـ 24 ساعة',
                style: TextStyle(fontSize: 12, color: _kOcean, height: 1.5),
              )),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (_) => false,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOcean,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('رجوع للرئيسية',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }
}
