// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Audit Log Service
//  Read-only wrapper over /admin/audit endpoints.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

class AuditEntry {
  final int id;
  final int? actorId;
  final String? actorEmail;
  final String? actorRole;
  final String action;
  final String? targetType;
  final int? targetId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String? ipAddress;
  final String? userAgent;
  final String? requestId;
  final DateTime createdAt;

  AuditEntry({
    required this.id,
    required this.actorId,
    required this.actorEmail,
    required this.actorRole,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.before,
    required this.after,
    required this.ipAddress,
    required this.userAgent,
    required this.requestId,
    required this.createdAt,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'] as int,
        actorId: j['actor_id'] as int?,
        actorEmail: j['actor_email'] as String?,
        actorRole: j['actor_role'] as String?,
        action: j['action'] as String,
        targetType: j['target_type'] as String?,
        targetId: j['target_id'] as int?,
        before: (j['before'] as Map?)?.cast<String, dynamic>(),
        after: (j['after'] as Map?)?.cast<String, dynamic>(),
        ipAddress: j['ip_address'] as String?,
        userAgent: j['user_agent'] as String?,
        requestId: j['request_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AuditStats {
  final int totalEntries;
  final List<({String action, int count})> topActions;
  final List<({String actor, int count})> topActors;

  AuditStats({
    required this.totalEntries,
    required this.topActions,
    required this.topActors,
  });

  factory AuditStats.fromJson(Map<String, dynamic> j) => AuditStats(
        totalEntries: (j['total_entries'] as num).toInt(),
        topActions: [
          for (final a in (j['top_actions'] as List))
            (
              action: a['action'] as String,
              count: (a['count'] as num).toInt(),
            )
        ],
        topActors: [
          for (final a in (j['top_actors'] as List))
            (
              actor: (a['actor'] as String?) ?? 'unknown',
              count: (a['count'] as num).toInt(),
            )
        ],
      );
}

class AuditLogService {
  static final _api = ApiClient();

  static Future<List<AuditEntry>> list({
    String? action,
    String? actionPrefix,
    int? actorId,
    String? targetType,
    int? targetId,
    int limit = 100,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (action != null) 'action': action,
      if (actionPrefix != null) 'action_prefix': actionPrefix,
      if (actorId != null) 'actor_id': '$actorId',
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': '$targetId',
    };
    final q = qp.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final res = await _api.get('/admin/audit?$q');
    return (res as List)
        .map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AuditStats> statsOverview() async {
    final res = await _api.get('/admin/audit/stats/overview');
    return AuditStats.fromJson(res as Map<String, dynamic>);
  }
}
