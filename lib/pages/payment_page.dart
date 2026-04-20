// ═══════════════════════════════════════════════════════════════
//  TALAA — Payment Page  v2
//  إلكتروني بس: فيزا · ميزة · فوري Pay · فودافون كاش · اتصالات كاش
//  Escrow model: held → released 24h after check-in → paid to owner
//  Commission: 8% platform, 92% owner
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show appSettings;
import '../models/payment_model.dart';
import '../models/property_model_api.dart';
import '../services/booking_service.dart';
import '../services/payment_service.dart';
import '../services/promo_code_service.dart';
import '../utils/api_client.dart';
import '../utils/app_strings.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';
import 'payment_status_page.dart';

const _kOcean = Color(0xFF1565C0);
const _kGreen = Color(0xFF22C55E);

// ── Payment Method ─────────────────────────────────────────────
class _PayMethod {
  final String id, name, desc, logo;
  final Color color, bg;
  const _PayMethod(
      this.id, this.name, this.desc, this.logo, this.color, this.bg);
}

// Payment methods — card payments only.  Cash / mobile-wallet
// methods were intentionally removed: bookings confirm instantly via
// Visa / Mastercard / Meeza so the escrow ledger always opens with
// cleared funds.
List<_PayMethod> get _kMethods => [
      _PayMethod('visa', S.visaMaster, S.visaDesc, '💳',
          const Color(0xFF1565C0), const Color(0xFFEEF2FF)),
      _PayMethod('meeza', S.meeza, S.meezaDesc, '🇪🇬',
          const Color(0xFF006633), const Color(0xFFE8F5E9)),
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

  // Promo-code state
  final _promoCtrl = TextEditingController();
  String? _appliedCode;
  double _discount = 0;
  bool _validatingPromo = false;
  String? _promoError;

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
    _promoCtrl.dispose();
    super.dispose();
  }

  PropertyApi get p => widget.property;

  // ── Promo-code actions ──────────────────────────────────────
  Future<void> _applyPromoCode() async {
    final input = _promoCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _validatingPromo = true;
      _promoError = null;
    });
    try {
      final res = await PromoCodeService.validate(
        code: input,
        bookingAmount: widget.totalAmount.toDouble(),
      );
      if (!mounted) return;
      if (!res.valid) {
        setState(() {
          _validatingPromo = false;
          _promoError = res.reasonAr ?? res.reason ?? 'كود غير صالح';
          _appliedCode = null;
          _discount = 0;
        });
        return;
      }
      setState(() {
        _validatingPromo = false;
        _appliedCode = res.code;
        _discount = res.discountAmount;
        _promoError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _validatingPromo = false;
        _promoError = 'تعذّر التحقق من الكود';
      });
    }
  }

  void _removePromoCode() {
    setState(() {
      _appliedCode = null;
      _discount = 0;
      _promoError = null;
      _promoCtrl.clear();
    });
  }

  int get _finalAmount =>
      (widget.totalAmount - _discount).clamp(0, double.infinity).toInt();

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
              const SizedBox(height: 12),
              _promoCard(),
              const SizedBox(height: 16),
              _escrowBanner(),
              const SizedBox(height: 24),
              Text('اختر طريقة الدفع',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.kText)),
              const SizedBox(height: 6),
              Text('مدفوعاتك مؤمّنة بتشفير البنوك الدولي — فيزا وماستر كارد و ميزة فقط',
                  style: TextStyle(fontSize: 12, color: context.kSub)),
              const SizedBox(height: 14),
              ..._kMethods.map(_methodTile),
              if (_sel == 'visa' || _sel == 'meeza') ...[
                const SizedBox(height: 16),
                _cardForm(),
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
          if (_discount > 0)
            _row(
              'كود خصم ($_appliedCode)',
              '- ${_discount.toStringAsFixed(0)} جنيه',
              color: _kGreen,
            ),
          Divider(height: 14, color: context.kBorder),
          _row(S.totalPrice, '$_finalAmount جنيه', bold: true),
        ]),
      );

  // ── Promo-code card ───────────────────────────────────────────
  Widget _promoCard() {
    if (_appliedCode != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kGreen.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.local_offer_rounded, color: _kGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تم تطبيق الكود $_appliedCode',
                    style: const TextStyle(
                        color: _kGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                Text(
                  'خصم ${_discount.toStringAsFixed(0)} جنيه',
                  style: TextStyle(color: context.kSub, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _removePromoCode,
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.local_offer_outlined, color: context.kText, size: 18),
            const SizedBox(width: 8),
            Text('عندك كود خصم؟',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.kText,
                )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _promoCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'أدخل الكود',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOcean,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _validatingPromo ? null : _applyPromoCode,
                child: _validatingPromo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : const Text('تطبيق',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          if (_promoError != null) ...[
            const SizedBox(height: 6),
            Text(_promoError!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _row(String l, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(l,
                  style: TextStyle(
                      fontSize: 13,
                      color: color ?? (bold ? context.kText : context.kSub),
                      fontWeight: bold ? FontWeight.w900 : FontWeight.w400))),
          Text(v,
              style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  color: color ?? (bold ? _kOcean : context.kText))),
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

  Widget _secBadge() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_rounded, size: 13, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Text('مدفوعاتك محمية بتشفير SSL 256-bit وفق معايير PCI-DSS',
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
  //  PAY — create booking → initiate payment → open gateway
  // ═══════════════════════════════════════
  /// Map the UI method id to a backend (provider, method) tuple.
  ({PayProvider provider, PayMethod method})? _mapSelection() {
    switch (_sel) {
      case 'visa':
      case 'meeza':
        return (provider: PayProvider.paymob, method: PayMethod.card);
    }
    return null;
  }

  Future<void> _pay() async {
    final mapped = _mapSelection();
    if (mapped == null) return;

    // Card forms are gateway-hosted now, but we still sanity-check
    // the local fields if the user filled them in.
    if (mapped.method == PayMethod.card) {
      if (_numCtrl.text.isNotEmpty &&
          (_numCtrl.text.length < 16 ||
              _expCtrl.text.length < 5 ||
              _cvvCtrl.text.length < 3 ||
              _nameCtrl.text.trim().isEmpty)) {
        _snack('يرجى إدخال بيانات البطاقة كاملة', isError: true);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      // ── 1. Create the booking (still pending until paid) ─────
      final parts = widget.checkIn.split('/');
      final checkInDt = DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final coParts = widget.checkOut.split('/');
      final checkOutDt = DateTime(
          int.parse(coParts[2]), int.parse(coParts[1]), int.parse(coParts[0]));

      final booking = await BookingService.createBooking(
        propertyId: p.id,
        checkIn: checkInDt,
        checkOut: checkOutDt,
        guestsCount: widget.guests,
        promoCode: _appliedCode,
      );

      // ── 2. Initiate payment with the chosen gateway ──────────
      final result = await PaymentService.initiate(
        bookingId: booking.id,
        provider: mapped.provider,
        method: mapped.method,
      );

      // ── 3. Open checkout URL (Paymob iframe / Fawry hosted) ──
      final url = result.checkoutUrl;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      HapticFeedback.mediumImpact();

      // ── 4. Land on the polling / status screen ───────────────
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentStatusPage(
            paymentId: result.paymentId,
            checkoutUrl: result.checkoutUrl,
            fawryReference:
                result.extra['reference_number']?.toString() ??
                    result.providerRef,
          ),
        ),
      );
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

}
