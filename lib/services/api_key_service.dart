// ═══════════════════════════════════════════════════════════════
//  TALAA — API Key Service
//  Wraps the admin endpoints under ``/admin/api-keys``.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

class ApiKeyItem {
  final int id;
  final String name;
  final String? description;
  final String keyPrefix;
  final List<String> scopes;
  final int? createdBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime? lastUsedAt;
  final int usageCount;
  // Plaintext is ONLY populated on the creation response.
  final String? plaintext;

  bool get isRevoked => revokedAt != null;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  ApiKeyItem({
    required this.id,
    required this.name,
    required this.description,
    required this.keyPrefix,
    required this.scopes,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    required this.revokedAt,
    required this.lastUsedAt,
    required this.usageCount,
    this.plaintext,
  });

  factory ApiKeyItem.fromJson(Map<String, dynamic> j) {
    DateTime? p(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);
    return ApiKeyItem(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String,
      description: j['description'] as String?,
      keyPrefix: j['key_prefix'] as String? ?? '',
      scopes: (j['scopes'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdBy: (j['created_by'] as num?)?.toInt(),
      createdAt: p(j['created_at']) ?? DateTime.now(),
      expiresAt: p(j['expires_at']),
      revokedAt: p(j['revoked_at']),
      lastUsedAt: p(j['last_used_at']),
      usageCount: (j['usage_count'] as num?)?.toInt() ?? 0,
      plaintext: j['plaintext'] as String?,
    );
  }
}

class ApiKeyService {
  static final _api = ApiClient();

  static Future<List<String>> allowedScopes() async {
    final res = await _api.get('/admin/api-keys/scopes');
    final m = res as Map<String, dynamic>;
    return (m['scopes'] as List).map((e) => e.toString()).toList();
  }

  static Future<List<ApiKeyItem>> list() async {
    final res = await _api.get('/admin/api-keys');
    return (res as List)
        .map((e) => ApiKeyItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns an [ApiKeyItem] whose [plaintext] is non-null.  Show it
  /// to the admin **once**; the server cannot retrieve it later.
  static Future<ApiKeyItem> create({
    required String name,
    String? description,
    List<String> scopes = const [],
    DateTime? expiresAt,
  }) async {
    final res = await _api.post('/admin/api-keys', {
      'name': name,
      if (description != null) 'description': description,
      'scopes': scopes,
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
    });
    return ApiKeyItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<ApiKeyItem> revoke(int id) async {
    final res = await _api.post('/admin/api-keys/$id/revoke', {});
    return ApiKeyItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> delete(int id) => _api.delete('/admin/api-keys/$id');
}
