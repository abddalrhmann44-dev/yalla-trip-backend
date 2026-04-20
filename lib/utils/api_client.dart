import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import '../main.dart' show appSettings;

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
  // ``_token`` is the short-lived access token, ``_refreshToken`` is
  // the long-lived rotated refresh token.  Both are persisted in
  // SharedPreferences so a restart keeps the user logged in.
  String? _token;
  String? _refreshToken;

  Future<String?> _getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  Future<String?> getRefreshToken() async {
    if (_refreshToken != null) return _refreshToken;
    final prefs = await SharedPreferences.getInstance();
    _refreshToken = prefs.getString('refresh_token');
    return _refreshToken;
  }

  Future<void> setToken(String token, {String? refreshToken}) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept-Language': appSettings.arabic ? 'ar' : 'en',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── GET ────────────────────────────────────────────────────
  Future<dynamic> get(String endpoint) async {
    return _withAutoRefresh(endpoint, () async =>
      http.get(Uri.parse('$baseUrl$endpoint'), headers: await _headers()));
  }

  // ── POST (JSON) ───────────────────────────────────────────
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    return _withAutoRefresh(endpoint, () async => http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
      body: jsonEncode(body),
    ));
  }

  // ── POST (Multipart — for file uploads) ───────────────────
  /// Uploads one or more files to [endpoint].
  ///
  /// - If [fieldNames] is provided, each file is attached under its
  ///   own distinct field name (length MUST match `files`).  This
  ///   covers endpoints like ``/properties/{id}/id-documents`` which
  ///   expect ``front`` + ``back`` instead of a repeated ``files[]``.
  /// - Otherwise all files are sent under a single [fieldName]
  ///   (FastAPI's default ``List[UploadFile] = File(...)`` pattern).
  /// - [fields] are optional extra form-data text fields.
  Future<dynamic> postMultipart(
    String endpoint,
    List<File> files, {
    String fieldName = 'files',
    List<String>? fieldNames,
    Map<String, String>? fields,
  }) async {
    assert(
      fieldNames == null || fieldNames.length == files.length,
      'fieldNames must have the same length as files',
    );
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (fields != null) {
      request.fields.addAll(fields);
    }

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final filename = file.path.split(Platform.pathSeparator).last;
      final name = fieldNames != null ? fieldNames[i] : fieldName;
      request.files.add(
        await http.MultipartFile.fromPath(name, file.path,
            filename: filename),
      );
    }

    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);
    return _handleResponse(resp);
  }

  // ── PUT ────────────────────────────────────────────────────
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    return _withAutoRefresh(endpoint, () async => http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
      body: jsonEncode(body),
    ));
  }

  // ── PATCH ──────────────────────────────────────────────────
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    return _withAutoRefresh(endpoint, () async => http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
      body: jsonEncode(body),
    ));
  }

  // ── DELETE ─────────────────────────────────────────────────
  Future<dynamic> delete(String endpoint) async {
    return _withAutoRefresh(endpoint, () async => http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
    ), allow204: true);
  }

  // ── 401 auto-refresh wrapper ─────────────────────────────
  // Dispatches [send], and on 401 tries the silent refresh-token
  // rotation exactly once, then replays the request.  If the refresh
  // also fails the original 401 bubbles up to the caller as usual.
  Future<dynamic> _withAutoRefresh(
    String endpoint,
    Future<http.Response> Function() send, {
    bool allow204 = false,
  }) async {
    // Serialise concurrent refreshes so a burst of 401s only rotates once.
    http.Response res = await send();
    if (res.statusCode == 401 && endpoint != '/auth/refresh') {
      final refreshed = await _refreshOnce();
      if (refreshed) {
        res = await send();
      }
    }
    if (allow204 && res.statusCode == 204) return null;
    return _handleResponse(res);
  }

  Future<bool>? _inflightRefresh;

  Future<bool> _refreshOnce() {
    final inflight = _inflightRefresh;
    if (inflight != null) return inflight;
    final future = _doRefresh();
    _inflightRefresh = future;
    future.whenComplete(() => _inflightRefresh = null);
    return future;
  }

  Future<bool> _doRefresh() async {
    final refresh = await getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      );
      if (res.statusCode != 200) return false;
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final access = body['access_token'] as String?;
      final newRefresh = body['refresh_token'] as String?;
      if (access == null) return false;
      await setToken(access, refreshToken: newRefresh);
      return true;
    } catch (_) {
      return false;
    }
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
