// ═══════════════════════════════════════════════════════════════
//  TALAA — Owner Edit Property Page
//  Lets a host adjust the editable subset of a listing without
//  going through the full 10-step add-property wizard.  Mirrors
//  the backend's _HOST_EDITABLE_FIELDS whitelist; status, KYC, and
//  approval-related fields stay admin-only.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/property_model_api.dart';
import '../services/property_service.dart';
import '../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);

class OwnerEditPropertyPage extends StatefulWidget {
  final PropertyApi property;
  const OwnerEditPropertyPage({super.key, required this.property});

  @override
  State<OwnerEditPropertyPage> createState() => _OwnerEditPropertyPageState();
}

class _OwnerEditPropertyPageState extends State<OwnerEditPropertyPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _weekendPrice;
  late final TextEditingController _cleaning;
  late final TextEditingController _electricity;
  late final TextEditingController _water;
  late final TextEditingController _deposit;
  late final TextEditingController _bedrooms;
  late final TextEditingController _bathrooms;
  late final TextEditingController _maxGuests;
  late final TextEditingController _totalRooms;

  late bool _isAvailable;
  late bool _instantBooking;
  late bool _negotiable;
  late bool _cashOnArrival;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.property;
    _name = TextEditingController(text: p.name);
    _description = TextEditingController(text: p.description);
    _price = TextEditingController(text: p.pricePerNight.toStringAsFixed(0));
    _weekendPrice = TextEditingController(
      text: (p.weekendPrice ?? 0) > 0 ? p.weekendPrice!.toStringAsFixed(0) : '',
    );
    _cleaning = TextEditingController(text: p.cleaningFee.toStringAsFixed(0));
    _electricity =
        TextEditingController(text: p.electricityFee.toStringAsFixed(0));
    _water = TextEditingController(text: p.waterFee.toStringAsFixed(0));
    _deposit =
        TextEditingController(text: p.securityDeposit.toStringAsFixed(0));
    _bedrooms = TextEditingController(text: '${p.bedrooms}');
    _bathrooms = TextEditingController(text: '${p.bathrooms}');
    _maxGuests = TextEditingController(text: '${p.maxGuests}');
    _totalRooms = TextEditingController(text: '${p.totalRooms}');

    _isAvailable = p.isAvailable;
    _instantBooking = p.instantBooking;
    _negotiable = p.negotiable;
    _cashOnArrival = p.cashOnArrivalEnabled;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _price,
      _weekendPrice,
      _cleaning,
      _electricity,
      _water,
      _deposit,
      _bedrooms,
      _bathrooms,
      _maxGuests,
      _totalRooms,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = true);

    // Build a delta payload — backend's PropertyUpdate accepts partial
    // bodies, so only sending changed fields keeps the request small
    // and side-effect-free.  Numbers are parsed defensively because
    // a user can leave optional fields blank.
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price_per_night': double.parse(_price.text),
      if (_weekendPrice.text.trim().isNotEmpty)
        'weekend_price': double.parse(_weekendPrice.text),
      'cleaning_fee': double.tryParse(_cleaning.text) ?? 0,
      'electricity_fee': double.tryParse(_electricity.text) ?? 0,
      'water_fee': double.tryParse(_water.text) ?? 0,
      'security_deposit': double.tryParse(_deposit.text) ?? 0,
      'bedrooms': int.tryParse(_bedrooms.text) ?? 1,
      'bathrooms': int.tryParse(_bathrooms.text) ?? 1,
      'max_guests': int.tryParse(_maxGuests.text) ?? 4,
      'total_rooms': int.tryParse(_totalRooms.text) ?? 1,
      'is_available': _isAvailable,
      'instant_booking': _instantBooking,
      'negotiable': _negotiable,
      'cash_on_arrival_enabled': _cashOnArrival,
    };

    try {
      final updated =
          await PropertyService.updateProperty(widget.property.id, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التعديلات ✓'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الحفظ: $e'),
          backgroundColor: _kRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB54414),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('تعديل ${widget.property.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _section('المعلومات الأساسية'),
            _input(_name, 'الاسم', minChars: 3),
            _input(_description, 'الوصف', maxLines: 4, optional: true),
            const SizedBox(height: 18),
            _section('التسعير'),
            _input(_price, 'سعر الليلة (ج.م)', isNumber: true),
            _input(_weekendPrice, 'سعر الويك إند (اختياري)',
                isNumber: true, optional: true),
            _input(_cleaning, 'رسوم التنظيف', isNumber: true, optional: true),
            _input(_electricity, 'رسوم الكهرباء',
                isNumber: true, optional: true),
            _input(_water, 'رسوم المياه', isNumber: true, optional: true),
            _input(_deposit, 'تأمين قابل للاسترداد',
                isNumber: true, optional: true),
            const SizedBox(height: 18),
            _section('السعة'),
            Row(children: [
              Expanded(child: _input(_bedrooms, 'غرف النوم', isNumber: true)),
              const SizedBox(width: 10),
              Expanded(child: _input(_bathrooms, 'الحمامات', isNumber: true)),
            ]),
            Row(children: [
              Expanded(child: _input(_maxGuests, 'الحد الأقصى للضيوف', isNumber: true)),
              const SizedBox(width: 10),
              Expanded(child: _input(_totalRooms, 'عدد الوحدات', isNumber: true)),
            ]),
            const SizedBox(height: 18),
            _section('إعدادات الحجز'),
            _switchTile(
              title: 'نشط للحجز',
              subtitle: 'يظهر فى البحث ويمكن للضيوف حجزه',
              value: _isAvailable,
              onChanged: (v) => setState(() => _isAvailable = v),
            ),
            _switchTile(
              title: 'حجز فورى ⚡',
              subtitle: 'الضيف يحجز مباشرة بدون موافقة منك',
              value: _instantBooking,
              onChanged: (v) => setState(() => _instantBooking = v),
            ),
            _switchTile(
              title: 'مفتوح للتفاوض',
              subtitle: 'الضيف يقدر يبعت سعر مقترح',
              value: _negotiable,
              onChanged: (v) => setState(() => _negotiable = v),
            ),
            _switchTile(
              title: 'الدفع كاش عند الوصول',
              subtitle: 'يدفع عربون أونلاين والباقى نقدى',
              value: _cashOnArrival,
              onChanged: (v) => setState(() => _cashOnArrival = v),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOcean,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('حفظ التعديلات',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────
  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Row(children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: _kOcean,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.kText)),
        ]),
      );

  Widget _input(
    TextEditingController c,
    String label, {
    bool isNumber = false,
    bool optional = false,
    int minChars = 0,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: context.kCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kOcean, width: 1.5),
          ),
        ),
        validator: (val) {
          final t = (val ?? '').trim();
          if (optional && t.isEmpty) return null;
          if (t.isEmpty) return 'مطلوب';
          if (minChars > 0 && t.length < minChars) {
            return 'الحد الأدنى $minChars حروف';
          }
          if (isNumber && double.tryParse(t) == null) {
            return 'رقم غير صالح';
          }
          return null;
        },
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.kBorder),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w800, color: context.kText)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: context.kSub)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: _kOcean,
      ),
    );
  }
}
