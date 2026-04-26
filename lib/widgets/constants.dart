import 'package:flutter/material.dart';

// ── Theme-aware color helpers ────────────────────────────
// Use these in any widget that has access to BuildContext:
//   final t = Theme.of(context);
//   final cs = t.colorScheme;
//   ... or use the extension:  context.kText, context.kCard, etc.
extension AppThemeX on BuildContext {
  ThemeData get _theme => Theme.of(this);
  bool get isDark => _theme.brightness == Brightness.dark;

  // Semantic page colors (match the old _k* constants)
  Color get kSand   => _theme.scaffoldBackgroundColor;
  Color get kCard   => _theme.cardColor;
  Color get kText   => _theme.colorScheme.onSurface;
  Color get kSub    => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  Color get kBorder => _theme.colorScheme.outline;

  // Surface used inside cards / bottom sheets — warm neutrals only.
  Color get kSurface     => _theme.colorScheme.surface;
  Color get kInputFill   => isDark ? const Color(0xFF1A140F) : const Color(0xFFFFF4EC);
  Color get kSheetBg     => isDark ? const Color(0xFF1A140F) : Colors.white;
  Color get kChipBg      => isDark ? const Color(0xFF2A211B) : const Color(0xFFFFF1E6);
  Color get kOverlayText => isDark ? const Color(0xFFF4EDE6) : const Color(0xFF2A1F1A);
}

// ── Colors ──────────────────────────────────────────────
// Brand: Talaa orange — warm, energetic, beach-vacation feel.
// All blues were removed app-wide on 2026-04-26 per design lead.
class AppColors {
  AppColors._();

  // Primary brand (orange) — drives ColorScheme.fromSeed in main.dart.
  static const Color primary      = Color(0xFFFF6B35); // hero orange
  static const Color primaryLight = Color(0xFFFF8A3D);
  static const Color primaryDark  = Color(0xFFE85A24);

  // Accent (warm gold) — used sparingly for CTAs.
  static const Color accent       = Color(0xFFFFB347);
  static const Color accentLight  = Color(0xFFFFD166);

  static const Color background   = Color(0xFFFFF8F4); // warm off-white
  static const Color white        = Color(0xFFFFFFFF);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color error        = Color(0xFFE57373);
  static const Color success      = Color(0xFF66BB6A);
  static const Color warning      = Color(0xFFFFA726);

  // Text: warm charcoal (NOT navy) so nothing reads "blue" on white.
  static const Color textPrimary   = Color(0xFF2A1F1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textHint      = Color(0xFF9E9E9E);
  static const Color textLight     = Color(0xFFBDBDBD);

  static const Color border        = Color(0xFFEEEEEE);
  static const Color divider       = Color(0xFFE0E0E0);

  // Category colors — kept warm to match brand. NO blues.
  static const Color beach     = Color(0xFFFF8C42); // sunset orange
  static const Color hotel     = Color(0xFFB07FCB); // soft violet
  static const Color chalet    = Color(0xFF66BB6A); // pine green
  static const Color aquapark  = Color(0xFFFFB347); // warm amber
}

// ── Text Styles ──────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle displayLarge = TextStyle(
    fontSize: 40, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, height: 1.15, letterSpacing: -1.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, height: 1.2, letterSpacing: -1.0,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: 0.5,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3,
  );
}

// ── Spacing ──────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();

  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

// ── Border Radius ─────────────────────────────────────────
class AppRadius {
  AppRadius._();

  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 28;
  static const double full = 100;
}

// ── Strings ───────────────────────────────────────────────
class AppStrings {
  AppStrings._();

  static const String appName    = 'Yalla Trip';
  static const String tagline    = 'Your ultimate travel companion';

  // Auth
  static const String login      = 'Sign In';
  static const String register   = 'Create Account';
  static const String email      = 'Email Address';
  static const String password   = 'Password';
  static const String fullName   = 'Full Name';
  static const String forgotPass = 'Forgot password?';
  static const String noAccount  = "Don't have an account? ";
  static const String hasAccount = 'Already have an account? ';
  static const String signUp     = 'Sign Up';
  static const String signIn     = 'Sign In';
  static const String or         = 'or';
  static const String google     = 'Continue with Google';

  // Home
  static const String explore    = 'Explore';
  static const String search     = 'Search destinations...';
  static const String featured   = 'Featured';
  static const String categories = 'Categories';
  static const String popular    = 'Popular Now';
  static const String seeAll     = 'See all';

  // Categories
  static const String beach      = 'Beach';
  static const String hotel      = 'Hotel';
  static const String chalet     = 'Chalet';
  static const String aquapark   = 'Aqua Park';

  // Errors
  static const String fieldRequired   = 'This field is required';
  static const String invalidEmail    = 'Enter a valid email';
  static const String shortPassword   = 'At least 6 characters';
  static const String passwordMismatch = 'Passwords do not match';

  // Success
  static const String loginSuccess    = 'Welcome back! 🌍';
  static const String registerSuccess = "Account created! Let's explore 🌍";
}

// ── Assets ────────────────────────────────────────────────
class AppAssets {
  AppAssets._();

  static const String logo        = 'assets/images/logo.png';
  static const String splash      = 'assets/images/splash.png';
  static const String placeholder = 'assets/images/placeholder.png';
}

// ── Duration ──────────────────────────────────────────────
class AppDurations {
  AppDurations._();

  static const Duration fast    = Duration(milliseconds: 200);
  static const Duration normal  = Duration(milliseconds: 400);
  static const Duration slow    = Duration(milliseconds: 700);
  static const Duration page    = Duration(milliseconds: 900);
}
