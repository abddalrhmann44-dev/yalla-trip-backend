// ═══════════════════════════════════════════════════════════════
//  TALAA — Promo Banner Service
//  Public endpoint:  /promo-banners/active   (homepage carousel)
//  Admin endpoints:  /admin/promo-banners/*  (CRUD)
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

class PromoBannerItem {
  final int id;
  final String? titleAr;
  final String? titleEn;
  final String? subtitleAr;
  final String? subtitleEn;
  final String imageUrl;
  final String? accentColor;
  final String ctaKind; // none | deeplink | url | property | area
  final String? ctaTarget;
  final int priority;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
  final int impressions;
  final int clicks;
  final int? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromoBannerItem({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.imageUrl,
    required this.accentColor,
    required this.ctaKind,
    required this.ctaTarget,
    required this.priority,
    required this.isActive,
    required this.startAt,
    required this.endAt,
    required this.impressions,
    required this.clicks,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromoBannerItem.fromJson(Map<String, dynamic> j) {
    DateTime? p(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);
    return PromoBannerItem(
      id: (j['id'] as num).toInt(),
      titleAr: j['title_ar'] as String?,
      titleEn: j['title_en'] as String?,
      subtitleAr: j['subtitle_ar'] as String?,
      subtitleEn: j['subtitle_en'] as String?,
      imageUrl: j['image_url'] as String? ?? '',
      accentColor: j['accent_color'] as String?,
      ctaKind: j['cta_kind'] as String? ?? 'none',
      ctaTarget: j['cta_target'] as String?,
      priority: (j['priority'] as num?)?.toInt() ?? 0,
      isActive: j['is_active'] as bool? ?? false,
      startAt: p(j['start_at']),
      endAt: p(j['end_at']),
      impressions: (j['impressions'] as num?)?.toInt() ?? 0,
      clicks: (j['clicks'] as num?)?.toInt() ?? 0,
      createdBy: (j['created_by'] as num?)?.toInt(),
      createdAt: p(j['created_at']) ?? DateTime.now(),
      updatedAt: p(j['updated_at']) ?? DateTime.now(),
    );
  }
}

class PromoBannerService {
  static final _api = ApiClient();

  // ── Public ──────────────────────────────────────────────
  /// Homepage carousel feed — anonymous-friendly.
  static Future<List<PromoBannerItem>> activeBanners() async {
    final res = await _api.get('/promo-banners/active');
    return (res as List)
        .map((e) => PromoBannerItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Best-effort metric.  Failures are swallowed by callers so a
  /// dropped network request doesn't turn into a user-visible error.
  static Future<void> logImpression(int id) async {
    try {
      await _api.post('/promo-banners/$id/impression', {});
    } catch (_) {/* best-effort */}
  }

  static Future<void> logClick(int id) async {
    try {
      await _api.post('/promo-banners/$id/click', {});
    } catch (_) {/* best-effort */}
  }

  // ── Admin ──────────────────────────────────────────────
  static Future<List<PromoBannerItem>> adminList() async {
    final res = await _api.get('/admin/promo-banners');
    return (res as List)
        .map((e) => PromoBannerItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<PromoBannerItem> create({
    required String imageUrl,
    String? titleAr,
    String? titleEn,
    String? subtitleAr,
    String? subtitleEn,
    String? accentColor,
    String ctaKind = 'none',
    String? ctaTarget,
    int priority = 0,
    bool isActive = false,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final res = await _api.post('/admin/promo-banners', {
      'image_url': imageUrl,
      if (titleAr != null) 'title_ar': titleAr,
      if (titleEn != null) 'title_en': titleEn,
      if (subtitleAr != null) 'subtitle_ar': subtitleAr,
      if (subtitleEn != null) 'subtitle_en': subtitleEn,
      if (accentColor != null) 'accent_color': accentColor,
      'cta_kind': ctaKind,
      if (ctaTarget != null) 'cta_target': ctaTarget,
      'priority': priority,
      'is_active': isActive,
      if (startAt != null) 'start_at': startAt.toIso8601String(),
      if (endAt != null) 'end_at': endAt.toIso8601String(),
    });
    return PromoBannerItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<PromoBannerItem> update(
    int id,
    Map<String, dynamic> changes,
  ) async {
    final res = await _api.patch('/admin/promo-banners/$id', changes);
    return PromoBannerItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> delete(int id) =>
      _api.delete('/admin/promo-banners/$id');
}
