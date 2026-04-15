import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// Unified HTTP client for communicating with the Talaa FastAPI backend.
///
/// Uses JWT tokens stored in SharedPreferences (set after Firebase auth
/// verification via POST /auth/verify-token).
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static String get baseUrl => ApiConfig.baseUrl;

  // ── Token management ──────────────────────────────────────
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

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── GET ────────────────────────────────────────────────────
  Future<dynamic> get(String endpoint) async {
    final res = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  // ── POST (JSON) ───────────────────────────────────────────
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(res);
  }

  // ── POST (Multipart — for file uploads) ───────────────────
  Future<dynamic> postMultipart(
    String endpoint,
    List<File> files, {
    String fieldName = 'files',
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    for (final file in files) {
      final filename = file.path.split(Platform.pathSeparator).last;
      request.files.add(
        await http.MultipartFile.fromPath(fieldName, file.path,
            filename: filename),
      );
    }

    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);
    return _handleResponse(resp);
  }

  // ── PUT ────────────────────────────────────────────────────
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(res);
  }

  // ── DELETE ─────────────────────────────────────────────────
  Future<dynamic> delete(String endpoint) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
    );
    if (res.statusCode == 204) return null;
    return _handleResponse(res);
  }

  // ── Response handler ──────────────────────────────────────
  dynamic _handleResponse(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    final detail = body is Map ? (body['detail'] ?? body.toString()) : body.toString();
    debugPrint('[ApiClient] ${res.statusCode}: $detail');
    throw ApiException(res.statusCode, detail.toString());
  }
}

/// Exception thrown when the API returns a non-2xx status code.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
