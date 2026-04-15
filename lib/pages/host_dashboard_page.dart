import 'package:flutter/material.dart';

import '../models/booking_model.dart';
import '../models/property_model_api.dart';
import '../services/booking_service.dart';
import '../services/property_service.dart';
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
  List<BookingModel> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await BookingService.getOwnerBookings(limit: 200);
      if (mounted) setState(() { _bookings = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _pri));
    }
    final bookedKeys = <String>{};
    for (final b in _bookings) {
      if (b.isCancelled) continue;
      var day = DateTime(b.checkIn.year, b.checkIn.month, b.checkIn.day);
      final last = DateTime(b.checkOut.year, b.checkOut.month, b.checkOut.day);
      while (day.isBefore(last)) {
        bookedKeys.add(_key(day));
        day = day.add(const Duration(days: 1));
      }
    }
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final startWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    return RefreshIndicator(
      color: _pri,
      onRefresh: _load,
      child: ListView(
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
        ],
      ),
    );
  }

  Widget _legendRow() => Row(
        children: const [
          _LegendDot(color: _danger, label: 'Booked'),
          SizedBox(width: 14),
          _LegendDot(color: _ok, label: 'Available'),
        ],
      );

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

class _HostChatsTab extends StatefulWidget {
  const _HostChatsTab();
  @override State<_HostChatsTab> createState() => _HostChatsTabState();
}

class _HostChatsTabState extends State<_HostChatsTab> {
  List<BookingModel> _bookings = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final list = await BookingService.getOwnerBookings(limit: 200);
      if (mounted) setState(() { _bookings = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _pri));
    }
    if (_bookings.isEmpty) {
      return const Center(
          child: Text('No customer chats', style: TextStyle(color: _sub)));
    }
    return RefreshIndicator(
      color: _pri,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (_, i) {
          final b = _bookings[i];
          final guest = b.guest?.name ?? 'Guest';
          final property = b.propertyName;
          final price = b.totalPrice.toInt().toString();
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
      ),
    );
  }
}

class _HostDailyBookingsTab extends StatefulWidget {
  const _HostDailyBookingsTab();
  @override State<_HostDailyBookingsTab> createState() =>
      _HostDailyBookingsTabState();
}

class _HostDailyBookingsTabState extends State<_HostDailyBookingsTab> {
  List<BookingModel> _today = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final all = await BookingService.getOwnerBookings(limit: 200);
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final filtered = all.where((b) {
        final ci = DateTime(b.checkIn.year, b.checkIn.month, b.checkIn.day);
        return ci == todayDate;
      }).toList();
      if (mounted) setState(() { _today = filtered; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _pri));
    }
    if (_today.isEmpty) {
      return const Center(
        child: Text('No bookings for today', style: TextStyle(color: _sub)),
      );
    }
    return RefreshIndicator(
      color: _pri,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _today.length,
        itemBuilder: (_, i) {
          final b = _today[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _card, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Row(
                  children: [
                    _statusPill(b.status),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.propertyName,
                              style: const TextStyle(
                                  color: _txt, fontWeight: FontWeight.w700)),
                          Text('Guest: ${b.guest?.name ?? ''}',
                              style: const TextStyle(color: _sub)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!b.isCancelled) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rejectBooking(b.id),
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
      ),
    );
  }

  Widget _statusPill(String s) {
    Color c = _warn;
    if (s == 'confirmed') c = _ok;
    if (s == 'cancelled') c = _danger;
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

  Future<void> _rejectBooking(int bookingId) async {
    try {
      await BookingService.cancelBooking(bookingId);
      _load();
    } catch (_) {}
  }
}

class _HostPropertyManagerTab extends StatefulWidget {
  const _HostPropertyManagerTab();
  @override State<_HostPropertyManagerTab> createState() =>
      _HostPropertyManagerTabState();
}

class _HostPropertyManagerTabState extends State<_HostPropertyManagerTab> {
  List<PropertyApi> _props = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final list = await PropertyService.getMyProperties();
      if (mounted) setState(() { _props = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _pri));
    }
    return RefreshIndicator(
      color: _pri,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OwnerAddPropertyPage()));
              _load();
            },
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('Add New Property'),
          ),
          const SizedBox(height: 12),
          ..._props.map((p) {
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
                        child: Text(p.name,
                            style: const TextStyle(
                                color: _txt, fontWeight: FontWeight.w700)),
                      ),
                      Switch(
                        value: p.isAvailable,
                        onChanged: (v) async {
                          await PropertyService.updateProperty(
                              p.id, {'is_available': v});
                          _load();
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Price:', style: TextStyle(color: _sub)),
                      const SizedBox(width: 8),
                      Text('EGP ${p.pricePerNight.toInt()}',
                          style: const TextStyle(
                              color: _txt, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            _openPriceEditor(context, p.id, p.pricePerNight.toInt()),
                        child: const Text('Edit Price'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openPriceEditor(
      BuildContext context, int id, int current) async {
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
              if (n == null || n <= 0) return;
              await PropertyService.updateProperty(
                  id, {'price_per_night': n});
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
