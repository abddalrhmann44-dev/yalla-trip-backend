// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — App Strings (Translation System)
//  استخدام: S.of(context).welcomeTitle
//  أو:      AppStrings.get('welcomeTitle')
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;

// ── الطريقة السهلة: S.ar أو S.en ──────────────────────────────
class S {
  static bool get _ar => appSettings.arabic;

  // ══════════════════════════════════════════
  //  WELCOME PAGE
  // ══════════════════════════════════════════
  static String get appName => 'Yalla Trip';
  static String get welcomeTagline =>
      _ar ? 'اكتشف • احجز • استمتع' : 'Discover • Book • Enjoy';
  static String get welcomeSubtitle => _ar
      ? 'أجمل الشاليهات والفيلات\nعلى الساحل المصري'
      : 'The finest chalets & villas\non Egypt\'s coast';
  static String get loginBtn => _ar ? 'تسجيل الدخول' : 'Login';
  static String get registerBtn => _ar ? 'إنشاء حساب جديد' : 'Create Account';
  static String get browseGuest => _ar ? 'تصفح كزائر' : 'Browse as Guest';
  static String get langLabel => _ar ? 'عربي' : 'English';
  static String get langFlag => _ar ? '🇪🇬' : '🇬🇧';

  // ══════════════════════════════════════════
  //  LOGIN PAGE
  // ══════════════════════════════════════════
  static String get loginTitle => _ar ? 'تسجيل الدخول' : 'Sign In';
  static String get loginSubtitle =>
      _ar ? 'أهلاً بك مجدداً في Yalla Trip' : 'Welcome back to Yalla Trip';
  static String get phoneTab => _ar ? 'الهاتف' : 'Phone';
  static String get emailTab => _ar ? 'البريد' : 'Email';
  static String get namePlaceholder => _ar ? 'الاسم الكامل' : 'Full Name';
  static String get phonePlaceholder => _ar ? 'رقم الهاتف' : 'Phone Number';
  static String get emailPlaceholder =>
      _ar ? 'البريد الإلكتروني' : 'Email Address';
  static String get passPlaceholder => _ar ? 'كلمة المرور' : 'Password';
  static String get confirmPass =>
      _ar ? 'تأكيد كلمة المرور' : 'Confirm Password';
  static String get forgotPass =>
      _ar ? 'نسيت كلمة المرور؟' : 'Forgot password?';
  static String get loginAction => _ar ? 'تسجيل الدخول' : 'Sign In';
  static String get orWith => _ar ? 'أو تابع مع' : 'Or continue with';
  static String get googleBtn => _ar ? 'Google' : 'Google';
  static String get appleBtn => _ar ? 'Apple' : 'Apple';
  static String get guestBtn => _ar ? 'تصفح كزائر' : 'Browse as Guest';
  static String get noAccount =>
      _ar ? 'مش عندك حساب؟' : 'Don\'t have an account?';
  static String get registerLink => _ar ? 'سجّل الآن' : 'Register now';
  static String get hasAccount =>
      _ar ? 'عندك حساب بالفعل؟' : 'Already have an account?';
  static String get loginLink => _ar ? 'تسجيل الدخول' : 'Sign In';

  // ══════════════════════════════════════════
  //  REGISTER PAGE
  // ══════════════════════════════════════════
  static String get registerTitle => _ar ? 'إنشاء حساب' : 'Create Account';
  static String get registerSub => _ar
      ? 'انضم لـ Yalla Trip واكتشف أجمل الوجهات'
      : 'Join Yalla Trip and discover top destinations';
  static String get registerAction => _ar ? 'إنشاء الحساب' : 'Create Account';

  // ══════════════════════════════════════════
  //  HOME PAGE
  // ══════════════════════════════════════════
  static String get searchHint => _ar
      ? 'ابحث عن شاليه، منتجع، أو شاطئ…'
      : 'Search chalets, resorts, beaches…';
  static String get filterBtn => _ar ? 'تصفية' : 'Filter';
  static String get exploreType => _ar ? 'استكشف حسب النوع' : 'Explore by Type';
  static String get destinations =>
      _ar ? 'الوجهات الساحلية' : 'Beach Destinations';
  static String get seeAll => _ar ? 'عرض الكل' : 'See All';
  static String get bookNow => _ar ? 'استكشف الآن' : 'Explore Now';
  static String get featuredProps =>
      _ar ? 'عقارات مميزة' : 'Featured Properties';
  static String get perNight => _ar ? 'جنيه/ليلة' : 'EGP/night';
  static String get instantBook => _ar ? 'حجز فوري' : 'Instant';
  static String get morning => _ar ? 'صباح الخير' : 'Good Morning';
  static String get afternoon => _ar ? 'مساء الخير' : 'Good Afternoon';
  static String get evening => _ar ? 'مساء النور' : 'Good Evening';

  // Hero areas
  static String get ainSokhna => _ar ? 'عين السخنة' : 'Ain Sokhna';
  static String get northCoast => _ar ? 'الساحل الشمالي' : 'North Coast';
  static String get gouna => _ar ? 'الجونة' : 'El Gouna';
  static String get hurghada => _ar ? 'الغردقة' : 'Hurghada';
  static String get sharm => _ar ? 'شرم الشيخ' : 'Sharm El Sheikh';
  static String get rasSedr => _ar ? 'رأس سدر' : 'Ras Sedr';

  // Categories
  static String get chalets => _ar ? 'شاليهات' : 'Chalets';
  static String get hotels => _ar ? 'فنادق' : 'Hotels';
  static String get beach => _ar ? 'شاطئ' : 'Beach';
  static String get aquaPark => _ar ? 'أكوا بارك' : 'Aqua Park';
  static String get seaSports => _ar ? 'رياضات بحرية' : 'Sea Sports';
  static String get resorts => _ar ? 'منتجعات' : 'Resorts';

  // ══════════════════════════════════════════
  //  PROFILE PAGE
  // ══════════════════════════════════════════
  static String get profile => _ar ? 'الملف الشخصي' : 'Profile';
  static String get editProfile => _ar ? 'تعديل الملف' : 'Edit Profile';
  static String get ownerBadge => _ar ? 'مالك عقار' : 'Property Owner';
  static String get guestBadge => _ar ? 'عميل' : 'Guest';
  static String get myBookings => _ar ? 'حجوزاتي' : 'My Bookings';
  static String get myProperties => _ar ? 'عقاراتي' : 'My Properties';
  static String get payoutMethod => _ar ? 'طريقة الاستلام' : 'Payout Method';
  static String get notifications => _ar ? 'الإشعارات' : 'Notifications';
  static String get preferences => _ar ? 'التفضيلات' : 'Preferences';
  static String get darkMode => _ar ? 'الوضع الداكن' : 'Dark Mode';
  static String get language => _ar ? 'اللغة / Language' : 'Language / اللغة';
  static String get helpCenter => _ar ? 'مركز المساعدة' : 'Help Center';
  static String get rateApp => _ar ? 'قيّم التطبيق ⭐' : 'Rate the App ⭐';
  static String get logout => _ar ? 'تسجيل الخروج' : 'Sign Out';
  static String get deleteAccount => _ar ? 'حذف الحساب' : 'Delete Account';
  static String get becomeOwner =>
      _ar ? 'هل تمتلك عقاراً؟ سجّل كمالك' : 'Own a property? Register as Owner';
  static String get switchToGuest =>
      _ar ? 'التبديل لوضع العميل' : 'Switch to Guest Mode';
  static String get trips => _ar ? 'رحلة' : 'Trip';
  static String get reviews => _ar ? 'تقييم' : 'Review';
  static String get listings => _ar ? 'عقار' : 'Listing';
  static String get bookings => _ar ? 'حجز' : 'Booking';

  // ══════════════════════════════════════════
  //  EXPLORE PAGE
  // ══════════════════════════════════════════
  static String get search => _ar ? 'بحث' : 'Search';
  static String get areas => _ar ? 'المناطق' : 'Areas';
  static String get trending => _ar ? 'الأكثر طلباً' : 'Trending';
  static String get deals => _ar ? 'عروض اليوم' : 'Today\'s Deals';
  static String get propertiesFound => _ar ? 'عقار متاح' : 'properties found';
  static String get noResults => _ar ? 'لا توجد نتائج' : 'No Results Found';
  static String get noResultsSub => _ar
      ? 'جرّب تغيير الفلاتر أو البحث بكلمة مختلفة'
      : 'Try different filters or search terms';
  static String get resetFilters => _ar ? 'مسح الفلاتر' : 'Reset Filters';
  static String get priceRange => _ar ? 'نطاق السعر' : 'Price Range';
  static String get guests => _ar ? 'عدد الضيوف' : 'Guests';
  static String get rooms => _ar ? 'الغرف' : 'Rooms';
  static String get instantOnly => _ar ? 'حجز فوري فقط' : 'Instant Book Only';
  static String get onlineOnly =>
      _ar ? 'دفع أونلاين فقط' : 'Online Payment Only';
  static String get minRating => _ar ? 'أقل تقييم' : 'Min Rating';

  // ══════════════════════════════════════════
  //  BOOKINGS PAGE
  // ══════════════════════════════════════════
  static String get myBookingsTitle => _ar ? 'حجوزاتي' : 'My Bookings';
  static String get upcoming => _ar ? 'قادمة' : 'Upcoming';
  static String get completed => _ar ? 'مكتملة' : 'Completed';
  static String get cancelled => _ar ? 'ملغاة' : 'Cancelled';
  static String get checkIn => _ar ? 'تسجيل الدخول' : 'Check In';
  static String get checkOut => _ar ? 'تسجيل الخروج' : 'Check Out';
  static String get nights => _ar ? 'ليلة' : 'Night';
  static String get totalPaid => _ar ? 'إجمالي المدفوع' : 'Total Paid';
  static String get confirmed => _ar ? 'مؤكد' : 'Confirmed';
  static String get pending => _ar ? 'في الانتظار' : 'Pending';

  // ══════════════════════════════════════════
  //  GENERAL
  // ══════════════════════════════════════════
  static String get cancel => _ar ? 'إلغاء' : 'Cancel';
  static String get confirm => _ar ? 'تأكيد' : 'Confirm';
  static String get save => _ar ? 'حفظ' : 'Save';
  static String get back => _ar ? 'رجوع' : 'Back';
  static String get next => _ar ? 'التالي' : 'Next';
  static String get done => _ar ? 'تم' : 'Done';
  static String get loading => _ar ? 'جاري التحميل…' : 'Loading…';
  static String get error => _ar ? 'حدث خطأ' : 'An error occurred';
  static String get retry => _ar ? 'إعادة المحاولة' : 'Retry';
  static String get egp => _ar ? 'ج.م' : 'EGP';
  static String get night => _ar ? 'ليلة' : 'night';
  static String get guest => _ar ? 'ضيف' : 'guest';
  static String get soon => _ar ? 'قريباً' : 'Coming Soon';
  static String get noData => _ar ? 'لا توجد بيانات' : 'No data available';
  static String get required => _ar ? 'مطلوب' : 'Required';
  static String get invalidEmail =>
      _ar ? 'بريد إلكتروني غير صحيح' : 'Invalid email';
  static String get weakPassword => _ar
      ? 'كلمة مرور ضعيفة (6 أحرف على الأقل)'
      : 'Weak password (min 6 chars)';
  static String get passMismatch =>
      _ar ? 'كلمتا المرور غير متطابقتين' : 'Passwords don\'t match';
}

// ── Helper extension على BuildContext ─────────────────────────
extension ContextLang on BuildContext {
  bool get isArabic => appSettings.arabic;
  String tr(String ar, String en) => appSettings.arabic ? ar : en;
}
