// ═══════════════════════════════════════════════════════════════
//  TALAA — Campaign Service (Push Broadcast Campaigns)
//  Wraps the admin-only ``/campaigns`` endpoints.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

enum CampaignAudience {
  allUsers('all_users'),
  hosts('hosts'),
  guests('guests'),
  byArea('by_area'),
  recentBookers('recent_bookers');

  final String apiValue;
  const CampaignAudience(this.apiValue);

  String get arabic => switch (this) {
        allUsers => 'كل المستخدمين',
        hosts => 'المضيفون فقط',
        guests => 'الضيوف فقط',
        byArea => 'منطقة محددة',
        recentBookers => 'الحاجزون مؤخراً',
      };

  static CampaignAudience parse(String v) {
    return CampaignAudience.values.firstWhere(
      (e) => e.apiValue == v,
      orElse: () => CampaignAudience.allUsers,
    );
  }
}

enum CampaignStatus {
  draft,
  scheduled,
  sending,
  sent,
  failed,
  cancelled;

  static CampaignStatus parse(String v) {
    return CampaignStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => CampaignStatus.draft,
    );
  }

  String get arabic => switch (this) {
        draft => 'مسودة',
        scheduled => 'مجدولة',
        sending => 'جاري الإرسال',
        sent => 'تم الإرسال',
        failed => 'فشل',
        cancelled => 'ملغية',
      };
}

class CampaignModel {
  final int id;
  final int? createdBy;
  final String titleAr;
  final String? titleEn;
  final String bodyAr;
  final String? bodyEn;
  final String? deeplink;
  final CampaignAudience audience;
  final String? filterArea;
  final int? filterRecentDays;
  final CampaignStatus status;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final int targetCount;
  final int successCount;
  final DateTime createdAt;

  CampaignModel({
    required this.id,
    required this.createdBy,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.deeplink,
    required this.audience,
    required this.filterArea,
    required this.filterRecentDays,
    required this.status,
    required this.scheduledAt,
    required this.sentAt,
    required this.targetCount,
    required this.successCount,
    required this.createdAt,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> j) {
    DateTime? p(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);
    return CampaignModel(
      id: (j['id'] as num).toInt(),
      createdBy: (j['created_by'] as num?)?.toInt(),
      titleAr: j['title_ar'] as String,
      titleEn: j['title_en'] as String?,
      bodyAr: j['body_ar'] as String,
      bodyEn: j['body_en'] as String?,
      deeplink: j['deeplink'] as String?,
      audience: CampaignAudience.parse(j['audience'] as String),
      filterArea: j['filter_area'] as String?,
      filterRecentDays: (j['filter_recent_days'] as num?)?.toInt(),
      status: CampaignStatus.parse(j['status'] as String),
      scheduledAt: p(j['scheduled_at']),
      sentAt: p(j['sent_at']),
      targetCount: (j['target_count'] as num?)?.toInt() ?? 0,
      successCount: (j['success_count'] as num?)?.toInt() ?? 0,
      createdAt: p(j['created_at']) ?? DateTime.now(),
    );
  }
}

class CampaignService {
  static final _api = ApiClient();

  static Future<List<CampaignModel>> list({String? status}) async {
    final qs = status != null ? '?status=$status' : '';
    final res = await _api.get('/campaigns$qs');
    return (res as List)
        .map((e) => CampaignModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<CampaignModel> create({
    required String titleAr,
    required String bodyAr,
    required CampaignAudience audience,
    String? titleEn,
    String? bodyEn,
    String? filterArea,
    int? filterRecentDays,
    String? deeplink,
    DateTime? scheduledAt,
  }) async {
    final body = <String, dynamic>{
      'title_ar': titleAr,
      'body_ar': bodyAr,
      'audience': audience.apiValue,
      if (titleEn != null && titleEn.isNotEmpty) 'title_en': titleEn,
      if (bodyEn != null && bodyEn.isNotEmpty) 'body_en': bodyEn,
      if (filterArea != null && filterArea.isNotEmpty)
        'filter_area': filterArea,
      if (filterRecentDays != null) 'filter_recent_days': filterRecentDays,
      if (deeplink != null && deeplink.isNotEmpty) 'deeplink': deeplink,
      if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
    };
    final res = await _api.post('/campaigns', body);
    return CampaignModel.fromJson(res as Map<String, dynamic>);
  }

  static Future<int> previewAudience(int campaignId) async {
    final res = await _api.get('/campaigns/$campaignId/preview');
    return (res['count'] as num?)?.toInt() ?? 0;
  }

  static Future<CampaignModel> send(int campaignId) async {
    final res = await _api.post('/campaigns/$campaignId/send', const {});
    return CampaignModel.fromJson(res as Map<String, dynamic>);
  }

  static Future<CampaignModel> cancel(int campaignId) async {
    final res = await _api.post('/campaigns/$campaignId/cancel', const {});
    return CampaignModel.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> delete(int campaignId) async {
    await _api.delete('/campaigns/$campaignId');
  }
}
