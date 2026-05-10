// ═══════════════════════════════════════════════════════════════
//  TALAA — User Verification Admin Service (KYC)
//  Wraps the admin endpoints under ``/admin/user-verifications``.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

class UserVerificationItem {
  final int id;
  final int userId;
  final int? reviewedBy;
  final String status;
  final String idDocType;
  final String idFrontUrl;
  final String? idBackUrl;
  final String selfieUrl;
  final String? adminNote;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  UserVerificationItem({
    required this.id,
    required this.userId,
    required this.reviewedBy,
    required this.status,
    required this.idDocType,
    required this.idFrontUrl,
    required this.idBackUrl,
    required this.selfieUrl,
    required this.adminNote,
    required this.submittedAt,
    required this.reviewedAt,
  });

  factory UserVerificationItem.fromJson(Map<String, dynamic> j) {
    DateTime? p(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);
    return UserVerificationItem(
      id: (j['id'] as num).toInt(),
      userId: (j['user_id'] as num).toInt(),
      reviewedBy: (j['reviewed_by'] as num?)?.toInt(),
      status: j['status'] as String? ?? 'pending',
      idDocType: j['id_doc_type'] as String? ?? 'national_id',
      idFrontUrl: j['id_front_url'] as String? ?? '',
      idBackUrl: j['id_back_url'] as String?,
      selfieUrl: j['selfie_url'] as String? ?? '',
      adminNote: j['admin_note'] as String?,
      submittedAt: p(j['submitted_at']) ?? DateTime.now(),
      reviewedAt: p(j['reviewed_at']),
    );
  }
}

class UserVerificationAdminService {
  static final _api = ApiClient();

  static Future<List<UserVerificationItem>> listPending(
      {int limit = 50}) async {
    final res =
        await _api.get('/admin/user-verifications/pending?limit=$limit');
    return (res as List)
        .map((e) =>
            UserVerificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<UserVerificationItem> approve(int id, {String? note}) async {
    final res =
        await _api.post('/admin/user-verifications/$id/approve', {
      if (note != null && note.isNotEmpty) 'admin_note': note,
    });
    return UserVerificationItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<UserVerificationItem> reject(int id,
      {required String note}) async {
    final res = await _api.post('/admin/user-verifications/$id/reject', {
      'admin_note': note,
    });
    return UserVerificationItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<UserVerificationItem> needsEdit(int id,
      {required String note}) async {
    final res =
        await _api.post('/admin/user-verifications/$id/needs-edit', {
      'admin_note': note,
    });
    return UserVerificationItem.fromJson(res as Map<String, dynamic>);
  }
}
