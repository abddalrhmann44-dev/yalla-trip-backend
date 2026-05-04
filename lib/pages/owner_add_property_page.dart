// ═══════════════════════════════════════════════════════════════
//  TALAA — Owner Add Property Page  (REST API)
//  ✅ Step validation — لا يعدي step إلا لو ملّى الإجباري
//  ✅ الاختياريات (شاطئ/جيم/بسين) مع badge "موصى به"
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import '../main.dart' show userProvider;
import '../services/user_role_service.dart';
import '../services/property_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/constants.dart';
import 'home_page.dart';
import 'phone_verification_page.dart';

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
  _Step('05', 'المرافق', 'اللي موجود جوا الوحدة', '✨'),
  _Step('06', 'المنشآت', 'المزايا العامة للمجمع', '🏊'),
  _Step('07', 'المناطق القريبة', 'إيه الموجود حواليك؟', '📍'),
  _Step('08', 'التسعير', 'حدد أسعارك بنفسك', '💰'),
  _Step('09', 'إعدادات الحجز', 'إزاي الضيوف يحجزوا', '⚙️'),
  _Step('10', 'إثبات الهوية', 'تصوير البطاقة بالكاميرا فقط', '📇'),
];

class _PropType {
  final String key, label, emoji, desc;
  final Color color;
  const _PropType(this.key, this.label, this.emoji, this.desc, this.color);
}

const _kPropTypes = [
  _PropType(
      'شاليه', 'شاليه', '🏖️', 'شاليه بحر أو حمام سباحة', Color(0xFFFF6B35)),
  _PropType('فندق', 'فندق', '🏨', 'فندق خدمة كاملة', Color(0xFF6A1B9A)),
  _PropType('منتجع', 'منتجع', '🏝️', 'منتجع متكامل', Color(0xFF00695C)),
  _PropType('فيلا', 'فيلا', '🏡', 'فيلا فاخرة خاصة', Color(0xFFE65100)),
  _PropType(
      'رحلة يوم واحد', 'رحلة يوم واحد', '☀️', 'دخول وخروج في نفس اليوم بدون مبيت', Color(0xFF0097A7)),
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
  final String emoji, label;
  final bool recommended; // موصى به — اختياري
  bool selected;
  _Toggle(this.emoji, this.label,
      {this.selected = false, this.recommended = false});
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
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selLocation;
  String _checkin = '14:00';
  String _checkout = '12:00';

  // Step 4
  int _bedrooms = 1;
  int _beds = 1;
  int _bathrooms = 1;
  int _guests = 2;
  int _hotelRooms = 1;
  // Boat-specific: max people + trip duration (hours).
  int _boatPeople = 6;
  int _boatHours = 4;

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
      _Toggle('📶', 'واي فاي', selected: true),
      _Toggle('📺', 'تلفزيون ذكي'),
      _Toggle('❄️', 'تكييف', selected: true),
      _Toggle('🍳', 'مطبخ'),
      _Toggle('🧊', 'ثلاجة'),
      _Toggle('🚿', 'مياه ساخنة', selected: true),
      _Toggle('🛋️', 'غرفة معيشة'),
      _Toggle('🌅', 'بلكونة'),
      _Toggle('🧺', 'غسالة'),
      _Toggle('🅿️', 'جراج خاص'),
      _Toggle('🔒', 'خزنة'),
      _Toggle('🌡️', 'تدفئة'),
      _Toggle('☕', 'ماكينة قهوة'),
      _Toggle('🍽️', 'منطقة طعام'),
      _Toggle('💡', 'مكتب عمل'),
    ];

    _facilities = [
      // موصى بيهم (recommended)
      _Toggle('🏖️', 'شاطئ خاص', recommended: true),
      _Toggle('🏊', 'حمام سباحة', recommended: true, selected: true),
      _Toggle('🎢', 'أكوا بارك', recommended: true),
      _Toggle('🏋️', 'جيم', recommended: true),
      _Toggle('🧘', 'سبا', recommended: true),
      // عادي
      _Toggle('🍽️', 'مطعم'),
      _Toggle('☕', 'كافيه'),
      _Toggle('🎮', 'منطقة أطفال'),
      _Toggle('🚗', 'موقف سيارات'),
      _Toggle('🎾', 'ملعب تنس'),
      _Toggle('⚽', 'ملعب كرة قدم'),
      _Toggle('🎪', 'قاعة فعاليات'),
      _Toggle('🩺', 'مركز طبي'),
      _Toggle('🛍️', 'منطقة تسوق'),
      _Toggle('🎯', 'ترفيه'),
    ];

    _nearby = [
      _Toggle('🍽️', 'مطاعم'),
      _Toggle('☕', 'كافيهات'),
      _Toggle('🛒', 'سوبر ماركت'),
      _Toggle('💊', 'صيدلية'),
      _Toggle('🏧', 'ATM'),
      _Toggle('🚑', 'مستشفى'),
      _Toggle('🚕', 'تاكسي'),
      _Toggle('⛽', 'محطة بنزين'),
      _Toggle('🏪', 'بقالة'),
      _Toggle('🎠', 'ملاهي'),
    ];
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _villageCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _weekendCtrl.dispose();
    _cleaningCtrl.dispose();
    super.dispose();
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

      case 1: // الصور — Wave 26: الحد الأدنى 6 صور والحد الأقصى 40
        if (_pickedFiles.length < 6) {
          return 'أضف 6 صور على الأقل (المتبقي: ${6 - _pickedFiles.length})';
        }
        if (_pickedFiles.length > 40) {
          return 'الحد الأقصى 40 صورة (لديك ${_pickedFiles.length})';
        }
        return null;

      case 2: // المعلومات الأساسية
        if (_nameCtrl.text.trim().isEmpty) {
          return 'اكتب اسم العقار';
        }
        if (_selLocation == null) {
          return 'اختار المنطقة';
        }
        if (_villageCtrl.text.trim().isEmpty) {
          return 'اكتب اسم القرية أو المجمع';
        }
        if (_addressCtrl.text.trim().isEmpty) {
          return 'اكتب العنوان التفصيلي';
        }
        if (_descCtrl.text.trim().length < 20) {
          return 'اكتب وصف للعقار (20 حرف على الأقل)';
        }
        return null;

      case 3: // تفاصيل العقار — الـ counters دايماً ≥ 1 فمفيش validation
        return null;

      case 4: // المرافق — اختار واحد على الأقل
        if (_amenities.where((a) => a.selected).isEmpty) {
          return 'اختار مرفق واحد على الأقل';
        }
        return null;

      case 5: // المنشآت — اختياري بالكامل، مش مطلوب
        return null;

      case 6: // المناطق القريبة — اختياري
        return null;

      case 7: // التسعير
        final price = int.tryParse(_priceCtrl.text.trim());
        if (price == null || price <= 0) {
          return 'اكتب السعر العادي في الليلة';
        }
        final weekend = int.tryParse(_weekendCtrl.text.trim());
        if (weekend == null || weekend <= 0) {
          return 'اكتب سعر الويك إند';
        }
        return null;

      case 8: // إعدادات الحجز — دايماً كاملة (bookingMode له default)
        return null;

      case 9: // إثبات الهوية — آخر خطوة
        if (_idFrontImage == null || _idBackImage == null) {
          return 'لازم تصور البطاقة (وش + ظهر) بالكاميرا';
        }
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
    // Wave 23: owner must have a verified phone before their listing
    // can receive chat / bookings.  Intercept the publish flow and
    // route them through the OTP page if needed.
    if (!userProvider.phoneVerified) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PhoneVerificationPage(
            initialPhone: userProvider.phone.isNotEmpty
                ? userProvider.phone
                : null,
            reasonAr:
                'لازم توثّق رقم موبايلك قبل نشر عقارك عشان الضيوف يقدروا يتواصلوا معاك بعد تأكيد الحجز.',
          ),
        ),
      );
      if (ok != true) return; // user backed out — don't publish
      await userProvider.loadProfile(force: true);
    }

    setState(() => _isPublishing = true);
    try {
      final isBoat = _isBoat;

      // Build request payload matching PropertyCreate schema.
      // For boats, ``price_per_night`` is semantically a price-per-hour
      // and ``max_guests`` is the number of passengers; the backend
      // understands this via the ``boat`` category.
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
        'area': _selLocation ?? '',
        'category': _selType?.key ?? '',
        'price_per_night': int.tryParse(_priceCtrl.text) ?? 0,
        if (!isBoat) 'weekend_price': int.tryParse(_weekendCtrl.text),
        if (!isBoat) 'cleaning_fee': int.tryParse(_cleaningCtrl.text) ?? 0,
        'bedrooms': isBoat ? 0 : _bedrooms,
        'bathrooms': isBoat ? 0 : _bathrooms,
        'max_guests': isBoat ? _boatPeople : _guests,
        'total_rooms': isBoat
            ? 0
            : (_selType?.key == 'فندق' ? _hotelRooms : 0),
        if (isBoat) 'trip_duration_hours': _boatHours,
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
                _buildStep5(),
                _buildStep6(),
                _buildStep7(),
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
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('المعلومات الأساسية',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _requiredLabel('كل الحقول مطلوبة'),
      const SizedBox(height: 16),
      _field(_nameCtrl, 'اسم العقار *', 'مثال: شاليه فاخر بإطلالة بحر'),
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
      _field(_villageCtrl, 'اسم القرية / المجمع *', 'مثال: بورتو السخنة'),
      const SizedBox(height: 14),
      _field(_addressCtrl, 'العنوان التفصيلي *', 'مثال: كيلو 108، طريق السخنة'),
      const SizedBox(height: 14),
      _field(_descCtrl, 'وصف العقار *',
          'اكتب وصف شامل للعقار، المميزات، والتجربة...',
          maxLines: 5),
      const SizedBox(height: 6),
      Text(
        '${_descCtrl.text.trim().length} / 20 حرف كحد أدنى',
        style: TextStyle(
            fontSize: 11,
            color: _descCtrl.text.trim().length >= 20 ? _kGreen : context.kSub),
      ),
      const SizedBox(height: 20),
      Text('أوقات الدخول والخروج',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: context.kText)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _timeField(
                'وقت الوصول', _checkin, (v) => setState(() => _checkin = v))),
        const SizedBox(width: 12),
        Expanded(
            child: _timeField('وقت المغادرة', _checkout,
                (v) => setState(() => _checkout = v))),
      ]),
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

    // ── Default property layout ──
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('تفاصيل العقار',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 16),
      _counter('🛏️  غرف النوم', _bedrooms,
          (v) => setState(() => _bedrooms = v), 1, 20),
      _counter('🛌  الأسرة', _beds, (v) => setState(() => _beds = v), 1, 30),
      _counter('🚿  الحمامات', _bathrooms,
          (v) => setState(() => _bathrooms = v), 1, 10),
      _counter(
          '👥  أقصى ضيوف', _guests, (v) => setState(() => _guests = v), 1, 30),
      if (_selType?.key == 'فندق')
        _counter('🚪  عدد الغرف المتاحة', _hotelRooms,
            (v) => setState(() => _hotelRooms = v), 1, 300),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 5 — AMENITIES (اختار واحد على الأقل)
  // ══════════════════════════════════════════════════════════
  Widget _buildStep5() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('المرافق الداخلية',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _requiredLabel('اختار واحد على الأقل'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _amenities
            .map((t) => GestureDetector(
                  onTap: () => setState(() => t.selected = !t.selected),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          t.selected ? _kOcean.withValues(alpha: 0.1) : context.kCard,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: t.selected ? _kOcean : context.kBorder,
                          width: t.selected ? 2 : 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.selected ? _kOcean : context.kText)),
                    ]),
                  ),
                ))
            .toList(),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 6 — FACILITIES (الاختياريات مع "موصى به")
  // ══════════════════════════════════════════════════════════
  Widget _buildStep6() {
    final recommended = _facilities.where((f) => f.recommended).toList();
    final regular = _facilities.where((f) => !f.recommended).toList();

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('منشآت المجمع',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _optionalLabel('اختياري — اختار اللي موجود عندك'),
      const SizedBox(height: 16),

      // Recommended section
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kOrange.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kOrange.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('⭐', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            const Text('موصى به — بيزيد الحجوزات كتير',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _kOrange)),
          ]),
          const SizedBox(height: 12),
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
                          Text(t.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 5),
                          Text(t.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: t.selected ? _kOrange : context.kText)),
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

      const SizedBox(height: 16),

      // Regular
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: regular
            .map((t) => GestureDetector(
                  onTap: () => setState(() => t.selected = !t.selected),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          t.selected ? _kOcean.withValues(alpha: 0.1) : context.kCard,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: t.selected ? _kOcean : context.kBorder,
                          width: t.selected ? 2 : 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.selected ? _kOcean : context.kText)),
                    ]),
                  ),
                ))
            .toList(),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 7 — NEARBY (اختياري)
  // ══════════════════════════════════════════════════════════
  Widget _buildStep7() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('المناطق القريبة',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _optionalLabel('اختياري'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _nearby
            .map((t) => GestureDetector(
                  onTap: () => setState(() => t.selected = !t.selected),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          t.selected ? _kOcean.withValues(alpha: 0.1) : context.kCard,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: t.selected ? _kOcean : context.kBorder,
                          width: t.selected ? 2 : 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.selected ? _kOcean : context.kText)),
                    ]),
                  ),
                ))
            .toList(),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 8 — PRICING
  // ══════════════════════════════════════════════════════════
  Widget _buildStep8() {
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
      ]);
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('التسعير',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _requiredLabel('السعر العادي وسعر الويك إند مطلوبين'),
      const SizedBox(height: 16),
      _priceField(_priceCtrl, 'السعر العادي *', 'في الليلة', required: true),
      const SizedBox(height: 14),
      _priceField(_weekendCtrl, 'سعر الويك إند *', 'جمعة وسبت', required: true),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
            child: _priceField(_cleaningCtrl, 'رسوم التنظيف', 'لكل إقامة')),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.kSub.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('اختياري',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: context.kSub)),
        ),
      ]),
    ]);
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
  //  STEP 10 — IDENTITY  (camera-only ID capture)
  // ══════════════════════════════════════════════════════════
  Widget _buildStep10() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('إثبات الهوية',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      _requiredLabel('تصوير البطاقة بالكاميرا فقط'),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFE85A24)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_user_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('خطوة أخيرة — تأمين حسابك',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(
                  'محتاجين صورة بطاقتك القومية (وش + ظهر) — الصور بتتخزن مشفرة ومش بتظهر للضيوف نهائياً.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.4),
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
      const SizedBox(height: 18),
      Row(children: [
        Icon(Icons.lock_rounded, size: 14, color: context.kSub),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'الصور بتتبعت لسيرفرات Talaa مباشرة بتشفير SSL 256-bit.',
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
          {int maxLines = 1}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
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
