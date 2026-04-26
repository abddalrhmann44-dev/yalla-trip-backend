// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Offer Creation Page
//  Owner creates / manages time-limited promotional offers
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/property_model_api.dart';
import '../services/offer_service.dart';
import '../services/property_service.dart';
import '../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kOrange = Color(0xFFFF6D00);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);

class OfferCreationPage extends StatefulWidget {
  const OfferCreationPage({super.key});
  @override
  State<OfferCreationPage> createState() => _OfferCreationPageState();
}

class _OfferCreationPageState extends State<OfferCreationPage> {
  List<PropertyApi> _properties = [];
  bool _loadingProps = true;

  PropertyApi? _selected;
  final _priceCtrl = TextEditingController();
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _saving = false;
  List<OfferItem> _activeOffers = [];

  // ── Computed ───────────────────────────────────────────────
  DateTime? get _offerStart {
    if (_startDate == null || _startTime == null) return null;
    return DateTime(_startDate!.year, _startDate!.month, _startDate!.day,
        _startTime!.hour, _startTime!.minute);
  }

  DateTime? get _offerEnd {
    if (_endDate == null || _endTime == null) return null;
    return DateTime(_endDate!.year, _endDate!.month, _endDate!.day,
        _endTime!.hour, _endTime!.minute);
  }

  double? get _offerPrice => double.tryParse(_priceCtrl.text.trim());

  bool get _canSave {
    if (_selected == null) return false;
    final p = _offerPrice;
    if (p == null || p <= 0) return false;
    if (p >= _selected!.pricePerNight) return false;
    if (_offerStart == null || _offerEnd == null) return false;
    if (!_offerEnd!.isAfter(_offerStart!)) return false;
    if (_offerEnd!.isBefore(DateTime.now())) return false;
    return true;
  }

  List<OfferItem> get _activeOfferItems => _activeOffers.where((o) => o.isActive).toList();

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProps();
    _loadOffers();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────
  Future<void> _loadProps() async {
    try {
      final list = await PropertyService.getMyProperties();
      if (mounted) setState(() { _properties = list; _loadingProps = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingProps = false);
    }
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await OfferService.getMyOffers();
      if (mounted) setState(() => _activeOffers = offers);
    } catch (_) {}
  }

  // ── Date / time pickers ──────────────────────────────────
  Future<void> _pickDate(bool isStart) async {
    final now   = DateTime.now();
    final first = now;
    final last  = now.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate   ?? (_startDate?.add(const Duration(days: 1)) ?? now.add(const Duration(days: 1)))),
      firstDate: first,
      lastDate:  last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   _kOcean,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) { _startDate = picked; } else { _endDate = picked; }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 14, minute: 0))
          : (_endTime   ?? const TimeOfDay(hour: 12, minute: 0)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   _kOcean,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) { _startTime = picked; } else { _endTime = picked; }
    });
  }

  // ── Actions ───────────────────────────────────────────────
  Future<void> _saveOffer() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      await OfferService.createOffer(
        propertyId: _selected!.id,
        offerPrice: _offerPrice!,
        offerStart: _offerStart!,
        offerEnd: _offerEnd!,
      );
      if (!mounted) return;
      _showSnack('✅ Offer activated successfully!', _kGreen);
      setState(() {
        _selected  = null;
        _priceCtrl.clear();
        _startDate = _endDate = null;
        _startTime = _endTime = null;
      });
      await _loadProps();
      await _loadOffers();
    } catch (e) {
      if (mounted) _showSnack('Error: $e', _kRed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelOffer(OfferItem o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Offer?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Remove the active offer from "${o.propertyName}"?',
            style: TextStyle(color: context.kSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep', style: TextStyle(color: context.kSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel Offer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await OfferService.cancelOffer(o.propertyId);
      _showSnack('Offer removed from "${o.propertyName}"', _kOrange);
      await _loadOffers();
    } catch (e) {
      if (mounted) _showSnack('Error: $e', _kRed);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.kSand,
        body: Column(children: [
          _buildHeader(),
          Expanded(
            child: _loadingProps
                ? const Center(child: CircularProgressIndicator(color: _kOcean))
                : _properties.isEmpty
                    ? _buildNoProperties()
                    : _buildBody(),
          ),
        ]),
      ),
    );
  }

  // ── Gradient header ─────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFB54414), Color(0xFFFF6B35)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 24),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time-Limited Offers',
                      style: TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Create discount offers for your listings',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_offer_rounded, size: 13, color: Colors.white),
                SizedBox(width: 5),
                Text('Offers', style: TextStyle(color: Colors.white,
                    fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Main scrollable body ────────────────────────────────
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ① Create New Offer section
        _sectionHeader('Create New Offer', Icons.add_circle_rounded, _kOcean),
        const SizedBox(height: 14),
        _buildPropertySelector(),
        const SizedBox(height: 14),
        if (_selected != null) ...[
          _buildOfferPriceField(),
          const SizedBox(height: 14),
          _buildDateRangeCard(),
          const SizedBox(height: 16),
          if (_canSave) ...[
            _buildPreviewCard(),
            const SizedBox(height: 16),
          ],
          _buildSaveButton(),
          const SizedBox(height: 28),
        ],

        // ② Active Offers section
        if (_activeOfferItems.isNotEmpty) ...[
          Divider(color: context.kBorder),
          const SizedBox(height: 20),
          _sectionHeader(
              'Your Active Offers (${_activeOfferItems.length})',
              Icons.local_offer_rounded, _kOrange),
          const SizedBox(height: 14),
          ..._activeOfferItems.map(_buildActiveOfferTile),
        ],
      ]),
    );
  }

  // ── Section header ──────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
              color: context.kText))),
    ]);
  }

  // ── Property selector ───────────────────────────────────
  Widget _buildPropertySelector() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fieldLabel(Icons.home_work_rounded, 'Select Property'),
        const SizedBox(height: 10),
        DropdownButtonHideUnderline(
          child: DropdownButton<PropertyApi>(
            value: _selected,
            isExpanded: true,
            hint: Text('Choose a property…',
                style: TextStyle(color: context.kSub, fontSize: 14)),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: context.kSub),
            onChanged: (p) => setState(() {
              _selected = p;
              _priceCtrl.clear();
            }),
            items: _properties.map((p) {
              return DropdownMenuItem<PropertyApi>(
                value: p,
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: p.areaColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(p.categoryEmoji,
                        style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.name, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.kText)),
                      Text('${p.area} · EGP ${p.pricePerNight.toInt()}/night',
                          style: TextStyle(fontSize: 11, color: context.kSub)),
                    ],
                  )),
                  if (_activeOffers.any((o) => o.propertyId == p.id && o.isActive))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
                      ),
                      child: const Text('OFFER', style: TextStyle(
                          color: _kOrange, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                ]),
              );
            }).toList(),
          ),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 8),
          Divider(color: context.kBorder, height: 1),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 13, color: context.kSub),
            const SizedBox(width: 5),
            Text('Current price: EGP ${_selected!.pricePerNight.toInt()} / night',
                style: TextStyle(fontSize: 12, color: context.kSub)),
            if (_activeOffers.any((o) => o.propertyId == _selected!.id && o.isActive)) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
                ),
                child: const Text('Has active offer',
                    style: TextStyle(color: _kOrange,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ],
      ]),
    );
  }

  // ── Offer price field ───────────────────────────────────
  Widget _buildOfferPriceField() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fieldLabel(Icons.sell_rounded, 'Offer Price (EGP / night)'),
        const SizedBox(height: 10),
        TextField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(
              RegExp(r'[0-9.]'))],
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: context.kText),
          decoration: InputDecoration(
            hintText: 'e.g. 1200',
            hintStyle: TextStyle(color: context.kSub),
            prefixIcon: const Icon(Icons.attach_money_rounded, color: _kGreen),
            filled: true,
            fillColor: context.kInputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kOcean, width: 1.5),
            ),
          ),
        ),
        if (_selected != null && _offerPrice != null) ...[
          const SizedBox(height: 8),
          if (_offerPrice! >= _selected!.pricePerNight)
            Row(children: [
              const Icon(Icons.warning_rounded, color: _kRed, size: 14),
              const SizedBox(width: 5),
              Text('Offer price must be lower than EGP ${_selected!.pricePerNight.toInt()}',
                  style: const TextStyle(color: _kRed, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ])
          else
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: _kGreen, size: 14),
              const SizedBox(width: 5),
              Text(
                'Save ${((((_selected!.pricePerNight - _offerPrice!) / _selected!.pricePerNight) * 100).round())}% discount',
                style: const TextStyle(color: _kGreen, fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ]),
        ],
      ]),
    );
  }

  // ── Date range picker card ──────────────────────────────
  Widget _buildDateRangeCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fieldLabel(Icons.date_range_rounded, 'Offer Duration'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _dateTile(
            label: 'Start',
            date: _startDate, time: _startTime,
            icon: Icons.play_arrow_rounded,
            color: _kGreen,
            onDateTap: () => _pickDate(true),
            onTimeTap: () => _pickTime(true),
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded,
                color: context.kSub, size: 18),
          ),
          Expanded(child: _dateTile(
            label: 'End',
            date: _endDate, time: _endTime,
            icon: Icons.stop_rounded,
            color: _kRed,
            onDateTap: () => _pickDate(false),
            onTimeTap: () => _pickTime(false),
          )),
        ]),
        // Duration summary
        if (_offerStart != null && _offerEnd != null) ...[
          const SizedBox(height: 12),
          Divider(color: context.kBorder, height: 1),
          const SizedBox(height: 10),
          if (!_offerEnd!.isAfter(_offerStart!))
            Row(children: const [
              Icon(Icons.error_rounded, color: _kRed, size: 14),
              SizedBox(width: 5),
              Text('End must be after start',
                  style: TextStyle(color: _kRed, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ])
          else
            Row(children: [
              const Icon(Icons.timelapse_rounded,
                  color: _kOcean, size: 14),
              const SizedBox(width: 5),
              Text(_formatDuration(_offerEnd!.difference(_offerStart!)),
                  style: const TextStyle(color: _kOcean, fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
        ],
      ]),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? date,
    required TimeOfDay? time,
    required IconData icon,
    required Color color,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Column(children: [
      Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
            color: color)),
      ]),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onDateTap,
        child: _pickerChip(
          date != null ? _fmtDate(date) : 'Pick date',
          Icons.calendar_today_rounded,
          date != null ? color : context.kSub,
        ),
      ),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onTimeTap,
        child: _pickerChip(
          time != null ? time.format(context) : 'Pick time',
          Icons.access_time_rounded,
          time != null ? color : context.kSub,
        ),
      ),
    ]);
  }

  Widget _pickerChip(String text, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: color),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  // ── Preview card ────────────────────────────────────────
  Widget _buildPreviewCard() {
    final p      = _selected!;
    final price  = _offerPrice!.toInt();
    final disc   = (((p.pricePerNight - price) / p.pricePerNight) * 100).round();
    final dur    = _formatDuration(_offerEnd!.difference(_offerStart!));

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFB54414), Color(0xFFFF6B35)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _kOcean.withValues(alpha: 0.3),
              blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('🔥', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('Offer Preview',
                style: TextStyle(color: Colors.white70, fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$disc% OFF',
                  style: const TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(p.name,
              style: const TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.w900),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(p.area,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12)),
          const SizedBox(height: 14),
          Row(children: [
            // Offer price
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Offer Price',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('EGP $price',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(width: 20),
            // Original price
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Was',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('EGP ${p.pricePerNight.toInt()}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 15,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.white54)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Duration',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text(dur,
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ]),
        ]),
      ),
    );
  }

  // ── Save button ─────────────────────────────────────────
  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _saving ? null : _saveOffer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: _canSave ? _kOcean : context.kBorder,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _canSave
              ? [BoxShadow(color: _kOcean.withValues(alpha: 0.35),
                  blurRadius: 16, offset: const Offset(0, 6))]
              : [],
        ),
        child: Center(
          child: _saving
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Activate Offer',
                      style: TextStyle(color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ]),
        ),
      ),
    );
  }

  // ── Active offer tile ───────────────────────────────────
  Widget _buildActiveOfferTile(OfferItem o) {
    final remain = o.offerEnd.difference(DateTime.now());
    final isValid = remain.isNegative == false;
    final tileColor = isValid ? _kOrange : _kRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tileColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: tileColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(child: Icon(
              isValid ? Icons.local_offer_rounded : Icons.timer_off_rounded,
              color: tileColor, size: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.propertyName, style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w800, color: context.kText),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Text('EGP ${o.originalPrice.toInt()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12,
                      decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 6),
              Text('EGP ${o.offerPrice.toInt()}',
                  style: TextStyle(color: _kGreen, fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text('-${o.discountPercent}%',
                  style: TextStyle(color: tileColor, fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Icon(isValid ? Icons.timer_rounded : Icons.timer_off_rounded,
                  size: 11, color: tileColor),
              const SizedBox(width: 3),
              Text(
                isValid
                    ? 'Ends in ${_formatDuration(remain)}'
                    : 'Expired',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: tileColor),
              ),
            ]),
          ],
        )),
        GestureDetector(
          onTap: () => _cancelOffer(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kRed.withValues(alpha: 0.25)),
            ),
            child: const Text('Cancel',
                style: TextStyle(color: _kRed, fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  // ── No properties state ─────────────────────────────────
  Widget _buildNoProperties() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: _kOcean.withValues(alpha: 0.07),
                shape: BoxShape.circle),
            child: const Icon(Icons.home_work_outlined,
                size: 38, color: _kOcean),
          ),
          const SizedBox(height: 20),
          Text('No Properties Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                  color: context.kText)),
          const SizedBox(height: 8),
          Text('Add a property first, then come back to create offers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.kSub, height: 1.5)),
        ]),
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  Widget _fieldLabel(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 15, color: _kOcean),
      const SizedBox(width: 7),
      Text(text, style: const TextStyle(fontSize: 13,
          fontWeight: FontWeight.w800, color: _kOcean)),
    ]);
  }

  // ── Format helpers ──────────────────────────────────────
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / ${d.year}';

  String _formatDuration(Duration d) {
    if (d.inDays >= 1)   return '${d.inDays} day${d.inDays == 1 ? '' : 's'}';
    if (d.inHours >= 1)  return '${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
    if (d.inMinutes >= 1) return '${d.inMinutes} min';
    return 'Less than a minute';
  }
}
