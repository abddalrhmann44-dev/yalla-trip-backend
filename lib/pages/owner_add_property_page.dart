// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Owner Add Property Page
//  Firebase Storage (images) + Firestore (data)
//  ✅ Step validation — لا يعدي step إلا لو ملّى الإجباري
//  ✅ الاختياريات (شاطئ/جيم/بسين) مع badge "موصى به"
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import '../services/user_role_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/property_model.dart';
import 'home_page.dart';

const _kOcean = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kSand = Color(0xFFF5F3EE);
const _kCard = Colors.white;
const _kText = Color(0xFF0D1B2A);
const _kSub = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFEF5350);

class _Step {
  final String number, title, subtitle, icon;
  const _Step(this.number, this.title, this.subtitle, this.icon);
}

const _kSteps = [
  _Step('01', 'نوع العقار', 'إيه نوع عقارك؟', '🏷️'),
  _Step('02', 'الصور', 'وريهم أحسن زوايا', '📸'),
  _Step('03', 'المعلومات الأساسية', 'الاسم والموقع والوصف', '📝'),
  _Step('04', 'تفاصيل العقار', 'الغرف والأسرة والطاقة الاستيعابية', '🛏️'),
  _Step('05', 'المرافق', 'إيه اللي موجود عندك؟', '✨'),
  _Step('06', 'المنشآت', 'مزايا المنتجع والفندق', '🏊'),
  _Step('07', 'المناطق القريبة', 'إيه الموجود حواليك؟', '📍'),
  _Step('08', 'التسعير', 'حدد أسعارك', '💰'),
  _Step('09', 'إعدادات الحجز', 'إزاي الضيوف يحجزوا', '⚙️'),
];

class _PropType {
  final String key, label, emoji, desc;
  final Color color;
  const _PropType(this.key, this.label, this.emoji, this.desc, this.color);
}

const _kPropTypes = [
  _PropType(
      'شاليه', 'شاليه', '🏖️', 'شاليه بحر أو حمام سباحة', Color(0xFF1565C0)),
  _PropType('فندق', 'فندق', '🏨', 'فندق خدمة كاملة', Color(0xFF6A1B9A)),
  _PropType('منتجع', 'منتجع', '🏝️', 'منتجع متكامل', Color(0xFF00695C)),
  _PropType('فيلا', 'فيلا', '🏡', 'فيلا فاخرة خاصة', Color(0xFFE65100)),
  _PropType(
      'بيت شاطئ', 'بيت شاطئ', '🌊', 'بيت على الشاطئ مباشرة', Color(0xFF0097A7)),
];

const _kLocations = [
  'عين السخنة',
  'الساحل الشمالي',
  'رأس سدر',
  'الجونة',
  'الغردقة',
  'شرم الشيخ',
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
  int _minNights = 1;
  int _maxNights = 30;

  bool _isPublishing = false;

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
          backgroundColor: Colors.red,
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

      case 1: // الصور
        if (_pickedFiles.isEmpty) {
          return 'أضف صورة واحدة على الأقل للعقار';
        }
        if (_idFrontImage == null || _idBackImage == null) {
          return 'لازم تصوير البطاقة (وش + ظهر) بالكاميرا';
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
    final files = await _picker.pickMultiImage(imageQuality: 80, limit: 10);
    if (files.isEmpty) return;
    setState(() => _pickedFiles.addAll(files));
  }

  Future<void> _pickFromCamera() async {
    final file =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file == null) return;
    setState(() => _pickedFiles.add(file));
  }

  Future<void> _pickIdentityImage({required bool isFront}) async {
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
  }

  void _removeImage(int idx) => setState(() => _pickedFiles.removeAt(idx));

  Future<List<String>> _uploadImages(String docId) async {
    final urls = <String>[];
    final storage = FirebaseStorage.instance;
    for (int i = 0; i < _pickedFiles.length; i++) {
      final file = File(_pickedFiles[i].path);
      final ref = storage.ref('properties/$docId/img_$i.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<Map<String, String>> _uploadIdentityImages(String ownerId) async {
    if (_idFrontImage == null || _idBackImage == null) {
      throw Exception('identity_images_required');
    }
    final storage = FirebaseStorage.instance;
    final frontRef = storage.ref('owner_identity/$ownerId/id_front.jpg');
    final backRef = storage.ref('owner_identity/$ownerId/id_back.jpg');
    await frontRef.putFile(File(_idFrontImage!.path));
    await backRef.putFile(File(_idBackImage!.path));
    final frontUrl = await frontRef.getDownloadURL();
    final backUrl = await backRef.getDownloadURL();
    return {'front': frontUrl, 'back': backUrl};
  }

  // ── Publish ─────────────────────────────────────────────────
  Future<void> _publish() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isPublishing = true);
    try {
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('properties').doc();

      setState(() => _uploadingImages = true);
      final imageUrls = await _uploadImages(docRef.id);
      final identityUrls = await _uploadIdentityImages(user.uid);
      setState(() => _uploadingImages = false);

      final data = PropertyModel(
        id: docRef.id,
        name: _nameCtrl.text.trim(),
        area: _selLocation ?? '',
        location: _villageCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _selType?.key ?? '',
        ownerId: user.uid,
        ownerName: user.displayName ?? 'مالك',
        price: int.tryParse(_priceCtrl.text) ?? 0,
        weekendPrice: int.tryParse(_weekendCtrl.text) ?? 0,
        cleaningFee: int.tryParse(_cleaningCtrl.text) ?? 0,
        rating: 0.0,
        reviewCount: 0,
        bedrooms: _bedrooms,
        beds: _beds,
        bathrooms: _bathrooms,
        maxGuests: _guests,
        images: imageUrls,
        amenities:
            _amenities.where((a) => a.selected).map((a) => a.label).toList(),
        facilities:
            _facilities.where((f) => f.selected).map((f) => f.label).toList(),
        nearby: _nearby.where((n) => n.selected).map((n) => n.label).toList(),
        instant: _bookingMode == 'instant',
        online: true,
        featured: false,
        available: true,
        autoConfirm: _autoConfirm,
        requireId: _requireId,
        minNights: _minNights,
        maxNights: _maxNights,
        totalRooms: _selType?.key == 'فندق' ? _hotelRooms : 0,
        availableRooms: _selType?.key == 'فندق' ? _hotelRooms : 0,
        blockedDates: const [],
        bookingMode: _bookingMode,
        currency: 'EGP',
        checkinTime: _checkin,
        checkoutTime: _checkout,
        createdAt: DateTime.now(),
      );

      await docRef.set(data.toFirestore());
      await db.collection('users').doc(user.uid).set({
        'identityVerified': true,
        'idFrontUrl': identityUrls['front'] ?? '',
        'idBackUrl': identityUrls['back'] ?? '',
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _isPublishing = false);
      _showSuccessDialog(docRef.id);
    } catch (e) {
      setState(() {
        _isPublishing = false;
        _uploadingImages = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حصل خطأ: $e'), backgroundColor: Colors.red),
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
                child: const Icon(Icons.check_circle_rounded,
                    color: _kGreen, size: 48)),
            const SizedBox(height: 20),
            const Text('تم نشر العقار!',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: _kText)),
            const SizedBox(height: 8),
            Text(
                'عقارك دلوقتي ظاهر على Yalla Trip\nكود العقار: ${docId.substring(0, 8).toUpperCase()}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _kSub)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSand,
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
      color: _kCard,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              IconButton(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                    backgroundColor: _kSand, foregroundColor: _kText),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_kSteps[_step].icon}  ${_kSteps[_step].title}',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _kText)),
                  Text(_kSteps[_step].subtitle,
                      style: const TextStyle(fontSize: 12, color: _kSub)),
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
              backgroundColor: _kBorder,
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
      color: _kCard,
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
              color: _kCard, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: _kOcean),
            const SizedBox(height: 20),
            Text(
              _uploadingImages ? 'جاري رفع الصور...' : 'جاري نشر العقار...',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _kText),
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
      const Text('اختار نوع عقارك',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: _kText)),
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
              color: sel ? t.color.withValues(alpha: 0.08) : _kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? t.color : _kBorder, width: sel ? 2.5 : 1.5),
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
                          color: sel ? t.color : _kText)),
                  Text(t.desc,
                      style: const TextStyle(fontSize: 13, color: _kSub)),
                ],
              )),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? t.color : Colors.transparent,
                  border: Border.all(color: sel ? t.color : _kBorder, width: 2),
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
      const Text('صور العقار',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: _kText)),
      const SizedBox(height: 6),
      _requiredLabel('صورة واحدة على الأقل'),
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
      const SizedBox(height: 18),
      const Text('توثيق الهوية (إجباري)',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: _kText)),
      const SizedBox(height: 6),
      const Text('لازم تصور البطاقة بالكاميرا فقط (وش + ظهر)',
          style: TextStyle(fontSize: 12, color: _kSub)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickIdentityImage(isFront: true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _idFrontImage == null
                    ? _kCard
                    : _kGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _idFrontImage == null ? _kBorder : _kGreen,
                  width: _idFrontImage == null ? 1.5 : 2,
                ),
              ),
              child: Column(children: [
                const Icon(Icons.badge_rounded, color: _kText, size: 22),
                const SizedBox(height: 6),
                Text(_idFrontImage == null ? 'البطاقة - الوش' : 'تم تصوير الوش',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _idFrontImage == null ? _kText : _kGreen)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickIdentityImage(isFront: false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _idBackImage == null
                    ? _kCard
                    : _kGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _idBackImage == null ? _kBorder : _kGreen,
                  width: _idBackImage == null ? 1.5 : 2,
                ),
              ),
              child: Column(children: [
                const Icon(Icons.badge_outlined, color: _kText, size: 22),
                const SizedBox(height: 6),
                Text(
                    _idBackImage == null ? 'البطاقة - الظهر' : 'تم تصوير الظهر',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _idBackImage == null ? _kText : _kGreen)),
              ]),
            ),
          ),
        ),
      ]),
      if (_pickedFiles.isNotEmpty) ...[
        const SizedBox(height: 16),
        Row(children: [
          Text('${_pickedFiles.length} صورة تم اختيارها',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _kOcean)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('✅ تمام',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _kGreen)),
          ),
        ]),
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
          child: const Column(children: [
            Text('📸', style: TextStyle(fontSize: 36)),
            SizedBox(height: 10),
            Text('لازم تضيف صورة واحدة على الأقل',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
            SizedBox(height: 4),
            Text('الصور بتزيد فرص الحجز كتير',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _kSub)),
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
      const Text('المعلومات الأساسية',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: _kText)),
      const SizedBox(height: 6),
      _requiredLabel('كل الحقول مطلوبة'),
      const SizedBox(height: 16),
      _field(_nameCtrl, 'اسم العقار *', 'مثال: شاليه فاخر بإطلالة بحر'),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _selLocation,
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
            color: _descCtrl.text.trim().length >= 20 ? _kGreen : _kSub),
      ),
      const SizedBox(height: 20),
      const Text('أوقات الدخول والخروج',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: _kText)),
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
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('تفاصيل العقار',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: _kText)),
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
      const Text('المرافق الداخلية',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: _kText)),
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
                          t.selected ? _kOcean.withValues(alpha: 0.1) : _kCard,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: t.selected ? _kOcean : _kBorder,
                          width: t.selected ? 2 : 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.selected ? _kOcean : _kText)),
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
      const Text('منشآت المجمع',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: _kText)),
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
                              color: t.selected ? _kOrange : _kBorder,
                              width: t.selected ? 2 : 1.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(t.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 5),
                          Text(t.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: t.selected ? _kOrange : _kText)),
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
                          t.selected ? _kOcean.withValues(alpha: 0.1) : _kCard,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: t.selected ? _kOcean : _kBorder,
                          width: t.selected ? 2 : 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.selected ? _kOcean : _kText)),
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
      const Text('المناطق القريبة',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: _kText)),
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
                          t.selected ? _kOcean.withValues(alpha: 0.1) : _kCard,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: t.selected ? _kOcean : _kBorder,
                          width: t.selected ? 2 : 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.selected ? _kOcean : _kText)),
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
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('التسعير',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: _kText)),
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
            color: _kSub.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('اختياري',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _kSub)),
        ),
      ]),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 9 — BOOKING SETTINGS
  // ══════════════════════════════════════════════════════════
  Widget _buildStep9() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('إعدادات الحجز',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: _kText)),
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
              color: sel ? _kOcean.withValues(alpha: 0.06) : _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: sel ? _kOcean : _kBorder, width: sel ? 2 : 1.5),
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
                          color: sel ? _kOcean : _kText)),
                  Text(sub, style: const TextStyle(fontSize: 12, color: _kSub)),
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
      const SizedBox(height: 16),
      _counter('🌙  أقل ليالي', _minNights,
          (v) => setState(() => _minNights = v), 1, 30),
      _counter('🌙  أقصى ليالي', _maxNights,
          (v) => setState(() => _maxNights = v), 1, 90),
    ]);
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
        color: _kSub.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline_rounded, size: 13, color: _kSub),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _kSub)),
      ]),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kSub),
        filled: true,
        fillColor: _kCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kBorder)),
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
            hintText: hint, hintStyle: const TextStyle(color: _kBorder)),
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
          suffixStyle: const TextStyle(color: _kSub, fontSize: 12),
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
      value: value,
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
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _kText)),
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
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _kText)),
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
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _kText)),
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
}
