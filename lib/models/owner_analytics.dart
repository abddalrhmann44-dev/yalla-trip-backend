// ═══════════════════════════════════════════════════════════════
//  TALAA — Owner Analytics Model
//  Mirrors the /analytics/owner response.
// ═══════════════════════════════════════════════════════════════

class AnalyticsTotals {
  final int propertiesCount;
  final int bookingsCount;
  final int bookingsCompleted;
  final int bookingsUpcoming;
  final double revenueTotal;
  final double revenuePending;
  final double avgRating;
  final int reviewsCount;

  const AnalyticsTotals({
    required this.propertiesCount,
    required this.bookingsCount,
    required this.bookingsCompleted,
    required this.bookingsUpcoming,
    required this.revenueTotal,
    required this.revenuePending,
    required this.avgRating,
    required this.reviewsCount,
  });

  factory AnalyticsTotals.fromJson(Map<String, dynamic> j) => AnalyticsTotals(
        propertiesCount: j['properties_count'] ?? 0,
        bookingsCount: j['bookings_count'] ?? 0,
        bookingsCompleted: j['bookings_completed'] ?? 0,
        bookingsUpcoming: j['bookings_upcoming'] ?? 0,
        revenueTotal: (j['revenue_total'] ?? 0).toDouble(),
        revenuePending: (j['revenue_pending'] ?? 0).toDouble(),
        avgRating: (j['avg_rating'] ?? 0).toDouble(),
        reviewsCount: j['reviews_count'] ?? 0,
      );
}

class MonthlyPoint {
  final String month; // YYYY-MM
  final int bookings;
  final double revenue;

  const MonthlyPoint({
    required this.month,
    required this.bookings,
    required this.revenue,
  });

  factory MonthlyPoint.fromJson(Map<String, dynamic> j) => MonthlyPoint(
        month: (j['month'] ?? '').toString(),
        bookings: j['bookings'] ?? 0,
        revenue: (j['revenue'] ?? 0).toDouble(),
      );
}

class TopProperty {
  final int propertyId;
  final String name;
  final int bookings;
  final double revenue;
  final double avgRating;
  final int reviewCount;

  const TopProperty({
    required this.propertyId,
    required this.name,
    required this.bookings,
    required this.revenue,
    required this.avgRating,
    required this.reviewCount,
  });

  factory TopProperty.fromJson(Map<String, dynamic> j) => TopProperty(
        propertyId: j['property_id'] ?? 0,
        name: (j['name'] ?? '').toString(),
        bookings: j['bookings'] ?? 0,
        revenue: (j['revenue'] ?? 0).toDouble(),
        avgRating: (j['avg_rating'] ?? 0).toDouble(),
        reviewCount: j['review_count'] ?? 0,
      );
}

class OccupancyPoint {
  final DateTime date;
  final int bookedNights;
  final int totalAvailable;
  final double occupancyRate;

  const OccupancyPoint({
    required this.date,
    required this.bookedNights,
    required this.totalAvailable,
    required this.occupancyRate,
  });

  factory OccupancyPoint.fromJson(Map<String, dynamic> j) => OccupancyPoint(
        date: DateTime.tryParse((j['date'] ?? '').toString()) ?? DateTime.now(),
        bookedNights: j['booked_nights'] ?? 0,
        totalAvailable: j['total_available'] ?? 0,
        occupancyRate: (j['occupancy_rate'] ?? 0).toDouble(),
      );
}

class OwnerAnalytics {
  final DateTime rangeFrom;
  final DateTime rangeTo;
  final AnalyticsTotals totals;
  final List<MonthlyPoint> monthly;
  final List<TopProperty> topProperties;
  final List<OccupancyPoint> occupancy;

  const OwnerAnalytics({
    required this.rangeFrom,
    required this.rangeTo,
    required this.totals,
    required this.monthly,
    required this.topProperties,
    required this.occupancy,
  });

  factory OwnerAnalytics.fromJson(Map<String, dynamic> j) => OwnerAnalytics(
        rangeFrom:
            DateTime.tryParse((j['range_from'] ?? '').toString()) ??
                DateTime.now(),
        rangeTo: DateTime.tryParse((j['range_to'] ?? '').toString()) ??
            DateTime.now(),
        totals: AnalyticsTotals.fromJson(
            (j['totals'] ?? {}) as Map<String, dynamic>),
        monthly: ((j['monthly'] ?? []) as List)
            .map((e) => MonthlyPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        topProperties: ((j['top_properties'] ?? []) as List)
            .map((e) => TopProperty.fromJson(e as Map<String, dynamic>))
            .toList(),
        occupancy: ((j['occupancy'] ?? []) as List)
            .map((e) => OccupancyPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
