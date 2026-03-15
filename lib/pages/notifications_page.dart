// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Notifications Page
//  Firebase real-time notifications from 'notifications' collection
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kSand   = Color(0xFFF5F3EE);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0D1B2A);
const _kSub    = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kGreen  = Color(0xFF22C55E);

// ── Notification Model ─────────────────────────────────────────
class _Notif {
  final String id, type, title, body, bookingId;
  final bool   isRead;
  final DateTime createdAt;

  _Notif.fromFirestore(String docId, Map<String, dynamic> d)
      : id        = docId,
        type      = d['type']      ?? 'info',
        title     = d['title']     ?? '',
        body      = d['body']      ?? '',
        bookingId = d['bookingId'] ?? '',
        isRead    = d['isRead']    ?? false,
        createdAt = (d['createdAt'] as Timestamp?)?.toDate()
            ?? DateTime.now();

  IconData get icon {
    switch (type) {
      case 'booking_confirmed': return Icons.check_circle_rounded;
      case 'booking_cancelled': return Icons.cancel_rounded;
      case 'booking_reminder':  return Icons.alarm_rounded;
      case 'payment_received':  return Icons.payments_rounded;
      case 'new_review':        return Icons.star_rounded;
      case 'promo':             return Icons.local_offer_rounded;
      default:                  return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'booking_confirmed': return _kGreen;
      case 'booking_cancelled': return const Color(0xFFEF5350);
      case 'booking_reminder':  return _kOrange;
      case 'payment_received':  return _kGreen;
      case 'new_review':        return const Color(0xFFF59E0B);
      case 'promo':             return _kOcean;
      default:                  return _kSub;
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1)  return S.justNow;
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)   return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7)     return 'منذ ${diff.inDays} يوم';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

// ══════════════════════════════════════════════════════════════
//  PAGE
// ══════════════════════════════════════════════════════════════
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override State<NotificationsPage> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {

  final _db  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<_Notif> _notifs  = [];
  bool         _loading = true;

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);

    _loadNotifs();
  }

  Future<void> _loadNotifs() async {
    if (_uid.isEmpty) {
      setState(() { _loading = false; _notifs = _demoNotifs(); });
      return;
    }
    try {
      final snap = await _db
          .collection('notifications')
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final list = snap.docs
          .map((d) => _Notif.fromFirestore(d.id, d.data()))
          .toList();

      // If no real notifications, show demos
      setState(() {
        _notifs  = list.isEmpty ? _demoNotifs() : list;
        _loading = false;
      });
    } catch (_) {
      setState(() { _notifs = _demoNotifs(); _loading = false; });
    }
  }

  // Demo notifications for empty state / guests
  List<_Notif> _demoNotifs() {
    final now = DateTime.now();
    return [
      _Notif.fromFirestore('d1', {
        'type': 'booking_confirmed',
        'title': 'تم تأكيد حجزك 🎉',
        'body': 'تم تأكيد حجزك في شاليه البحر الأزرق بعين السخنة',
        'isRead': false,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
      }),
      _Notif.fromFirestore('d2', {
        'type': 'booking_reminder',
        'title': 'تذكير: رحلتك بعد 3 أيام ⏰',
        'body': 'لا تنسى رحلتك للجونة يوم الجمعة القادم',
        'isRead': false,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
      }),
      _Notif.fromFirestore('d3', {
        'type': 'promo',
        'title': 'عرض حصري! 🏷️ خصم 20%',
        'body': 'احجز خلال 48 ساعة واستمتع بخصم 20% على الساحل الشمالي',
        'isRead': true,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      }),
      _Notif.fromFirestore('d4', {
        'type': 'new_review',
        'title': 'تقييم جديد ⭐',
        'body': 'أضاف أحمد تقييماً 5 نجوم لإقامته في شاليهك',
        'isRead': true,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
      }),
      _Notif.fromFirestore('d5', {
        'type': 'payment_received',
        'title': 'استلمنا دفعتك ✅',
        'body': 'تم استلام مبلغ 3500 جنيه بنجاح عبر فوري',
        'isRead': true,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
      }),
    ];
  }

  int get _unreadCount =>
      _notifs.where((n) => !n.isRead).length;

  Future<void> _markAllRead() async {
    setState(() {
      _notifs = _notifs.map((n) => _Notif.fromFirestore(n.id, {
        'type': n.type, 'title': n.title, 'body': n.body,
        'bookingId': n.bookingId, 'isRead': true,
        'createdAt': Timestamp.fromDate(n.createdAt),
      })).toList();
    });
    if (_uid.isEmpty) return;
    final batch = _db.batch();
    for (final n in _notifs.where((x) => !x.isRead)) {
      batch.update(_db.collection('notifications').doc(n.id),
          {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _markRead(String id) async {
    setState(() {
      final idx = _notifs.indexWhere((n) => n.id == id);
      if (idx == -1) return;
      final n = _notifs[idx];
      _notifs[idx] = _Notif.fromFirestore(n.id, {
        'type': n.type, 'title': n.title, 'body': n.body,
        'bookingId': n.bookingId, 'isRead': true,
        'createdAt': Timestamp.fromDate(n.createdAt),
      });
    });
    if (_uid.isNotEmpty) {
      await _db.collection('notifications').doc(id)
          .update({'isRead': true});
    }
  }

  Future<void> _deleteNotif(String id) async {
    setState(() => _notifs.removeWhere((n) => n.id == id));
    if (_uid.isNotEmpty) {
      await _db.collection('notifications').doc(id).delete();
    }
  }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSand,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(S.notificationsTitle,
              style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w900, color: _kText)),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kOcean,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$_unreadCount',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ),
          ],
        ]),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('قرأة الكل',
                  style: TextStyle(color: _kOcean,
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kOcean))
          : _notifs.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  color: _kOcean,
                  onRefresh: _loadNotifs,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    itemCount: _notifs.length,
                    itemBuilder: (_, i) => _notifTile(_notifs[i]),
                  ),
                ),
    );
  }

  Widget _notifTile(_Notif n) => Dismissible(
    key: Key(n.id),
    direction: DismissDirection.endToStart,
    onDismissed: (_) => _deleteNotif(n.id),
    background: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20),
      child: const Icon(Icons.delete_rounded,
          color: Colors.white, size: 24),
    ),
    child: GestureDetector(
      onTap: () => _markRead(n.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead
              ? _kCard
              : n.color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.isRead
                ? _kBorder
                : n.color.withValues(alpha: 0.25),
            width: n.isRead ? 1 : 1.5,
          ),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha:
                n.isRead ? 0.03 : 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Icon circle
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: n.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(n.icon, size: 20, color: n.color),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(n.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: n.isRead
                          ? FontWeight.w600
                          : FontWeight.w900,
                      color: _kText,
                    ))),
                if (!n.isRead)
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: n.color, shape: BoxShape.circle),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(n.body, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: _kSub, height: 1.5)),
              const SizedBox(height: 6),
              Text(n.timeAgo,
                  style: TextStyle(
                    fontSize: 11,
                    color: n.isRead
                        ? Colors.grey.shade400
                        : n.color,
                    fontWeight: n.isRead
                        ? FontWeight.w400
                        : FontWeight.w700,
                  )),
            ],
          )),
        ]),
      ),
    ),
  );

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: _kOcean.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.notifications_off_outlined,
              size: 48,
              color: _kOcean.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 20),
        const Text('مفيش إشعارات لحد دلوقتي',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: _kText)),
        const SizedBox(height: 8),
        const Text('هيظهروا هنا لما تحجز أو يجيلك عرض',
            style: TextStyle(fontSize: 13, color: _kSub)),
      ],
    ),
  );
}
