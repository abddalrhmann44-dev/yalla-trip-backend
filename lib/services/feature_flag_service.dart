// ═══════════════════════════════════════════════════════════════
//  TALAA — Feature Flag Service
//  Wraps the admin endpoints under ``/admin/feature-flags``.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

class FeatureFlagItem {
  final int id;
  final String key;
  final String? description;
  final String kind; // boolean | rollout | ab_test
  final bool enabled;
  final bool defaultValue;
  final int rolloutPercent;
  final String? variantA;
  final String? variantB;
  final String? lastChangeNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int assignmentCount;

  FeatureFlagItem({
    required this.id,
    required this.key,
    required this.description,
    required this.kind,
    required this.enabled,
    required this.defaultValue,
    required this.rolloutPercent,
    required this.variantA,
    required this.variantB,
    required this.lastChangeNote,
    required this.createdAt,
    required this.updatedAt,
    required this.assignmentCount,
  });

  factory FeatureFlagItem.fromJson(Map<String, dynamic> j) {
    DateTime p(Object? v) =>
        v == null ? DateTime.now() : DateTime.tryParse(v as String) ?? DateTime.now();
    return FeatureFlagItem(
      id: (j['id'] as num).toInt(),
      key: j['key'] as String,
      description: j['description'] as String?,
      kind: j['kind'] as String? ?? 'boolean',
      enabled: j['enabled'] as bool? ?? false,
      defaultValue: j['default_value'] as bool? ?? false,
      rolloutPercent: (j['rollout_percent'] as num?)?.toInt() ?? 0,
      variantA: j['variant_a'] as String?,
      variantB: j['variant_b'] as String?,
      lastChangeNote: j['last_change_note'] as String?,
      createdAt: p(j['created_at']),
      updatedAt: p(j['updated_at']),
      assignmentCount: (j['assignment_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class FeatureFlagService {
  static final _api = ApiClient();

  static Future<List<FeatureFlagItem>> list() async {
    final res = await _api.get('/admin/feature-flags');
    return (res as List)
        .map((e) => FeatureFlagItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<FeatureFlagItem> create({
    required String key,
    String? description,
    String kind = 'boolean',
    bool enabled = false,
    bool defaultValue = false,
    int rolloutPercent = 0,
    String? variantA,
    String? variantB,
  }) async {
    final res = await _api.post('/admin/feature-flags', {
      'key': key,
      if (description != null) 'description': description,
      'kind': kind,
      'enabled': enabled,
      'default_value': defaultValue,
      'rollout_percent': rolloutPercent,
      if (variantA != null) 'variant_a': variantA,
      if (variantB != null) 'variant_b': variantB,
    });
    return FeatureFlagItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<FeatureFlagItem> update(
    int id, {
    bool? enabled,
    bool? defaultValue,
    int? rolloutPercent,
    String? variantA,
    String? variantB,
    String? description,
    String? note,
  }) async {
    final res = await _api.patch('/admin/feature-flags/$id', {
      if (enabled != null) 'enabled': enabled,
      if (defaultValue != null) 'default_value': defaultValue,
      if (rolloutPercent != null) 'rollout_percent': rolloutPercent,
      if (variantA != null) 'variant_a': variantA,
      if (variantB != null) 'variant_b': variantB,
      if (description != null) 'description': description,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return FeatureFlagItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> delete(int id) =>
      _api.delete('/admin/feature-flags/$id');

  static Future<void> resetAssignments(int id) =>
      _api.post('/admin/feature-flags/$id/reset-assignments', {});
}
