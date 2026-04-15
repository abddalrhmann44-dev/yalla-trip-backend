// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Properties Management  (REST API)
//  List all properties, search, approve/reject/delete
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/constants.dart';
import '../../models/property_model_api.dart';
import '../../services/admin_service.dart';

const _kOcean  = Color(0xFF1565C0);
const _kGreen  = Color(0xFF4CAF50);
const _kOrange = Color(0xFFFF6D00);
const _kRed    = Color(0xFFEF5350);

class AdminPropertiesPage extends StatefulWidget {
  const AdminPropertiesPage({super.key});
  @override
  State<AdminPropertiesPage> createState() => _AdminPropertiesPageState();
}

class _AdminPropertiesPageState extends State<AdminPropertiesPage> {
  List<PropertyApi> _all = [];
  List<PropertyApi> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _all = await AdminService.getProperties(limit: 200);
      _applyFilter();
    } catch (e) {
      debugPrint('Admin properties error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.of(_all);
    } else {
      _filtered = _all
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.area.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q))
          .toList();
    }
  }

  // ── Actions ────────────────────────────────────────────────
  Future<void> _approve(PropertyApi p) async {
    try {
      await AdminService.approveProperty(p.id);
      HapticFeedback.mediumImpact();
      _snack('تمت الموافقة على ${p.name}', _kGreen);
      _load();
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _reject(PropertyApi p) async {
    try {
      await AdminService.rejectProperty(p.id);
      _snack('تم رفض ${p.name}', _kOrange);
      _load();
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _delete(PropertyApi p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف العقار؟',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text('هيتم حذف "${p.name}" نهائياً.',
            style: TextStyle(color: context.kSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء',
                style: TextStyle(
                    color: context.kSub, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حذف',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminService.deleteProperty(p.id);
      HapticFeedback.mediumImpact();
      _snack('تم حذف ${p.name}', _kRed);
      _load();
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: context.kCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.kText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('إدارة العقارات (${_filtered.length})',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() => _applyFilter()),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.kText),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو المنطقة...',
              hintStyle: TextStyle(
                  fontSize: 13, color: context.kSub),
              prefixIcon:
                  Icon(Icons.search_rounded, color: context.kSub, size: 20),
              filled: true,
              fillColor: context.kCard,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kOcean, width: 1.5)),
            ),
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kOcean))
              : _filtered.isEmpty
                  ? Center(
                      child: Text('لا توجد عقارات',
                          style: TextStyle(
                              fontSize: 14, color: context.kSub)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _kOcean,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _propCard(_filtered[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _propCard(PropertyApi p) {
    final img = p.images.isNotEmpty ? p.images.first : null;
    final statusColor = p.isAvailable ? _kGreen : _kOrange;
    final statusText = p.isAvailable ? 'متاح' : 'معلق';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(children: [
        // Image + info
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: img != null
                    ? CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            color: context.kBorder),
                        errorWidget: (_, __, ___) => Container(
                          color: context.kBorder,
                          child: Icon(Icons.image_not_supported_rounded,
                              color: context.kSub, size: 24),
                        ),
                      )
                    : Container(
                        color: context.kBorder,
                        child: Icon(Icons.apartment_rounded,
                            color: context.kSub, size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.kText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        size: 12, color: context.kSub),
                    const SizedBox(width: 2),
                    Text('${p.area} · ${p.category}',
                        style: TextStyle(
                            fontSize: 11, color: context.kSub)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${p.pricePerNight.toStringAsFixed(0)} ج.م/ليلة',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _kOcean)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(statusText,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ),
                  ]),
                ],
              ),
            ),
          ]),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(children: [
            if (!p.isAvailable) ...[
              _actionBtn('موافقة', _kGreen, () => _approve(p)),
              const SizedBox(width: 8),
              _actionBtn('رفض', _kOrange, () => _reject(p)),
              const SizedBox(width: 8),
            ],
            _actionBtn('حذف', _kRed, () => _delete(p)),
          ]),
        ),
      ]),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ),
    );
  }
}
