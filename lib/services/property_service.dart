// ═══════════════════════════════════════════════════════════════
//  TALAA — Property Service
//  All property-related API calls (list, detail, CRUD, images)
// ═══════════════════════════════════════════════════════════════

import 'dart:io';

import '../models/property_model_api.dart';
import '../utils/api_client.dart';

class PropertyService {
  static final _api = ApiClient();

  // ── List properties (with filters + pagination) ───────────
  //
  // Mirrors GET /properties query params.  ``checkIn``/``checkOut``
  // enforce availability server-side so the list never includes
  // already-booked inventory.
  static Future<List<PropertyApi>> getProperties({
    String? area,
    String? category,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    int? bedrooms,
    int? maxGuests,
    bool? instantBooking,
    String? search,
    List<String>? amenities,
    DateTime? checkIn,
    DateTime? checkOut,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String sortBy = 'best_match',
    int page = 1,
    int limit = 20,
  }) async {
    // A plain map doesn't support duplicate keys, so build the query
    // manually to preserve multi-valued ``amenities=X&amenities=Y``.
    final parts = <String>[
      'page=$page',
      'limit=$limit',
      'sort_by=${Uri.encodeComponent(sortBy)}',
    ];
    void add(String k, String? v) {
      if (v != null && v.isNotEmpty) {
        parts.add('$k=${Uri.encodeComponent(v)}');
      }
    }

    add('area', area);
    add('category', category);
    if (minPrice != null) parts.add('min_price=$minPrice');
    if (maxPrice != null) parts.add('max_price=$maxPrice');
    if (minRating != null) parts.add('min_rating=$minRating');
    if (bedrooms != null) parts.add('bedrooms=$bedrooms');
    if (maxGuests != null) parts.add('max_guests=$maxGuests');
    if (instantBooking != null) parts.add('instant_booking=$instantBooking');
    add('search', search);
    if (checkIn != null) {
      parts.add('check_in=${_ymd(checkIn)}');
    }
    if (checkOut != null) {
      parts.add('check_out=${_ymd(checkOut)}');
    }
    if (latitude != null) parts.add('latitude=$latitude');
    if (longitude != null) parts.add('longitude=$longitude');
    if (radiusKm != null) parts.add('radius_km=$radiusKm');
    if (amenities != null) {
      for (final a in amenities) {
        parts.add('amenities=${Uri.encodeComponent(a)}');
      }
    }

    final data = await _api.get('/properties?${parts.join('&')}');
    return (data['items'] as List)
        .map((e) => PropertyApi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── Autocomplete / suggestions ────────────────────────────
  //
  // Returns a small list of {type, id, label, secondary} maps for the
  // search bar dropdown.  ``type`` is one of ``property`` or ``area``.
  static Future<List<Map<String, dynamic>>> suggest(
    String query, {
    int limit = 8,
  }) async {
    if (query.trim().isEmpty) return [];
    final data = await _api.get(
      '/properties/suggest?q=${Uri.encodeComponent(query)}&limit=$limit',
    );
    final list = (data as Map)['suggestions'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  // ── My properties (owner) ────────────────────────────────
  static Future<List<PropertyApi>> getMyProperties() async {
    final data = await _api.get('/properties/mine');
    return (data as List)
        .map((e) => PropertyApi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Get single property ───────────────────────────────────
  static Future<PropertyApi> getProperty(int id) async {
    final data = await _api.get('/properties/$id');
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Similar properties (recommendations) ──────────────────
  static Future<List<PropertyApi>> getSimilar(int id, {int limit = 8}) async {
    final data = await _api.get('/properties/$id/similar?limit=$limit');
    return (data as List)
        .map((e) => PropertyApi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Get properties by area ────────────────────────────────
  static Future<List<PropertyApi>> getByArea(String area) async {
    return getProperties(area: area);
  }

  // ── Search ────────────────────────────────────────────────
  static Future<List<PropertyApi>> search(String query) async {
    return getProperties(search: query);
  }

  // ── Create property (Owner) ───────────────────────────────
  static Future<PropertyApi> createProperty(
      Map<String, dynamic> propertyData) async {
    final data = await _api.post('/properties', propertyData);
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Update property ───────────────────────────────────────
  static Future<PropertyApi> updateProperty(
      int id, Map<String, dynamic> updates) async {
    final data = await _api.put('/properties/$id', updates);
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Delete property ───────────────────────────────────────
  static Future<void> deleteProperty(int id) async {
    await _api.delete('/properties/$id');
  }

  // ── Upload images ─────────────────────────────────────────
  static Future<PropertyApi> uploadImages(
      int propertyId, List<File> images) async {
    final data = await _api.postMultipart(
      '/properties/$propertyId/images',
      images,
    );
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  /// Upload the owner's national-ID front + back for this property.
  ///
  /// Both images are required.  The backend stores the URLs on the
  /// property row so admins can review them during listing approval.
  static Future<PropertyApi> uploadIdDocuments(
    int propertyId, {
    required File front,
    required File back,
  }) async {
    final data = await _api.postMultipart(
      '/properties/$propertyId/id-documents',
      [front, back],
      fields: {'_pair': 'front_back'}, // unused, kept for consistency
      fieldNames: ['front', 'back'],
    );
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Delete single image ───────────────────────────────────
  static Future<PropertyApi> deleteImage(
      int propertyId, String imageUrl) async {
    final encoded = Uri.encodeComponent(imageUrl);
    final data =
        await _api.delete('/properties/$propertyId/images?image_url=$encoded');
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Booked dates (for calendar) ───────────────────────────
  /// Returns availability info for the property.
  ///
  /// For chalets/villas: `fully_booked_dates` = dates to grey out.
  /// For hotels: also includes `date_availability` with per-date room counts.
  /// For beaches/aqua parks: `unlimited = true`, never fully booked.
  static Future<Map<String, dynamic>> getBookedDates(
    int propertyId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    String query = '';
    if (fromDate != null || toDate != null) {
      final params = <String>[];
      if (fromDate != null) {
        params.add('from_date=${fromDate.toIso8601String().split('T')[0]}');
      }
      if (toDate != null) {
        params.add('to_date=${toDate.toIso8601String().split('T')[0]}');
      }
      query = '?${params.join('&')}';
    }

    final data = await _api.get('/properties/$propertyId/booked-dates$query');
    return data as Map<String, dynamic>;
  }

  // ── Available services list (for owner form) ──────────────
  /// Returns the list of all available services and category rules.
  static Future<Map<String, dynamic>> getAvailableServices() async {
    final data = await _api.get('/properties/services');
    return data as Map<String, dynamic>;
  }
}
