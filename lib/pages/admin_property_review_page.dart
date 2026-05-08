// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Property Review Page (Wave 28)
//
//  Opened from the AdminPendingPage when a moderator taps a card.
//  Surfaces *everything* an admin needs to make an approval call:
//   - Image carousel (tap to zoom — same PhotoViewerPage as guests)
//   - Listing facts (name, area, category, price, fees…)
//   - Owner block (name + verified badge)
//   - **National-ID document images** — front + back, tap-to-zoom
//   - Sticky bottom bar with Approve / Reject / Request-Edit
//
//  Design choice: we keep the guest-facing [PropertyDetailsPage]
//  free of admin concerns and ship a separate page so neither side
//  leaks the other's UI elements.
// ═══════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appSettings;
import '../models/property_model_api.dart';
import '../services/admin_service.dart';
import '../utils/api_client.dart';
import '../utils/app_strings.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';
import 'photo_viewer_page.dart';

const _kOcean = Color(0xFFFF6B35);
const _kOrange = Color(0xFFFF6D00);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFEF5350);

class AdminPropertyReviewPage extends StatefulWidget {
  final PropertyApi property;
  const AdminPropertyReviewPage({super.key, required this.property});

  @override
  State<AdminPropertyReviewPage> createState() =>
      _AdminPropertyReviewPageState();
}

class _AdminPropertyReviewPageState extends State<AdminPropertyReviewPage> {
  late PropertyApi _p;
  final PageController _galleryCtrl = PageController();
  int _galleryIndex = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _p = widget.property;
    appSettings.addListener(_onLangChange);
  }

  void _onLangChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    _galleryCtrl.dispose();
    super.dispose();
  }

  // ── Admin actions ───────────────────────────────────────────
  Future<void> _confirmThen(String title, String body, Color color,
      Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.w900, color: color)),
        content: Text(body, style: TextStyle(color: context.kSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.cancel,
                style: const TextStyle(
                    color: _kOcean, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(S.confirm,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      // Pop with `true` so the pending list refreshes itself.
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final msg = e is ApiException ? ErrorHandler.getDetailOrDefault(e) : '$e';
      _snack(msg, _kRed);
    }
  }

  void _approve() => _confirmThen(
        S.adminApprove,
        S.adminApproveConfirm,
        _kGreen,
        () => AdminService.approveProperty(_p.id),
      );

  void _reject() => _confirmThen(
        S.adminReject,
        S.adminRejectConfirm,
        _kRed,
        () => AdminService.rejectProperty(_p.id),
      );

  void _requestEdit() => _confirmThen(
        S.adminRequestEdit,
        S.adminEditConfirm,
        _kOrange,
        () => AdminService.needsEditProperty(_p.id),
      );

  void _snack(String msg, Color color) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  void _openPhotoViewer(List<String> imgs, int index) {
    if (imgs.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerPage(
          images: imgs,
          initialIndex: index,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final ar = appSettings.arabic;
    return Scaffold(
      backgroundColor: context.kSand,
      bottomNavigationBar: _buildActionBar(),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          backgroundColor: _kOcean,
          expandedHeight: 280,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            ar ? 'مراجعة العقار' : 'Review property',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16),
          ),
          centerTitle: true,
          flexibleSpace: _buildGallery(),
        ),
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildOwnerBlock()),
        SliverToBoxAdapter(child: _buildKycBlock()),
        SliverToBoxAdapter(child: _buildFactsBlock()),
        SliverToBoxAdapter(child: _buildPricingBlock()),
        if (_p.amenities.isNotEmpty)
          SliverToBoxAdapter(child: _buildAmenitiesBlock()),
        if ((_p.description).trim().isNotEmpty)
          SliverToBoxAdapter(child: _buildDescriptionBlock()),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    );
  }

  // ── Gallery ─────────────────────────────────────────────────
  Widget _buildGallery() {
    final imgs = _p.images;
    return Stack(fit: StackFit.expand, children: [
      if (imgs.isEmpty)
        Container(
          color: _kOcean,
          child:
              const Icon(Icons.villa_rounded, color: Colors.white54, size: 80),
        )
      else
        PageView.builder(
          controller: _galleryCtrl,
          physics: const ClampingScrollPhysics(),
          onPageChanged: (i) => setState(() => _galleryIndex = i),
          itemCount: imgs.length,
          itemBuilder: (_, i) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openPhotoViewer(imgs, i),
            child: Hero(
              tag: imgs[i],
              child: CachedNetworkImage(
                imageUrl: imgs[i],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: _kOcean),
                errorWidget: (_, __, ___) => Container(
                  color: _kOcean,
                  child: const Icon(Icons.image_not_supported_rounded,
                      color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
        ),
      if (imgs.length > 1)
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_galleryIndex + 1} / ${imgs.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      // Bottom gradient so the AppBar title stays readable.
      Positioned.fill(
        child: IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Colors.transparent],
                stops: [0.0, 0.4],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Header (name + status + price) ──────────────────────────
  Widget _buildHeader() {
    return Container(
      color: context.kCard,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge(_p.category, _kOcean),
            const SizedBox(width: 8),
            _badge(_p.area, _kOrange),
            const Spacer(),
            _badge(S.statusPending, _kRed),
          ]),
          const SizedBox(height: 12),
          Text(
            _p.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.kText,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.calendar_today_rounded, size: 13, color: context.kSub),
            const SizedBox(width: 4),
            Text(
              '${S.submittedAt}: ${_p.createdAt.day}/${_p.createdAt.month}/${_p.createdAt.year}',
              style: TextStyle(fontSize: 12, color: context.kSub),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.payments_rounded, size: 13, color: _kOcean),
            const SizedBox(width: 4),
            Text(
              '${_p.pricePerNight.toInt()} ${S.egp}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _kOcean,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Owner block ─────────────────────────────────────────────
  Widget _buildOwnerBlock() {
    final ar = appSettings.arabic;
    final owner = _p.owner;
    return _section(
      title: ar ? 'المالك' : 'Owner',
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _kOcean.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            image: owner?.avatarUrl != null
                ? DecorationImage(
                    image: NetworkImage(owner!.avatarUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: owner?.avatarUrl == null
              ? const Icon(Icons.person_rounded,
                  color: _kOcean, size: 24)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                owner?.name ?? (ar ? 'غير معروف' : 'Unknown'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.kText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ID: ${_p.ownerId}',
                style: TextStyle(fontSize: 11, color: context.kSub),
              ),
            ],
          ),
        ),
        if (owner?.isVerified == true)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_rounded,
                  color: _kGreen, size: 14),
              const SizedBox(width: 4),
              Text(
                ar ? 'موثّق' : 'Verified',
                style: const TextStyle(
                  color: _kGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  // ── KYC documents ───────────────────────────────────────────
  Widget _buildKycBlock() {
    final ar = appSettings.arabic;
    final front = _p.idDocumentFrontUrl;
    final back = _p.idDocumentBackUrl;
    final hasAny = (front != null && front.isNotEmpty) ||
        (back != null && back.isNotEmpty);
    return _section(
      title: ar ? 'بطاقة المالك (KYC)' : 'Owner ID document',
      tail: hasAny
          ? null
          : Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ar ? 'لم تُرفع' : 'Not uploaded',
                style: const TextStyle(
                  color: _kRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      child: hasAny
          ? Row(children: [
              Expanded(
                child: _idCard(
                  label: ar ? 'وش البطاقة' : 'ID front',
                  url: front,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _idCard(
                  label: ar ? 'ظهر البطاقة' : 'ID back',
                  url: back,
                ),
              ),
            ])
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kRed.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: _kRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ar
                        ? 'المالك لم يرفع البطاقة الشخصية بعد. يُفضّل رفض الطلب أو طلب تعديل.'
                        : 'Owner has not uploaded their national ID yet. Reject or request edit.',
                    style: TextStyle(fontSize: 12, color: context.kText),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _idCard({required String label, required String? url}) {
    final has = url != null && url.isNotEmpty;
    return GestureDetector(
      onTap: has ? () => _openPhotoViewer([url], 0) : null,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (has)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: context.kBorder.withValues(alpha: 0.4),
                child: const Center(
                  child: CircularProgressIndicator(
                      color: _kOcean, strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: context.kBorder.withValues(alpha: 0.4),
                child: Icon(Icons.broken_image_rounded,
                    color: context.kSub, size: 28),
              ),
            )
          else
            Container(
              color: context.kBorder.withValues(alpha: 0.3),
              child: Icon(Icons.image_not_supported_rounded,
                  color: context.kSub, size: 28),
            ),
          // Bottom label gradient
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (has)
            const PositionedDirectional(
              top: 6,
              end: 6,
              child: Icon(Icons.zoom_in_rounded,
                  color: Colors.white, size: 18),
            ),
        ]),
      ),
    );
  }

  // ── Property facts (rooms, guests, fees…) ───────────────────
  Widget _buildFactsBlock() {
    final ar = appSettings.arabic;
    final facts = <_Fact>[
      _Fact(
          icon: Icons.bed_rounded,
          label: ar ? 'غرف نوم' : 'Bedrooms',
          value: '${_p.bedrooms}'),
      _Fact(
          icon: Icons.bathtub_rounded,
          label: ar ? 'حمامات' : 'Bathrooms',
          value: '${_p.bathrooms}'),
      _Fact(
          icon: Icons.group_rounded,
          label: ar ? 'ضيوف' : 'Guests',
          value: '${_p.maxGuests}'),
      if (_p.totalRooms > 1)
        _Fact(
            icon: Icons.meeting_room_rounded,
            label: ar ? 'إجمالي الغرف' : 'Total rooms',
            value: '${_p.totalRooms}'),
      if (_p.tripDurationHours != null)
        _Fact(
            icon: Icons.timer_rounded,
            label: ar ? 'مدة الرحلة (ساعة)' : 'Trip hours',
            value: '${_p.tripDurationHours}'),
    ];
    return _section(
      title: ar ? 'تفاصيل العقار' : 'Listing facts',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: facts.map((f) => _factChip(f)).toList(),
      ),
    );
  }

  Widget _factChip(_Fact f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.kSand,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(f.icon, size: 14, color: _kOcean),
        const SizedBox(width: 6),
        Text(
          '${f.label}: ',
          style: TextStyle(fontSize: 11, color: context.kSub),
        ),
        Text(
          f.value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: context.kText,
          ),
        ),
      ]),
    );
  }

  // ── Pricing block ───────────────────────────────────────────
  Widget _buildPricingBlock() {
    final ar = appSettings.arabic;
    final rows = <_PriceRow>[
      _PriceRow(
        ar ? 'السعر الأساسي' : 'Base price',
        '${_p.pricePerNight.toInt()} ${S.egp}',
      ),
      if (_p.weekendPrice != null)
        _PriceRow(
          ar ? 'سعر الويك إند' : 'Weekend',
          '${_p.weekendPrice!.toInt()} ${S.egp}',
        ),
      if (_p.pricePerPerson != null)
        _PriceRow(
          ar ? 'سعر الفرد' : 'Per person',
          '${_p.pricePerPerson!.toInt()} ${S.egp}',
        ),
      if (_p.cleaningFee > 0)
        _PriceRow(
          ar ? 'رسوم النظافة' : 'Cleaning fee',
          '${_p.cleaningFee.toInt()} ${S.egp}',
        ),
      if (_p.villageFees > 0)
        _PriceRow(
          ar ? 'رسوم القرية' : 'Village fees',
          '${_p.villageFees.toInt()} ${S.egp}',
        ),
      if (_p.electricityFee > 0)
        _PriceRow(
          ar ? 'رسوم الكهرباء' : 'Electricity',
          '${_p.electricityFee.toInt()} ${S.egp}',
        ),
      if (_p.waterFee > 0)
        _PriceRow(
          ar ? 'رسوم المياه' : 'Water',
          '${_p.waterFee.toInt()} ${S.egp}',
        ),
      _PriceRow(
        ar ? 'المواقف' : 'Parking',
        _p.parkingIsFree
            ? (ar ? 'مجاني' : 'Free')
            : '${_p.parkingFee.toInt()} ${S.egp}',
      ),
    ];
    return _section(
      title: ar ? 'التسعير' : 'Pricing',
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        r.label,
                        style: TextStyle(fontSize: 12, color: context.kSub),
                      ),
                    ),
                    Text(
                      r.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.kText,
                      ),
                    ),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  // ── Amenities ───────────────────────────────────────────────
  Widget _buildAmenitiesBlock() {
    final ar = appSettings.arabic;
    return _section(
      title: ar ? 'المرافق' : 'Amenities',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _p.amenities
            .map((a) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.kSand,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.kBorder),
                  ),
                  child: Text(
                    a,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.kText,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Description ─────────────────────────────────────────────
  Widget _buildDescriptionBlock() {
    final ar = appSettings.arabic;
    return _section(
      title: ar ? 'وصف المالك' : 'Owner description',
      child: Text(
        _p.description,
        style: TextStyle(
          fontSize: 13,
          height: 1.6,
          color: context.kText,
        ),
      ),
    );
  }

  // ── Bottom action bar ───────────────────────────────────────
  Widget _buildActionBar() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: context.kCard,
          border: Border(top: BorderSide(color: context.kBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Expanded(
            child: _actionBtn(
              icon: Icons.cancel_rounded,
              label: S.adminReject,
              color: _kRed,
              onTap: _busy ? null : _reject,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionBtn(
              icon: Icons.edit_note_rounded,
              label: S.adminRequestEdit,
              color: _kOrange,
              onTap: _busy ? null : _requestEdit,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionBtn(
              icon: Icons.check_circle_rounded,
              label: S.adminApprove,
              color: _kGreen,
              onTap: _busy ? null : _approve,
              filled: true,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: filled ? Colors.white : color),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: filled ? Colors.white : color,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────
  Widget _section({
    required String title,
    required Widget child,
    Widget? tail,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: context.kText,
                ),
              ),
            ),
            if (tail != null) tail,
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _Fact {
  final IconData icon;
  final String label;
  final String value;
  const _Fact({required this.icon, required this.label, required this.value});
}

class _PriceRow {
  final String label;
  final String value;
  const _PriceRow(this.label, this.value);
}
