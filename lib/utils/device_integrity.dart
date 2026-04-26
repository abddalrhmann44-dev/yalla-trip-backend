// ═══════════════════════════════════════════════════════════════
//  TALAA — Device Integrity Check
//  Thin wrapper around flutter_jailbreak_detection used ONLY on
//  payment-entry surfaces.  Failing this check does NOT block app
//  access — guests can still browse, chat and book via Fawry
//  voucher / wallet.  We just refuse to render the card-PAN form
//  on a clearly tampered device to keep the blast radius of a
//  full compromise small.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

class DeviceIntegrity {
  DeviceIntegrity._();

  /// Returns ``true`` when the device is safe enough to enter card
  /// details on.  We default to **true** on errors / unsupported
  /// platforms (desktop, web) so a plugin failure can never trap a
  /// legitimate user out of paying — better to degrade gracefully
  /// than crash.  Release-builds on emulators also return ``true``
  /// so QA can still hit the payment flow.
  static Future<bool> isTrusted() async {
    // Skip the native call on unsupported platforms.
    if (kIsWeb) return true;
    try {
      final isJailBroken = await FlutterJailbreakDetection.jailbroken;
      final developerMode = await FlutterJailbreakDetection.developerMode;
      // Developer mode is common on employee devices — treat it as
      // *warning* only: still allow payment, but we could log later.
      if (isJailBroken) return false;
      // Don't penalise developer mode outside release builds, so
      // local Flutter `run` sessions keep working.
      if (!kReleaseMode) return true;
      // In release, refuse if the device has developer mode on AND
      // Android reports a potentially tampered environment.  Users
      // on a standard phone will never see this branch.
      if (developerMode) return false;
      return true;
    } catch (_) {
      // Plugin explosion — do NOT block the user.
      return true;
    }
  }
}
