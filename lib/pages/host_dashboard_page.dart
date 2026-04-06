import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_page.dart';
import 'owner_add_property_page.dart';

const _bg = Color(0xFF0B1220);
const _panel = Color(0xFF131D30);
const _card = Color(0xFF1A263D);
const _txt = Color(0xFFEAF0FF);
const _sub = Color(0xFFA8B3C7);
const _pri = Color(0xFF4D8DFF);
const _ok = Color(0xFF22C55E);
const _warn = Color(0xFFF59E0B);
const _danger = Color(0xFFEF4444);

class HostDashboardPage extends StatefulWidget {
  const HostDashboardPage({super.key});

  @override
  State<HostDashboardPage> createState() => _HostDashboardPageState();
}

class _HostDashboardPageState extends State<HostDashboardPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _HostBookingsCalendarTab(),
      _HostChatsTab(),
      _HostDailyBookingsTab(),
      _HostPropertyManagerTab(),
    ];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panel,
        foregroundColor: _txt,
        title: const Text(
          'Host Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: pages[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 16,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 74,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _HostNavItem(
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month_rounded,
                  label: 'Bookings',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _HostNavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_rounded,
                  label: 'Messages',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _HostNavItem(
                  icon: Icons.today_outlined,
                  activeIcon: Icons.today_rounded,
                  label: 'Daily',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _HostNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Manager',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HostNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HostNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFE61E4D) : const Color(0xFF7A7A7A);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostBookingsCalendarTab extends StatefulWidget {
  const _HostBookingsCalendarTab();

  @override
  State<_HostBookingsCalendarTab> createState() =>
      _HostBookingsCalendarTabState();
}

class _HostBookingsCalendarTabState extends State<_HostBookingsCalendarTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _discountCtrl = TextEditingController();

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(child: Text('No owner session'));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final bookedKeys = <String>{};
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final data = d.data();
            final inS = (data['checkIn'] ?? '').toString();
            final outS = (data['checkOut'] ?? '').toString();
            final inDt = _parseDmy(inS);
            final outDt = _parseDmy(outS);
            if (inDt == null || outDt == null) {
              continue;
            }
            var day = DateTime(inDt.year, inDt.month, inDt.day);
            final last = DateTime(outDt.year, outDt.month, outDt.day);
            while (day.isBefore(last)) {
              bookedKeys.add(_key(day));
              day = day.add(const Duration(days: 1));
            }
          }
        }
        final first = DateTime(_month.year, _month.month, 1);
        final days = DateUtils.getDaysInMonth(_month.year, _month.month);
        final startWeekday = first.weekday % 7;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                    }),
                    icon: const Icon(Icons.chevron_left_rounded, color: _txt),
                  ),
                  Expanded(
                    child: Text(
                      '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _txt,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                    }),
                    icon: const Icon(Icons.chevron_right_rounded, color: _txt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: startWeekday + days,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (_, i) {
                  if (i < startWeekday) {
                    return const SizedBox.shrink();
                  }
                  final dayNum = i - startWeekday + 1;
                  final date = DateTime(_month.year, _month.month, dayNum);
                  final isBooked = bookedKeys.contains(_key(date));
                  return Container(
                    decoration: BoxDecoration(
                      color: isBooked
                          ? _danger.withValues(alpha: 0.24)
                          : _ok.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '$dayNum',
                        style: const TextStyle(
                            color: _txt, fontWeight: FontWeight.w700),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _legendRow(),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _card, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Discount Offer',
                      style:
                          TextStyle(color: _txt, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _discountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: _txt),
                    decoration: const InputDecoration(
                      hintText: 'Discount % for selected month',
                      hintStyle: TextStyle(color: _sub),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final v = int.tryParse(_discountCtrl.text.trim());
                      if (v == null || v <= 0) {
                        return;
                      }
                      await FirebaseFirestore.instance
                          .collection('owner_offers')
                          .add({
                        'ownerId': uid,
                        'month': '${_month.year}-${_month.month}',
                        'discount': v,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Offer saved')),
                        );
                      }
                    },
                    child: const Text('Save Offer'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _legendRow() => Row(
        children: const [
          _LegendDot(color: _danger, label: 'Booked'),
          SizedBox(width: 14),
          _LegendDot(color: _ok, label: 'Available'),
        ],
      );

  DateTime? _parseDmy(String s) {
    final p = s.split('/');
    if (p.length != 3) {
      return null;
    }
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) {
      return null;
    }
    return DateTime(y, m, d);
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _sub)),
      ],
    );
  }
}

class _HostChatsTab extends StatelessWidget {
  const _HostChatsTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _pri));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text('No customer chats', style: TextStyle(color: _sub)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final guest = (d['userName'] ?? 'Guest').toString();
            final property = (d['propertyName'] ?? 'Property').toString();
            final price = (d['totalPaid'] ?? 0).toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: _card, borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const CircleAvatar(
                    backgroundColor: _pri,
                    child: Icon(Icons.person, color: Colors.white)),
                title: Text(guest,
                    style: const TextStyle(
                        color: _txt, fontWeight: FontWeight.w700)),
                subtitle: Text('$property • EGP $price',
                    style: const TextStyle(color: _sub)),
                trailing: const Icon(Icons.chevron_right, color: _sub),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        ownerName: guest,
                        propertyName: property,
                        propertyEmoji: '💬',
                        currentPrice: price,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _HostDailyBookingsTab extends StatelessWidget {
  const _HostDailyBookingsTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now = DateTime.now();
    final todayKey = '${now.day}/${now.month}/${now.year}';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerId', isEqualTo: uid)
          .where('checkIn', isEqualTo: todayKey)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _pri));
        }
        final list = snap.data!.docs;
        if (list.isEmpty) {
          return const Center(
            child: Text('No bookings for today', style: TextStyle(color: _sub)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final d = list[i].data();
            final status = (d['status'] ?? 'pending').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _card, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Row(
                    children: [
                      _statusPill(status),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((d['propertyName'] ?? '').toString(),
                                style: const TextStyle(
                                    color: _txt, fontWeight: FontWeight.w700)),
                            Text('Guest: ${(d['userName'] ?? '').toString()}',
                                style: const TextStyle(color: _sub)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (status != 'cancelled') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectBooking(
                              bookingId: list[i].id,
                              userId: (d['userId'] ?? '').toString(),
                              propertyName:
                                  (d['propertyName'] ?? '').toString(),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _danger),
                            ),
                            child: const Text('Reject',
                                style: TextStyle(color: _danger)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusPill(String s) {
    Color c = _warn;
    if (s == 'upcoming' || s == 'confirmed') {
      c = _ok;
    }
    if (s == 'cancelled') {
      c = _danger;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20)),
      child: Text(s,
          style:
              TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Future<void> _rejectBooking({
    required String bookingId,
    required String userId,
    required String propertyName,
  }) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({
      'status': 'cancelled',
      'ownerDecisionAt': FieldValue.serverTimestamp(),
    });
    if (userId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'type': 'booking_rejected',
        'title': 'تم رفض الحجز',
        'body': 'تم رفض الحجز من قبل المالك: $propertyName',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

class _HostPropertyManagerTab extends StatelessWidget {
  const _HostPropertyManagerTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .where('ownerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _pri));
        }
        final list = snap.data!.docs;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OwnerAddPropertyPage()));
              },
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Add New Property'),
            ),
            const SizedBox(height: 12),
            ...list.map((doc) {
              final d = doc.data();
              final name = (d['name'] ?? '').toString();
              final available = (d['available'] ?? true) == true;
              final price = (d['price'] ?? 0) as num;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _card, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  color: _txt, fontWeight: FontWeight.w700)),
                        ),
                        Switch(
                          value: available,
                          onChanged: (v) async {
                            await FirebaseFirestore.instance
                                .collection('properties')
                                .doc(doc.id)
                                .update({
                              'available': v,
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Price:', style: TextStyle(color: _sub)),
                        const SizedBox(width: 8),
                        Text('EGP ${price.toInt()}',
                            style: const TextStyle(
                                color: _txt, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              _openPriceEditor(context, doc.id, price.toInt()),
                          child: const Text('Edit Price'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _openPriceEditor(
      BuildContext context, String id, int current) async {
    final c = TextEditingController(text: '$current');
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Price'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'New price'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final n = int.tryParse(c.text.trim());
              if (n == null || n <= 0) {
                return;
              }
              await FirebaseFirestore.instance
                  .collection('properties')
                  .doc(id)
                  .update({'price': n});
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
