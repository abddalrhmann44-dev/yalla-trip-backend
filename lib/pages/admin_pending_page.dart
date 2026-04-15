// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Pending Properties Page  (REST API)
//  Admin can: Approve / Reject / Request Edit
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import '../main.dart' show appSettings;
import '../models/property_model_api.dart';
import '../services/admin_service.dart';

const _kOcean  = Color(0xFF1565C0);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);
const _kOrange = Color(0xFFFF6D00);

class AdminPendingPage extends StatefulWidget {
  const AdminPendingPage({super.key});
  @override
  State<AdminPendingPage> createState() => _AdminPendingPageState();
}

class _AdminPendingPageState extends State<AdminPendingPage> {
  List<PropertyApi> _pending = [];
  bool _loading = true;

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    _load();
  }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all = await AdminService.getProperties(limit: 100);
      // Pending = not yet available (awaiting admin approval)
      final pending = all.where((p) => !p.isAvailable).toList();
      if (mounted) setState(() { _pending = pending; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ════════════════════════════════════════════════════════
  //  ADMIN ACTIONS
  // ════════════════════════════════════════════════════════

  Future<void> _approve(int propId, String propName) async {
    final confirmed = await _confirmDialog(
      S.adminApprove,
      S.adminApproveConfirm,
      _kGreen,
    );
    if (confirmed != true) return;
    try {
      await AdminService.approveProperty(propId);
      _load();
      if (mounted) _snack(S.adminApproved, _kGreen);
    } catch (_) {
      if (mounted) _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _reject(int propId, String propName) async {
    final confirmed = await _confirmDialog(
      S.adminReject,
      S.adminRejectConfirm,
      _kRed,
    );
    if (confirmed != true) return;
    try {
      await AdminService.rejectProperty(propId);
      _load();
      if (mounted) _snack(S.adminRejected, _kRed);
    } catch (_) {
      if (mounted) _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _requestEdit(int propId, String propName) async {
    final confirmed = await _confirmDialog(
      S.adminRequestEdit,
      S.adminEditConfirm,
      _kOrange,
    );
    if (confirmed != true) return;
    try {
      await AdminService.needsEditProperty(propId);
      _load();
      if (mounted) _snack(S.adminEditRequested, _kOrange);
    } catch (_) {
      if (mounted) _snack('حصل خطأ', _kRed);
    }
  }

  // ── Helpers ──────────────────────────────────────────────
  Future<bool?> _confirmDialog(String title, String body, Color color) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
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
  }

  void _snack(String msg, Color color) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
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
        title: Text(S.adminPending,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : _pending.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  color: _kOcean,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pending.length,
                    itemBuilder: (_, i) => _propertyCard(_pending[i]),
                  ),
                ),
    );
  }

  // ── Property Card ────────────────────────────────────────
  Widget _propertyCard(PropertyApi p) {
    final name = p.name;
    final area = p.area;
    final category = p.category;
    final ownerName = p.owner?.name ?? '';
    final images = p.images;
    final createdAt = p.createdAt;
    final price = p.pricePerNight.toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(children: [
        // Image
        if (images.isNotEmpty)
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: CachedNetworkImage(
              imageUrl: images.first,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 180,
                color: context.kBorder,
                child: const Center(
                    child: CircularProgressIndicator(
                        color: _kOcean, strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 180,
                color: context.kBorder,
                child: Icon(Icons.image_not_supported_rounded,
                    size: 40, color: context.kSub),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Status badge + category
            Row(children: [
              _badge(S.statusPending, _kOrange),
              const SizedBox(width: 8),
              _badge(S.catName(category), _kOcean),
              const Spacer(),
              Text('$price ${S.egp}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _kOcean)),
            ]),
            const SizedBox(height: 10),

            // Name
            Text(name,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
            const SizedBox(height: 6),

            // Info row
            Row(children: [
              Icon(Icons.location_on_outlined,
                  size: 14, color: context.kSub),
              const SizedBox(width: 4),
              Text('${S.areaLabel}: ${S.areaName(area)}',
                  style:
                      TextStyle(fontSize: 12, color: context.kSub)),
              const SizedBox(width: 12),
              Icon(Icons.person_outline_rounded,
                  size: 14, color: context.kSub),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${S.ownerLabel}: $ownerName',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: context.kSub)),
              ),
            ]),

            const SizedBox(height: 4),
            Text(
                '${S.submittedAt}: ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                style: TextStyle(
                    fontSize: 11, color: context.kSub)),

            const SizedBox(height: 16),

            // Action buttons
            Row(children: [
              Expanded(
                child: _actionBtn(
                  icon: Icons.check_circle_rounded,
                  label: S.adminApprove,
                  color: _kGreen,
                  onTap: () => _approve(p.id, name),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  icon: Icons.cancel_rounded,
                  label: S.adminReject,
                  color: _kRed,
                  onTap: () => _reject(p.id, name),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  icon: Icons.edit_note_rounded,
                  label: S.adminRequestEdit,
                  color: _kOrange,
                  onTap: () => _requestEdit(p.id, name),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ]),
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
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline_rounded,
                size: 48, color: _kGreen.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(S.adminNoPending,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.kText)),
          const SizedBox(height: 8),
          Text(S.adminNoPendingSub,
              style: TextStyle(fontSize: 13, color: context.kSub)),
        ],
      ),
    );
  }
}
