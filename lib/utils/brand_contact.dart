// ═══════════════════════════════════════════════════════════════
//  TALAA — Brand Contact Constants  (single source of truth)
//
//  Centralised so the email / phone / WhatsApp number never drifts
//  between Terms, Privacy, Refund, About, Contact and the in-page
//  footers.  When the support number changes, this is the *only*
//  edit needed.
// ═══════════════════════════════════════════════════════════════

import 'package:url_launcher/url_launcher.dart';

class BrandContact {
  // Plain values (use in code).
  static const String email = 'support@talaa-trip.com';
  static const String phone = '+201070771908';

  // Display form — `\u200e` (LEFT-TO-RIGHT MARK) forces phone digits
  // to render LTR even when embedded inside an RTL paragraph.
  static const String phoneDisplay = '\u200e$phone';

  // ── Launch URLs ─────────────────────────────────────────────
  static const String mailtoUrl = 'mailto:$email';
  // wa.me requires the phone number without the leading `+`.
  static const String whatsappUrl = 'https://wa.me/201070771908';
  // tel: URI for native dialer.
  static const String telUrl = 'tel:$phone';

  /// Open an external URL (mail client / WhatsApp / phone dialer)
  /// in its native app instead of the in-app web view.
  static Future<void> openExternal(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
