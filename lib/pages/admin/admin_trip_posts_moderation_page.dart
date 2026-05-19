// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Trip Posts Moderation Page
//
//  عرض جميع بوستات "أحسن رحلة" مع إمكانية:
//  • الفلترة: الكل / المخفية فقط / محبوبة / مش حلوة
//  • البحث باسم الكاتب أو العقار
//  • إخفاء / إظهار بوست
//  • حذف بوست نهائياً
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);
const _kAmber  = Color(0xFFFFA726);

class AdminTripPostsModerationPage extends StatefulWidget {
  const AdminTripPostsModerationPage({super.key});
  @override
  State<AdminTripPostsModerationPage> createState() =>
      _AdminTripPostsModerationPageState();
}

enum _Filter { all, hiddenOnly, loved, disliked }

class _AdminTripPostsModerationPageState
    extends State<AdminTripPostsModerationPage> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  _Filter _filter = _Filter.all;
  List<Map<String, dynamic>> _posts = [];

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
      final posts = await AdminService.adminListTripPosts(
        hiddenOnly: _filter == _Filter.hiddenOnly,
        verdict: _filter == _Filter.loved
            ? 'loved'
            : _filter == _Filter.disliked
                ? 'disliked'
                : null,
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
      );
      setState(() => _posts = posts);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  Future<void> _toggleHide(Map<String, dynamic> post) async {
    final hidden = post['is_hidden'] as bool;
    final id = post['id'] as int;
    try {
      if (hidden) {
        await AdminService.adminUnhideTripPost(id);
        _snack('تم إظهار البوست', _kGreen);
      } else {
        await AdminService.adminHideTripPost(id);
        _snack('تم إخفاء البوست', _kAmber);
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('خطأ: $e', _kRed);
    }
  }

  Future<void> _delete(Map<String, dynamic> post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف البوست',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
            'هيتحذف نهائياً ومش هيرجع. تأكيد؟',
            style: TextStyle(fontSize: 13)),
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('حذف',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await AdminService.adminDeleteTripPost(post['id'] as int);
      _snack('تم الحذف', _kGreen);
      _load();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('خطأ: $e', _kRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('إشراف بوستات الرحلات',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(children: [
        // ── Filter chips ──────────────────────────────────────
        Container(
          color: _kOcean,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('الكل', _Filter.all),
              const SizedBox(width: 8),
              _filterChip('المخفية', _Filter.hiddenOnly),
              const SizedBox(width: 8),
              _filterChip('محبوبة ❤️', _Filter.loved),
              const SizedBox(width: 8),
              _filterChip('مش حلوة 👎', _Filter.disliked),
            ]),
          ),
        ),

        // ── Search ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _searchCtrl,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'ابحث باسم الكاتب أو العقار...',
              hintStyle:
                  TextStyle(fontSize: 13, color: context.kSub),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _load();
                      })
                  : null,
              isDense: true,
              filled: true,
              fillColor: context.kCard,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),

        // ── Count badge ───────────────────────────────────────
        if (!_loading)
          Padding(
            padding: const EdgeInsets.only(
                left: 14, right: 14, bottom: 8),
            child: Row(children: [
              Text('${_posts.length} بوست',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.kSub)),
            ]),
          ),

        // ── List ──────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kOcean))
              : _posts.isEmpty
                  ? Center(
                      child: Text('لا توجد بوستات',
                          style: TextStyle(
                              color: context.kSub,
                              fontWeight: FontWeight.w600)))
                  : RefreshIndicator(
                      color: _kOcean,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 24),
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _postCard(_posts[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, _Filter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _load();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? _kOcean : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final id = post['id'] as int;
    final verdict = post['verdict'] as String;
    final caption = post['caption'] as String?;
    final isHidden = post['is_hidden'] as bool;
    final authorName =
        (post['author_name'] as String?) ?? 'مستخدم #${post['author_id']}';
    final propName =
        (post['property_name'] as String?) ?? 'عقار #${post['property_id']}';
    final images = (post['image_urls'] as List?)?.cast<String>() ?? [];
    final isLoved = verdict == 'loved';

    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHidden
              ? _kRed.withValues(alpha: 0.3)
              : context.kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              // Verdict badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLoved
                      ? _kGreen.withValues(alpha: 0.12)
                      : _kRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLoved ? 'محبوبة ❤️' : 'مش حلوة 👎',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isLoved ? _kGreen : _kRed,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isHidden)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'مخفي',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kRed),
                  ),
                ),
              const Spacer(),
              Text('#$id',
                  style: TextStyle(
                      fontSize: 11,
                      color: context.kSub,
                      fontWeight: FontWeight.w600)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author + property
                Row(children: [
                  Icon(Icons.person_rounded,
                      size: 14, color: context.kSub),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(authorName,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.kText)),
                  ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.apartment_rounded,
                      size: 14, color: context.kSub),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(propName,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.kSub)),
                  ),
                ]),

                // Caption
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: context.kText,
                          height: 1.4)),
                ],

                // Images thumbnails
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 6),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          images[i],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: context.kBorder,
                            child: Icon(Icons.broken_image_rounded,
                                color: context.kSub, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Actions ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _toggleHide(post),
                  icon: Icon(
                    isHidden
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 16,
                    color: isHidden ? _kGreen : _kAmber,
                  ),
                  label: Text(
                    isHidden ? 'إظهار' : 'إخفاء',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isHidden ? _kGreen : _kAmber),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color:
                            isHidden ? _kGreen : _kAmber),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _delete(post),
                  icon: const Icon(Icons.delete_rounded,
                      size: 16, color: _kRed),
                  label: const Text('حذف',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kRed)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kRed),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
