// ═══════════════════════════════════════════════════════════════
//  TALAA — Report Service
//  Users can file reports; admins can moderate them.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

/// Matches backend `ReportTarget` enum.
enum ReportTarget { property, user, review, booking }

String _targetStr(ReportTarget t) => t.name;

/// Matches backend `ReportReason` enum.
enum ReportReason {
  spam,
  inappropriate,
  fraud,
  fakeListing,
  abuse,
  notAsDescribed,
  paymentIssue,
  other,
}

extension ReportReasonCode on ReportReason {
  String get code {
    switch (this) {
      case ReportReason.spam:
        return 'spam';
      case ReportReason.inappropriate:
        return 'inappropriate';
      case ReportReason.fraud:
        return 'fraud';
      case ReportReason.fakeListing:
        return 'fake_listing';
      case ReportReason.abuse:
        return 'abuse';
      case ReportReason.notAsDescribed:
        return 'not_as_described';
      case ReportReason.paymentIssue:
        return 'payment_issue';
      case ReportReason.other:
        return 'other';
    }
  }

  /// Arabic display name for the reason.
  String get labelAr {
    switch (this) {
      case ReportReason.spam:
        return 'سبام';
      case ReportReason.inappropriate:
        return 'محتوى غير لائق';
      case ReportReason.fraud:
        return 'احتيال';
      case ReportReason.fakeListing:
        return 'عقار وهمي';
      case ReportReason.abuse:
        return 'إساءة';
      case ReportReason.notAsDescribed:
        return 'غير مطابق للوصف';
      case ReportReason.paymentIssue:
        return 'مشكلة في الدفع';
      case ReportReason.other:
        return 'أخرى';
    }
  }
}

class ReportModel {
  final int id;
  final int reporterId;
  final String targetType;
  final int targetId;
  final String reason;
  final String? details;
  final String status;
  final String? resolutionNotes;
  final int? resolvedById;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    required this.status,
    required this.resolutionNotes,
    required this.resolvedById,
    required this.resolvedAt,
    required this.createdAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> j) => ReportModel(
        id: j['id'] as int,
        reporterId: j['reporter_id'] as int,
        targetType: j['target_type'] as String,
        targetId: j['target_id'] as int,
        reason: j['reason'] as String,
        details: j['details'] as String?,
        status: j['status'] as String,
        resolutionNotes: j['resolution_notes'] as String?,
        resolvedById: j['resolved_by_id'] as int?,
        resolvedAt: j['resolved_at'] != null
            ? DateTime.parse(j['resolved_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ReportService {
  static final _api = ApiClient();

  /// File a new report as the logged-in user.
  static Future<ReportModel> create({
    required ReportTarget target,
    required int targetId,
    required ReportReason reason,
    String? details,
  }) async {
    final body = {
      'target_type': _targetStr(target),
      'target_id': targetId,
      'reason': reason.code,
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
    };
    final res = await _api.post('/reports', body);
    return ReportModel.fromJson(res as Map<String, dynamic>);
  }

  /// My own reports (history / tracking).
  static Future<List<ReportModel>> listMine() async {
    final res = await _api.get('/reports/mine');
    return (res as List)
        .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Admin endpoints ──────────────────────────────────────
  static Future<List<ReportModel>> adminList({
    String? status,
    String? targetType,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (status != null) 'status': status,
      if (targetType != null) 'target_type': targetType,
    };
    final query = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    final res = await _api.get('/reports/admin?$query');
    return (res as List)
        .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> adminStats() async {
    final res = await _api.get('/reports/admin/stats');
    return res as Map<String, dynamic>;
  }

  static Future<ReportModel> adminResolve(int id, {String? notes}) async {
    final res = await _api.patch(
      '/reports/admin/$id/resolve',
      {if (notes != null) 'notes': notes},
    );
    return ReportModel.fromJson(res as Map<String, dynamic>);
  }

  static Future<ReportModel> adminDismiss(int id, {String? notes}) async {
    final res = await _api.patch(
      '/reports/admin/$id/dismiss',
      {if (notes != null) 'notes': notes},
    );
    return ReportModel.fromJson(res as Map<String, dynamic>);
  }
}
