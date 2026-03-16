import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
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
        DefaultCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },

      // ── أول شاشة — تحقق من Auth مباشرة بدون Splash ───
      home: const _AuthGate(),

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
            return MaterialPageRoute(builder: (_) => const WelcomePage());
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
//  AUTH GATE — تحقق فوري من Firebase بدون splash
// ══════════════════════════════════════════════════════════════
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A1628),
            body: SizedBox.shrink(),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }
        return const WelcomePage();
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
