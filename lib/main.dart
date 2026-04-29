import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/property_details_page.dart';
import 'pages/owner_add_property_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/chat_page.dart';
import 'pages/chat_inbox_page.dart';
import 'pages/explore_page.dart';
import 'pages/bookings_page.dart';
import 'pages/host_shell_page.dart';
import 'pages/profile_page.dart';
import 'widgets/constants.dart';
import 'utils/app_strings.dart';
import 'services/connectivity_guard.dart';
import 'services/version_check_service.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'services/sentry_service.dart';
import 'pages/admin/admin_main_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/user_provider.dart';
import 'providers/favorites_provider.dart';

class AppSettings extends ChangeNotifier {
  bool _darkMode = false;
  bool _arabic = true;
  bool _hasSelectedLanguage = false;

  bool get darkMode => _darkMode;
  bool get arabic => _arabic;
  bool get hasSelectedLanguage => _hasSelectedLanguage;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool('dark_mode') ?? false;
    _arabic = prefs.getBool('lang_ar') ?? true;
    _hasSelectedLanguage = prefs.getBool('lang_selected') ?? false;
  }

  Future<void> toggleDark() async {
    _darkMode = !_darkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
  }

  Future<void> toggleArabic() async {
    _arabic = !_arabic;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lang_ar', _arabic);
  }

  Future<void> setLanguage(bool isArabic) async {
    _arabic = isArabic;
    _hasSelectedLanguage = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lang_ar', _arabic);
    await prefs.setBool('lang_selected', true);
  }
}

final appSettings = AppSettings();
final userProvider = UserProvider();
final favoritesProvider = FavoritesProvider();

void main() async {
  // The Dart-side splash screen was removed by user request — the
  // app now boots straight from the native (orange) launch screen
  // into HomePage, with no Talaa artwork or logo stage in between.
  // We therefore don't ``FlutterNativeSplash.preserve()`` either;
  // the native splash auto-dismisses on the first rendered frame.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Already initialized
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await appSettings.load();

  // Wrap runApp in the Sentry zone so uncaught errors are reported.
  // When SENTRY_DSN isn't defined the helper transparently calls the
  // runner directly, keeping dev/tests identical to before.
  await SentryService.bootstrap(() async {
    runApp(const ProviderScope(child: TalaaApp()));
    // Defer heavy startup work (FCM permission, token fetch, backend
    // registration, deep-link probe) until *after* the first frame so
    // the UI appears immediately.  These operations can each block
    // for 1-3s on slow networks and were previously delaying cold
    // start by several seconds.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Fire-and-forget — failures here must never crash the app.
      // ignore: unawaited_futures
      NotificationService.instance.initialize().catchError((e, st) {
        debugPrint('[Notifications] init failed: $e');
      });
      // ignore: unawaited_futures
      DeepLinkService.instance.initialize().catchError((e, st) {
        debugPrint('[DeepLink] init failed: $e');
      });
    });
  });
}

class TalaaApp extends StatelessWidget {
  const TalaaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder rebuilds **only** the MaterialApp subtree when
    // appSettings notifies — not the whole widget tree above it.  The
    // previous ``setState(() {})`` on a StatefulWidget rebuilt every
    // route currently on the navigator stack on every toggle, which
    // caused a visible ~150ms freeze on mid-range Android devices.
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) => _buildApp(context),
    );
  }

  Widget _buildApp(BuildContext context) {
    final isDark = appSettings.darkMode;
    final isArabic = appSettings.arabic;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));

    return MaterialApp(
      title: S.appName,
      navigatorKey: NotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      locale: Locale(isArabic ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return ConnectivityGuard(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            ),
          ),
        );
      },
      // No splash, no onboarding — straight to AuthGate, which
      // itself drops into HomePage regardless of auth state (login
      // is pushed on-demand only when a gated action is tapped).
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/onboarding': (_) => const OnboardingPage(),
        '/home': (_) => const HomePage(),
        '/owner': (_) => const OwnerAddPropertyPage(),
        '/explore': (_) => const ExplorePage(),
        '/bookings': (_) => const BookingsPage(),
        '/host': (_) => const HostShellPage(),
        '/profile': (_) => const ProfilePage(),
        '/admin': (_) => const AdminMainPage(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/chat':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final convId = args['conversationId'] as int?;
            final propId = args['propertyId'] as int?;
            if (convId == null && propId == null) {
              return MaterialPageRoute(
                  builder: (_) => const ChatInboxPage());
            }
            return MaterialPageRoute(
              builder: (_) => ChatPage(
                conversationId: convId,
                propertyId: propId,
              ),
            );
          case '/property':
            final propertyId = _propertyIdFromRouteArgs(settings.arguments);
            if (propertyId == null) {
              return MaterialPageRoute(builder: (_) => const HomePage());
            }
            return MaterialPageRoute(
              builder: (_) => PropertyDetailsPage(propertyId: propertyId),
            );
          case '/payment':
            return MaterialPageRoute(builder: (_) => const HomePage());
          default:
            return MaterialPageRoute(builder: (_) => const LoginPage());
        }
      },
    );
  }

  int? _propertyIdFromRouteArgs(Object? args) {
    if (args is int) return args;
    if (args is String) return int.tryParse(args);
    if (args is Map) {
      final raw = args['propertyId'] ?? args['property_id'] ?? args['id'];
      if (raw is int) return raw;
      if (raw != null) return int.tryParse(raw.toString());
    }
    return null;
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // All neutrals are warm-tinted (browns / off-whites) — no navy / slate.
    final scaffoldBg = isDark ? const Color(0xFF14100C) : Colors.white;
    final surface = isDark ? const Color(0xFF1A140F) : const Color(0xFFFFF8F4);
    final card = isDark ? const Color(0xFF221A14) : Colors.white;
    final onBg = isDark ? const Color(0xFFF4EDE6) : const Color(0xFF2A1F1A);
    final onSurface = isDark ? const Color(0xFFF4EDE6) : const Color(0xFF2A1F1A);
    final outline = isDark ? const Color(0xFF3A2E26) : const Color(0xFFEFE3D8);

    final schemeBase = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    final scheme = schemeBase.copyWith(
      // Pin primary to the exact brand orange — fromSeed sometimes
      // shifts it toward red/amber and we need pixel-perfect parity.
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: onSurface,
      outline: outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: card,
    );

    // Apply Cairo to every default text style.  Widgets that hard-code
    // ``fontFamily: 'monospace'`` (referral codes, txn IDs, audit log)
    // continue to override per-call so they stay monospace.
    final cairoTextTheme = GoogleFonts.cairoTextTheme(base.textTheme).apply(
      bodyColor: onBg,
      displayColor: onBg,
    );
    final cairoPrimaryTextTheme =
        GoogleFonts.cairoTextTheme(base.primaryTextTheme).apply(
      bodyColor: onBg,
      displayColor: onBg,
    );

    return base.copyWith(
      textTheme: cairoTextTheme,
      primaryTextTheme: cairoPrimaryTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1A140F) : Colors.white,
        foregroundColor: isDark ? onBg : AppColors.primary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: isDark ? onBg : AppColors.primary),
        actionsIconTheme: IconThemeData(color: isDark ? onBg : AppColors.primary),
      ),
      iconTheme: IconThemeData(color: onSurface),
      dividerTheme: DividerThemeData(color: outline),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface,
        textColor: onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF221A14) : const Color(0xFFFFF4EC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
        labelStyle: TextStyle(color: onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1A140F) : Colors.white,
        selectedItemColor: scheme.primary,
        unselectedItemColor: isDark ? const Color(0xFF9C8E83) : const Color(0xFF8B7B6E),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(
              fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// Root auth surface — decides between HomePage (logged in or
/// guest) and any future post-login gates.  Was previously
/// ``_AuthGate`` (private) but is kept public so deep links and
/// notifications can navigate back to it explicitly if needed.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkedVersion = false;
  bool _profileLoaded = false;

  // NOTE: The onboarding stage was removed from the cold-start flow
  // by user request — the splash now hands off directly to HomePage
  // (logged in or guest).  We deliberately *don't* read
  // ``kOnboardingSeenKey`` here anymore; if onboarding is ever
  // re-introduced it should be triggered explicitly from Profile or
  // a "what's new" entry point, not on every app launch.

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedVersion) return;
    _checkedVersion = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final update = await VersionCheckService.checkForUpdate();
      if (!mounted || !update.requiresUpdate) return;
      await VersionCheckService.showForceUpdateDialog(
        context: context,
        storeUrl: update.storeUrl,
      );
    });
  }

  /// While the auth stream and the onboarding flag are still
  /// resolving, show a *plain brand-orange surface* — no spinner,
  /// no logo, no text.  This is a visual continuation of the splash
  /// (which paints the same orange) so the user never sees a
  /// loader pop in between the splash and the home screen.  Both
  /// futures (Firebase auth + SharedPreferences) typically resolve
  /// in <100 ms, so this surface is essentially invisible — but
  /// when it is visible, it just looks like the splash is still up.
  Widget _waiting() {
    return const ColoredBox(color: AppColors.primary);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _waiting();
        }

        // Save FCM token & load user profile ONCE when user logs in
        if (snapshot.hasData && snapshot.data != null && !_profileLoaded) {
          _profileLoaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.instance.saveTokenToFirestore();
            userProvider.loadProfile();
            favoritesProvider.loadIds();
          });
        }
        // Reset flag when user signs out
        if (!snapshot.hasData || snapshot.data == null) {
          _profileLoaded = false;
        }

        // Logged in OR guest — go straight to HomePage.  No
        // onboarding stage; the login screen is pushed on-demand
        // when a gated action (booking / chat / favourites) is
        // tapped, so guests can browse without any pre-home wall.
        return const HomePage();
      },
    );
  }
}

// Terms acceptance is enforced inline on the Register screen via an
// explicit checkbox. No additional post-login gate is needed.
