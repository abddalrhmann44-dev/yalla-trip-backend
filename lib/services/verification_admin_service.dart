// ═══════════════════════════════════════════════════════════════
//  TALAA — Verification Admin Service
//  Admin moderation of property-ownership verifications.
//  Wraps the admin endpoints under ``/verifications``.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

class VerificationItem {
  final int id;
  final int propertyId;
  final int? submittedBy;
  final int? reviewedBy;
  final String status; // pending | approved | rejected | needs_edit
  final List<String> documentUrls;
  final String primaryDocumentType;
  final String? hostNote;
  final String? adminNote;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  VerificationItem({
    required this.id,
    required this.propertyId,
    required this.submittedBy,
    required this.reviewedBy,
    required this.status,
    required this.documentUrls,
    required this.primaryDocumentType,
    required this.hostNote,
    required this.adminNote,
    required this.submittedAt,
    required this.reviewedAt,
  });

  factory VerificationItem.fromJson(Map<String, dynamic> j) {
    DateTime? p(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);
    return VerificationItem(
      id: (j['id'] as num).toInt(),
      propertyId: (j['property_id'] as num).toInt(),
      submittedBy: (j['submitted_by'] as num?)?.toInt(),
      reviewedBy: (j['reviewed_by'] as num?)?.toInt(),
      status: j['status'] as String? ?? 'pending',
      documentUrls: (j['document_urls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      primaryDocumentType:
          j['primary_document_type'] as String? ?? 'ownership_contract',
      hostNote: j['host_note'] as String?,
      adminNote: j['admin_note'] as String?,
      submittedAt: p(j['submitted_at']) ?? DateTime.now(),
      reviewedAt: p(j['reviewed_at']),
    );
  }
}

class VerificationAdminService {
  static final _api = ApiClient();

  static Future<List<VerificationItem>> listPending({int limit = 50}) async {
    final res = await _api.get('/verifications/pending?limit=$limit');
    return (res as List)
        .map((e) => VerificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<VerificationItem> get(int verificationId) async {
    final res = await _api.get('/verifications/$verificationId');
    return VerificationItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<VerificationItem> approve(int id, {String? note}) async {
    final res = await _api.post('/verifications/$id/approve', {
      if (note != null && note.isNotEmpty) 'admin_note': note,
    });
    return VerificationItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<VerificationItem> reject(int id, {required String note}) async {
    final res = await _api.post('/verifications/$id/reject', {
      'admin_note': note,
    });
    return VerificationItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<VerificationItem> needsEdit(int id,
      {required String note}) async {
    final res = await _api.post('/verifications/$id/needs-edit', {
      'admin_note': note,
    });
    return VerificationItem.fromJson(res as Map<String, dynamic>);
  }
}
