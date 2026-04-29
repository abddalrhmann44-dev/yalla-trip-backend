// ═══════════════════════════════════════════════════════════════
//  TALAA — Payment Page  v2
//  إلكتروني بس: فيزا · ميزة · فوري Pay · فودافون كاش · اتصالات كاش
//  Escrow model: held → released 24h after check-in → paid to owner
//  Commission: 10% platform, 90% owner
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appSettings;
import '../models/payment_model.dart';
import '../models/property_model_api.dart';
import '../services/booking_service.dart';
import '../services/payment_service.dart';
import '../services/promo_code_service.dart';
import '../services/wallet_service.dart';
import '../utils/api_client.dart';
import '../utils/app_strings.dart';
import '../utils/device_integrity.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';
import 'payment_status_page.dart';
import 'payment_webview_page.dart';

const _kOrange = Color(0xFFFF6D00);
const _kGreen  = Color(0xFF22C55E);

// ── Payment Method ─────────────────────────────────────────────
/// One row in the "اختر طريقة الدفع" list.
///
/// [logos] is a list of asset paths so the row can show one OR two
/// logos side-by-side (Visa + Mastercard share a single row per
/// product decision — the gateway routes the payment automatically
/// based on the card's BIN).
class _PayMethod {
  final String id;
  final String name;
  final String desc;
  final List<String> logos;
  final Color color;
  final Color bg;
  const _PayMethod({
    required this.id,
    required this.name,
    required this.desc,
    required this.logos,
    required this.color,
    required this.bg,
  });
}

// Payment methods.  Three groups, mapped server-side to Paymob:
//   1. Cards          → method=card        (Visa + Mastercard merged + Meeza)
//   2. Mobile wallets → method=wallet      (Vodafone / Orange / e& Money)
// The backend reads `extra.wallet_type` to route wallet payments to
// the correct Paymob integration ID.
const _kCardsBlue   = Color(0xFFFF6B35);
const _kCardsBlueBg = Color(0xFFEEF2FF);
const _kMeezaGreen  = Color(0xFF6A1B9A); // Meeza brand purple
const _kMeezaBg     = Color(0xFFF3E5F5);
const _kVfRed       = Color(0xFFE60000);
const _kVfBg        = Color(0xFFFFEBEE);
const _kOrangeBrand = Color(0xFFFF7900);
const _kOrangeBg    = Color(0xFFFFF3E0);
const _kEtisalat    = Color(0xFF6F1F2C);
const _kEtisalatBg  = Color(0xFFFCE4EC);

List<_PayMethod> get _kMethods => [
      _PayMethod(
        id: 'card',
        name: 'فيزا / ماستر كارد',
        desc: 'الدفع بالكارت — أى بنك مصرى أو أجنبى',
        logos: const [
          'assets/images/payment/visa.jpeg',
          'assets/images/payment/mastercard.jpeg',
        ],
        color: _kCardsBlue,
        bg: _kCardsBlueBg,
      ),
      _PayMethod(
        id: 'meeza',
        name: 'ميزة',
        desc: 'كروت ميزة الوطنية المصرية',
        logos: const ['assets/images/payment/meeza.jpeg'],
        color: _kMeezaGreen,
        bg: _kMeezaBg,
      ),
      _PayMethod(
        id: 'vodafone_cash',
        name: 'فودافون كاش',
        desc: 'ادفع من محفظة فودافون كاش',
        logos: const ['assets/images/payment/vodafone_cash.jpeg'],
        color: _kVfRed,
        bg: _kVfBg,
      ),
      _PayMethod(
        id: 'orange_cash',
        name: 'اورنچ كاش',
        desc: 'ادفع من محفظة Orange Cash',
        logos: const ['assets/images/payment/orange_cash.jpeg'],
        color: _kOrangeBrand,
        bg: _kOrangeBg,
      ),
      _PayMethod(
        id: 'etisalat_cash',
        name: 'e& money',
        desc: 'ادفع من محفظة اتصالات الجديدة',
        logos: const ['assets/images/payment/etisalat_money.jpeg'],
        color: _kEtisalat,
        bg: _kEtisalatBg,
      ),
    ];

// ══════════════════════════════════════════════════════════════
//  PAGE
// ══════════════════════════════════════════════════════════════
class PaymentPage extends StatefulWidget {
  final PropertyApi property;
  final String checkIn, checkOut, guestNote;
  final int nights, guests, baseAmount, cleaningFee, totalAmount;
  // Wave 25 — hybrid deposit + cash-on-arrival.  Optional so legacy
  // call-sites keep working; when present the page renders a
  // "you pay X online, Y in cash on arrival" split and the gateway
  // only charges ``depositAmount``.
  final int depositAmount;
  final int remainingCash;

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
    this.depositAmount = 0,
    this.remainingCash = 0,
  });

  /// True when the host enabled cash-on-arrival and the booking flow
  /// passed a non-zero deposit + remainder split.  Centralising the
  /// check here keeps every render-site consistent.
  bool get isCashOnArrival =>
      property.cashOnArrivalEnabled &&
      depositAmount > 0 &&
      remainingCash > 0;

  /// Amount we actually charge the gateway.  Falls back to the full
  /// total for legacy 100 %-online listings.
  int get chargeableAmount =>
      isCashOnArrival ? depositAmount : totalAmount;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const double _kCommissionRate = 0.10;
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
  RedeemPreview? _walletPreview;
  bool _useWalletCredit = false;
  bool _loadingWallet = true;

  // Device integrity — assume trusted until proven otherwise so the
  // page renders instantly; the native probe runs in the background
  // and rebuilds with a warning if the device is rooted / jailbroken.
  bool _deviceTrusted = true;

  void _onLangChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    _checkDeviceIntegrity();
    _loadWalletPreview();
  }

  Future<void> _loadWalletPreview() async {
    final hadPreview = _walletPreview != null;
    final subtotal = _walletPreviewSubtotal;
    if (mounted) {
      setState(() => _loadingWallet = true);
    }
    if (subtotal <= 0) {
      if (!mounted) return;
      setState(() {
        _walletPreview = null;
        _useWalletCredit = false;
        _loadingWallet = false;
      });
      return;
    }
    try {
      final preview = await WalletService.redeemPreview(subtotal);
      if (!mounted) return;
      setState(() {
        _walletPreview = preview;
        _useWalletCredit = hadPreview
            ? _useWalletCredit && preview.maxRedeemable > 0
            : preview.maxRedeemable > 0;
        _loadingWallet = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _walletPreview = null;
        _useWalletCredit = false;
        _loadingWallet = false;
      });
    }
  }

  Future<void> _checkDeviceIntegrity() async {
    final trusted = await DeviceIntegrity.isTrusted();
    if (!mounted || trusted == _deviceTrusted) return;
    setState(() => _deviceTrusted = trusted);
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
        await _loadWalletPreview();
        return;
      }
      setState(() {
        _validatingPromo = false;
        _appliedCode = res.code;
        _discount = res.discountAmount;
        _promoError = null;
      });
      await _loadWalletPreview();
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
    _loadWalletPreview();
  }

  // Wave 25 — for hybrid bookings the gateway only collects the
  // online deposit, so the "amount due now" the page advertises must
  // be the deposit (minus any promo) rather than the full grand total.
  int get _finalAmount =>
      _estimatedChargeableAmount
          .clamp(0, double.infinity)
          .toInt();

  double get _walletDiscount =>
      _useWalletCredit ? (_walletPreview?.maxRedeemable ?? 0) : 0;

  double get _walletPreviewSubtotal {
    final subtotal = widget.totalAmount.toDouble() - _discount;
    return subtotal > 0 ? subtotal : 0;
  }

  double get _effectiveTotalAfterDiscounts =>
      (widget.totalAmount.toDouble() - _discount - _walletDiscount)
          .clamp(0, double.infinity);

  double get _estimatedChargeableAmount {
    final total = _effectiveTotalAfterDiscounts;
    if (!widget.isCashOnArrival || total <= 0) return total;
    final perNight = widget.property.pricePerNight;
    if (perNight <= 0) return total;
    final nightsNeeded = ((total * _kCommissionRate) / perNight).ceil();
    final depositNights = nightsNeeded < 1 ? 1 : nightsNeeded;
    final deposit = perNight * depositNights;
    return deposit > total ? total : deposit;
  }

  double get _estimatedRemainingCash {
    if (!widget.isCashOnArrival) return 0;
    return (_effectiveTotalAfterDiscounts - _estimatedChargeableAmount)
        .clamp(0, double.infinity);
  }

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
              const SizedBox(height: 12),
              _walletCreditCard(),
              const SizedBox(height: 16),
              _escrowBanner(),
              if (!_deviceTrusted) ...[
                const SizedBox(height: 16),
                _tamperedDeviceBanner(),
              ],
              const SizedBox(height: 24),
              Text('اختر طريقة الدفع',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.kText)),
              const SizedBox(height: 6),
              Text(
                'كل المعاملات مؤمّنة بتشفير البنوك الدولى وفق معايير PCI-DSS',
                style: TextStyle(fontSize: 12, color: context.kSub),
              ),
              const SizedBox(height: 14),
              ..._kMethods.map(_methodTile),
              // Manual card form is shown only when the user picks the
              // Card row.  Wallet payments (Vodafone / Orange / e&) and
              // Meeza go straight to Paymob's hosted iframe, no PAN
              // entry on our side.
              if (_deviceTrusted && _sel == 'card') ...[
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

  // ── Tampered Device Banner ─────────────────────────────────────
  // Shown in place of the card form when flutter_jailbreak_detection
  // flags the device as rooted / jailbroken.  We don't block the user
  // from paying entirely — they can still use Fawry voucher or wallet
  // — but we refuse to render a PAN entry field on a compromised OS.
  Widget _tamperedDeviceBanner() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFB91C1C), Color(0xFFEF4444)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.gpp_bad_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('جهازك غير آمن لإدخال بيانات البطاقة ⚠️',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text(
                  'عشان حماية فلوسك من الاختراق — الدفع بالكارت '
                  'غير متاح على أجهزة Root/Jailbreak. '
                  'يمكنك الدفع بـ فوري أو المحفظة بأمان.',
                  style: TextStyle(color: Colors.white, fontSize: 11, height: 1.5)),
            ],
          )),
        ]),
      );

  // ── Escrow Banner ─────────────────────────────────────────────
  Widget _escrowBanner() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFE65100), Color(0xFFFF6D00)]),
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
                      color: _kOrange.withValues(alpha: 0.1),
                      child: const Icon(Icons.villa_rounded, color: _kOrange))
                  : Image.network(p.images[0],
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: _kOrange.withValues(alpha: 0.1),
                          child:
                              const Icon(Icons.villa_rounded, color: _kOrange))),
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
          if (_walletDiscount > 0)
            _row(
              'رصيد الدعوات',
              '- ${_walletDiscount.toStringAsFixed(0)} جنيه',
              color: _kGreen,
            ),
          Divider(height: 14, color: context.kBorder),
          _row(
            S.totalPrice,
            '${_effectiveTotalAfterDiscounts.toStringAsFixed(0)} جنيه',
            bold: true,
          ),
          if (widget.isCashOnArrival) ...[
            const SizedBox(height: 12),
            _depositSplitBox(),
          ] else ...[
            // Legacy 100 %-online flow keeps the original "amount due
            // now" line right under the total.
            const SizedBox(height: 4),
            _row('المطلوب الآن', '$_finalAmount جنيه', bold: true,
                color: _kOrange),
          ],
        ]),
      );

  /// Card that highlights the "you pay X online now, Y in cash on
  /// arrival" split for hybrid bookings.  Mirrors the breakdown the
  /// guest already saw on the previous booking flow page.
  Widget _depositSplitBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF66BB6A), width: 1.2),
      ),
      child: Column(children: [
        Row(children: const [
          Text('💵', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'دفع جزئى — الباقى كاش للمضيف عند الوصول',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B5E20)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _row('تدفع الآن (عربون)', '$_finalAmount جنيه', bold: true),
        _row('تدفع كاش عند الوصول',
            '${_estimatedRemainingCash.toStringAsFixed(0)} جنيه'),
      ]),
    );
  }

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
                  backgroundColor: _kOrange,
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

  Widget _walletCreditCard() {
    final preview = _walletPreview;
    final canUse = preview != null && preview.maxRedeemable > 0;
    final available = preview?.availableBalance ?? 0;
    final reason = preview?.capReason;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: _kGreen, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('استخدم رصيد الدعوات',
                  style: TextStyle(
                      color: context.kText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                _loadingWallet
                    ? 'جارى فحص الرصيد...'
                    : canUse
                        ? 'متاح خصم ${preview.maxRedeemable.toStringAsFixed(0)} جنيه من رصيدك'
                        : reason ?? 'متاح عند حجوزات من 3000 جنيه أو أكثر',
                style: TextStyle(color: context.kSub, fontSize: 11.5),
              ),
              if (!_loadingWallet && available > 0) ...[
                const SizedBox(height: 2),
                Text('رصيدك: ${available.toStringAsFixed(0)} جنيه',
                    style: TextStyle(color: context.kSub, fontSize: 11)),
              ],
            ],
          ),
        ),
        Switch(
          value: _useWalletCredit && canUse,
          activeThumbColor: _kGreen,
          onChanged: canUse
              ? (v) => setState(() => _useWalletCredit = v)
              : null,
        ),
      ]),
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
                  color: color ?? (bold ? _kOrange : context.kText))),
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
          border: Border.all(
              color: sel ? m.color : context.kBorder, width: sel ? 2 : 1.5),
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
          _logoCluster(m, sel),
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
              const SizedBox(height: 2),
              Text(m.desc,
                  style: TextStyle(fontSize: 11.5, color: context.kSub)),
            ],
          )),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? m.color : Colors.transparent,
              border:
                  Border.all(color: sel ? m.color : context.kBorder, width: 2),
            ),
            child: sel
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }

  /// Renders the brand logo(s) on the left of a method tile.
  ///
  /// One logo → 56×40 white card with the asset centred.
  /// Two logos (Visa+Mastercard) → both stacked side-by-side in the
  /// same card so the row reads as a single "cards" choice.
  Widget _logoCluster(_PayMethod m, bool selected) {
    return Container(
      width: m.logos.length > 1 ? 76 : 56,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? m.color.withValues(alpha: 0.35)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < m.logos.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Image.asset(
                m.logos[i],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.payment_rounded, size: 22),
              ),
            ),
          ],
        ],
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
            prefixIcon: Icon(icon, size: 18, color: _kOrange),
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
                backgroundColor: _kOrange,
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
                        // Wave 25 — show the deposit (= what's
                        // actually leaving the card) for hybrid
                        // bookings, the full total otherwise.
                        child: Text('$_finalAmount جنيه',
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
  /// Map the UI method id to a backend (provider, method) tuple plus
  /// any extra metadata the gateway needs to disambiguate (e.g. which
  /// wallet brand for a `wallet` payment).
  ///
  /// All methods route through Paymob — the difference is the
  /// `method` enum and the `wallet_type` hint in `extra`.
  ({
    PayProvider provider,
    PayMethod method,
    Map<String, dynamic> extra,
  })? _mapSelection() {
    switch (_sel) {
      case 'card':
      case 'meeza':
        return (
          provider: PayProvider.paymob,
          method: PayMethod.card,
          extra: const {},
        );
      case 'vodafone_cash':
        return (
          provider: PayProvider.paymob,
          method: PayMethod.wallet,
          extra: const {'wallet_type': 'vodafone_cash'},
        );
      case 'orange_cash':
        return (
          provider: PayProvider.paymob,
          method: PayMethod.wallet,
          extra: const {'wallet_type': 'orange_cash'},
        );
      case 'etisalat_cash':
        return (
          provider: PayProvider.paymob,
          method: PayMethod.wallet,
          extra: const {'wallet_type': 'etisalat_cash'},
        );
    }
    return null;
  }

  Future<void> _pay() async {
    final mapped = _mapSelection();
    if (mapped == null) return;

    // The card form is only relevant for the merged Visa/Mastercard
    // row — Meeza and the wallets all delegate the PAN entry to
    // Paymob's hosted iframe, so we don't pre-validate anything for
    // them here.  When the user did opt into our local card form we
    // sanity-check the four fields are complete before calling the
    // gateway.
    if (_sel == 'card' && _numCtrl.text.isNotEmpty) {
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
        walletAmount: _walletDiscount,
      );

      // ── 2. Initiate payment with the chosen gateway ──────────
      final result = await PaymentService.initiate(
        bookingId: booking.id,
        provider: mapped.provider,
        method: mapped.method,
        extra: mapped.extra,
      );

      // ── 3. Open checkout URL inside an in-app WebView ────────
      // Fawry vouchers and COD have no iframe — they jump straight
      // to the status screen which shows the reference number.  For
      // every other provider we host the gateway iframe in-app so
      // the user never leaves Talaa.
      final url = result.checkoutUrl;
      final hasIframe = url != null && url.isNotEmpty;

      if (hasIframe) {
        if (!mounted) return;
        await Navigator.of(context).push<PaymentWebViewOutcome>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PaymentWebViewPage(checkoutUrl: url),
          ),
        );
        // We deliberately ignore the WebView outcome here — the
        // PaymentStatusPage poller is the source of truth and will
        // reflect the gateway webhook once it lands on the backend.
        // The outcome is just a UX hint; success/failure UI is owned
        // by the status screen.
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
