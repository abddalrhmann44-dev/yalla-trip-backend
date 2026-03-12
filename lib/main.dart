import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/owner_add_property_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/chat_page.dart';
import 'pages/explore_page.dart';
import 'pages/bookings_page.dart';
import 'pages/profile_page.dart';
import 'widgets/constants.dart';

// ── Global App State ─────────────────────────────────
class AppSettings extends ChangeNotifier {
  bool _darkMode = false;
  bool _arabic   = false;

  bool get darkMode => _darkMode;
  bool get arabic   => _arabic;

  void toggleDark()   { _darkMode = !_darkMode; notifyListeners(); }
  void toggleArabic() { _arabic   = !_arabic;   notifyListeners(); }
}

final appSettings = AppSettings();

void main() async {
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

  runApp(const YallaTripApp());
}

class YallaTripApp extends StatefulWidget {
  const YallaTripApp({super.key});
  @override State<YallaTripApp> createState() => _YallaTripAppState();
}

class _YallaTripAppState extends State<YallaTripApp> {
  @override
  void initState() {
    super.initState();
    appSettings.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = appSettings.darkMode;
    final isArabic = appSettings.arabic;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:     isDark ? Brightness.dark  : Brightness.light,
    ));

    return MaterialApp(
      title: 'Yalla Trip',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme:     _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),

      locale: isArabic ? const Locale('ar') : const Locale('en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),

      // ── أول شاشة هي الـ SplashScreen ─────────────────
      home: const _SplashScreen(),

      routes: {
        '/welcome':    (_) => const WelcomePage(),
        '/login':      (_) => const LoginPage(),
        '/register':   (_) => const RegisterPage(),
        '/onboarding': (_) => const OnboardingPage(),
        '/home':       (_) => const HomePage(),
        '/owner':      (_) => const OwnerAddPropertyPage(),
        '/explore':    (_) => const ExplorePage(),
        '/bookings':   (_) => const BookingsPage(),
        '/profile':    (_) => const ProfilePage(),
      },

      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/chat':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => ChatPage(
                ownerName:     args['ownerName']     ?? 'المالك',
                propertyName:  args['propertyName']  ?? 'العقار',
                propertyEmoji: args['propertyEmoji'] ?? '🏡',
                currentPrice:  args['currentPrice']  ?? '850',
              ),
            );
          case '/payment':
            return MaterialPageRoute(builder: (_) => const HomePage());
          default:
            return MaterialPageRoute(builder: (_) => const _SplashScreen());
        }
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
      ),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0D1117) : Colors.white,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor:    isDark ? Colors.white : const Color(0xFF0D1B2A),
        displayColor: isDark ? Colors.white : const Color(0xFF0D1B2A),
      ),
      cardColor: isDark ? const Color(0xFF1C2333) : Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.primary,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontFamily: 'Outfit', fontSize: 15,
              fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SPLASH SCREEN
//  يتحقق من Firebase Auth — لو logged in يروح HomePage
//  لو مش logged in يروح OnboardingPage (أول مرة) أو LoginPage
// ══════════════════════════════════════════════════════════════
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));

    _ctrl.forward();

    // بعد 2.2 ثانية — تحقق من الـ auth state
    Future.delayed(const Duration(milliseconds: 2200), _checkAuth);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    Widget nextPage;

    if (user != null) {
      // ── مستخدم مسجل دخوله — روح الرئيسية ─────────────
      nextPage = const HomePage();
    } else {
      // ── مستخدم جديد — روح الـ Onboarding ──────────────
      // لو عايز تروح LoginPage مباشرة بدل Onboarding:
      // nextPage = const LoginPage();
      nextPage = const WelcomePage();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => nextPage,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Logo Icon ──────────────────────────
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.flight_takeoff_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── App Name ───────────────────────────
                  const Text(
                    'Yalla Trip',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Tagline ────────────────────────────
                  Text(
                    'اكتشف • احجز • استمتع',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.9),
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 60),

                  // ── Loading indicator ──────────────────
                  SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
