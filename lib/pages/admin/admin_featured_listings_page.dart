// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Featured Listings Page  (Wave 30)
//
//  Curate the homepage's "أبرز العقارات" rail.  Two tabs:
//    • Featured — currently flagged, ordered by name
//    • All      — every approved property, search + tap to feature
//
//  Toggling fires ``PATCH /admin/properties/{id}/featured`` and is
//  audit-logged on the backend.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/property_model_api.dart';
import '../../services/admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';
import '../property_details_page.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

class AdminFeaturedListingsPage extends StatefulWidget {
  const AdminFeaturedListingsPage({super.key});
  @override
  State<AdminFeaturedListingsPage> createState() =>
      _AdminFeaturedListingsPageState();
}

class _AdminFeaturedListingsPageState extends State<AdminFeaturedListingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loadingAll = true;
  List<PropertyApi> _all = [];
  final Set<int> _busy = {};
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingAll = true);
    try {
      _all = await AdminService.getProperties(
        search: _query.isEmpty ? null : _query,
        limit: 100,
      );
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = v.trim());
      _load();
    });
  }

  Future<void> _toggle(PropertyApi p) async {
    HapticFeedback.lightImpact();
    setState(() => _busy.add(p.id));
    try {
      final updated = await AdminService.setPropertyFeatured(
          p.id, !p.isFeatured);
      if (!mounted) return;
      setState(() {
        final idx = _all.indexWhere((x) => x.id == p.id);
        if (idx != -1) _all[idx] = updated;
      });
      _snack(
        updated.isFeatured
            ? 'تم تمييز العقار ⭐'
            : 'تم إلغاء التمييز',
        _kGreen,
      );
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل العملية: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  void _snack(String msg, Color color) {
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

  @override
  Widget build(BuildContext context) {
    final featured = _all.where((p) => p.isFeatured).toList();
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('العقارات المميزة',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'ابحث عن عقار...',
                  hintStyle: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.white70, size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            TabBar(
              controller: _tab,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(text: 'مميزة (${featured.length})'),
                Tab(text: 'كل العقارات'),
              ],
            ),
          ]),
        ),
      ),
      body: _loadingAll
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : TabBarView(
              controller: _tab,
              children: [
                _buildList(featured, emptyMsg: 'لا يوجد عقارات مميزة بعد'),
                _buildList(_all, emptyMsg: 'لا يوجد عقارات تطابق بحثك'),
              ],
            ),
    );
  }

  Widget _buildList(List<PropertyApi> rows, {required String emptyMsg}) {
    return RefreshIndicator(
      color: _kOcean,
      onRefresh: _load,
      child: rows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                Icon(Icons.star_outline_rounded,
                    size: 64,
                    color: context.kSub.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Center(
                    child: Text(emptyMsg,
                        style: TextStyle(
                            color: context.kSub,
                            fontSize: 14,
                            fontWeight: FontWeight.w600))),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _PropertyRow(
                p: rows[i],
                busy: _busy.contains(rows[i].id),
                onToggle: () => _toggle(rows[i]),
                onOpen: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PropertyDetailsPage(propertyApi: rows[i]),
                  ),
                ),
              ),
            ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  final PropertyApi p;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  const _PropertyRow({
    required this.p,
    required this.busy,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cover = p.images.isNotEmpty ? p.images.first : null;
    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: p.isFeatured
                ? _kAmber.withValues(alpha: 0.5)
                : context.kBorder),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 56,
            height: 56,
            child: cover == null
                ? Container(
                    color: _kOcean.withValues(alpha: 0.15),
                    child: const Icon(Icons.villa_rounded,
                        color: _kOcean, size: 22),
                  )
                : CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: context.kBorder),
                    errorWidget: (_, __, ___) => Container(
                      color: _kOcean.withValues(alpha: 0.15),
                      child: const Icon(Icons.villa_rounded,
                          color: _kOcean, size: 22),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.kText)),
                const SizedBox(height: 2),
                Text('${p.area} • ${p.pricePerNight.toStringAsFixed(0)} ج.م',
                    style: TextStyle(
                        fontSize: 11,
                        color: context.kSub,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: busy ? null : onToggle,
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kAmber))
              : Icon(
                  p.isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: p.isFeatured ? _kAmber : context.kSub,
                  size: 26,
                ),
          tooltip: p.isFeatured ? 'إلغاء التمييز' : 'تمييز',
        ),
      ]),
    );
  }
}
