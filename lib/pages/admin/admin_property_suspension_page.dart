// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Property Suspension Management
//  Suspend/activate properties and hide/show from public listing.
//  Backend: Firebase Firestore — collection "properties"
//  Fields managed: isActive (bool), isVisible (bool)
// ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kOrange = Color(0xFFFF6D00);
const _kRed    = Color(0xFFEF5350);

// ── Local DTO ──────────────────────────────────────────────
class _PropertyRow {
  final String docId;
  final String name;
  final String ownerName;
  final String location;
  final String? imageUrl;
  final bool isActive;
  final bool isVisible;

  const _PropertyRow({
    required this.docId,
    required this.name,
    required this.ownerName,
    required this.location,
    required this.imageUrl,
    required this.isActive,
    required this.isVisible,
  });

  factory _PropertyRow.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final images = d['images'];
    String? img;
    if (images is List && images.isNotEmpty) {
      img = images.first?.toString();
    } else if (images is String && images.isNotEmpty) {
      img = images;
    }
    return _PropertyRow(
      docId: doc.id,
      name: (d['name'] ?? '').toString(),
      ownerName: (d['ownerName'] ?? d['owner_name'] ?? '').toString(),
      location: (d['area'] ?? d['location'] ?? '').toString(),
      imageUrl: img,
      isActive: d['isActive'] as bool? ?? true,
      isVisible: d['isVisible'] as bool? ?? true,
    );
  }

  /// Composite status used by filter chips.
  _Status get status {
    if (!isActive) return _Status.suspended;
    if (!isVisible) return _Status.hidden;
    return _Status.active;
  }

  bool matchesSearch(String q) {
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        ownerName.toLowerCase().contains(q) ||
        location.toLowerCase().contains(q);
  }
}

enum _Status { active, suspended, hidden }

// ── Page ───────────────────────────────────────────────────
class AdminPropertySuspensionPage extends StatefulWidget {
  const AdminPropertySuspensionPage({super.key});
  @override
  State<AdminPropertySuspensionPage> createState() =>
      _AdminPropertySuspensionPageState();
}

class _AdminPropertySuspensionPageState
    extends State<AdminPropertySuspensionPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _searchQ = '';
  String _filter = 'الكل';

  static const _filters = ['الكل', 'نشط', 'موقوف', 'مخفي'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Firestore write helpers ─────────────────────────────
  Future<void> _setActive(String docId, bool value) async {
    await _db.collection('properties').doc(docId).update({'isActive': value});
  }

  Future<void> _setVisible(String docId, bool value) async {
    await _db.collection('properties').doc(docId).update({'isVisible': value});
  }

  // ── Confirm dialog ──────────────────────────────────────
  Future<bool> _confirm({
    required String title,
    required String body,
    required Color actionColor,
    required String actionLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: actionColor)),
        content: Text(body,
            style: TextStyle(fontSize: 13, color: context.kSub)),
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
              backgroundColor: actionColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionLabel,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ── Toggle handlers ─────────────────────────────────────
  Future<void> _onActiveToggle(_PropertyRow row, bool newValue) async {
    if (!newValue) {
      // Confirm before suspending
      final ok = await _confirm(
        title: 'وقف العقار؟',
        body: 'هيتم وقف عقار "${row.name}" ومش هيظهر للضيوف حتى يتفعّل تاني.',
        actionColor: _kRed,
        actionLabel: 'وقف',
      );
      if (!ok) return;
    }
    try {
      await _setActive(row.docId, newValue);
      HapticFeedback.mediumImpact();
      _snack(
        newValue ? 'تم تفعيل "${row.name}"' : 'تم وقف "${row.name}"',
        newValue ? _kGreen : _kRed,
      );
    } catch (e) {
      _snack('حصل خطأ أثناء التحديث', _kRed);
    }
  }

  Future<void> _onVisibleToggle(_PropertyRow row, bool newValue) async {
    if (!newValue) {
      // Confirm before hiding
      final ok = await _confirm(
        title: 'إخفاء العقار؟',
        body: 'هيتم إخفاء "${row.name}" من نتائج البحث العامة.',
        actionColor: _kOrange,
        actionLabel: 'إخفاء',
      );
      if (!ok) return;
    }
    try {
      await _setVisible(row.docId, newValue);
      HapticFeedback.mediumImpact();
      _snack(
        newValue ? 'تم إظهار "${row.name}"' : 'تم إخفاء "${row.name}"',
        newValue ? _kGreen : _kOrange,
      );
    } catch (e) {
      _snack('حصل خطأ أثناء التحديث', _kRed);
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

  // ── Filter logic ────────────────────────────────────────
  List<_PropertyRow> _applyFilter(List<_PropertyRow> all) {
    return all.where((row) {
      if (!row.matchesSearch(_searchQ)) return false;
      switch (_filter) {
        case 'نشط':
          return row.status == _Status.active;
        case 'موقوف':
          return row.status == _Status.suspended;
        case 'مخفي':
          return row.status == _Status.hidden;
        default:
          return true;
      }
    }).toList();
  }

  // ── Build ───────────────────────────────────────────────
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
        title: Text('إدارة وقف العقارات',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: Column(children: [
        // ── Search bar ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQ = v.trim().toLowerCase()),
            style: TextStyle(fontSize: 14, color: context.kText),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو المالك أو المنطقة...',
              hintStyle: TextStyle(fontSize: 13, color: context.kSub),
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

        // ── Filter chips ───────────────────────────────────
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final sel = f == _filter;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? _kOcean : context.kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? _kOcean : context.kBorder),
                  ),
                  child: Text(f,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : context.kText)),
                ),
              );
            },
          ),
        ),

        // ── Property list (Firestore stream) ───────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('properties')
                .orderBy('name')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kOcean));
              }
              if (snap.hasError) {
                return _errorView(snap.error.toString());
              }

              final docs = snap.data?.docs ?? [];
              final all = docs.map(_PropertyRow.fromDoc).toList();
              final rows = _applyFilter(all);

              if (rows.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.apartment_rounded,
                          size: 48, color: context.kBorder),
                      const SizedBox(height: 12),
                      Text('لا توجد عقارات',
                          style: TextStyle(
                              fontSize: 14, color: context.kSub)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                itemCount: rows.length,
                itemBuilder: (_, i) => _propCard(rows[i]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _errorView(String err) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: _kRed.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text('تعذّر تحميل البيانات',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.kText)),
              const SizedBox(height: 6),
              Text(err,
                  style: TextStyle(fontSize: 11, color: context.kSub),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );

  // ── Property card ───────────────────────────────────────
  Widget _propCard(_PropertyRow row) {
    final (badgeColor, badgeLabel, badgeIcon) = switch (row.status) {
      _Status.active    => (_kGreen, 'نشط', Icons.check_circle_rounded),
      _Status.suspended => (_kRed, 'موقوف', Icons.block_rounded),
      _Status.hidden    => (_kOrange, 'مخفي', Icons.visibility_off_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: row.status == _Status.active
              ? context.kBorder
              : badgeColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Top row: image + info + badge ─────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: row.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: row.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: context.kBorder),
                        errorWidget: (_, __, ___) => _imageFallback(),
                      )
                    : _imageFallback(),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(row.name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.kText),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(badgeIcon, size: 11, color: badgeColor),
                          const SizedBox(width: 3),
                          Text(badgeLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Owner
                  Row(children: [
                    Icon(Icons.person_rounded,
                        size: 12, color: context.kSub),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        row.ownerName.isNotEmpty ? row.ownerName : '—',
                        style: TextStyle(fontSize: 11, color: context.kSub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  // Location
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        size: 12, color: context.kSub),
                    const SizedBox(width: 3),
                    Text(row.location.isNotEmpty ? row.location : '—',
                        style:
                            TextStyle(fontSize: 11, color: context.kSub)),
                  ]),
                ],
              ),
            ),
          ]),
        ),

        // ── Divider ────────────────────────────────────────
        Divider(height: 1, color: context.kBorder),

        // ── Toggle switches ────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            // وقف / تفعيل
            Expanded(
              child: _switchRow(
                label: row.isActive ? 'مُفعّل' : 'موقوف',
                subLabel: 'وقف / تفعيل',
                icon: row.isActive
                    ? Icons.play_circle_rounded
                    : Icons.pause_circle_rounded,
                iconColor: row.isActive ? _kGreen : _kRed,
                value: row.isActive,
                activeColor: _kGreen,
                onChanged: (v) => _onActiveToggle(row, v),
              ),
            ),

            // Vertical divider between switches
            Container(
              width: 1,
              height: 40,
              color: context.kBorder,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),

            // إخفاء / إظهار
            Expanded(
              child: _switchRow(
                label: row.isVisible ? 'ظاهر' : 'مخفي',
                subLabel: 'إخفاء / إظهار',
                icon: row.isVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                iconColor: row.isVisible ? _kGreen : _kOrange,
                value: row.isVisible,
                activeColor: _kOrange,
                onChanged: (v) => _onVisibleToggle(row, v),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _switchRow({
    required String label,
    required String subLabel,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(children: [
      Icon(icon, size: 18, color: iconColor),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.kText)),
            Text(subLabel,
                style: TextStyle(fontSize: 10, color: context.kSub)),
          ],
        ),
      ),
      Transform.scale(
        scale: 0.85,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: activeColor,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: context.kBorder,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ]);
  }

  Widget _imageFallback() => Container(
        color: context.kBorder,
        child: Icon(Icons.apartment_rounded,
            color: context.kSub, size: 28),
      );
}
