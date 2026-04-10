import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/api_config.dart';

/// Central API service for communicating with the FastAPI backend.
///
/// Flow for image upload:
/// ```
/// Flutter (pickImage) -> POST /properties/{id}/images
///   -> FastAPI -> boto3 -> S3 Bucket
///   -> Return public URL
///   -> Save URL in PostgreSQL
///   -> Flutter displays image from S3 URL
/// ```
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get _baseUrl => ApiConfig.baseUrl;

  // ── Auth token ──────────────────────────────────────────────────────

  String? _token;

  Future<String?> _getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Properties ──────────────────────────────────────────────────────

  /// Fetch a single property by [id].
  Future<Map<String, dynamic>?> getProperty(int id) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/properties/$id'),
        headers: await _authHeaders(),
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      debugPrint('[ApiService] getProperty $id failed: ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] getProperty error: $e');
      return null;
    }
  }

  // ── Image Upload (the core flow) ────────────────────────────────────

  /// Upload images to `POST /properties/{propertyId}/images`.
  ///
  /// Returns the updated property JSON (including the new `images` list)
  /// or `null` on failure.
  ///
  /// **Flow:**
  /// 1. Flutter picks files via `image_picker`
  /// 2. This method sends them as multipart to FastAPI
  /// 3. FastAPI uploads each file to S3 via boto3
  /// 4. FastAPI saves the returned S3 URLs in PostgreSQL
  /// 5. FastAPI returns the updated property with all image URLs
  /// 6. Flutter renders images using `CachedNetworkImage` / `Image.network`
  Future<Map<String, dynamic>?> uploadPropertyImages(
    int propertyId,
    List<File> images,
  ) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('$_baseUrl/properties/$propertyId/images');

      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      for (final image in images) {
        final filename = image.path.split(Platform.pathSeparator).last;
        request.files.add(
          await http.MultipartFile.fromPath('files', image.path, filename: filename),
        );
      }

      final streamedResp = await request.send();
      final resp = await http.Response.fromStream(streamedResp);

      if (resp.statusCode == 200) {
        debugPrint('[ApiService] Images uploaded for property $propertyId');
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }

      debugPrint('[ApiService] uploadPropertyImages failed: ${resp.statusCode} ${resp.body}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] uploadPropertyImages error: $e');
      return null;
    }
  }

  // ── Image Delete ────────────────────────────────────────────────────

  /// Delete a single image from a property.
  ///
  /// Calls `DELETE /properties/{propertyId}/images?image_url=...`
  /// which removes the file from S3 and the URL from PostgreSQL.
  Future<Map<String, dynamic>?> deletePropertyImage(
    int propertyId,
    String imageUrl,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/properties/$propertyId/images').replace(
        queryParameters: {'image_url': imageUrl},
      );

      final resp = await http.delete(uri, headers: await _authHeaders());

      if (resp.statusCode == 200) {
        debugPrint('[ApiService] Image deleted from property $propertyId');
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }

      debugPrint('[ApiService] deletePropertyImage failed: ${resp.statusCode} ${resp.body}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] deletePropertyImage error: $e');
      return null;
    }
  }
}
