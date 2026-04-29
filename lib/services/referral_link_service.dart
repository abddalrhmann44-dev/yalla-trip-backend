import 'package:shared_preferences/shared_preferences.dart';

class ReferralLinkService {
  static const _pendingReferralCodeKey = 'pending_referral_code';

  static Future<void> saveReferralCode(String code) async {
    final normalized = _normalize(code);
    if (normalized == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingReferralCodeKey, normalized);
  }

  static Future<String?> getPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalize(prefs.getString(_pendingReferralCodeKey) ?? '');
  }

  static Future<void> clearPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingReferralCodeKey);
  }

  static String? _normalize(String code) {
    final value = code.trim().toUpperCase();
    if (value.isEmpty || value.length > 16) return null;
    return value;
  }
}
