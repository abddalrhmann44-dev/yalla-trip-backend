// ═══════════════════════════════════════════════════════════════
//  TALAA — Best Trip feed
//
//  Global social feed where users who have completed a booking can
//  publish a short post about their stay (loved / disliked, caption,
//  photos).  Replaces the old "Bookings" bottom-nav tab — the
//  bookings list now lives inside the profile page.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../main.dart' show appSettings;
import '../services/trip_post_service.dart';
import '../widgets/constants.dart';
import 'property_details_page.dart';

const _kOrange = Color(0xFFFF6D00);

class BestTripPage extends StatefulWidget {
  final bool embedded;
  const BestTripPage({super.key, this.embedded = false});

  @override
  State<BestTripPage> createState() => _BestTripPageState();
}

class _BestTripPageState extends State<BestTripPage> {
  List<TripPost> _posts = const [];
  bool _loading = true;
  String? _error;
  TripVerdict? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final items = await TripPostService.feed(verdict: _filter, limit: 30);
      if (!mounted) return;
      setState(() {
        _posts = items;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCompose() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _ComposeTripPostPage()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(appSettings.arabic ? 'أحلى رحلة' : 'Best Trip'),
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: Text(appSettings.arabic ? 'شارك رحلتك' : 'Share your trip'),
      ),
      body: RefreshIndicator(
        color: _kOrange,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            if (widget.embedded)
              SliverToBoxAdapter(child: _buildEmbeddedHeader()),
            SliverToBoxAdapter(child: _buildFilterBar()),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _kOrange),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.kSub)),
                  ),
                ),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else
              SliverList.separated(
                itemCount: _posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _PostCard(post: _posts[i]),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF8A3D), _kOrange],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.travel_explore_rounded,
                  color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Text(
                  appSettings.arabic
                      ? 'أحلى رحلة'
                      : 'Best Trip',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              appSettings.arabic
                  ? 'شوف تجارب الناس واختار رحلتك الجاية'
                  : 'Discover real trip experiences from fellow travellers',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final chips = [
      (null, appSettings.arabic ? 'الكل' : 'All'),
      (TripVerdict.loved, appSettings.arabic ? 'حلوة 😍' : 'Loved 😍'),
      (TripVerdict.disliked, appSettings.arabic ? 'مش حلوة 😕' : 'Skip 😕'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: chips.map((c) {
          final sel = _filter == c.$1;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(c.$2),
              selected: sel,
              onSelected: (_) {
                setState(() => _filter = c.$1);
                _load();
              },
              selectedColor: _kOrange,
              labelStyle: TextStyle(
                color: sel ? Colors.white : context.kText,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore_outlined,
                size: 72, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              appSettings.arabic
                  ? 'لا يوجد بوستات لسه — كن أول واحد يشارك رحلته!'
                  : 'No posts yet — be the first to share your trip!',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.kSub, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single post card ─────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final TripPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final loved = post.verdict == TripVerdict.loved;
    final isAr = appSettings.arabic;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: avatar + name + time
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _kOrange.withValues(alpha: 0.15),
                  backgroundImage: post.author.avatarUrl != null &&
                          post.author.avatarUrl!.isNotEmpty
                      ? NetworkImage(post.author.avatarUrl!)
                      : null,
                  child: (post.author.avatarUrl == null ||
                          post.author.avatarUrl!.isEmpty)
                      ? Text(
                          post.author.name.isNotEmpty
                              ? post.author.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: _kOrange,
                              fontWeight: FontWeight.w900))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.author.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.kText,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (post.author.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                size: 14, color: _kOrange),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _friendlyDate(post.createdAt, isAr),
                        style:
                            TextStyle(color: context.kSub, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (loved ? Colors.green : Colors.redAccent)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        loved
                            ? Icons.favorite_rounded
                            : Icons.thumb_down_alt_rounded,
                        size: 14,
                        color: loved ? Colors.green : Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        loved
                            ? (isAr ? 'حلوة' : 'Loved')
                            : (isAr ? 'مش حلوة' : 'Skip'),
                        style: TextStyle(
                          color: loved ? Colors.green : Colors.redAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Images (if any)
          if (post.imageUrls.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: PageView.builder(
                itemCount: post.imageUrls.length,
                itemBuilder: (_, i) => Image.network(
                  post.imageUrls[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFEEEEEE),
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),

          // ── Caption + property link
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.caption != null && post.caption!.trim().isNotEmpty) ...[
                  Text(
                    post.caption!.trim(),
                    style: TextStyle(
                      color: context.kText,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                InkWell(
                  onTap: () => _openProperty(context, post.propertyId),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kOrange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _kOrange.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.home_work_rounded,
                            color: _kOrange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post.property.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: context.kText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 1),
                              Text(post.property.area,
                                  style: TextStyle(
                                      color: context.kSub, fontSize: 11)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded,
                            color: _kOrange),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProperty(BuildContext ctx, int pid) async {
    await Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => PropertyDetailsPage(propertyId: pid),
      ),
    );
  }

  String _friendlyDate(DateTime dt, bool isAr) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) {
      return intl.DateFormat(isAr ? 'dd MMM' : 'dd MMM yyyy',
              isAr ? 'ar' : 'en')
          .format(dt);
    }
    if (diff.inHours >= 1) {
      return isAr ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    }
    if (diff.inMinutes >= 1) {
      return isAr
          ? 'منذ ${diff.inMinutes} دقيقة'
          : '${diff.inMinutes}m ago';
    }
    return isAr ? 'الآن' : 'just now';
  }
}

// ══════════════════════════════════════════════════════════════
//  Compose page
// ══════════════════════════════════════════════════════════════

class _ComposeTripPostPage extends StatefulWidget {
  const _ComposeTripPostPage();
  @override
  State<_ComposeTripPostPage> createState() => _ComposeTripPostPageState();
}

class _ComposeTripPostPageState extends State<_ComposeTripPostPage> {
  List<EligibleBooking> _eligible = const [];
  bool _loading = true;
  String? _error;

  EligibleBooking? _selectedBooking;
  TripVerdict _verdict = TripVerdict.loved;
  final _captionCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadEligible();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEligible() async {
    try {
      _eligible = await TripPostService.eligibleBookings();
      _selectedBooking = _eligible.isNotEmpty ? _eligible.first : null;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final b = _selectedBooking;
    if (b == null) return;
    setState(() => _submitting = true);
    try {
      await TripPostService.create(
        bookingId: b.bookingId,
        verdict: _verdict,
        caption: _captionCtrl.text.trim().isEmpty
            ? null
            : _captionCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل النشر: $e'),
        backgroundColor: const Color(0xFFEF5350),
      ));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        title: Text(appSettings.arabic ? 'شارك رحلتك' : 'Share your trip'),
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.kSub)))
                )
              : _eligible.isEmpty
                  ? _noEligibleState()
                  : _form(),
    );
  }

  Widget _noEligibleState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty_rounded,
                size: 72, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              appSettings.arabic
                  ? 'ماعندكش رحلات مكتملة تنشرها لسه — احجز واستمتع الأول 🙂'
                  : 'No completed trips to post yet — book one first 🙂',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.kSub, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(appSettings.arabic ? 'اختر الرحلة' : 'Pick your trip',
            style: TextStyle(
                color: context.kText,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ..._eligible.map((b) {
          final sel = _selectedBooking?.bookingId == b.bookingId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedBooking = b),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sel
                      ? _kOrange.withValues(alpha: 0.10)
                      : context.kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: sel
                          ? _kOrange
                          : context.kBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      sel
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: sel ? _kOrange : context.kSub,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.propertyName,
                              style: TextStyle(
                                  color: context.kText,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                              '${appSettings.arabic ? "انتهت في" : "Ended"} '
                              '${intl.DateFormat('dd/MM/yyyy').format(b.checkOut)}',
                              style: TextStyle(
                                  color: context.kSub, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 18),
        Text(appSettings.arabic ? 'كانت الرحلة إزاي؟' : 'How was it?',
            style: TextStyle(
                color: context.kText,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _verdictChip(TripVerdict.loved)),
          const SizedBox(width: 10),
          Expanded(child: _verdictChip(TripVerdict.disliked)),
        ]),
        const SizedBox(height: 18),
        TextField(
          controller: _captionCtrl,
          maxLines: 5,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText: appSettings.arabic
                ? 'اكتب عن رحلتك (اختياري)'
                : 'Write about your trip (optional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _submitting || _selectedBooking == null ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              appSettings.arabic ? 'نشر البوست' : 'Post',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _verdictChip(TripVerdict v) {
    final sel = _verdict == v;
    final loved = v == TripVerdict.loved;
    final color = loved ? Colors.green : Colors.redAccent;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _verdict = v),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.12) : context.kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? color : context.kBorder),
        ),
        child: Column(
          children: [
            Icon(
              loved
                  ? Icons.favorite_rounded
                  : Icons.thumb_down_alt_rounded,
              color: sel ? color : context.kSub,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              loved
                  ? (appSettings.arabic ? 'كانت حلوة' : 'Loved it')
                  : (appSettings.arabic ? 'مش حلوة' : 'Didn’t like it'),
              style: TextStyle(
                color: sel ? color : context.kText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
