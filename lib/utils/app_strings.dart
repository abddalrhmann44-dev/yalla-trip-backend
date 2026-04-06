// ═══════════════════════════════════════════════════════════════
//  TALAA — Complete Translation System
//  كل نص في التطبيق هنا — عربي وإنجليزي
// ═══════════════════════════════════════════════════════════════

import '../main.dart' show appSettings;

class S {
  static bool get _ar => appSettings.arabic;
  static bool get ar => appSettings.arabic; // public alias

  // ── GENERAL ─────────────────────────────────────────────────
  static String get appName => 'Talaa (طلعة)';
  static String get loading => _ar ? 'جاري التحميل…' : 'Loading…';
  static String get error => _ar ? 'حدث خطأ' : 'An error occurred';
  static String get retry => _ar ? 'إعادة المحاولة' : 'Retry';
  static String get cancel => _ar ? 'إلغاء' : 'Cancel';
  static String get confirm => _ar ? 'تأكيد' : 'Confirm';
  static String get save => _ar ? 'حفظ' : 'Save';
  static String get back => _ar ? 'رجوع' : 'Back';
  static String get next => _ar ? 'التالي' : 'Next';
  static String get done => _ar ? 'تم' : 'Done';
  static String get close => _ar ? 'إغلاق' : 'Close';
  static String get edit => _ar ? 'تعديل' : 'Edit';
  static String get seeAll => _ar ? 'عرض الكل' : 'See All';
  static String get noData => _ar ? 'لا توجد بيانات' : 'No data';
  static String get egp => _ar ? 'ج.م' : 'EGP';
  static String get night => _ar ? 'ليلة' : 'night';
  static String get nights => _ar ? 'ليالي' : 'nights';
  static String get perNight => _ar ? 'جنيه/ليلة' : 'EGP/night';
  static String get saveChanges => _ar ? 'حفظ التعديلات' : 'Save Changes';
  static String get yes => _ar ? 'نعم' : 'Yes';
  static String get no => _ar ? 'لا' : 'No';
  static String get required => _ar ? 'مطلوب' : 'Required';
  static String get invalidEmail =>
      _ar ? 'بريد إلكتروني غير صحيح' : 'Invalid email';
  static String get weakPassword => _ar
      ? 'كلمة مرور ضعيفة (6 أحرف على الأقل)'
      : 'Weak password (min 6 chars)';
  static String get passMismatch =>
      _ar ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match';
  static String get apply => _ar ? 'تطبيق' : 'Apply';
  static String get all => _ar ? 'الكل' : 'All';
  static String get soon => _ar ? 'قريباً' : 'Coming Soon';
  static String get places => _ar ? 'عقار' : 'places';
  static String get share => _ar ? 'مشاركة' : 'Share';

  // ── LANGUAGE ────────────────────────────────────────────────
  static String get langLabel => _ar ? 'عربي' : 'English';
  static String get langFlag => _ar ? '🇪🇬' : '🇬🇧';
  static String get langSwitch => _ar ? 'اللغة / Language' : 'Language / اللغة';

  // ── AREAS ───────────────────────────────────────────────────
  static String get ainSokhna => _ar ? 'عين السخنة' : 'Ain Sokhna';
  static String get northCoast => _ar ? 'الساحل الشمالي' : 'North Coast';
  static String get gouna => _ar ? 'الجونة' : 'El Gouna';
  static String get hurghada => _ar ? 'الغردقة' : 'Hurghada';
  static String get sharm => _ar ? 'شرم الشيخ' : 'Sharm El Sheikh';
  static String get rasSedr => _ar ? 'رأس سدر' : 'Ras Sedr';
  static String get egypt => _ar ? 'مصر' : 'Egypt';

  static String areaName(String ar) {
    switch (ar) {
      case 'عين السخنة':
        return _ar ? ar : 'Ain Sokhna';
      case 'الساحل الشمالي':
        return _ar ? ar : 'North Coast';
      case 'الجونة':
        return _ar ? ar : 'El Gouna';
      case 'الغردقة':
        return _ar ? ar : 'Hurghada';
      case 'شرم الشيخ':
        return _ar ? ar : 'Sharm El Sheikh';
      case 'رأس سدر':
        return _ar ? ar : 'Ras Sedr';
      default:
        return ar;
    }
  }

  // ── CATEGORIES ──────────────────────────────────────────────
  static String get chalets => _ar ? 'شاليهات' : 'Chalets';
  static String get hotels => _ar ? 'فنادق' : 'Hotels';
  static String get resorts => _ar ? 'منتجعات' : 'Resorts';
  static String get villas => _ar ? 'فيلات' : 'Villas';
  static String get aquaPark => _ar ? 'أكوا بارك' : 'Aqua Park';
  static String get beachHouse => _ar ? 'بيت شاطئ' : 'Beach House';
  static String get beach => _ar ? 'شاطئ' : 'Beach';
  static String get seaSports => _ar ? 'رياضات بحرية' : 'Sea Sports';
  static String get diving => _ar ? 'غوص' : 'Diving';
  static String get marina => _ar ? 'مارينا' : 'Marina';

  static String catName(String ar) {
    switch (ar) {
      case 'شاليه':
        return _ar ? ar : 'Chalet';
      case 'شاليهات':
        return _ar ? ar : 'Chalets';
      case 'فيلا':
        return _ar ? ar : 'Villa';
      case 'فيلات':
        return _ar ? ar : 'Villas';
      case 'فندق':
        return _ar ? ar : 'Hotel';
      case 'فنادق':
        return _ar ? ar : 'Hotels';
      case 'منتجع':
        return _ar ? ar : 'Resort';
      case 'منتجعات':
        return _ar ? ar : 'Resorts';
      case 'أكوا بارك':
        return _ar ? ar : 'Aqua Park';
      case 'بيت شاطئ':
        return _ar ? ar : 'Beach House';
      case 'الكل':
        return _ar ? ar : 'All';
      case 'غوص':
        return _ar ? ar : 'Diving';
      case 'مارينا':
        return _ar ? ar : 'Marina';
      case 'رياضات بحرية':
        return _ar ? ar : 'Sea Sports';
      default:
        return ar;
    }
  }

  // ── WELCOME PAGE ────────────────────────────────────────────
  static String get welcomeTagline =>
      _ar ? 'اكتشف • احجز • استمتع' : 'Discover • Book • Enjoy';
  static String get welcomeSubtitle => _ar
      ? 'أجمل الشاليهات والفيلات\nعلى الساحل المصري'
      : 'The finest chalets & villas\non Egypt\'s coast';
  static String get loginBtn => _ar ? 'تسجيل الدخول' : 'Sign In';
  static String get registerBtn => _ar ? 'إنشاء حساب جديد' : 'Create Account';
  static String get browseGuest => _ar ? 'تصفح كزائر' : 'Browse as Guest';

  // ── LOGIN / REGISTER ────────────────────────────────────────
  static String get loginTitle => _ar ? 'تسجيل الدخول' : 'Sign In';
  static String get loginSubtitle =>
      _ar ? 'أهلاً بك مجدداً في Talaa' : 'Welcome back to Talaa';
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
  static String get guestBtn => _ar ? 'تصفح كزائر' : 'Browse as Guest';
  static String get noAccount =>
      _ar ? 'مش عندك حساب؟' : 'Don\'t have an account?';
  static String get registerLink => _ar ? 'سجّل الآن' : 'Register now';
  static String get hasAccount =>
      _ar ? 'عندك حساب بالفعل؟' : 'Already have an account?';
  static String get loginLink => _ar ? 'تسجيل الدخول' : 'Sign In';
  static String get registerTitle => _ar ? 'إنشاء حساب' : 'Create Account';
  static String get registerSub => _ar
      ? 'انضم لـ Talaa واكتشف أجمل الوجهات'
      : 'Join Talaa and discover top destinations';
  static String get registerAction => _ar ? 'إنشاء الحساب' : 'Create Account';

  // ── OTP PAGE ────────────────────────────────────────────────
  static String get otpTitle => _ar ? 'التحقق من الهاتف' : 'Phone Verification';
  static String get otpSubtitle =>
      _ar ? 'أدخل الكود المرسل إلى' : 'Enter the code sent to';
  static String get otpEnterCode => _ar
      ? 'أدخل الكود المكون من 6 أرقام كاملاً'
      : 'Enter the complete 6-digit code';
  static String get otpVerify => _ar ? 'تحقق' : 'Verify';
  static String get otpResend => _ar ? 'إعادة إرسال الكود' : 'Resend Code';
  static String get otpWrong => _ar
      ? 'الكود غير صحيح، حاول مرة أخرى'
      : 'Incorrect code, please try again';
  static String get otpExpired => _ar
      ? 'انتهت صلاحية الكود، اطلب كوداً جديداً'
      : 'Code expired, request a new one';
  static String get otpInvalid =>
      _ar ? 'الكود المدخل غير صحيح' : 'Invalid code entered';
  static String get otpResent =>
      _ar ? 'تم إرسال كود جديد ✅' : 'New code sent ✅';
  static String get otpResendFailed =>
      _ar ? 'فشل إرسال الكود، حاول مرة أخرى' : 'Failed to send code, try again';

  // ── HOME PAGE ───────────────────────────────────────────────
  static String get searchHint => _ar
      ? 'ابحث عن شاليه، منتجع، أو شاطئ…'
      : 'Search chalets, resorts, beaches…';
  static String get filterBtn => _ar ? 'تصفية' : 'Filter';
  static String get exploreType => _ar ? 'استكشف حسب النوع' : 'Explore by Type';
  static String get destinations =>
      _ar ? 'الوجهات الساحلية' : 'Beach Destinations';
  static String get bookNow => _ar ? 'استكشف الآن' : 'Explore Now';
  static String get featuredProps =>
      _ar ? 'عقارات مميزة' : 'Featured Properties';
  static String get instantBook => _ar ? 'حجز فوري' : 'Instant Book';
  static String get morning => _ar ? 'صباح الخير' : 'Good Morning';
  static String get afternoon => _ar ? 'مساء الخير' : 'Good Afternoon';
  static String get evening => _ar ? 'مساء النور' : 'Good Evening';
  static String get recentSearch => _ar ? 'بحث سابق' : 'Recent Searches';
  static String get suggestions => _ar ? 'اقتراحات مميزة' : 'Top Suggestions';

  // Hero
  static String get ainSokhnaSub =>
      _ar ? 'عروض حتى 40% خصم' : 'Up to 40% off deals';
  static String get hurghadaSub =>
      _ar ? 'شعاب مرجانية وبحر بلوري' : 'Coral reefs & crystal sea';
  static String get northCoastSub =>
      _ar ? 'شواطئ بيضاء راقية' : 'Premium white beaches';
  static String get sharmSub =>
      _ar ? 'جنة الغطس والاسترخاء' : 'Diving & relaxation paradise';

  static List<String> get ainSokhnaCategories => _ar
      ? ['شاليهات', 'فيلات', 'منتجعات', 'بيت شاطئ']
      : ['Chalets', 'Villas', 'Resorts', 'Beach House'];
  static List<String> get hurghadaCategories => _ar
      ? ['غوص', 'فنادق', 'منتجعات', 'رياضات بحرية']
      : ['Diving', 'Hotels', 'Resorts', 'Sea Sports'];
  static List<String> get northCoastCategories => _ar
      ? ['شاليهات', 'فيلات', 'أكوا بارك', 'مارينا']
      : ['Chalets', 'Villas', 'Aqua Park', 'Marina'];
  static List<String> get sharmCategories => _ar
      ? ['فنادق', 'منتجعات', 'غوص', 'رياضات بحرية']
      : ['Hotels', 'Resorts', 'Diving', 'Sea Sports'];

  // Filter sheet
  static String get filterTitle => _ar ? 'تصفية النتائج' : 'Filter Results';
  static String get clearAll => _ar ? 'مسح الكل' : 'Clear All';
  static String get area => _ar ? 'المنطقة' : 'Area';
  static String get propType => _ar ? 'نوع العقار' : 'Property Type';
  static String get priceRange => _ar ? 'نطاق السعر' : 'Price Range';
  static String get guestsCount => _ar ? 'عدد الضيوف' : 'Guests';
  static String get roomsCount => _ar ? 'الغرف' : 'Rooms';
  static String get instantOnly => _ar ? 'حجز فوري فقط' : 'Instant Book Only';
  static String get onlineOnly =>
      _ar ? 'دفع أونلاين فقط' : 'Online Payment Only';
  static String get minRating => _ar ? 'أقل تقييم' : 'Min Rating';
  static String get pool => _ar ? 'حمام سباحة' : 'Pool';
  static String get beachAccess => _ar ? 'وصول للشاطئ' : 'Beach Access';
  static String get wifi => _ar ? 'واي فاي' : 'WiFi';
  static String get parking => _ar ? 'موقف سيارات' : 'Parking';
  static String get resetFilters => _ar ? 'مسح الفلاتر' : 'Reset Filters';
  static String get showResults => _ar ? 'عرض النتائج' : 'Show Results';

  // ── EXPLORE PAGE ────────────────────────────────────────────
  static String get search => _ar ? 'بحث' : 'Search';
  static String get areasTab => _ar ? 'المناطق' : 'Areas';
  static String get trending => _ar ? 'الأكثر طلباً' : 'Trending';
  static String get deals => _ar ? 'عروض اليوم' : 'Today\'s Deals';
  static String get propertiesFound => _ar ? 'عقار متاح' : 'properties found';
  static String get noResults => _ar ? 'لا توجد نتائج' : 'No Results Found';
  static String get noResultsSub => _ar
      ? 'جرّب تغيير الفلاتر أو البحث بكلمة مختلفة'
      : 'Try different filters or search terms';
  static String get allAreas => _ar ? 'كل المناطق' : 'All Areas';
  static String get sortBy => _ar ? 'ترتيب حسب' : 'Sort by';

  // ── AREA RESULTS PAGE ───────────────────────────────────────
  static String get availableProps => _ar ? 'عقار متاح' : 'available';
  static String get viewAll => _ar ? 'عرض الكل' : 'View All';
  static String get noPropsArea =>
      _ar ? 'لا توجد عقارات في هذه المنطقة' : 'No properties in this area';
  static String get comingSoon =>
      _ar ? 'جاري إضافة عقارات جديدة قريباً' : 'New properties coming soon';

  // ── PROPERTY DETAILS ────────────────────────────────────────
  static String get featured => _ar ? 'مميز' : 'Featured';
  static String get reviews => _ar ? 'تقييم' : 'reviews';
  static String get instantBooking => _ar ? 'حجز فوري' : 'Instant Booking';
  static String get needsApproval => _ar ? 'يحتاج موافقة' : 'Needs Approval';
  static String get rooms => _ar ? 'غرف' : 'Rooms';
  static String get bathrooms => _ar ? 'حمامات' : 'Bathrooms';
  static String get maxGuests => _ar ? 'ضيوف' : 'Guests';
  static String get amenities => _ar ? 'المرافق' : 'Amenities';
  static String get location => _ar ? 'الموقع' : 'Location';
  static String get aboutProperty => _ar ? 'عن العقار' : 'About';
  static String get showMore => _ar ? 'عرض المزيد' : 'Show More';
  static String get showLess => _ar ? 'عرض أقل' : 'Show Less';
  static String get bookProperty => _ar ? 'احجز الآن' : 'Book Now';
  static String get contactOwner => _ar ? 'تواصل مع المالك' : 'Contact Owner';
  static String get cleaningFee => _ar ? 'رسوم التنظيف' : 'Cleaning Fee';
  static String get totalPrice => _ar ? 'الإجمالي' : 'Total';
  static String get notAvailable => _ar ? 'غير متاح حالياً' : 'Not Available';
  static String get nearby => _ar ? 'أماكن قريبة' : 'Nearby';
  static String get facilities => _ar ? 'الخدمات' : 'Facilities';
  static String get newProp => _ar ? 'جديد' : 'New';
  static String get perNightLabel => _ar ? 'لكل ليلة' : 'per night';

  // ── BOOKING FLOW ────────────────────────────────────────────
  static String get chooseDates => _ar ? 'اختر مواعيدك' : 'Choose Your Dates';
  static String get bookingDetails => _ar ? 'تفاصيل الحجز' : 'Booking Details';
  static String get confirmBooking => _ar ? 'تأكيد الحجز' : 'Confirm Booking';
  static String get arrivalDate => _ar ? 'تاريخ الوصول' : 'Check-in Date';
  static String get departureDate => _ar ? 'تاريخ المغادرة' : 'Check-out Date';
  static String get checkIn => _ar ? 'تسجيل الدخول' : 'Check In';
  static String get checkOut => _ar ? 'تسجيل الخروج' : 'Check Out';
  static String get guestsNum => _ar ? 'عدد الضيوف' : 'Number of Guests';
  static String get guestNote => _ar ? 'ملاحظة للمالك' : 'Note to Owner';
  static String get guestNotePlh =>
      _ar ? 'أي طلبات أو ملاحظات خاصة…' : 'Any special requests…';
  static String get nightsCount => _ar ? 'عدد الليالي' : 'Nights';
  static String get pricePerNight => _ar ? 'سعر الليلة' : 'Price per night';
  static String get proceedPayment =>
      _ar ? 'المتابعة للدفع' : 'Proceed to Payment';
  static String get minNightsMsg => _ar ? 'الحد الأدنى' : 'Minimum';
  static String get dateRange =>
      _ar ? 'تاريخ الوصول والمغادرة' : 'Check-in & Check-out';
  static String get selectDates => _ar ? 'اختر التواريخ' : 'Select Dates';
  static String get weekendPrice => _ar ? 'سعر نهاية الأسبوع' : 'Weekend price';

  // ── PAYMENT PAGE ────────────────────────────────────────────
  static String get paymentMethod => _ar ? 'طريقة الدفع' : 'Payment Method';
  static String get visaMaster =>
      _ar ? 'فيزا / ماستر كارد' : 'Visa / Mastercard';
  static String get visaDesc =>
      _ar ? 'بطاقة ائتمان أو خصم مباشر' : 'Credit or debit card';
  static String get meeza => _ar ? 'ميزة' : 'Meeza';
  static String get meezaDesc =>
      _ar ? 'البطاقة الوطنية المصرية' : 'Egyptian national card';
  static String get fawry => _ar ? 'فوري Pay' : 'Fawry Pay';
  static String get fawryDesc =>
      _ar ? 'ادفع إلكترونياً عبر فوري' : 'Pay via Fawry';
  static String get vodafone => _ar ? 'فودافون كاش' : 'Vodafone Cash';
  static String get vodafoneDesc =>
      _ar ? 'ادفع عبر محفظة فودافون' : 'Pay via Vodafone wallet';
  static String get payNow => _ar ? 'ادفع الآن' : 'Pay Now';
  static String get orderSummary => _ar ? 'ملخص الطلب' : 'Order Summary';
  static String get paymentSuccess =>
      _ar ? 'تم الدفع بنجاح 🎉' : 'Payment Successful 🎉';
  static String get paymentFailed => _ar ? 'فشل الدفع' : 'Payment Failed';
  static String get platformFee =>
      _ar ? 'رسوم المنصة (8%)' : 'Platform Fee (8%)';
  static String get ownerReceives =>
      _ar ? 'يستلم المالك (92%)' : 'Owner receives (92%)';
  static String get bookingConfirmed =>
      _ar ? 'تم تأكيد الحجز ✅' : 'Booking Confirmed ✅';

  // ── BOOKINGS PAGE ───────────────────────────────────────────
  static String get myBookingsTitle => _ar ? 'حجوزاتي' : 'My Bookings';
  static String get upcoming => _ar ? 'قادمة' : 'Upcoming';
  static String get completed => _ar ? 'مكتملة' : 'Completed';
  static String get cancelled => _ar ? 'ملغاة' : 'Cancelled';
  static String get confirmed => _ar ? 'مؤكد' : 'Confirmed';
  static String get pending => _ar ? 'في الانتظار' : 'Pending';
  static String get totalPaid => _ar ? 'إجمالي المدفوع' : 'Total Paid';
  static String get noBookings =>
      _ar ? 'لا توجد حجوزات بعد' : 'No bookings yet';
  static String get noBookingsSub => _ar
      ? 'ابدأ باستكشاف الوجهات وأحجز رحلتك القادمة'
      : 'Start exploring and book your next trip';
  static String get exploreNow => _ar ? 'استكشف الآن' : 'Explore Now';
  static String get viewDetails => _ar ? 'عرض التفاصيل' : 'View Details';
  static String get cancelBooking => _ar ? 'إلغاء الحجز' : 'Cancel Booking';
  static String get rateStay => _ar ? 'قيّم إقامتك' : 'Rate Your Stay';
  static String get checkInLabel => _ar ? 'دخول' : 'Check-in';
  static String get checkOutLabel => _ar ? 'خروج' : 'Check-out';

  // ── CHAT PAGE ───────────────────────────────────────────────
  static String get chatTitle => _ar ? 'المحادثة' : 'Chat';
  static String get typeMessage => _ar ? 'اكتب رسالتك…' : 'Type a message…';
  static String get send => _ar ? 'إرسال' : 'Send';
  static String get online => _ar ? 'متصل الآن' : 'Online';
  static String get offline => _ar ? 'غير متصل' : 'Offline';
  static String get chatProtected => _ar
      ? '🔒 المحادثة محمية — لا يُسمح بتبادل أرقام الهاتف قبل تأكيد الحجز'
      : '🔒 Chat protected — phone numbers not allowed before booking confirmation';
  static String get numberBlocked => _ar
      ? '🚫 غير مسموح بتبادل أرقام الهاتف قبل تأكيد الحجز'
      : '🚫 Phone numbers not allowed before booking confirmation';

  // ── NOTIFICATIONS ───────────────────────────────────────────
  static String get notificationsTitle => _ar ? 'الإشعارات' : 'Notifications';
  static String get noNotifications =>
      _ar ? 'لا توجد إشعارات' : 'No notifications yet';
  static String get markAllRead =>
      _ar ? 'تحديد الكل كمقروء' : 'Mark all as read';
  static String get justNow => _ar ? 'الآن' : 'Just now';
  static String get minutesAgo => _ar ? 'دقيقة' : 'min ago';
  static String get hoursAgo => _ar ? 'ساعة' : 'hr ago';
  static String get daysAgo => _ar ? 'يوم' : 'day ago';
  static String get newMessage => _ar ? 'رسالة جديدة' : 'New Message';
  static String get specialOffer => _ar ? 'عرض خاص 🔥' : 'Special Offer 🔥';

  // ── PROFILE PAGE ────────────────────────────────────────────
  static String get profile => _ar ? 'الملف الشخصي' : 'Profile';
  static String get editProfile => _ar ? 'تعديل الملف' : 'Edit Profile';
  static String get ownerBadge => _ar ? 'مالك عقار' : 'Property Owner';
  static String get guestBadge => _ar ? 'عميل' : 'Guest';
  static String get myProfile => _ar ? 'بياناتي الشخصية' : 'My Profile';
  static String get fullName => _ar ? 'الاسم الكامل' : 'Full Name';
  static String get phone => _ar ? 'رقم الهاتف' : 'Phone Number';
  static String get email => _ar ? 'البريد الإلكتروني' : 'Email';
  static String get myBookings => _ar ? 'حجوزاتي' : 'My Bookings';
  static String get myProperties => _ar ? 'عقاراتي' : 'My Properties';
  static String get payoutMethod => _ar ? 'طريقة الاستلام' : 'Payout Method';
  static String get notifications => _ar ? 'الإشعارات' : 'Notifications';
  static String get preferences => _ar ? 'التفضيلات' : 'Preferences';
  static String get darkMode => _ar ? 'الوضع الداكن' : 'Dark Mode';
  static String get darkModeDesc =>
      _ar ? 'تحويل للثيم الداكن' : 'Switch to dark theme';
  static String get language => _ar ? 'اللغة / Language' : 'Language / اللغة';
  static String get helpCenter => _ar ? 'مركز المساعدة' : 'Help Center';
  static String get rateApp => _ar ? 'قيّم التطبيق ⭐' : 'Rate the App ⭐';
  static String get logout => _ar ? 'تسجيل الخروج' : 'Sign Out';
  static String get logoutConfirm =>
      _ar ? 'هل تريد تسجيل الخروج؟' : 'Sign out?';
  static String get deleteAccount => _ar ? 'حذف الحساب' : 'Delete Account';
  static String get deleteConfirm => _ar
      ? 'هل أنت متأكد من حذف حسابك؟'
      : 'Are you sure? This cannot be undone.';
  static String get becomeOwner => _ar ? 'هل عندك عقار؟' : 'Own a Property?';
  static String get becomeOwnerSub => _ar
      ? 'حوّل حسابك لمالك وضيف عقارك الآن'
      : 'List your property and start earning';
  static String get switchGuest =>
      _ar ? 'التبديل لوضع العميل' : 'Switch to Guest Mode';
  static String get ownerMode =>
      _ar ? 'أنت في وضع المالك' : 'You\'re in Owner Mode';
  static String get tripsCount => _ar ? 'رحلاتي' : 'My Trips';
  static String get reviewsCountL => _ar ? 'تقييماتي' : 'My Reviews';
  static String get listingsCount => _ar ? 'عقاراتي' : 'My Listings';
  static String get bookingsCount => _ar ? 'حجوزاتي' : 'My Bookings';
  static String get totalRevenue =>
      _ar ? 'إجمالي ما استلمته' : 'Total Earnings';
  static String get addProperty => _ar ? 'إضافة عقار جديد' : 'Add New Property';
  static String get addPropertySub => _ar
      ? 'أضف شاليهك أو فيلتك في دقائق'
      : 'Add your chalet or villa in minutes';
  static String get noBookingsYet =>
      _ar ? 'لا يوجد حجوزات بعد' : 'No bookings yet';
  static String get support => _ar ? 'الدعم' : 'Support';
  static String get notifBookings =>
      _ar ? '📅 تحديثات الحجز' : '📅 Booking Updates';
  static String get notifBookingsSub =>
      _ar ? 'اعرف أي جديد في حجوزاتك' : 'Stay updated on your bookings';
  static String get notifMessages => _ar ? '💬 الرسائل' : '💬 Messages';
  static String get notifMessagesSub => _ar
      ? 'رسائل جديدة من الملاك أو الضيوف'
      : 'New messages from owners or guests';
  static String get notifDeals => _ar ? '⚡ عروض خاصة' : '⚡ Special Offers';
  static String get notifDealsSub =>
      _ar ? 'عروض محدودة الوقت على العقارات' : 'Limited time deals';

  // ── OWNER DASHBOARD ─────────────────────────────────────────
  static String get ownerDashboard => _ar ? 'لوحة التحكم' : 'Dashboard';
  static String get myListings => _ar ? 'عقاراتي' : 'My Listings';
  static String get addListing => _ar ? 'إضافة عقار' : 'Add Property';
  static String get ownerBookings =>
      _ar ? 'الحجوزات الواردة' : 'Incoming Bookings';
  static String get earnings => _ar ? 'الأرباح' : 'Earnings';
  static String get payouts => _ar ? 'المستحقات' : 'Payouts';
  static String get active => _ar ? 'نشط' : 'Active';
  static String get inactive => _ar ? 'غير نشط' : 'Inactive';
  static String get editProperty => _ar ? 'تعديل العقار' : 'Edit Property';
  static String get deleteProperty => _ar ? 'حذف العقار' : 'Delete Property';
  static String get noListings =>
      _ar ? 'لا توجد عقارات بعد' : 'No listings yet';
  static String get noListingsSub => _ar
      ? 'أضف عقارك الأول وابدأ في الكسب'
      : 'Add your first property and start earning';
  static String get bookingsCountOwner => _ar ? 'الحجوزات' : 'Bookings';
  static String get totalEarnings => _ar ? 'الإجمالي' : 'Total Earnings';
  static String get bookingsPending => _ar ? 'في الانتظار' : 'Pending';
  static String get bookingsActive => _ar ? 'نشطة' : 'Active';

  // ── OWNER PAYOUTS ───────────────────────────────────────────
  static String get myPayouts => _ar ? 'مستحقاتي' : 'My Payouts';
  static String get paid => _ar ? 'تم التحويل ✅' : 'Paid ✅';
  static String get processing => _ar ? 'جاري التحويل ⏳' : 'Processing ⏳';
  static String get readyToPay => _ar ? 'جاهز للصرف 🟢' : 'Ready 🟢';
  static String get held => _ar ? 'محجوز ⏸️' : 'Held ⏸️';
  static String get days => _ar ? 'يوم' : 'days';
  static String get hours => _ar ? 'ساعة' : 'hours';
  static String get noPayouts => _ar ? 'لا توجد مستحقات بعد' : 'No payouts yet';

  // ── ADD PROPERTY ────────────────────────────────────────────
  static String get addPropertyTitle =>
      _ar ? 'إضافة عقار جديد' : 'Add New Property';
  static String get propertyName => _ar ? 'اسم العقار' : 'Property Name';
  static String get propertyDesc => _ar ? 'وصف العقار' : 'Description';
  static String get propertyArea => _ar ? 'المنطقة' : 'Area';
  static String get propertyType => _ar ? 'نوع العقار' : 'Property Type';
  static String get pricePerNightL =>
      _ar ? 'السعر لكل ليلة' : 'Price per Night';
  static String get bedroomsCount => _ar ? 'غرف النوم' : 'Bedrooms';
  static String get bathroomsCount => _ar ? 'الحمامات' : 'Bathrooms';
  static String get maxGuestsCount => _ar ? 'أقصى عدد ضيوف' : 'Max Guests';
  static String get addPhotos => _ar ? 'إضافة صور' : 'Add Photos';
  static String get submitProperty => _ar ? 'نشر العقار' : 'Publish Property';
  static String get propertyAmenities =>
      _ar ? 'المرافق والخدمات' : 'Amenities & Services';
  static String get instantBookingL => _ar ? 'حجز فوري' : 'Instant Booking';
  static String get onlinePayment => _ar ? 'دفع إلكتروني' : 'Online Payment';
  static String get minNightsL =>
      _ar ? 'الحد الأدنى للليالي' : 'Minimum Nights';
  static String get maxNightsL =>
      _ar ? 'الحد الأقصى للليالي' : 'Maximum Nights';
}
