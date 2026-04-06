import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheckResult {
  final bool requiresUpdate;
  final String storeUrl;
  const VersionCheckResult({
    required this.requiresUpdate,
    required this.storeUrl,
  });
}

class VersionCheckService {
  // TODO: replace with your production endpoint.
  static const String _versionApi =
      'https://example.com/api/mobile/latest-version';

  static Future<VersionCheckResult> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final current = packageInfo.version;
      final response = await http.get(Uri.parse(_versionApi));
      if (response.statusCode != 200) {
        return const VersionCheckResult(requiresUpdate: false, storeUrl: '');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = (data['latestVersion'] ?? '').toString();
      final storeUrl = (data['storeUrl'] ?? '').toString();
      final requiresUpdate = _isOutdated(current, latest);

      return VersionCheckResult(
        requiresUpdate: requiresUpdate,
        storeUrl: storeUrl,
      );
    } catch (_) {
      return const VersionCheckResult(requiresUpdate: false, storeUrl: '');
    }
  }

  static bool _isOutdated(String current, String latest) {
    if (current.isEmpty || latest.isEmpty) return false;
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLen = c.length > l.length ? c.length : l.length;
    for (var i = 0; i < maxLen; i++) {
      final cv = i < c.length ? c[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (cv < lv) return true;
      if (cv > lv) return false;
    }
    return false;
  }

  static Future<void> showForceUpdateDialog({
    required BuildContext context,
    required String storeUrl,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('تحديث مطلوب'),
        content: const Text('يرجى تحديث التطبيق للاستمرار'),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (storeUrl.isEmpty) return;
              final uri = Uri.parse(storeUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('التحديث الآن'),
          ),
        ],
      ),
    );
  }
}
