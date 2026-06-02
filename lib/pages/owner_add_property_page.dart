// ═══════════════════════════════════════════════════════════════
//  TALAA — Owner Add Property Page  (REST API)
//  ✅ Step validation — لا يعدي step إلا لو ملّى الإجباري
//  ✅ الاختياريات (شاطئ/جيم/بسين) مع badge "موصى به"
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import '../models/property_model_api.dart';
import '../services/user_role_service.dart';
import '../services/property_service.dart';
import '../services/offer_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/constants.dart';
import 'home_page.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kOrange = Color(0xFFFF6D00);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFEF5350);

class _Step {
  final String number, title, subtitle, icon;
  const _Step(this.number, this.title, this.subtitle, this.icon);
}

const _kSteps = [
  _Step('01', 'نوع العقار', 'اختار الصنف اللي يناسب عقارك', '🏷️'),
  _Step('02', 'الصور', '6 صور على الأقل — كل ما زادت زاد الحجز', '📸'),
  _Step('03', 'المعلومات الأساسية', 'الاسم والموقع والوصف', '📝'),
  _Step('04', 'تفاصيل العقار', 'الغرف والطاقة الاستيعابية', '🛏️'),
  _Step('05', 'المزايا والمرافق', 'المرافق الداخلية والمنشآت والأماكن القريبة', '✨'),
  _Step('06', 'التسعير', 'حدد أسعارك بنفسك', '💰'),
  _Step('07', 'إعدادات الحجز', 'إزاي الضيوف يحجزوا', '⚙️'),
  _Step('08', 'توثيق الحساب', 'اختياري — تقدر تتخطى وتوثق بعدين', '📇'),
];

class _PropType {
  final String key, label, emoji, desc;
  final Color color;
  const _PropType(this.key, this.label, this.emoji, this.desc, this.color);
}

// Wave 32: split day-use into two visually distinct options so the
// owner can clearly route their listing to the right home-page bucket
// ("رحلة يوم واحد" beach card vs the dedicated "أكوا بارك" filter).
// The keys MUST stay aligned with backend ``Category`` enum values
// (``رحلة يوم واحد`` and ``أكوا بارك``); only the user-facing label /
// emoji / description differ.  Both share identical billing & form
// behavior — see ``_isDayLikePass`` getter below.
const _kPropTypes = [
  _PropType(
      'شاليه', 'شاليه', '🏖️', 'شاليه بحر أو حمام سباحة', Color(0xFFFF6B35)),
  _PropType('فندق', 'فندق', '🏨', 'فندق خدمة كاملة', Color(0xFF6A1B9A)),
  _PropType('منتجع', 'منتجع', '🏝️', 'منتجع متكامل', Color(0xFF00695C)),
  _PropType('فيلا', 'فيلا', '🏡', 'فيلا فاخرة خاصة', Color(0xFFE65100)),
  _PropType(
      'رحلة يوم واحد', 'رحلة يوم - شاطئ', '🏖️',
      'دخول وخروج في نفس اليوم — للشاطئ والبحر فقط', Color(0xFF0097A7)),
  _PropType(
      'أكوا بارك', 'رحلة يوم - أكوا بارك', '🎢',
      'دخول وخروج في نفس اليوم — للأكوا بارك فقط', Color(0xFF0288D1)),
  _PropType(
      'مركب', 'مركب / يخت', '⛵', 'رحلات بحرية بالساعة', Color(0xFFE65100)),
];

// Single source of truth for the host's location dropdown.
// MUST stay in sync with:
//   * ``_kAreas`` in lib/pages/home_page.dart (filter chips)
//   * ``_kDestinations`` in lib/pages/home_page.dart (cards)
//   * ``_areaColor`` / ``_areaIcon`` in lib/pages/area_results_page.dart
//   * ``S.areaName`` in lib/utils/app_strings.dart (i18n)
// If a string here is missing from any of those, the area card on
// the home screen will route to an empty results page.
const _kLocations = [
  'عين السخنة',
  'الساحل الشمالي',
  'العلمين الجديدة',
  'مرسى مطروح',
  'رأس سدر',
  'الجونة',
  'الغردقة',
  'شرم الشيخ',
  'دهب',
  'القاهرة',
  'اسكندرية',
  'الفيوم',
  'سهل حشيش',
  'مرسى علم',
  'الأقصر',
  'أسوان',
];

class _Toggle {
  final String label;
  final bool recommended;
  bool selected;
  XFile? image;
  _Toggle(this.label, {this.selected = false, this.recommended = false});
}

// ══════════════════════════════════════════════════════════════
//  MAIN PAGE
// ══════════════════════════════════════════════════════════════

class OwnerAddPropertyPage extends StatefulWidget {
  const OwnerAddPropertyPage({super.key});
  @override
  State<OwnerAddPropertyPage> createState() => _OwnerAddPropertyPageState();
}

class _OwnerAddPropertyPageState extends State<OwnerAddPropertyPage>
    with TickerProviderStateMixin {
  int _step = 0;
  final PageController _pageCtrl = PageController(keepPage: true);
  late AnimationController _progressCtrl;

  // Step 1
  _PropType? _selType;

  // Step 2
  final List<XFile> _pickedFiles = [];
  final ImagePicker _picker = ImagePicker();
  bool _uploadingImages = false;
  XFile? _idFrontImage;
  XFile? _idBackImage;

  // Step 3
  final _nameCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  // Wave 28: ``_mapsLinkCtrl`` replaces the legacy free-form
  // "detailed address" textbox.  Hosts paste a Google Maps URL and the
  // detail page renders a tappable button that opens the map at the
  // exact pin — a much better UX than guessing from a paragraph.
  final _mapsLinkCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selLocation;
  String _checkin = '14:00';
  String _checkout = '12:00';

  // Step 4
  int _bedrooms = 1;
  int _bathrooms = 1;
  int _guests = 2;
  int _hotelRooms = 1;
  // Boat-specific: max people + trip duration (hours).
  int _boatPeople = 6;
  int _boatHours = 4;
  // Wave 28: replaces the old free-form "عدد الأسرّة" counter.
  // Values match the backend ``AudienceType`` enum.
  String _audienceType = 'both';

  // Step 5 — Amenities (كلها إجبارية من منظور "الحد الأدنى = اختار 1")
  late List<_Toggle> _amenities;

  // Step 6 — Facilities (الاختياريات موصى بيها)
  late List<_Toggle> _facilities;

  // Step 7 — Nearby
  late List<_Toggle> _nearby;

  // Step 8
  final _priceCtrl = TextEditingController();
  final _weekendCtrl = TextEditingController();
  final _cleaningCtrl = TextEditingController();
  // Wave 28: chalet/villa village fees (e.g. resort entry).
  final _villageFeesCtrl = TextEditingController();
  // Wave 28: chalet utility fees (electricity / water).
  final _electricityCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  // Wave 28: optional paid parking — only collected if !parkingIsFree.
  // Even when paid the value is informational and NOT added to the
  // booking total (host collects on arrival).
  bool _parkingIsFree = true;
  final _parkingFeeCtrl = TextEditingController();
  // Wave 28: day-use per-person price.
  final _pricePerPersonCtrl = TextEditingController();

  // ── Step 8 — Limited-time offer (Wave 28) ───────────────────────
  // Optional: when [_hasOffer] is true, the form requires a discounted
  // price strictly less than the regular nightly / per-person rate plus
  // a [_offerStart, _offerEnd] window in the future.  After the
  // property is created we POST /offers/{id} so the listing surfaces in
  // the home-page Offers section with a live countdown.
  bool _hasOffer = false;
  final _offerPriceCtrl = TextEditingController();
  DateTime? _offerStart;
  DateTime? _offerEnd;

  // Step 9
  String _bookingMode = 'instant';
  bool _autoConfirm = true;
  bool _requireId = false;
  // Wave 24 — owner opt-in for chat-based price haggling.  When this
  // is true, guests see a "فاوض" button on the property page that
  // opens a price-negotiation thread (Wave 23).
  bool _negotiable = false;
  // Wave 25 — owner opt-in for hybrid deposit + cash-on-arrival.
  // When true the guest only pays a deposit online (sized to cover
  // the platform commission + at least one nightly rate); the
  // remainder is collected in cash by the host on arrival.
  bool _cashOnArrival = false;
  int _minNights = 1;
  int _maxNights = 30;

  bool _isPublishing = false;
  bool _isPicking = false;

  Future<void> _checkOwnerAccess() async {
    final isOwner = await UserRoleService.instance.isOwner;
    if (!isOwner && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ هذه الصفحة للملاك فقط'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _checkOwnerAccess();
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _progressCtrl.forward();

    _amenities = [
      _Toggle('واي فاي', selected: true),
      _Toggle('تلفزيون ذكي'),
      _Toggle('تكييف', selected: true),
      _Toggle('مطبخ'),
      _Toggle('ثلاجة'),
      _Toggle('مياه ساخنة', selected: true),
      _Toggle('غرفة معيشة'),
      _Toggle('بلكونة'),
      _Toggle('غسالة'),
      _Toggle('جراج خاص'),
      _Toggle('خزنة'),
      _Toggle('تدفئة'),
      _Toggle('ماكينة قهوة'),
      _Toggle('منطقة طعام'),
      _Toggle('مكتب عمل'),
    ];

    _facilities = [
      // موصى بيهم (recommended)
      _Toggle('شاطئ خاص', recommended: true),
      _Toggle('حمام سباحة', recommended: true, selected: true),
      _Toggle('أكوا بارك', recommended: true),
      _Toggle('جيم', recommended: true),
      _Toggle('سبا', recommended: true),
      // عادي
      _Toggle('مطعم'),
      _Toggle('كافيه'),
      _Toggle('منطقة أطفال'),
      _Toggle('موقف سيارات'),
      _Toggle('ملعب تنس'),
      _Toggle('ملعب كرة قدم'),
      _Toggle('قاعة فعاليات'),
      _Toggle('مركز طبي'),
      _Toggle('منطقة تسوق'),
      _Toggle('ترفيه'),
    ];

    _nearby = [
      _Toggle('مطاعم'),
      _Toggle('كافيهات'),
      _Toggle('سوبر ماركت'),
      _Toggle('صيدلية'),
      _Toggle('ATM'),
      _Toggle('مستشفى'),
      _Toggle('تاكسي'),
      _Toggle('محطة بنزين'),
      _Toggle('بقالة'),
      _Toggle('ملاهي'),
    ];
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _villageCtrl.dispose();
    _mapsLinkCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _weekendCtrl.dispose();
    _cleaningCtrl.dispose();
    _villageFeesCtrl.dispose();
    _electricityCtrl.dispose();
    _waterCtrl.dispose();
    _parkingFeeCtrl.dispose();
    _pricePerPersonCtrl.dispose();
    _offerPriceCtrl.dispose();
    super.dispose();
  }

  // ── Offer helpers (Wave 28) ───────────────────────────────
  /// The "regular" price the offer is discounting.  For day-use
  /// listings that's price-per-person; for everything else it's the
  /// nightly / hourly rate from [_priceCtrl].
  int? get _basePriceForOffer => _isDayLikePass
      ? int.tryParse(_pricePerPersonCtrl.text.trim())
      : int.tryParse(_priceCtrl.text.trim());

  /// Convenience: combines [showDatePicker] + [showTimePicker] into a
  /// single async flow and returns a UTC-anchored [DateTime] (or null
  /// if either picker is dismissed).
  Future<DateTime?> _pickDateTime({
    DateTime? initial,
    DateTime? firstDate,
  }) async {
    final now = DateTime.now();
    final init = initial ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: firstDate ?? now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(init),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} — ${two(dt.hour)}:${two(dt.minute)}';
  }

  /// Step 7 (تسعير) validator.  Bundled into its own method because
  /// the shape varies per category and — since Wave 28 — we also
  /// need to validate the optional limited-time offer block (
  /// [_hasOffer] toggle below the regular price form).
  String? _validatePricingStep() {
    // ── 1) Per-category mandatory pricing fields.
    if (_isDayLikePass) {
      final pp = int.tryParse(_pricePerPersonCtrl.text.trim());
      if (pp == null || pp <= 0) {
        return _isAquaPark
            ? 'اكتب سعر تذكرة الفرد للأكوا بارك'
            : 'اكتب سعر الفرد الواحد';
      }
    } else {
      final price = int.tryParse(_priceCtrl.text.trim());
      if (price == null || price <= 0) {
        return _isBoat
            ? 'اكتب السعر في الساعة'
            : 'اكتب السعر العادي في الليلة';
      }
      final weekend = int.tryParse(_weekendCtrl.text.trim());
      if (weekend == null || weekend <= 0) {
        return _isBoat
            ? 'اكتب سعر الويك إند في الساعة'
            : 'اكتب سعر الويك إند';
      }
    }

    // ── 2) Optional limited-time offer (Wave 28).
    if (_hasOffer) {
      final off = int.tryParse(_offerPriceCtrl.text.trim());
      if (off == null || off <= 0) {
        return 'اكتب السعر المخفّض للعرض';
      }
      final base = _basePriceForOffer ?? 0;
      if (base <= 0) {
        return 'حدد السعر العادي قبل ما تضيف عرض';
      }
      if (off >= base) {
        return 'السعر المخفّض لازم يقل عن السعر العادي';
      }
      if (_offerStart == null) {
        return 'حدد تاريخ بداية العرض';
      }
      if (_offerEnd == null) {
        return 'حدد تاريخ نهاية العرض';
      }
      if (!_offerEnd!.isAfter(_offerStart!)) {
        return 'لازم يكون نهاية العرض بعد بدايته';
      }
      if (_offerEnd!.isBefore(DateTime.now())) {
        return 'تاريخ نهاية العرض لازم يكون في المستقبل';
      }
    }

    return null;
  }

  // ══════════════════════════════════════════════════════════
  //  VALIDATION — كل step له شروطه
  // ══════════════════════════════════════════════════════════

  /// يرجع null لو كل شيء تمام، أو رسالة الخطأ
  String? _validateStep(int step) {
    switch (step) {
      case 0: // نوع العقار
        if (_selType == null) {
          return 'اختار نوع العقار أولاً';
        }
        return null;

      case 1: // الصور — الحد الأدنى 6 صور والحد الأقصى 40
        if (_pickedFiles.length < 6) {
          return 'أضف 6 صور على الأقل (المتبقي: ${6 - _pickedFiles.length})';
        }
        if (_pickedFiles.length > 40) {
          return 'الحد الأقصى 40 صورة (لديك ${_pickedFiles.length})';
        }
        return null;

      case 2: // المعلومات الأساسية
        if (_nameCtrl.text.trim().isEmpty) {
          if (_isAquaPark) return 'اكتب اسم الأكوا بارك';
          if (_isDayUse) return 'اكتب اسم الشاطئ';
          return 'اكتب اسم العقار';
        }
        if (_selLocation == null) {
          return 'اختار المنطقة';
        }
        if (!_isDayLikePass && !_isBoat && _villageCtrl.text.trim().isEmpty) {
          return 'اكتب اسم القرية أو المجمع';
        }
        final link = _mapsLinkCtrl.text.trim();
        if (link.isEmpty) {
          return 'حط لينك الموقع من جوجل ماب';
        }
        if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(link)) {
          return 'لينك الموقع لازم يبدأ بـ https://';
        }
        if (_descCtrl.text.trim().length < 20) {
          return 'اكتب وصف للعقار (20 حرف على الأقل)';
        }
        final descError = _checkDescriptionContent(_descCtrl.text);
        if (descError != null) return descError;
        return null;

      case 3: // تفاصيل العقار — الـ counters دايماً ≥ 1 فمفيش validation
        return null;

      case 4: // المزايا والمرافق — اختار مرفق داخلي واحد على الأقل
        if (_amenities.where((a) => a.selected).isEmpty) {
          return 'اختار مرفق واحد على الأقل من المرافق الداخلية';
        }
        return null;

      case 5: // التسعير
        return _validatePricingStep();

      case 6: // إعدادات الحجز — دايماً كاملة (bookingMode له default)
        return null;

      case 7: // توثيق الحساب — اختياري بالكامل
        return null;

      default:
        return null;
    }
  }

  void _showValidationError(String msg) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
      backgroundColor: _kRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Navigation ─────────────────────────────────────────────
  void _goStep(int s) {
    setState(() => _step = s.clamp(0, _kSteps.length - 1));
    _pageCtrl.animateToPage(_step,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic);
    _progressCtrl
      ..reset()
      ..forward();
  }

  void _next() {
    // تحقق من الـ step الحالي
    final error = _validateStep(_step);
    if (error != null) {
      _showValidationError(error);
      return;
    }

    if (_step < _kSteps.length - 1) {
      _goStep(_step + 1);
    } else {
      _publish();
    }
  }

  void _back() {
    if (_step > 0) {
      _goStep(_step - 1);
    } else {
      Navigator.pop(context);
    }
  }

  // ── Pick Images ─────────────────────────────────────────────
  Future<void> _pickImages() async {
    if (_isPicking) return;
    final remaining = 40 - _pickedFiles.length;
    if (remaining <= 0) {
      _showValidationError('وصلت للحد الأقصى 40 صورة');
      return;
    }
    _isPicking = true;
    try {
      // imageQuality:80 forces image_picker to recompress to JPEG,
      // which sidesteps the iPhone HEIC issue entirely.
      final files =
          await _picker.pickMultiImage(imageQuality: 80, limit: remaining);
      if (files.isEmpty) return;
      setState(() => _pickedFiles.addAll(files.take(remaining)));
    } finally {
      _isPicking = false;
    }
  }

  Future<void> _pickFromCamera() async {
    if (_isPicking) return;
    if (_pickedFiles.length >= 40) {
      _showValidationError('وصلت للحد الأقصى 40 صورة');
      return;
    }
    _isPicking = true;
    try {
      final file =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (file == null) return;
      setState(() => _pickedFiles.add(file));
    } finally {
      _isPicking = false;
    }
  }

  Future<void> _pickIdentityImage({required bool isFront}) async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() {
        if (isFront) {
          _idFrontImage = file;
        } else {
          _idBackImage = file;
        }
      });
    } finally {
      _isPicking = false;
    }
  }

  void _removeImage(int idx) => setState(() => _pickedFiles.removeAt(idx));

  // ── Publish ─────────────────────────────────────────────────
  Future<void> _publish() async {
    // Wave 31: phone verification is no longer a precondition for
    // publishing.  Owners can list right after Google sign-in; phone
    // can still be added later from the profile page if they want
    // bookings/chat to surface their number to confirmed guests.

    setState(() => _isPublishing = true);
    try {
      final isBoat = _isBoat;
      final isDayLikePass = _isDayLikePass; // day_use OR aqua_park
      final isChaletOrVilla = _isChalet || _isVilla;

      // Build request payload matching PropertyCreate schema.  Three
      // category-shaped variants:
      //   • boat:    price_per_night = hourly rate; weekend_price = weekend hourly rate.
      //   • day-use: price_per_person drives billing; price_per_night is
      //              ignored server-side (mirrored from price_per_person
      //              in the validator) but we still send a positive value
      //              so the schema's ``ge=0`` doesn't trip.
      //   • stay:    price_per_night + weekend_price + optional fees.
      final pricePerPerson = isDayLikePass
          ? (int.tryParse(_pricePerPersonCtrl.text.trim()) ?? 0)
          : null;
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
        'area': _selLocation ?? '',
        'category': _selType?.key ?? '',
        'audience_type': _audienceType,
        'price_per_night': isDayLikePass
            ? (pricePerPerson ?? 0)
            : (int.tryParse(_priceCtrl.text) ?? 0),
        if (isDayLikePass) 'price_per_person': pricePerPerson,
        if (!isDayLikePass) 'weekend_price': int.tryParse(_weekendCtrl.text),
        // Cleaning fee only travels with chalet / villa / day-use; the
        // backend zeroes it out for everyone else but suppressing it on
        // the wire keeps the payload tidy.
        if (isChaletOrVilla)
          'cleaning_fee': int.tryParse(_cleaningCtrl.text) ?? 0,
        if (_isChalet) ...{
          'electricity_fee': int.tryParse(_electricityCtrl.text) ?? 0,
          'water_fee': int.tryParse(_waterCtrl.text) ?? 0,
        },
        if (isChaletOrVilla) ...{
          'village_fees': int.tryParse(_villageFeesCtrl.text) ?? 0,
          'parking_is_free': _parkingIsFree,
          'parking_fee':
              _parkingIsFree ? 0 : (int.tryParse(_parkingFeeCtrl.text) ?? 0),
        },
        'bedrooms': (isBoat || isDayLikePass) ? 0 : _bedrooms,
        'bathrooms': (isBoat || isDayLikePass) ? 0 : _bathrooms,
        'max_guests': isBoat ? _boatPeople : _guests,
        'total_rooms': isBoat
            ? 0
            : (_selType?.key == 'فندق' ? _hotelRooms : 0),
        if (isBoat) 'trip_duration_hours': _boatHours,
        // Wave 28: village name + Google Maps URL travel as their own
        // top-level keys (the backend split them out of description).
        if (!isDayLikePass && !isBoat && _villageCtrl.text.trim().isNotEmpty)
          'village_name': _villageCtrl.text.trim(),
        if (_mapsLinkCtrl.text.trim().isNotEmpty)
          'location_link': _mapsLinkCtrl.text.trim(),
        'amenities': _amenities
            .where((a) => a.selected)
            .map((a) => a.label)
            .toList(),
        'instant_booking': _bookingMode == 'instant',
        'negotiable': _negotiable,
        'cash_on_arrival_enabled': _cashOnArrival,
      };

      // ── Step A: Create property via API ──
      late final PropertyApi created;
      try {
        created = await PropertyService.createProperty(payload);
      } catch (e) {
        rethrow;  // will be caught below with "إنشاء العقار"
      }

      // ── Step B: Upload gallery images ──
      if (_pickedFiles.isNotEmpty) {
        try {
          setState(() => _uploadingImages = true);
          final files = _pickedFiles.map((xf) => File(xf.path)).toList();
          await PropertyService.uploadImages(created.id, files);
          setState(() => _uploadingImages = false);
        } catch (e) {
          setState(() => _uploadingImages = false);
          if (!mounted) return;
          final msg = e is ApiException ? ErrorHandler.getDetailOrDefault(e) : '$e';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل رفع الصور: $msg'),
              backgroundColor: const Color(0xFFE53935),
            ),
          );
          // Property was created — continue to ID upload
        }
      }

      // ── Step C: Upload owner's ID card ──
      if (_idFrontImage != null && _idBackImage != null) {
        try {
          await PropertyService.uploadIdDocuments(
            created.id,
            front: File(_idFrontImage!.path),
            back: File(_idBackImage!.path),
          );
        } catch (e) {
          if (!mounted) return;
          setState(() => _isPublishing = false);
          final msg = e is ApiException ? ErrorHandler.getDetailOrDefault(e) : '$e';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل رفع البطاقة: $msg'),
              backgroundColor: const Color(0xFFE53935),
            ),
          );
          return;
        }
      }

      // ── Step D: Activate limited-time offer (Wave 28) ──────────────
      // The /offers endpoint is post-create-only since it needs a
      // property id.  We never *block* publish on this — if the offer
      // call fails we still surface the success dialog for the listing
      // itself and just toast the offer-specific error.
      if (_hasOffer && _offerStart != null && _offerEnd != null) {
        try {
          final off = double.parse(_offerPriceCtrl.text.trim());
          await OfferService.createOffer(
            propertyId: created.id,
            offerPrice: off,
            offerStart: _offerStart!,
            offerEnd: _offerEnd!,
          );
        } catch (e) {
          if (mounted) {
            final msg = e is ApiException
                ? ErrorHandler.getDetailOrDefault(e)
                : '$e';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('العقار اتنشر، بس فشل تفعيل العرض: $msg'),
                backgroundColor: const Color(0xFFE53935),
              ),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() => _isPublishing = false);
      _showSuccessDialog(created.id.toString());
    } catch (e) {
      setState(() {
        _isPublishing = false;
        _uploadingImages = false;
      });
      if (!mounted) return;
      final msg = e is ApiException ? ErrorHandler.getDetailOrDefault(e) : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إنشاء العقار: $msg'), backgroundColor: const Color(0xFFE53935)),
      );
    }
  }

  void _showSuccessDialog(String docId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.check_circle_rounded,
                    color: _kGreen, size: 48)),
            const SizedBox(height: 20),
            Text('تم نشر العقار!',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
            const SizedBox(height: 8),
            Text(
                'عقارك دلوقتي ظاهر على Talaa\nكود العقار: #$docId',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.kSub)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (_) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: const Text('روح الرئيسية',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════

  bool get _isBoat => _selType?.key == 'مركب';
  bool get _isDayUse => _selType?.key == 'رحلة يوم واحد';
  bool get _isAquaPark => _selType?.key == 'أكوا بارك';
  /// Both day-use variants (beach + aqua park) share identical form
  /// behavior: per-person pricing, no bedrooms/bathrooms/village name,
  /// no nightly weekend split, no min/max nights.  The ONLY difference
  /// between them is the backend ``category`` value, which routes the
  /// listing to its dedicated home-page bucket ("رحلة يوم واحد" card
  /// vs the "أكوا بارك" filter chip).
  bool get _isDayLikePass => _isDayUse || _isAquaPark;
  bool get _isHotelOrResort =>
      _selType?.key == 'فندق' || _selType?.key == 'منتجع';
  bool get _isChalet => _selType?.key == 'شاليه';
  bool get _isVilla => _selType?.key == 'فيلا';

  /// Validates the description has no embedded phone numbers or links.
  /// Mirrors the backend regex in ``app/schemas/property.py``.
  /// Returns null when clean, otherwise the localised error message.
  String? _checkDescriptionContent(String text) {
    final ar = '٠١٢٣٤٥٦٧٨٩';
    final en = '0123456789';
    var normalised = text;
    for (var i = 0; i < ar.length; i++) {
      normalised = normalised.replaceAll(ar[i], en[i]);
    }
    normalised = normalised
        .replaceAll('\u200b', '')
        .replaceAll('\u200c', '')
        .replaceAll('\u200d', '')
        .replaceAll('\u200e', '')
        .replaceAll('\u200f', '');
    final urlRe = RegExp(
      r'(?:https?:\/\/|www\.|\b\w+\.(?:com|net|org|me|io|app)\b|t\.me\/|wa\.me\/)',
      caseSensitive: false,
    );
    final phoneRe = RegExp(r'(?:\+?\d[\s\-]?){7,}');
    if (urlRe.hasMatch(normalised)) {
      return 'ممنوع إضافة روابط في الوصف';
    }
    if (phoneRe.hasMatch(normalised)) {
      return 'ممنوع إضافة أرقام تليفون في الوصف';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      body: Stack(children: [
        Column(children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
                _buildCombinedAmenitiesStep(),
                _buildStep8(),
                _buildStep9(),
                _buildStep10(),
              ],
            ),
          ),
          _buildBottomBar(),
        ]),
        if (_isPublishing) _buildPublishingOverlay(),
      ]),
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader() {
    final progress = (_step + 1) / _kSteps.length;
    return Container(
      color: context.kCard,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              IconButton(
                onPressed: _back,
                icon: Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                    backgroundColor: context.kSand, foregroundColor: context.kText),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_kSteps[_step].icon}  ${_kSteps[_step].title}',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: context.kText)),
                  Text(_kSteps[_step].subtitle,
                      style: TextStyle(fontSize: 12, color: context.kSub)),
                ],
              )),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: _kOcean.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${_step + 1} / ${_kSteps.length}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _kOcean)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _progressCtrl,
            builder: (_, __) => LinearProgressIndicator(
              value: progress * _progressCtrl.value,
              backgroundColor: context.kBorder,
              valueColor: const AlwaysStoppedAnimation(_kOcean),
              minHeight: 3,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Bottom Bar ───────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isLast = _step == _kSteps.length - 1;
    return Container(
      color: context.kCard,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isPublishing ? null : _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: isLast ? _kGreen : _kOcean,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(
            isLast ? '🚀  نشر العقار' : 'التالي  ←',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _buildPublishingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: context.kCard, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: _kOcean),
            const SizedBox(height: 20),
            Text(
              _uploadingImages ? 'جاري رفع الصور...' : 'جاري نشر العقار...',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: context.kText),
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 1 — TYPE
  // ══════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('اختار نوع عقارك',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _requiredLabel('مطلوب'),
      const SizedBox(height: 16),
      ..._kPropTypes.map((t) {
        final sel = _selType?.key == t.key;
        return GestureDetector(
          onTap: () => setState(() => _selType = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: sel ? t.color.withValues(alpha: 0.08) : context.kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? t.color : context.kBorder, width: sel ? 2.5 : 1.5),
              boxShadow: sel
                  ? [
                      BoxShadow(
                          color: t.color.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ]
                  : [],
            ),
            child: Row(children: [
              Text(t.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.label,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: sel ? t.color : context.kText)),
                  Text(t.desc,
                      style: TextStyle(fontSize: 13, color: context.kSub)),
                ],
              )),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? t.color : Colors.transparent,
                  border: Border.all(color: sel ? t.color : context.kBorder, width: 2),
                ),
                child: sel
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : null,
              ),
            ]),
          ),
        );
      }),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 2 — PHOTOS (الصور تفضل زي ما هي)
  // ══════════════════════════════════════════════════════════
  Widget _buildStep2() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('صور العقار',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _requiredLabel('6 صور على الأقل (الحد الأقصى 40)'),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickImages,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: _kOcean.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: _kOcean.withValues(alpha: 0.3), width: 2),
              ),
              child: Column(children: [
                Icon(Icons.photo_library_rounded,
                    size: 36, color: _kOcean.withValues(alpha: 0.7)),
                const SizedBox(height: 8),
                const Text('من الألبوم',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kOcean)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _pickFromCamera,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: _kOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _kOrange.withValues(alpha: 0.3), width: 2),
              ),
              child: Column(children: [
                Icon(Icons.camera_alt_rounded,
                    size: 36, color: _kOrange.withValues(alpha: 0.7)),
                const SizedBox(height: 8),
                const Text('الكاميرا',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kOrange)),
              ]),
            ),
          ),
        ),
      ]),
      if (_pickedFiles.isNotEmpty) ...[
        const SizedBox(height: 16),
        Builder(builder: (_) {
          // Wave 27: minimum 6 photos.  The badge swaps between
          // "ينقص N" (red) while the host is still under the
          // threshold and "تمام" (green) once they've crossed it,
          // so the floor is visually obvious without waiting for
          // the next-step validator to fire.
          final n = _pickedFiles.length;
          final reachedMin = n >= 6;
          final missing = (6 - n).clamp(0, 6);
          return Row(children: [
            Text('$n / 40 صورة',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kOcean)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: (reachedMin ? _kGreen : _kRed)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                reachedMin ? '✅ تمام' : '⚠️ ينقص $missing',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: reachedMin ? _kGreen : _kRed),
              ),
            ),
          ]);
        }),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: _pickedFiles.length,
          itemBuilder: (_, i) => Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_pickedFiles[i].path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            if (i == 0)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _kOcean, borderRadius: BorderRadius.circular(6)),
                  child: const Text('غلاف',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeImage(i),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
      ] else ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kRed.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kRed.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            const Text('📸', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            Text('لازم تضيف 6 صور على الأقل',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: context.kText)),
            const SizedBox(height: 4),
            Text('الحد الأقصى 40 صورة — كل ما زادت زاد الحجز',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.kSub)),
          ]),
        ),
      ],
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 3 — INFO
  // ══════════════════════════════════════════════════════════
  Widget _buildStep3() {
    final descError = _checkDescriptionContent(_descCtrl.text);
    final nameLabel = _isAquaPark
        ? 'اسم الأكوا بارك *'
        : (_isDayUse ? 'اسم الشاطئ *' : 'اسم العقار *');
    final nameHint = _isAquaPark
        ? 'مثال: مكادي ووتر وورلد'
        : (_isDayUse
            ? 'مثال: شاطئ كليوباترا'
            : 'مثال: شاليه فاخر بإطلالة بحر');
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('المعلومات الأساسية',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _requiredLabel('كل الحقول مطلوبة'),
      const SizedBox(height: 16),
      _field(_nameCtrl, nameLabel, nameHint),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: _selLocation,
        decoration: _inputDec('المنطقة *'),
        items: _kLocations
            .map((l) => DropdownMenuItem(value: l, child: Text(l)))
            .toList(),
        onChanged: (v) => setState(() => _selLocation = v),
      ),
      const SizedBox(height: 14),
      // Village / compound name — only meaningful for stays.  Day-use
      // beach passes, aqua-park tickets and boat trips skip this row
      // because the listing IS the destination itself.
      if (!_isDayLikePass && !_isBoat) ...[
        _field(_villageCtrl, 'اسم القرية / المجمع *', 'مثال: بورتو السخنة'),
        const SizedBox(height: 14),
      ],
      // Wave 28: Google Maps URL replaces the legacy detailed address.
      _field(_mapsLinkCtrl, 'لينك الموقع على جوجل ماب *',
          'https://maps.app.goo.gl/...',
          keyboardType: TextInputType.url),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _kOcean.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: _kOcean),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'افتح خرائط جوجل، اختار العقار، اضغط مشاركة، انسخ اللينك وحطه هنا.',
              style: TextStyle(
                  fontSize: 11, color: context.kSub, height: 1.3),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _field(_descCtrl, 'وصف العقار *',
          'اكتب وصف شامل للعقار، المميزات، والتجربة...',
          maxLines: 5),
      const SizedBox(height: 6),
      // Description guards: minimum length AND no embedded phone/links.
      if (descError != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                size: 14, color: _kRed),
            const SizedBox(width: 6),
            Expanded(
              child: Text(descError,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kRed)),
            ),
          ]),
        )
      else
        Text(
          '${_descCtrl.text.trim().length} / 20 حرف كحد أدنى — ممنوع أرقام تليفون أو روابط',
          style: TextStyle(
              fontSize: 11,
              color:
                  _descCtrl.text.trim().length >= 20 ? _kGreen : context.kSub),
        ),
      // Check-in / check-out times only matter for overnight stays.
      if (!_isDayLikePass && !_isBoat) ...[
        const SizedBox(height: 20),
        Text('أوقات الدخول والخروج',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.kText)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _timeField('وقت الوصول', _checkin,
                  (v) => setState(() => _checkin = v))),
          const SizedBox(width: 12),
          Expanded(
              child: _timeField('وقت المغادرة', _checkout,
                  (v) => setState(() => _checkout = v))),
        ]),
      ],
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 4 — DETAILS
  // ══════════════════════════════════════════════════════════
  Widget _buildStep4() {
    // ── Boat-specific layout: hours + people only ──
    if (_isBoat) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text('تفاصيل المركب',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        const SizedBox(height: 6),
        _requiredLabel('حدد عدد الأفراد ومدة الرحلة'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE65100).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFFE65100).withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Text('⛵', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'المركب بيتحجز بالساعة — حدد السعة القصوى ومتوسط مدة الرحلة.',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE65100)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _counter('👥  عدد الأفراد', _boatPeople,
            (v) => setState(() => _boatPeople = v), 1, 50),
        _counter('⏱️  مدة الرحلة (ساعات)', _boatHours,
            (v) => setState(() => _boatHours = v), 1, 24),
      ]);
    }

    // ── Day-use / Aqua-park layout: just the audience selector
    // (no rooms / beds / max-guests counter; price-per-person handles
    // capacity organically).  Both share this layout — only the title
    // changes so the host knows which type they picked in Step 1.
    if (_isDayLikePass) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text(
          _isAquaPark ? 'تفاصيل الأكوا بارك' : 'تفاصيل الشاطئ',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.kText),
        ),
        const SizedBox(height: 6),
        _optionalLabel('اختار الفئة المستهدفة'),
        const SizedBox(height: 16),
        _audienceSelector(),
      ]);
    }

    // ── Default property layout ──
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('تفاصيل العقار',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 16),
      _counter('🛏️  غرف النوم', _bedrooms,
          (v) => setState(() => _bedrooms = v), 1, 20),
      _counter('🚿  الحمامات', _bathrooms,
          (v) => setState(() => _bathrooms = v), 1, 10),
      _counter(
          '👥  أقصى ضيوف', _guests, (v) => setState(() => _guests = v), 1, 30),
      if (_selType?.key == 'فندق')
        _counter('🚪  عدد الغرف المتاحة', _hotelRooms,
            (v) => setState(() => _hotelRooms = v), 1, 300),
      const SizedBox(height: 8),
      // Wave 28: replaces the old "عدد الأسرّة" counter that was never
      // surfaced anywhere on the guest side.  Audience policy IS
      // surfaced — guests see a chip on the property card.
      _audienceSelector(),
    ]);
  }

  Widget _audienceSelector() {
    const opts = [
      ('family_only', '👨\u200d👩\u200d👧', 'عائلات فقط'),
      ('youth_only', '🧑\u200d🤝\u200d🧑', 'شباب فقط'),
      ('both', '🤝', 'الاتنين عادي'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الفئة المستهدفة',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.kText)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opts.map((o) {
            final (key, emoji, label) = o;
            final sel = _audienceType == key;
            return GestureDetector(
              onTap: () => setState(() => _audienceType = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? _kOcean.withValues(alpha: 0.1)
                      : context.kSand,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: sel ? _kOcean : context.kBorder,
                      width: sel ? 2 : 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel ? _kOcean : context.kText)),
                ]),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Future<void> _pickToggleImage(_Toggle t) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => t.image = picked);
  }

  Widget _uploadDot(_Toggle t, {Color activeColor = _kOcean}) {
    return GestureDetector(
      onTap: () => _pickToggleImage(t),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: t.image != null
              ? Colors.green.withValues(alpha: 0.15)
              : activeColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: t.image != null ? Colors.green : activeColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Icon(
          t.image != null ? Icons.check_rounded : Icons.add_rounded,
          size: 13,
          color: t.image != null ? Colors.green.shade700 : activeColor,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 5 — المزايا والمرافق (مدمج: مرافق + منشآت + قريبة)
  // ══════════════════════════════════════════════════════════
  Widget _buildCombinedAmenitiesStep() {
    final recommended = _facilities.where((f) => f.recommended).toList();
    final regular = _facilities.where((f) => !f.recommended).toList();

    Widget chipRow(List<_Toggle> items, Color activeColor) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((t) => GestureDetector(
                    onTap: () => setState(() => t.selected = !t.selected),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: t.selected
                            ? activeColor.withValues(alpha: 0.1)
                            : context.kCard,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: t.selected ? activeColor : context.kBorder,
                            width: t.selected ? 2 : 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _uploadDot(t, activeColor: activeColor),
                        Text(t.label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    t.selected ? activeColor : context.kText)),
                      ]),
                    ),
                  ))
              .toList(),
        );

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('المزايا والمرافق',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _requiredLabel('اختار مرفق داخلي واحد على الأقل'),
      const SizedBox(height: 16),

      // ── قسم 1: المرافق الداخلية ──
      Text('المرافق الداخلية',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: context.kText)),
      const SizedBox(height: 10),
      chipRow(_amenities, _kOcean),

      const SizedBox(height: 20),
      Divider(color: context.kBorder),
      const SizedBox(height: 16),

      // ── قسم 2: منشآت المجمع ──
      Row(children: [
        Text('منشآت المجمع',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.kText)),
        const SizedBox(width: 8),
        _optionalLabel('اختياري'),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kOrange.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kOrange.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('⭐', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            const Text('موصى به — بيزيد الحجوزات',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _kOrange)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recommended
                .map((t) => GestureDetector(
                      onTap: () => setState(() => t.selected = !t.selected),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.selected
                              ? _kOrange.withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: t.selected ? _kOrange : context.kBorder,
                              width: t.selected ? 2 : 1.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _uploadDot(t, activeColor: _kOrange),
                          Text(t.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      t.selected ? _kOrange : context.kText)),
                          if (t.selected) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle_rounded,
                                size: 13, color: _kOrange),
                          ],
                        ]),
                      ),
                    ))
                .toList(),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      chipRow(regular, _kOcean),

      const SizedBox(height: 20),
      Divider(color: context.kBorder),
      const SizedBox(height: 16),

      // ── قسم 3: المناطق القريبة ──
      Row(children: [
        Text('المناطق القريبة',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.kText)),
        const SizedBox(width: 8),
        _optionalLabel('اختياري'),
      ]),
      const SizedBox(height: 10),
      chipRow(_nearby, _kOcean),
      const SizedBox(height: 8),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 8 — PRICING
  // ══════════════════════════════════════════════════════════
  Widget _buildStep8() {
    // ── Boat: per-hour pricing + weekend per-hour ──
    if (_isBoat) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text('تسعير المركب',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        const SizedBox(height: 6),
        _requiredLabel('السعر للساعة الواحدة'),
        const SizedBox(height: 16),
        _priceField(_priceCtrl, 'السعر في الساعة *', 'لكل ساعة رحلة',
            required: true),
        const SizedBox(height: 14),
        // Wave 28: weekend hourly rate is now mandatory for boats too —
        // that's what was tripping the "اكتب سعر الويك إند" guard on
        // upload before this migration.
        _priceField(_weekendCtrl, 'سعر الويك إند في الساعة *',
            'جمعة وسبت',
            required: true),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: _kOrange, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'الإجمالي للرحلة يحسب تلقائياً = السعر × مدة الرحلة.',
                style: TextStyle(fontSize: 12, color: context.kText),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _buildOfferSection(),
      ]);
    }

    // ── Day-use / Aqua-park: price-per-person, no weekend split,
    // no fees.  Both variants share the same pricing UI but the
    // copy is reworded so aqua-park hosts feel they're filling the
    // right form ("تذكرة الدخول" reads more naturally than
    // "الفرد الواحد" when the listing is a water park).
    if (_isDayLikePass) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text(
          _isAquaPark
              ? 'تسعير تذكرة الأكوا بارك'
              : 'تسعير رحلة اليوم الواحد',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.kText),
        ),
        const SizedBox(height: 6),
        _requiredLabel(
            _isAquaPark ? 'سعر تذكرة الفرد' : 'سعر الفرد الواحد'),
        const SizedBox(height: 16),
        _priceField(
          _pricePerPersonCtrl,
          _isAquaPark ? 'سعر تذكرة الفرد *' : 'سعر الفرد *',
          _isAquaPark ? 'لكل تذكرة دخول' : 'لكل ضيف',
          required: true,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kOcean.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: _kOcean, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isAquaPark
                    ? 'الإجمالي يحسب تلقائياً = سعر التذكرة × عدد الزوار.'
                    : 'الإجمالي يحسب تلقائياً = سعر الفرد × عدد الضيوف.',
                style: TextStyle(fontSize: 12, color: context.kText),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _buildOfferSection(),
      ]);
    }

    // ── Hotel / Resort: only nightly + weekend.  Cleaning, electricity,
    // water and parking are mandatorily included in the room rate, so
    // the form hides those rows entirely.
    if (_isHotelOrResort) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text('التسعير',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        const SizedBox(height: 6),
        _requiredLabel('السعر العادي وسعر الويك إند مطلوبين'),
        const SizedBox(height: 16),
        _priceField(_priceCtrl, 'السعر العادي *', 'في الليلة',
            required: true),
        const SizedBox(height: 14),
        _priceField(_weekendCtrl, 'سعر الويك إند *', 'جمعة وسبت',
            required: true),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: _kGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'النظافة والكهرباء والمية والمواقف كلها بتبقى شاملة في السعر.',
                style: TextStyle(fontSize: 12, color: context.kText),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _buildOfferSection(),
      ]);
    }

    // ── Chalet / Villa: full pricing form with village fees, parking,
    // cleaning, and (chalet only) utility fees.  ──
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('التسعير',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.kText)),
      const SizedBox(height: 6),
      _requiredLabel('السعر العادي وسعر الويك إند مطلوبين'),
      const SizedBox(height: 16),
      _priceField(_priceCtrl, 'السعر العادي *', 'في الليلة',
          required: true),
      const SizedBox(height: 14),
      _priceField(_weekendCtrl, 'سعر الويك إند *', 'جمعة وسبت',
          required: true),
      const SizedBox(height: 18),
      Text('رسوم إضافية',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.kText)),
      const SizedBox(height: 8),
      _optionalLabel('اختياري — تظهر للضيف ضمن تفاصيل التكلفة'),
      const SizedBox(height: 12),
      // Wave 28: village fees come BEFORE cleaning per spec.
      _priceField(_villageFeesCtrl, 'رسوم القرية / المجمع',
          'لكل إقامة'),
      const SizedBox(height: 12),
      _priceField(_cleaningCtrl, 'رسوم التنظيف', 'لكل إقامة'),
      if (_isChalet) ...[
        const SizedBox(height: 12),
        _priceField(_electricityCtrl, 'رسوم الكهرباء', 'لكل إقامة'),
        const SizedBox(height: 12),
        _priceField(_waterCtrl, 'رسوم المياه', 'لكل إقامة'),
      ],
      const SizedBox(height: 18),
      // Parking row — toggle + conditional fee.
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🅿️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
                child: Text('مواقف السيارات مجانية',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: context.kText))),
            Switch.adaptive(
              value: _parkingIsFree,
              activeThumbColor: _kOcean,
              onChanged: (v) => setState(() => _parkingIsFree = v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
          if (!_parkingIsFree) ...[
            const SizedBox(height: 10),
            _priceField(_parkingFeeCtrl, 'رسوم المواقف', 'لكل إقامة'),
            const SizedBox(height: 6),
            Text(
              'المبلغ ده الضيف بيدفعه لك كاش عند الوصول — مش بيتحسب ضمن إجمالي الحجز.',
              style: TextStyle(
                  fontSize: 11, color: context.kSub, height: 1.3),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 18),
      _buildOfferSection(),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 8.5 — LIMITED-TIME OFFER (shared by all categories)
  //  Owner toggles ``عرض محدود الوقت`` to expose three inputs:
  //   • discounted price (must be < the regular base price)
  //   • start date+time
  //   • end   date+time
  //  After the property is created we POST /offers/{id} so it surfaces
  //  in the home page Offers section with a live countdown.
  // ══════════════════════════════════════════════════════════
  Widget _buildOfferSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasOffer ? _kOrange : context.kBorder,
          width: _hasOffer ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('⏱️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'عرض محدود الوقت',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: context.kText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'خلي العقار يظهر في قسم العروض بعداد تنازلي',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.kSub,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _hasOffer,
              activeThumbColor: _kOrange,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => setState(() => _hasOffer = v),
            ),
          ]),
          if (_hasOffer) ...[
            const SizedBox(height: 14),
            _priceField(
              _offerPriceCtrl,
              _isAquaPark
                  ? 'السعر المخفّض للتذكرة *'
                  : (_isDayUse
                      ? 'السعر المخفّض للفرد *'
                      : (_isBoat
                          ? 'السعر المخفّض في الساعة *'
                          : 'السعر المخفّض في الليلة *')),
              'لازم يقل عن السعر العادي',
              required: true,
            ),
            const SizedBox(height: 12),
            _offerDateTile(
              icon: Icons.play_arrow_rounded,
              label: 'بداية العرض',
              value: _offerStart,
              onTap: () async {
                final dt = await _pickDateTime(initial: _offerStart);
                if (dt == null) return;
                setState(() => _offerStart = dt);
              },
            ),
            const SizedBox(height: 10),
            _offerDateTile(
              icon: Icons.stop_rounded,
              label: 'نهاية العرض',
              value: _offerEnd,
              onTap: () async {
                final dt = await _pickDateTime(
                  initial: _offerEnd ?? _offerStart,
                  firstDate: _offerStart,
                );
                if (dt == null) return;
                setState(() => _offerEnd = dt);
              },
            ),
            if (_offerPriceCtrl.text.trim().isNotEmpty &&
                (_basePriceForOffer ?? 0) > 0) ...[
              const SizedBox(height: 10),
              Builder(builder: (_) {
                final base = _basePriceForOffer!;
                final off = int.tryParse(_offerPriceCtrl.text.trim()) ?? 0;
                if (off <= 0 || off >= base) return const SizedBox.shrink();
                final pct = (((base - off) / base) * 100).round();
                return Row(children: [
                  const Icon(Icons.local_offer_rounded,
                      color: _kGreen, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    'خصم $pct% لـ $off بدل $base ج.م',
                    style: const TextStyle(
                      color: _kGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]);
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _offerDateTile({
    required IconData icon,
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.kSand,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.kBorder),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: _kOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value == null ? label : '$label — ${_fmtDateTime(value)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: value == null ? context.kSub : context.kText,
              ),
            ),
          ),
          Icon(Icons.calendar_month_rounded, size: 18, color: context.kSub),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 9 — BOOKING SETTINGS
  // ══════════════════════════════════════════════════════════
  Widget _buildStep9() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('إعدادات الحجز',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 16),
      ...[
        ('instant', '⚡', 'حجز فوري', 'الحجز يتأكد تلقائياً'),
        ('chat', '💬', 'طلب وتأكيد', 'الضيف يبعت طلب وأنت تقبله'),
        ('contact', '📞', 'تواصل أولاً', 'الضيف يتواصل معك قبل الحجز'),
      ].map((item) {
        final (key, emoji, title, sub) = item;
        final sel = _bookingMode == key;
        return GestureDetector(
          onTap: () => setState(() => _bookingMode = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sel ? _kOcean.withValues(alpha: 0.06) : context.kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: sel ? _kOcean : context.kBorder, width: sel ? 2 : 1.5),
            ),
            child: Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: sel ? _kOcean : context.kText)),
                  Text(sub, style: TextStyle(fontSize: 12, color: context.kSub)),
                ],
              )),
              if (sel)
                const Icon(Icons.check_circle_rounded,
                    color: _kOcean, size: 22),
            ]),
          ),
        );
      }),
      const SizedBox(height: 16),
      _switchRow('تأكيد تلقائي', _autoConfirm,
          (v) => setState(() => _autoConfirm = v)),
      _switchRow(
          'طلب إثبات هوية', _requireId, (v) => setState(() => _requireId = v)),
      _negotiableRow(),
      _cashOnArrivalRow(),
      if (!_isBoat) ...[
        const SizedBox(height: 16),
        _counter('🌙  أقل ليالي', _minNights,
            (v) => setState(() => _minNights = v), 1, 30),
        _counter('🌙  أقصى ليالي', _maxNights,
            (v) => setState(() => _maxNights = v), 1, 90),
      ],
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 8 — توثيق الحساب (اختياري)
  // ══════════════════════════════════════════════════════════
  Widget _buildStep10() {
    final bothDone = _idFrontImage != null && _idBackImage != null;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('توثيق الحساب',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _optionalLabel('اختياري — تقدر تنشر وترجع توثق بعدين'),
      const SizedBox(height: 16),

      // Banner إعلامي بدل البنر الإجباري
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kOcean.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kOcean.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kOcean.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.verified_user_rounded, color: _kOcean, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('وثّق حسابك لتبني ثقة أكتر',
                    style: TextStyle(
                        color: context.kText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  'العقارات الموثقة بتاخد أولوية في الظهور وبتزيد ثقة الضيوف.',
                  style: TextStyle(
                      color: context.kSub, fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
          ),
        ]),
      ),

      const SizedBox(height: 18),
      _idCaptureCard(
        title: 'وش البطاقة',
        subtitle: 'الصورة الأمامية — اسمك ورقم البطاقة',
        picked: _idFrontImage,
        onTap: () => _pickIdentityImage(isFront: true),
      ),
      const SizedBox(height: 12),
      _idCaptureCard(
        title: 'ظهر البطاقة',
        subtitle: 'الصورة الخلفية — تاريخ الإصدار',
        picked: _idBackImage,
        onTap: () => _pickIdentityImage(isFront: false),
      ),
      const SizedBox(height: 14),

      if (bothDone)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(Icons.check_circle_rounded, color: _kGreen, size: 18),
            const SizedBox(width: 8),
            Text('تمام! البطاقة محفوظة — اضغط "نشر العقار"',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kGreen)),
          ]),
        )
      else
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.kSand,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.kBorder),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, color: context.kSub, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تقدر تتخطى دلوقتي وتوثق حسابك بعدين من الإعدادات.',
                style: TextStyle(fontSize: 12, color: context.kSub),
              ),
            ),
          ]),
        ),

      const SizedBox(height: 14),
      Row(children: [
        Icon(Icons.lock_rounded, size: 13, color: context.kSub),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'الصور بتتبعت لسيرفرات Talaa بتشفير SSL 256-bit ومش بتظهر للضيوف.',
            style: TextStyle(fontSize: 11, color: context.kSub),
          ),
        ),
      ]),
    ]);
  }

  Widget _idCaptureCard({
    required String title,
    required String subtitle,
    required XFile? picked,
    required VoidCallback onTap,
  }) {
    final done = picked != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? _kGreen.withValues(alpha: 0.06) : context.kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: done ? _kGreen : context.kBorder,
              width: done ? 2 : 1.5),
        ),
        child: Row(children: [
          if (done)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(picked.path),
                width: 72,
                height: 56,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 72,
              height: 56,
              decoration: BoxDecoration(
                color: _kOcean.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: _kOcean, size: 24),
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
                        color: done ? _kGreen : context.kText)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: context.kSub)),
              ],
            ),
          ),
          Icon(
            done ? Icons.check_circle_rounded : Icons.chevron_left_rounded,
            color: done ? _kGreen : context.kSub,
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ══════════════════════════════════════════════════════════

  /// Badge "مطلوب" أحمر
  Widget _requiredLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 13, color: _kRed),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _kRed)),
      ]),
    );
  }

  /// Badge "اختياري" رمادي
  Widget _optionalLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.kSub.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded, size: 13, color: context.kSub),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: context.kSub)),
      ]),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.kSub),
        filled: true,
        fillColor: context.kCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kOcean, width: 2)),
      );

  Widget _field(TextEditingController c, String label, String hint,
          {int maxLines = 1, TextInputType? keyboardType}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}), // لتحديث عداد الحروف
        decoration: _inputDec(label).copyWith(
            hintText: hint, hintStyle: TextStyle(color: context.kBorder)),
      );

  Widget _priceField(TextEditingController c, String label, String suffix,
          {bool required = false}) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _inputDec(label).copyWith(
          prefixText: 'EGP  ',
          suffixText: suffix,
          suffixStyle: TextStyle(color: context.kSub, fontSize: 12),
        ),
      );

  Widget _timeField(
      String label, String value, void Function(String) onChanged) {
    final times = [
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:00',
      '16:00',
      '17:00',
      '18:00'
    ];
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _inputDec(label),
      items:
          times.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (v) {
        if (v != null) {
          onChanged(v);
        }
      },
    );
  }

  Widget _counter(
      String label, int value, void Function(int) onChanged, int min, int max) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: context.kText)),
        const Spacer(),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: _kOcean,
        ),
        SizedBox(
          width: 32,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: context.kText)),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: _kOcean,
        ),
      ]),
    );
  }

  Widget _switchRow(String label, bool value, void Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: context.kText)),
        const Spacer(),
        Switch.adaptive(
          value: value,
          activeThumbColor: _kOcean,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  /// Cash-on-arrival toggle — explains the hybrid model so the
  /// host knows exactly what they're opting into before flipping it.
  Widget _cashOnArrivalRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _cashOnArrival
            ? const Color(0xFFE8F5E9)
            : context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _cashOnArrival
              ? const Color(0xFF2E7D32)
              : context.kBorder,
          width: _cashOnArrival ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        const Text('💵', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'استلم الباقى كاش عند الوصول',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: context.kText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'الضيف يدفع عربون أونلاين (= ليلة واحدة على الأقل + عمولة المنصة) ويدفعلك الباقى كاش لما يوصل — توافق أنت وهو على التسليم داخل التطبيق',
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.kSub,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: _cashOnArrival,
          activeThumbColor: const Color(0xFF2E7D32),
          onChanged: (v) => setState(() => _cashOnArrival = v),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  /// Negotiation toggle — same shape as ``_switchRow`` but with an
  /// emoji + secondary line so the owner understands what enabling
  /// haggling actually does to their listing.
  Widget _negotiableRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _negotiable
            ? const Color(0xFFFFF3E0)
            : context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _negotiable ? const Color(0xFFFF6D00) : context.kBorder,
          width: _negotiable ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        const Text('💬', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اقبل التفاوض على السعر',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: context.kText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'الضيف يقدر يبعتلك عرض سعر مخصوص — تقبل أو ترفض أو ترد بعرض مضاد',
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.kSub,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: _negotiable,
          activeThumbColor: const Color(0xFFFF6D00),
          onChanged: (v) => setState(() => _negotiable = v),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}
