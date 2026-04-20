// ═══════════════════════════════════════════════════════════════
//  TALAA — Availability Service
//  Thin DTO + API wrapper over /availability/* endpoints.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

// ── Rule types ──────────────────────────────────────────────

enum RuleType { pricing, minStay, closed, note }

RuleType _ruleTypeFromCode(String s) {
  switch (s) {
    case 'pricing':
      return RuleType.pricing;
    case 'min_stay':
      return RuleType.minStay;
    case 'closed':
      return RuleType.closed;
    case 'note':
      return RuleType.note;
  }
  return RuleType.note;
}

String _ruleTypeToCode(RuleType t) {
  switch (t) {
    case RuleType.pricing:
      return 'pricing';
    case RuleType.minStay:
      return 'min_stay';
    case RuleType.closed:
      return 'closed';
    case RuleType.note:
      return 'note';
  }
}

String ruleTypeLabelAr(RuleType t) {
  switch (t) {
    case RuleType.pricing:
      return 'تسعير مخصص';
    case RuleType.minStay:
      return 'حد أدنى للإقامة';
    case RuleType.closed:
      return 'مغلق';
    case RuleType.note:
      return 'ملاحظة';
  }
}

// ── DTOs ─────────────────────────────────────────────────────

class AvailabilityRule {
  final int id;
  final int propertyId;
  final RuleType ruleType;
  final DateTime startDate;
  final DateTime endDate;
  final double? priceOverride;
  final int? minNights;
  final String? label;
  final String? note;

  const AvailabilityRule({
    required this.id,
    required this.propertyId,
    required this.ruleType,
    required this.startDate,
    required this.endDate,
    this.priceOverride,
    this.minNights,
    this.label,
    this.note,
  });

  factory AvailabilityRule.fromJson(Map<String, dynamic> j) => AvailabilityRule(
        id: j['id'] as int,
        propertyId: j['property_id'] as int,
        ruleType: _ruleTypeFromCode(j['rule_type'] as String),
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: DateTime.parse(j['end_date'] as String),
        priceOverride: (j['price_override'] as num?)?.toDouble(),
        minNights: j['min_nights'] as int?,
        label: j['label'] as String?,
        note: j['note'] as String?,
      );
}

class DayDetail {
  final DateTime date;
  final double basePrice;
  final double effectivePrice;
  final bool isClosed;
  final int minNights;
  final bool isBooked;
  final bool isBlocked;
  final List<String> labels;

  const DayDetail({
    required this.date,
    required this.basePrice,
    required this.effectivePrice,
    this.isClosed = false,
    this.minNights = 1,
    this.isBooked = false,
    this.isBlocked = false,
    this.labels = const [],
  });

  factory DayDetail.fromJson(Map<String, dynamic> j) => DayDetail(
        date: DateTime.parse(j['date'] as String),
        basePrice: (j['base_price'] as num).toDouble(),
        effectivePrice: (j['effective_price'] as num).toDouble(),
        isClosed: j['is_closed'] as bool? ?? false,
        minNights: j['min_nights'] as int? ?? 1,
        isBooked: j['is_booked'] as bool? ?? false,
        isBlocked: j['is_blocked'] as bool? ?? false,
        labels: (j['labels'] as List?)?.cast<String>() ?? [],
      );

  /// True if the day is unavailable for any reason.
  bool get isUnavailable => isClosed || isBooked || isBlocked;
}

// ── Service ──────────────────────────────────────────────────

class AvailabilityService {
  final _api = ApiClient();

  // ── Rules CRUD ──────────────────────────────────────────────

  Future<List<AvailabilityRule>> getRules(
    int propertyId, {
    RuleType? ruleType,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final params = <String, String>{};
    if (ruleType != null) params['rule_type'] = _ruleTypeToCode(ruleType);
    if (fromDate != null) {
      params['from_date'] = fromDate.toIso8601String().split('T').first;
    }
    if (toDate != null) {
      params['to_date'] = toDate.toIso8601String().split('T').first;
    }
    final qs = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    final data = await _api.get('/availability/$propertyId/rules$qs');
    return (data as List).map((j) => AvailabilityRule.fromJson(j)).toList();
  }

  Future<AvailabilityRule> createRule(
    int propertyId, {
    required RuleType ruleType,
    required DateTime startDate,
    required DateTime endDate,
    double? priceOverride,
    int? minNights,
    String? label,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'rule_type': _ruleTypeToCode(ruleType),
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      if (priceOverride != null) 'price_override': priceOverride,
      if (minNights != null) 'min_nights': minNights,
      if (label != null) 'label': label,
      if (note != null) 'note': note,
    };
    final data = await _api.post('/availability/$propertyId/rules', body);
    return AvailabilityRule.fromJson(data);
  }

  Future<AvailabilityRule> updateRule(
    int propertyId,
    int ruleId,
    Map<String, dynamic> fields,
  ) async {
    final data =
        await _api.put('/availability/$propertyId/rules/$ruleId', fields);
    return AvailabilityRule.fromJson(data);
  }

  Future<void> deleteRule(int propertyId, int ruleId) async {
    await _api.delete('/availability/$propertyId/rules/$ruleId');
  }

  // ── Bulk operations ─────────────────────────────────────────

  Future<List<AvailabilityRule>> bulkCreateRules(
    int propertyId,
    List<Map<String, dynamic>> rules,
  ) async {
    final data = await _api.post(
      '/availability/$propertyId/rules/bulk',
      {'rules': rules},
    );
    return (data as List).map((j) => AvailabilityRule.fromJson(j)).toList();
  }

  Future<void> bulkDeleteRules(int propertyId, List<int> ids) async {
    await _api.post(
      '/availability/$propertyId/rules/bulk-delete',
      {'ids': ids},
    );
  }

  // ── Calendar grid ───────────────────────────────────────────

  Future<List<DayDetail>> getCalendarGrid(
    int propertyId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final s = start.toIso8601String().split('T').first;
    final e = end.toIso8601String().split('T').first;
    final data =
        await _api.get('/availability/$propertyId/calendar?start=$s&end=$e');
    return (data as List).map((j) => DayDetail.fromJson(j)).toList();
  }
}
