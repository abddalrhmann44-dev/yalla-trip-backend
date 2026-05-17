// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Owner Detail Page
//  Full owner profile + 3 tabs: Properties / Reviews / Revenue
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/constants.dart';
import '../../models/user_model_api.dart';
import '../../models/property_model_api.dart';
import '../../models/admin_review_item.dart';
import '../../services/admin_service.dart';
import '../../services/payout_service.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kOrange = Color(0xFFFF6D00);
const _kRed    = Color(0xFFEF5350);
const _kPurple = Color(0xFF7E57C2);

class AdminOwnerDetailPage extends StatefulWidget {
  final UserApi owner;
  final List<PropertyApi> ownerProperties;

  const AdminOwnerDetailPage({
    super.key,
    required this.owner,
    required this.ownerProperties,
  });

  @override
  State<AdminOwnerDetailPage> createState() => _AdminOwnerDetailPageState();
}

class _AdminOwnerDetailPageState extends State<AdminOwnerDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late List<PropertyApi> _props;

  // Reviews
  List<AdminReviewItem> _reviews = [];
  bool _reviewsLoading = false;
  bool _reviewsLoaded = false;

  // Payouts
  List<PayoutModel> _payouts = [];
  bool _payoutsLoading = false;
  bool _payoutsLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _props = List.of(widget.ownerProperties);
    _tabs.addListener(() {
      if (_tabs.index == 1 && !_reviewsLoaded) _loadReviews();
      if (_tabs.index == 2 && !_payoutsLoaded) _loadPayouts();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    if (_reviewsLoading) return;
    setState(() => _reviewsLoading = true);
    try {
      // Load reviews for each property this owner has
      final List<AdminReviewItem> all = [];
      for (final p in _props) {
        final result = await AdminService.getReviewsForModeration(
            propertyId: p.id, limit: 30);
        all.addAll(result.items);
      }
      if (mounted) setState(() { _reviews = all; _reviewsLoaded = true; });
    } catch (e) {
      debugPrint('Owner reviews error: $e');
      if (mounted) setState(() => _reviewsLoaded = true);
    }
    if (mounted) setState(() => _reviewsLoading = false);
  }

  Future<void> _loadPayouts() async {
    if (_payoutsLoading) return;
    setState(() => _payoutsLoading = true);
    try {
      final list = await PayoutService.adminList(hostId: widget.owner.id, limit: 50);
      if (mounted) setState(() { _payouts = list; _payoutsLoaded = true; });
    } catch (e) {
      debugPrint('Owner payouts error: $e');
      if (mounted) setState(() => _payoutsLoaded = true);
    }
    if (mounted) setState(() => _payoutsLoading = false);
  }

  // ── Property actions ────────────────────────────────────
  Future<void> _approve(PropertyApi p) async {
    try {
      await AdminService.approveProperty(p.id);
      HapticFeedback.mediumImpact();
      _snack('تمت الموافقة على ${p.name}', _kGreen);
      _refreshProp(p.id, 'approved');
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _reject(PropertyApi p) async {
    try {
      await AdminService.rejectProperty(p.id);
      _snack('تم رفض ${p.name}', _kOrange);
      _refreshProp(p.id, 'rejected');
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _toggleFeatured(PropertyApi p) async {
    try {
      await AdminService.setPropertyFeatured(p.id, !p.isFeatured);
      HapticFeedback.mediumImpact();
      _snack(
        p.isFeatured ? 'تم إلغاء التمييز' : 'تم تمييز ${p.name}',
        _kOrange,
      );
      setState(() {
        final idx = _props.indexWhere((x) => x.id == p.id);
        if (idx != -1) _props[idx] = p.copyWith(isFeatured: !p.isFeatured);
      });
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _deleteProperty(PropertyApi p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف العقار؟',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text('هيتم حذف "${p.name}" نهائياً مع كل حجوزاته.',
            style: TextStyle(color: context.kSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء',
                style: TextStyle(color: context.kSub, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حذف',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminService.deleteProperty(p.id);
      HapticFeedback.mediumImpact();
      _snack('تم حذف ${p.name}', _kRed);
      setState(() => _props.removeWhere((x) => x.id == p.id));
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  void _refreshProp(int id, String newStatus) {
    setState(() {
      final idx = _props.indexWhere((x) => x.id == id);
      if (idx == -1) return;
      _props[idx] = _props[idx].copyWith(status: newStatus);
    });
  }

  // ── Review actions ──────────────────────────────────────
  Future<void> _toggleHide(AdminReviewItem r) async {
    try {
      final updated = await AdminService.setReviewHidden(r.id, !r.isHidden);
      setState(() {
        final idx = _reviews.indexWhere((x) => x.id == r.id);
        if (idx != -1) _reviews[idx] = updated;
      });
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _deleteReview(AdminReviewItem r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف التقييم؟',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('هيتم حذفه نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminService.deleteReview(r.id);
      setState(() => _reviews.removeWhere((x) => x.id == r.id));
      _snack('تم حذف التقييم', _kRed);
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final u = widget.owner;
    final ownerCode = 'OWN-${u.id.toString().padLeft(4, '0')}';

    return Scaffold(
      backgroundColor: context.kSand,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: context.kCard,
            elevation: 0,
            pinned: true,
            expandedHeight: 200,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: context.kText, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _header(u, ownerCode),
            ),
            bottom: TabBar(
              controller: _tabs,
              labelColor: _kOcean,
              unselectedLabelColor: context.kSub,
              indicatorColor: _kOcean,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: 'العقارات'),
                Tab(text: 'التقييمات'),
                Tab(text: 'الإيرادات'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _propertiesTab(),
            _reviewsTab(),
            _revenueTab(),
          ],
        ),
      ),
    );
  }

  Widget _header(UserApi u, String ownerCode) {
    final initials = u.name.isNotEmpty
        ? u.name.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';
    return Container(
      color: context.kCard,
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipOval(
          child: SizedBox(
            width: 64,
            height: 64,
            child: u.avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: u.avatarUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _initialsBox(initials, 64),
                  )
                : _initialsBox(initials, 64),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Expanded(
                  child: Text(u.name,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: context.kText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (u.isVerified)
                  const Icon(Icons.verified_rounded, size: 16, color: _kPurple),
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kOcean.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(ownerCode,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _kOcean,
                        letterSpacing: 0.5)),
              ),
              const SizedBox(height: 6),
              if (u.phone != null)
                Row(children: [
                  Icon(Icons.phone_rounded, size: 12, color: context.kSub),
                  const SizedBox(width: 3),
                  Text(u.phone!,
                      style: TextStyle(fontSize: 11, color: context.kSub)),
                ]),
              if (u.email != null)
                Row(children: [
                  Icon(Icons.email_rounded, size: 12, color: context.kSub),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(u.email!,
                        style: TextStyle(fontSize: 11, color: context.kSub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (u.isActive ? _kGreen : _kRed).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(u.isActive ? 'حساب مُفعّل' : 'حساب موقوف',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: u.isActive ? _kGreen : _kRed)),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _initialsBox(String initials, double size) => Container(
        width: size,
        height: size,
        color: _kOcean.withValues(alpha: 0.15),
        child: Center(
          child: Text(initials,
              style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w900,
                  color: _kOcean)),
        ),
      );

  // ── Tab 1: Properties ───────────────────────────────────
  Widget _propertiesTab() {
    if (_props.isEmpty) {
      return Center(
        child: Text('لا توجد عقارات لهذا المالك',
            style: TextStyle(fontSize: 14, color: context.kSub)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _props.length,
      itemBuilder: (_, i) => _propCard(_props[i]),
    );
  }

  Widget _propCard(PropertyApi p) {
    final img = p.images.isNotEmpty ? p.images.first : null;
    final (statusColor, statusText) = switch (p.status) {
      'approved'   => (_kGreen, 'معتمد'),
      'rejected'   => (_kRed, 'مرفوض'),
      'needs_edit' => (_kOrange, 'يحتاج تعديل'),
      _            => (const Color(0xFFF59E0B), 'في الانتظار'),
    };
    final needsAction = p.status == 'pending' || p.status == 'needs_edit';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: img != null
                    ? CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: context.kBorder),
                        errorWidget: (_, __, ___) => Container(
                          color: context.kBorder,
                          child: Icon(Icons.image_not_supported_rounded,
                              color: context.kSub, size: 20),
                        ),
                      )
                    : Container(
                        color: context.kBorder,
                        child: Icon(Icons.apartment_rounded,
                            color: context.kSub, size: 24),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.kText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${p.area} · ${p.category}',
                      style: TextStyle(fontSize: 11, color: context.kSub)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text('${p.pricePerNight.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _kOcean)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(statusText,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ),
                    if (p.isFeatured) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 14, color: _kOrange),
                    ],
                  ]),
                ],
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            if (needsAction) ...[
              _actionBtn('موافقة', _kGreen, () => _approve(p)),
              _actionBtn('رفض', _kOrange, () => _reject(p)),
            ],
            _actionBtn(
              p.isFeatured ? 'إلغاء التمييز' : 'تمييز',
              _kOrange,
              () => _toggleFeatured(p),
            ),
            _actionBtn('حذف', _kRed, () => _deleteProperty(p)),
          ]),
        ),
      ]),
    );
  }

  // ── Tab 2: Reviews ──────────────────────────────────────
  Widget _reviewsTab() {
    if (_reviewsLoading) {
      return const Center(child: CircularProgressIndicator(color: _kOcean));
    }
    if (_reviews.isEmpty) {
      return Center(
        child: Text('لا توجد تقييمات',
            style: TextStyle(fontSize: 14, color: context.kSub)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _reviews.length,
      itemBuilder: (_, i) => _reviewCard(_reviews[i]),
    );
  }

  Widget _reviewCard(AdminReviewItem r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: r.isHidden
                ? _kRed.withValues(alpha: 0.3)
                : context.kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(r.propertyName ?? 'عقار #${r.propertyId}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.kSub)),
          const Spacer(),
          Row(children: List.generate(5, (i) => Icon(
            i < r.rating.round()
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            size: 14,
            color: _kOrange,
          ))),
        ]),
        if (r.comment != null) ...[
          const SizedBox(height: 6),
          Text(r.comment!,
              style: TextStyle(fontSize: 13, color: context.kText),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 8),
        Row(children: [
          if (r.isHidden)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('مخفي',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: _kRed)),
            ),
          if (r.reportCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _kOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${r.reportCount} بلاغ',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: _kOrange)),
            ),
          ],
          const Spacer(),
          _actionBtn(
            r.isHidden ? 'إظهار' : 'إخفاء',
            r.isHidden ? _kGreen : _kOrange,
            () => _toggleHide(r),
          ),
          const SizedBox(width: 6),
          _actionBtn('حذف', _kRed, () => _deleteReview(r)),
        ]),
      ]),
    );
  }

  // ── Tab 3: Revenue ──────────────────────────────────────
  Widget _revenueTab() {
    if (_payoutsLoading) {
      return const Center(child: CircularProgressIndicator(color: _kOcean));
    }

    final totalPaid = _payouts
        .where((p) => p.status == PayoutStatus.paid)
        .fold<double>(0, (sum, p) => sum + p.totalAmount);
    final totalPending = _payouts
        .where((p) => p.status == PayoutStatus.pending)
        .fold<double>(0, (sum, p) => sum + p.totalAmount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Summary cards
        Row(children: [
          _revenueCard('إجمالي مدفوع', '${totalPaid.toStringAsFixed(0)} ج.م', _kGreen),
          const SizedBox(width: 10),
          _revenueCard('قيد الانتظار', '${totalPending.toStringAsFixed(0)} ج.م', _kOrange),
        ]),
        const SizedBox(height: 16),
        if (_payouts.isEmpty)
          Center(
            child: Text('لا توجد دفعات',
                style: TextStyle(fontSize: 14, color: context.kSub)),
          )
        else ...[
          Text('سجل الدفعات',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.kText)),
          const SizedBox(height: 10),
          ..._payouts.map(_payoutCard),
        ],
      ],
    );
  }

  Widget _revenueCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: context.kSub)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ]),
      ),
    );
  }

  Widget _payoutCard(PayoutModel p) {
    final statusColor = switch (p.status) {
      PayoutStatus.paid       => _kGreen,
      PayoutStatus.processing => _kOcean,
      PayoutStatus.failed     => _kRed,
      _                       => _kOrange,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.payments_rounded, color: statusColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.totalAmount.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: context.kText)),
              Text(
                '${p.cycleStart.day}/${p.cycleStart.month} → ${p.cycleEnd.day}/${p.cycleEnd.month}',
                style: TextStyle(fontSize: 11, color: context.kSub),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(p.status.labelAr,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor)),
        ),
      ]),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}
