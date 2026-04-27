// ═══════════════════════════════════════════════════════════════
//  TALAA — Host Shell (Airbnb-style)
//
//  Bottom-nav scaffold that hosts the four primary host workflows:
//
//    1. Today        — overview (revenue, upcoming, KYC alerts)
//    2. Listings     — properties list (manage / edit / toggle)
//    3. Reservations — bookings inbox
//    4. Earnings     — payouts + bank accounts
//
//  Each tab keeps its own navigation state via an IndexedStack so
//  switching tabs preserves scroll position and any pushed routes.
//  This replaces the old "long page of action buttons" UX which made
//  the host hop in and out of unrelated screens to perform any task.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/constants.dart';
import 'bookings_page.dart';
import 'host_payouts_page.dart';
import 'host_today_tab.dart';
import 'owner_dashboard_page.dart';

const _kOcean = Color(0xFFFF6B35);

class HostShellPage extends StatefulWidget {
  const HostShellPage({super.key});

  @override
  State<HostShellPage> createState() => _HostShellPageState();
}

class _HostShellPageState extends State<HostShellPage> {
  int _index = 0;

  // One Navigator per tab so a push inside Listings doesn't pop the
  // entire shell — same pattern Airbnb / Booking use.  Keys must be
  // stable across rebuilds; instantiate once.
  final _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  // Lazy-built tab roots.  Built once on first switch and cached so
  // bouncing between tabs doesn't re-fetch the bookings list.
  final _tabPages = const <Widget>[
    HostTodayTab(),
    OwnerDashboardPage(),
    BookingsPage(),
    HostPayoutsPage(),
  ];

  Future<bool> _onWillPop() async {
    final nav = _navKeys[_index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
  }

  void _switchTab(int i) {
    if (i == _index) {
      // Tap the active tab again → pop to first route in that tab,
      // matching native iOS / Airbnb behaviour.  Avoids the host
      // getting stuck inside a sub-screen with no easy way back.
      _navKeys[i].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && mounted) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        backgroundColor: context.kSand,
        body: IndexedStack(
          index: _index,
          children: List.generate(4, (i) {
            return Navigator(
              key: _navKeys[i],
              onGenerateRoute: (settings) => MaterialPageRoute(
                settings: settings,
                builder: (_) => _tabPages[i],
              ),
            );
          }),
        ),
        bottomNavigationBar: _HostBottomBar(
          index: _index,
          onTap: _switchTab,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Bottom bar — Airbnb-flavoured: white surface, accent on active,
//  generous tap targets, clean Arabic labels.
// ═══════════════════════════════════════════════════════════════
class _HostBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _HostBottomBar({required this.index, required this.onTap});

  static const _items = <_TabItem>[
    _TabItem(
        icon: Icons.home_outlined,
        active: Icons.home_rounded,
        label: 'الرئيسية'),
    _TabItem(
        icon: Icons.apartment_outlined,
        active: Icons.apartment_rounded,
        label: 'عقاراتى'),
    _TabItem(
        icon: Icons.calendar_today_outlined,
        active: Icons.calendar_today_rounded,
        label: 'الحجوزات'),
    _TabItem(
        icon: Icons.account_balance_wallet_outlined,
        active: Icons.account_balance_wallet_rounded,
        label: 'الأرباح'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        border: Border(
          top: BorderSide(color: context.kBorder, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == index;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  splashColor: _kOcean.withValues(alpha: 0.1),
                  highlightColor: _kOcean.withValues(alpha: 0.05),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          selected ? item.active : item.icon,
                          key: ValueKey('${i}_$selected'),
                          size: 24,
                          color: selected ? _kOcean : context.kSub,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? _kOcean : context.kSub,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData active;
  final String label;
  const _TabItem({
    required this.icon,
    required this.active,
    required this.label,
  });
}
