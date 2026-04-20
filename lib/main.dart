import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/owner_add_property_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/chat_page.dart';
import 'pages/chat_inbox_page.dart';
import 'pages/explore_page.dart';
import 'pages/bookings_page.dart';
import 'pages/host_dashboard_page.dart';
import 'pages/profile_page.dart';
import 'widgets/constants.dart';
import 'utils/app_strings.dart';
import 'services/connectivity_guard.dart';
import 'services/version_check_service.dart';
import 'services/notification_service.dart';
import 'services/sentry_service.dart';
import 'pages/admin/admin_main_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/user_provider.dart';
import 'providers/favorites_provider.dart';
import 'pages/terms_acceptance_page.dart';
import 'pages/splash_screen.dart';

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
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ✅ شيل الـ native splash فوراً — Flutter splash بيظهر بدله فوراً
  FlutterNativeSplash.remove();

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

  // Initialize FCM & local notifications
  await NotificationService.instance.initialize();

  // Wrap runApp in the Sentry zone so uncaught errors are reported.
  // When SENTRY_DSN isn't defined the helper transparently calls the
  // runner directly, keeping dev/tests identical to before.
  await SentryService.bootstrap(() async {
    runApp(const ProviderScope(child: TalaaApp()));
  });
}

class TalaaApp extends StatefulWidget {
  const TalaaApp({super.key});
  @override
  State<TalaaApp> createState() => _TalaaAppState();
}

class _TalaaAppState extends State<TalaaApp> {
  @override
  void initState() {
    super.initState();
    appSettings.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
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
      home: const _AuthGate(),
      routes: {
        '/welcome': (_) => const WelcomePage(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/onboarding': (_) => const OnboardingPage(),
        '/home': (_) => const HomePage(),
        '/owner': (_) => const OwnerAddPropertyPage(),
        '/explore': (_) => const ExplorePage(),
        '/bookings': (_) => const BookingsPage(),
        '/host': (_) => const HostDashboardPage(),
        '/profile': (_) => const ProfilePage(),
        '/admin': (_) => const AdminMainPage(),
        '/splash': (_) => const SplashScreen(),
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
          case '/payment':
            return MaterialPageRoute(builder: (_) => const HomePage());
          default:
            return MaterialPageRoute(builder: (_) => const WelcomePage());
        }
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0B0F14) : Colors.white;
    final surface = isDark ? const Color(0xFF111827) : const Color(0xFFF8F7F4);
    final card = isDark ? const Color(0xFF161F2E) : Colors.white;
    final onBg = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF0D1B2A);
    final onSurface = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF0D1B2A);
    final outline = isDark ? const Color(0xFF2B3445) : const Color(0xFFE5E7EB);

    final schemeBase = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    final scheme = schemeBase.copyWith(
      surface: surface,
      onSurface: onSurface,
      outline: outline,
      onPrimary: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: card,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: onBg,
        displayColor: onBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
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
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
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
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        selectedItemColor: scheme.primary,
        unselectedItemColor: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate>
    with SingleTickerProviderStateMixin {
  bool _showSplash = true;
  bool _checkedVersion = false;
  bool _profileLoaded = false;
  bool? _onboardingSeen;

  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.elasticOut)));

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.20, curve: Curves.easeIn)));

    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut)));

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.50, curve: Curves.easeIn)));

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.0, curve: Curves.easeInOut)));

    _controller.forward().then((_) {
      if (mounted) setState(() => _showSplash = false);
    });

    _loadOnboardingFlag();
  }

  Future<void> _loadOnboardingFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(kOnboardingSeenKey) ?? false;
      if (!mounted) return;
      setState(() => _onboardingSeen = seen);
    } catch (_) {
      if (mounted) setState(() => _onboardingSeen = true);
    }
  }

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => FadeTransition(
          opacity: _exitFade,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Image.asset(
                        'assets/images/splash.png',
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Text(S.appName.toUpperCase(),
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B4D5C),
                              letterSpacing: 4,
                              fontFamily: 'Outfit')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: const Text('اكتشف أجمل الشاليهات',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFB8A05A),
                              letterSpacing: 1,
                              fontFamily: 'Outfit')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
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

        if (snapshot.hasData && snapshot.data != null) {
          return const _TermsOrHome();
        }
        // Not logged in — onboarding first (if not seen yet).
        if (_onboardingSeen == null) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
        }
        return _onboardingSeen!
            ? const WelcomePage()
            : const OnboardingPage();
      },
    );
  }
}

// ── Terms gate: shows acceptance page on first login ──────────
class _TermsOrHome extends StatefulWidget {
  const _TermsOrHome();
  @override
  State<_TermsOrHome> createState() => _TermsOrHomeState();
}

class _TermsOrHomeState extends State<_TermsOrHome> {
  bool? _accepted;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await TermsAcceptancePage.hasAccepted();
    if (mounted) setState(() => _accepted = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return _accepted! ? const HomePage() : const TermsAcceptancePage();
  }
}
