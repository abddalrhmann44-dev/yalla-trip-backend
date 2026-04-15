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
    String sortBy = 'newest',
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'sort_by': sortBy,
    };
    if (area != null) params['area'] = area;
    if (category != null) params['category'] = category;
    if (minPrice != null) params['min_price'] = '$minPrice';
    if (maxPrice != null) params['max_price'] = '$maxPrice';
    if (minRating != null) params['min_rating'] = '$minRating';
    if (bedrooms != null) params['bedrooms'] = '$bedrooms';
    if (maxGuests != null) params['max_guests'] = '$maxGuests';
    if (instantBooking != null) params['instant_booking'] = '$instantBooking';
    if (search != null) params['search'] = search;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final data = await _api.get('/properties?$query');
    return (data['items'] as List)
        .map((e) => PropertyApi.fromJson(e as Map<String, dynamic>))
        .toList();
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
