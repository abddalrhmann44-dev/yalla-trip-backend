// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Reviews Moderation Page  (Wave 30)
//
//  Surfaces every review on the platform with the moderation flags
//  (``is_hidden``, ``report_count``) front-and-center so abuse is
//  obvious at a glance.  Three top-level tabs:
//
//    • All         — every review, newest first
//    • Flagged     — ``report_count > 0`` (reviews users reported)
//    • Hidden      — already soft-hidden by an admin
//
//  Per-row actions:
//    • Hide / Unhide  — soft-toggle ``is_hidden``.  Preferred over
//      delete for borderline content because it preserves the
//      booking ↔ review link (so the same booking cannot be
//      review-bombed twice if the guest re-submits).
//    • Delete         — permanent removal, recomputes the property's
//      average rating.  Behind a confirmation dialog because it is
//      irreversible.
//    • Open property  — jumps to the public property page so the
//      moderator can see the review in context.
//
//  All endpoints called here are admin-only — the backend enforces
//  ``require_role(admin)`` on every route.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../models/admin_review_item.dart';
import '../../services/admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';
import '../property_details_page.dart';

const _kOcean = Color(0xFFFF6B35);
const _kOrange = Color(0xFFFF6D00);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

enum _Tab { all, flagged, hidden }

class AdminReviewsModerationPage extends StatefulWidget {
  const AdminReviewsModerationPage({super.key});
  @override
  State<AdminReviewsModerationPage> createState() =>
      _AdminReviewsModerationPageState();
}

class _AdminReviewsModerationPageState extends State<AdminReviewsModerationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  _Tab _current = _Tab.all;

  // Per-tab cache so switching tabs doesn't re-hit the network.
  final Map<_Tab, List<AdminReviewItem>> _data = {};
  final Map<_Tab, bool> _loading = {};
  final Map<_Tab, int> _total = {};

  // Search field (matches against the review comment, server-side).
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _search = '';

  // Per-row action flags (so hide/delete buttons can show a spinner
  // without locking the whole list).
  final Set<int> _busyRowIds = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _Tab.values.length, vsync: this)
      ..addListener(() {
        if (_tab.indexIsChanging) return;
        setState(() => _current = _Tab.values[_tab.index]);
        if (_data[_current] == null) _load(_current);
      });
    _load(_current);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Networking ─────────────────────────────────────────────
  Future<void> _load(_Tab tab) async {
    setState(() => _loading[tab] = true);
    try {
      final result = await AdminService.getReviewsForModeration(
        hidden: tab == _Tab.hidden ? true : (tab == _Tab.all ? null : false),
        flaggedOnly: tab == _Tab.flagged,
        search: _search.isEmpty ? null : _search,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _data[tab] = result.items;
        _total[tab] = result.total;
      });
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل تحميل التقييمات: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading[tab] = false);
    }
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = v.trim());
      _load(_current);
    });
  }

  Future<void> _toggleHide(AdminReviewItem r) async {
    HapticFeedback.lightImpact();
    setState(() => _busyRowIds.add(r.id));
    try {
      final updated = await AdminService.setReviewHidden(r.id, !r.isHidden);
      if (!mounted) return;
      setState(() {
        // Patch the row in every cached tab where it appears.
        for (final tab in _Tab.values) {
          final list = _data[tab];
          if (list == null) continue;
          final idx = list.indexWhere((x) => x.id == r.id);
          if (idx == -1) continue;
          // If the new flag conflicts with the tab filter, drop the
          // row from that tab so the user sees the move land.
          if (tab == _Tab.hidden && !updated.isHidden) {
            list.removeAt(idx);
          } else {
            list[idx] = updated;
          }
        }
      });
      _snack(
        updated.isHidden ? 'تم إخفاء التقييم' : 'تم إظهار التقييم',
        _kGreen,
      );
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل العملية: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busyRowIds.remove(r.id));
    }
  }

  Future<void> _deleteReview(AdminReviewItem r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.delete_forever_rounded,
                color: _kRed, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('حذف التقييم نهائياً؟',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _kRed,
                    fontSize: 15)),
          ),
        ]),
        content: const Text(
          'هذا الإجراء لا يمكن التراجع عنه. سيتم حذف التقييم من العقار '
          'وإعادة حساب متوسط التقييمات. للحالات الحدية، استخدم خيار '
          '"إخفاء" بدل الحذف.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(
                    color: _kOcean, fontWeight: FontWeight.w700)),
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
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    setState(() => _busyRowIds.add(r.id));
    try {
      await AdminService.deleteReview(r.id);
      if (!mounted) return;
      setState(() {
        for (final tab in _Tab.values) {
          _data[tab]?.removeWhere((x) => x.id == r.id);
        }
      });
      _snack('تم حذف التقييم', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل الحذف: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busyRowIds.remove(r.id));
    }
  }

  void _openProperty(AdminReviewItem r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetailsPage(propertyId: r.propertyId),
      ),
    );
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

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('إدارة التقييمات',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(children: [
            // Search box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'ابحث في التعليقات...',
                  hintStyle: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.white70, size: 20),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.18),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // Tabs
            TabBar(
              controller: _tab,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'الكل'),
                Tab(text: 'مُبلَّغ عنها'),
                Tab(text: 'مخفية'),
              ],
            ),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _Tab.values.map(_buildList).toList(),
      ),
    );
  }

  // ── Per-tab list ───────────────────────────────────────────
  Widget _buildList(_Tab tab) {
    final loading = _loading[tab] ?? false;
    final rows = _data[tab];
    final total = _total[tab];

    if (loading && rows == null) {
      return const Center(child: CircularProgressIndicator(color: _kOcean));
    }
    if (rows == null) {
      return Center(
        child: Text('—',
            style: TextStyle(color: context.kSub, fontSize: 14)),
      );
    }
    return RefreshIndicator(
      color: _kOcean,
      onRefresh: () => _load(tab),
      child: rows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                Icon(Icons.rate_review_outlined,
                    size: 64, color: context.kSub.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _search.isNotEmpty
                        ? 'لا توجد تقييمات تطابق بحثك'
                        : tab == _Tab.flagged
                            ? 'لا توجد تقييمات مُبلَّغ عنها'
                            : tab == _Tab.hidden
                                ? 'لا توجد تقييمات مخفية'
                                : 'لا توجد تقييمات بعد',
                    style: TextStyle(
                        color: context.kSub,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: rows.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == 0) return _totalChip(total ?? rows.length);
                return _ReviewCard(
                  item: rows[i - 1],
                  busy: _busyRowIds.contains(rows[i - 1].id),
                  onToggleHide: () => _toggleHide(rows[i - 1]),
                  onDelete: () => _deleteReview(rows[i - 1]),
                  onOpenProperty: () => _openProperty(rows[i - 1]),
                );
              },
            ),
    );
  }

  Widget _totalChip(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _kOcean.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOcean.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: _kOcean, size: 16),
        const SizedBox(width: 8),
        Text('$total تقييم في هذا التبويب',
            style: const TextStyle(
                color: _kOcean,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Review row
// ═══════════════════════════════════════════════════════════════
class _ReviewCard extends StatelessWidget {
  final AdminReviewItem item;
  final bool busy;
  final VoidCallback onToggleHide;
  final VoidCallback onDelete;
  final VoidCallback onOpenProperty;

  const _ReviewCard({
    required this.item,
    required this.busy,
    required this.onToggleHide,
    required this.onDelete,
    required this.onOpenProperty,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = intl.DateFormat('y/MM/dd – HH:mm').format(
      item.createdAt.toLocal(),
    );
    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: item.isHidden
                ? _kRed.withValues(alpha: 0.4)
                : context.kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: property + flags ───────────────────────
          InkWell(
            onTap: onOpenProperty,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: item.propertyImage == null
                        ? Container(
                            color: _kOcean.withValues(alpha: 0.15),
                            child: const Icon(Icons.villa_rounded,
                                color: _kOcean, size: 20),
                          )
                        : CachedNetworkImage(
                            imageUrl: item.propertyImage!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: context.kBorder),
                            errorWidget: (_, __, ___) => Container(
                              color: _kOcean.withValues(alpha: 0.15),
                              child: const Icon(Icons.villa_rounded,
                                  color: _kOcean, size: 20),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.propertyName ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.kText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${item.propertyId}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: context.kSub),
                      ),
                    ],
                  ),
                ),
                if (item.isHidden)
                  _statusChip(
                      'مخفي', _kRed, Icons.visibility_off_rounded),
                if (item.reportCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _statusChip(
                      '${item.reportCount} بلاغ',
                      _kAmber,
                      Icons.flag_rounded,
                    ),
                  ),
              ]),
            ),
          ),
          const Divider(height: 1, thickness: 0.5),

          // ── Reviewer + rating ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _kOcean.withValues(alpha: 0.15),
                backgroundImage: item.reviewerAvatar != null
                    ? CachedNetworkImageProvider(item.reviewerAvatar!)
                    : null,
                child: item.reviewerAvatar == null
                    ? Text(
                        (item.reviewerName ?? '?')
                            .characters
                            .first
                            .toUpperCase(),
                        style: const TextStyle(
                            color: _kOcean,
                            fontWeight: FontWeight.w800,
                            fontSize: 13),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.reviewerName ?? '—',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: context.kText),
                    ),
                    Text(
                      dateLabel,
                      style: TextStyle(
                          fontSize: 10,
                          color: context.kSub,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              _ratingBadge(item.rating),
            ]),
          ),

          // ── Comment body ───────────────────────────────────
          if ((item.comment ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                item.comment!.trim(),
                style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: item.isHidden
                        ? context.kSub
                        : context.kText,
                    fontStyle: item.isHidden
                        ? FontStyle.italic
                        : FontStyle.normal),
              ),
            ),

          // ── Owner reply, if any ────────────────────────────
          if ((item.ownerResponse ?? '').trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kOcean.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: _kOcean.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.reply_rounded,
                        color: _kOcean, size: 14),
                    const SizedBox(width: 6),
                    const Text('رد المضيف',
                        style: TextStyle(
                            color: _kOcean,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    item.ownerResponse!.trim(),
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: context.kText),
                  ),
                ],
              ),
            ),

          // ── Actions ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              Expanded(
                child: _actionBtn(
                  context,
                  icon: item.isHidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  label: item.isHidden ? 'إظهار' : 'إخفاء',
                  color: item.isHidden ? _kGreen : _kOrange,
                  busy: busy,
                  onTap: onToggleHide,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionBtn(
                  context,
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف',
                  color: _kRed,
                  busy: busy,
                  onTap: onDelete,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionBtn(
                  context,
                  icon: Icons.open_in_new_rounded,
                  label: 'العقار',
                  color: _kOcean,
                  busy: false,
                  onTap: onOpenProperty,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _ratingBadge(double r) {
    final color = r >= 4
        ? _kGreen
        : r >= 3
            ? _kAmber
            : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_rounded, color: color, size: 14),
        const SizedBox(width: 3),
        Text(r.toStringAsFixed(1),
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _statusChip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _actionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: busy ? 0.04 : 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: busy
            ? SizedBox(
                height: 14,
                width: 14,
                child: Center(
                  child: SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              )
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ]),
      ),
    );
  }
}
