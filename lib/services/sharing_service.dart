// ═══════════════════════════════════════════════════════════════
//  Sharing service (Wave 20)
//
//  Builds shareable universal links pointing at the backend SEO
//  landing pages (e.g. https://talaa.app/p/123) so that:
//
//  - Opening the link on iOS/Android with the app installed
//    triggers the Universal Link / App Link and deep-links into the
//    app (see `talaa://properties/<id>` handler in `main.dart`).
//  - Opening without the app shows a rich Open Graph preview
//    rendered by `GET /p/{id}` on the backend.
//
//  Used by the property details page's share button and by the
//  referral screen.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart' show appSettings;

class SharingService {
  SharingService._();
  static final SharingService instance = SharingService._();

  /// Public-facing base URL of the SEO site. Build-time override:
  ///   `--dart-define=PUBLIC_APP_URL=https://talaa.app`
  static const String _publicBase = String.fromEnvironment(
    'PUBLIC_APP_URL',
    defaultValue: 'https://talaa.app',
  );

  /// Shareable universal-link URL for a property.
  String propertyUrl(int propertyId) => '$_publicBase/p/$propertyId';

  /// Shareable referral link (used from Wave 11).
  String referralUrl(String code) =>
      '$_publicBase/signup?ref=${Uri.encodeComponent(code)}';

  /// Open the native share sheet with a bilingual message for a property.
  ///
  /// Returns `true` if the user completed a share, `false` if they
  /// dismissed the sheet.  Any platform error is swallowed so callers
  /// can chain UI feedback without extra try/catch.
  Future<bool> shareProperty({
    required int propertyId,
    required String propertyName,
    double? pricePerNight,
  }) async {
    final url = propertyUrl(propertyId);
    final isAr = appSettings.arabic;

    final priceLine = pricePerNight == null
        ? ''
        : isAr
            ? '\nالسعر: ${pricePerNight.toStringAsFixed(0)} ج.م / ليلة'
            : '\nPrice: EGP ${pricePerNight.toStringAsFixed(0)} / night';

    final text = isAr
        ? 'شوف العقار ده على Talaa 👇\n$propertyName$priceLine\n$url'
        : 'Check out this property on Talaa 👇\n$propertyName$priceLine\n$url';

    try {
      final result = await Share.share(text, subject: propertyName);
      return result.status == ShareResultStatus.success;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Open the native share sheet for a referral code.
  Future<bool> shareReferral(String code) async {
    final url = referralUrl(code);
    final isAr = appSettings.arabic;

    final text = isAr
        ? 'انضم معايا على Talaa واحجز أول رحلة بخصم 🎉\n$url'
        : 'Join me on Talaa and get a discount on your first trip 🎉\n$url';

    try {
      final result = await Share.share(text);
      return result.status == ShareResultStatus.success;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
