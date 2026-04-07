// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Admin Pending Properties Page
//  Admin can: Approve / Reject / Request Edit
//  Each action updates Firestore → triggers Cloud Function → FCM
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import '../main.dart' show appSettings;

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
  final _db = FirebaseFirestore.instance;

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  //  ADMIN ACTIONS
  // ══════════════════════════════════════════════════════════

  Future<void> _approve(String docId, String propName) async {
    final confirmed = await _confirmDialog(
      S.adminApprove,
      S.adminApproveConfirm,
      _kGreen,
    );
    if (confirmed != true) return;

    await _db.collection('properties').doc(docId).update({
      'approved': true,
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Log notification in Firestore
    final propDoc = await _db.collection('properties').doc(docId).get();
    final ownerId = propDoc.data()?['ownerId'] ?? '';
    if (ownerId.isNotEmpty) {
      await _db.collection('notifications').add({
        'userId': ownerId,
        'ownerId': ownerId,
        'itemId': docId,
        'type': 'approved',
        'title': S.notifPropertyApproved,
        'body': S.notifApprovedBody(propName),
        'isRead': false,
        'seen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) _snack(S.adminApproved, _kGreen);
  }

  Future<void> _reject(String docId, String propName) async {
    final confirmed = await _confirmDialog(
      S.adminReject,
      S.adminRejectConfirm,
      _kRed,
    );
    if (confirmed != true) return;

    await _db.collection('properties').doc(docId).update({
      'approved': false,
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final propDoc = await _db.collection('properties').doc(docId).get();
    final ownerId = propDoc.data()?['ownerId'] ?? '';
    if (ownerId.isNotEmpty) {
      await _db.collection('notifications').add({
        'userId': ownerId,
        'ownerId': ownerId,
        'itemId': docId,
        'type': 'rejected',
        'title': S.notifPropertyRejected,
        'body': S.notifRejectedBody(propName),
        'isRead': false,
        'seen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) _snack(S.adminRejected, _kRed);
  }

  Future<void> _requestEdit(String docId, String propName) async {
    final confirmed = await _confirmDialog(
      S.adminRequestEdit,
      S.adminEditConfirm,
      _kOrange,
    );
    if (confirmed != true) return;

    await _db.collection('properties').doc(docId).update({
      'approved': false,
      'status': 'needs_edit',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final propDoc = await _db.collection('properties').doc(docId).get();
    final ownerId = propDoc.data()?['ownerId'] ?? '';
    if (ownerId.isNotEmpty) {
      await _db.collection('notifications').add({
        'userId': ownerId,
        'ownerId': ownerId,
        'itemId': docId,
        'type': 'needs_edit',
        'title': S.notifNeedsEdit,
        'body': S.notifNeedsEditBody(propName),
        'isRead': false,
        'seen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) _snack(S.adminEditRequested, _kOrange);
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('properties')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kOcean));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _emptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _propertyCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  // ── Property Card ────────────────────────────────────────
  Widget _propertyCard(String docId, Map<String, dynamic> data) {
    final name = data['name'] ?? '';
    final area = data['area'] ?? '';
    final category = data['category'] ?? '';
    final ownerName = data['ownerName'] ?? '';
    final images = List<String>.from(data['images'] ?? []);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final price = (data['price'] ?? 0).toInt();

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

            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                  '${S.submittedAt}: ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                  style: TextStyle(
                      fontSize: 11, color: context.kSub)),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(children: [
              Expanded(
                child: _actionBtn(
                  icon: Icons.check_circle_rounded,
                  label: S.adminApprove,
                  color: _kGreen,
                  onTap: () => _approve(docId, name),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  icon: Icons.cancel_rounded,
                  label: S.adminReject,
                  color: _kRed,
                  onTap: () => _reject(docId, name),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  icon: Icons.edit_note_rounded,
                  label: S.adminRequestEdit,
                  color: _kOrange,
                  onTap: () => _requestEdit(docId, name),
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
