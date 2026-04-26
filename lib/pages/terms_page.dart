// ═══════════════════════════════════════════════════════════════
//  TALAA — سياسة الاستخدام والخصوصية
//  Comprehensive bilingual Terms of Service & Privacy Policy.
//  Rewritten with Airbnb-style protections:
//    * Platform positioned as a neutral technology marketplace,
//      not a party to the rental contract between host & guest.
//    * Strong liability disclaimers, "AS IS" warranty waiver,
//      limitation of liability capped at platform fees paid.
//    * Mutual indemnification obligations.
//    * Egyptian governing law (Personal Data Protection Law
//      151/2020) with CRCICA arbitration as optional forum.
//    * Community standards covering parties, discrimination,
//      off-platform transactions, safety and prohibited conduct.
//  The page listens to `appSettings` so toggling AR/EN refreshes
//  every section without having to reopen the screen.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../widgets/constants.dart';

// Unified brand accent (same orange used across profile + wallet).
const _kBrand = Color(0xFFFF6B35);
const _kBrandDark = Color(0xFFE85A24);

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, _) {
        final ar = appSettings.arabic;
        return Scaffold(
          backgroundColor: context.kSand,
          appBar: AppBar(
            backgroundColor: context.kCard,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: context.kText, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              ar ? 'سياسة الاستخدام والخصوصية' : 'Terms & Privacy Policy',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: context.kText),
            ),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            children: [
              _header(context, ar),
              const SizedBox(height: 24),
              ..._sections.map((s) => _sectionCard(context, ar, s)),
              _footer(context, ar),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, bool ar) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kBrandDark, _kBrand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _kBrand.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: [
        const Icon(Icons.verified_user_rounded,
            color: Colors.white, size: 38),
        const SizedBox(height: 10),
        const Text('Talaa Trip',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(
          ar ? 'سياسة الاستخدام والخصوصية' : 'Terms of Service & Privacy',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            ar ? 'آخر تحديث: أبريل 2026' : 'Last updated: April 2026',
            style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }

  Widget _sectionCard(BuildContext context, bool ar, _Section s) {
    final title = ar ? s.titleAr : s.titleEn;
    final items = ar ? s.itemsAr : s.itemsEn;
    final number = ar ? s.numAr : s.numEn;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kBrand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: _kBrand)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
          ),
        ]),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _kBrand,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.75,
                            color: context.kSub,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            )),
      ]),
    );
  }

  Widget _footer(BuildContext context, bool ar) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBrand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBrand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.mail_outline_rounded,
                size: 18, color: _kBrand),
            const SizedBox(width: 8),
            Text(
              ar ? 'للتواصل القانوني' : 'Legal contact',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: context.kText),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            ar
                ? 'أي استفسار بخصوص هذه السياسة أو طلب يتعلق ببياناتك '
                  'الشخصية يُرسل إلى:'
                : 'Questions about these Terms or requests regarding your '
                  'personal data should be sent to:',
            style: TextStyle(fontSize: 12, color: context.kSub, height: 1.6),
          ),
          const SizedBox(height: 6),
          const Text('legal@talaa.app',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _kBrand)),
          const SizedBox(height: 4),
          const Text('privacy@talaa.app',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _kBrand)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  Policy section container — bilingual (AR primary, EN mirror)
// ────────────────────────────────────────────────────────────

class _Section {
  final String numAr;
  final String numEn;
  final String titleAr;
  final String titleEn;
  final List<String> itemsAr;
  final List<String> itemsEn;
  const _Section({
    required this.numAr,
    required this.numEn,
    required this.titleAr,
    required this.titleEn,
    required this.itemsAr,
    required this.itemsEn,
  });
}

const _sections = <_Section>[
  // ──────────────────────── 1. Introduction ────────────────────────
  _Section(
    numAr: '١', numEn: '1',
    titleAr: 'مقدمة وقبول الشروط',
    titleEn: 'Introduction & Acceptance',
    itemsAr: [
      'تُدار منصة Talaa Trip ("المنصة" / "نحن") داخل جمهورية مصر العربية وتُقدّم خدماتها الرقمية من خلال تطبيقات الهاتف والموقع الإلكتروني.',
      'تُعدّ المنصة وسيطاً تقنياً فقط يُيسّر التعارف بين الضيوف ومُلّاك العقارات؛ وليست طرفاً في أي عقد إيجار يُبرم من خلالها.',
      'بمجرد إنشائك حساباً أو استخدامك للمنصة، فإنك تُقرّ بأنك قرأت ووافقت صراحة على هذه السياسة وسياسة الخصوصية والسياسات الفرعية المُشار إليها داخل التطبيق.',
      'في حال عدم موافقتك على أي بند، يجب عليك التوقف فوراً عن استخدام الخدمة وحذف التطبيق.',
      'قد تُحدَّث هذه الشروط من وقت لآخر، وسيُعدّ استخدامك المستمر موافقةً ضمنية على النسخة الأحدث.',
    ],
    itemsEn: [
      'Talaa Trip ("Platform", "we", "us") is operated within the Arab Republic of Egypt and delivers its digital services through mobile apps and the web.',
      'The Platform acts solely as a technology intermediary that facilitates the connection between guests and property hosts. It is NOT a party to any rental contract formed through it.',
      'By creating an account or otherwise using the Platform, you expressly acknowledge having read and agreed to these Terms, the Privacy Policy, and any sub-policies referenced in-app.',
      'If you do not agree to any provision, you must immediately stop using the service and delete the application.',
      'These Terms may be updated from time to time; your continued use constitutes implied acceptance of the latest version.',
    ],
  ),

  // ──────────────────────── 2. Definitions ────────────────────────
  _Section(
    numAr: '٢', numEn: '2',
    titleAr: 'التعريفات',
    titleEn: 'Definitions',
    itemsAr: [
      '"المنصة" / "Talaa Trip": التطبيق وكل خدماته الإلكترونية والمحتوى المنشور عليه.',
      '"المستخدم": أي شخص طبيعي يسجّل أو يستخدم المنصة.',
      '"الضيف": المستخدم الذي يحجز عقاراً أو يدفع ثمن إقامة.',
      '"المالك": المستخدم الذي يعرض عقاراً أو وحدة للإيجار.',
      '"الحجز": الاتفاق الرقمي المُبرَم بين الضيف والمالك عبر المنصة.',
      '"الخدمات": إدراج العقارات، البحث، الحجز، الرسائل، والدفع.',
      '"الرسوم": عمولة المنصة، رسوم الخدمة، ورسوم معالجة الدفع.',
      '"القانون المعمول به": قوانين جمهورية مصر العربية.',
    ],
    itemsEn: [
      '"Platform" / "Talaa Trip": the application, its online services and content.',
      '"User": any natural person who registers or uses the Platform.',
      '"Guest": a User who books a property or pays for a stay.',
      '"Host": a User who lists a property or unit for rental.',
      '"Booking": the digital agreement concluded between the Guest and the Host through the Platform.',
      '"Services": listing, search, booking, messaging and payments.',
      '"Fees": Platform commission, service fees and payment-processing fees.',
      '"Applicable Law": the laws of the Arab Republic of Egypt.',
    ],
  ),

  // ──────────────────────── 3. Eligibility ────────────────────────
  _Section(
    numAr: '٣', numEn: '3',
    titleAr: 'الأهلية والتحقق من الهوية',
    titleEn: 'Eligibility & Identity Verification',
    itemsAr: [
      'يجب ألا يقل عمرك عن 18 عاماً وأن تكون كامل الأهلية القانونية للتعاقد طبقاً للقانون المصري.',
      'تلتزم بتقديم اسم حقيقي، ورقم قومي أو جواز سفر صالح، ورقم هاتف نشط، وبريد إلكتروني قابل للتحقق.',
      'يحق للمنصة في أي وقت طلب مستندات هوية، إثبات ملكية (للمُلّاك)، أو أي بيانات لازمة للتحقق ضمن سياسات مكافحة الاحتيال والـ KYC.',
      'يُحظر استخدام الخدمة من أي شخص محظور عليه التعاقد بموجب قرارات قضائية أو قوائم عقوبات دولية.',
      'أنت ممنوع من استخدام المنصة نيابةً عن كيان قاصر أو غير مفوَّض.',
    ],
    itemsEn: [
      'You must be at least 18 years old and possess full legal capacity to enter binding contracts under Egyptian law.',
      'You must provide a real name, a valid national ID or passport, an active phone number, and a verifiable email address.',
      'The Platform may at any time request identity documents, proof of ownership (for Hosts), or any data required for KYC / anti-fraud verification.',
      'Using the service is prohibited for any person barred from contracting under court orders or included on international sanctions lists.',
      'You may not use the Platform on behalf of a minor or any unauthorised entity.',
    ],
  ),

  // ──────────────────────── 4. Account Rules ────────────────────────
  _Section(
    numAr: '٤', numEn: '4',
    titleAr: 'التسجيل والحساب',
    titleEn: 'Registration & Account',
    itemsAr: [
      'يُسمح بحساب واحد فقط لكل شخص. تُغلَق الحسابات المكرَّرة دون إشعار.',
      'أنت المسؤول الوحيد عن سرية بيانات الدخول الخاصة بك وكل نشاط يتم عبر حسابك.',
      'يجب إخطار فريق الدعم فوراً عند الاشتباه في أي استخدام غير مصرح به.',
      'يحق للمنصة تعليق أو إنهاء أي حساب يُخالف هذه الشروط أو يُقدّم بيانات مغلوطة، دون التزام بالتعويض.',
      'لا يجوز نقل الحساب أو بيعه أو إعارته لأي طرف آخر.',
    ],
    itemsEn: [
      'One account per person is allowed; duplicate accounts will be terminated without notice.',
      'You are solely responsible for the confidentiality of your credentials and all activity under your account.',
      'You must notify support immediately if you suspect any unauthorised use.',
      'The Platform may suspend or terminate any account that breaches these Terms or provides misleading data, without any obligation of compensation.',
      'Accounts may not be transferred, sold or loaned to any third party.',
    ],
  ),

  // ──────────────────────── 5. Role of Platform (CRITICAL) ────────
  _Section(
    numAr: '٥', numEn: '5',
    titleAr: 'دور المنصة ⚠️ بند جوهري',
    titleEn: 'Role of the Platform ⚠️ Key Provision',
    itemsAr: [
      'Talaa Trip وسيط تقني فقط، ولا تمتلك أو تُشغّل أو تُدير أو تُعاين أي عقار من العقارات المعروضة.',
      'لا تُعدّ المنصة وكيلاً عقارياً أو سمساراً أو شركة تأجير أو مؤمِّناً أو منظِّم سياحة.',
      'عقد الإيجار يُبرم حصراً بين الضيف والمالك، وهما وحدهما المسؤولان عن تنفيذه.',
      'كل المعلومات عن العقار (الأوصاف، الصور، الأسعار، المرافق) يُقدّمها المالك على مسؤوليته الشخصية، وتتحقق المنصة منها قدر الإمكان دون ضمان شامل.',
      'لا تضمن المنصة هوية أو نزاهة أو سلوك أي مستخدم، ولا سلامة أو جودة أو مطابقة أي عقار للمواصفات أو للقانون.',
      'استخدامك للمنصة يكون على مسؤوليتك الكاملة.',
    ],
    itemsEn: [
      'Talaa Trip is a technology intermediary only; it does not own, operate, manage or inspect any listed property.',
      'The Platform is NOT a real-estate agent, broker, rental company, insurer or tour operator.',
      'The rental contract is formed exclusively between the Guest and the Host, who alone are responsible for its performance.',
      'All property information (descriptions, photos, prices, amenities) is supplied by the Host at their own responsibility; the Platform performs reasonable checks but does not provide a comprehensive guarantee.',
      'The Platform does not guarantee the identity, integrity, or conduct of any User, nor the safety, quality or legal compliance of any property.',
      'Your use of the Platform is entirely at your own risk.',
    ],
  ),

  // ──────────────────────── 6. Host Obligations ────────────────────
  _Section(
    numAr: '٦', numEn: '6',
    titleAr: 'التزامات المالك',
    titleEn: 'Host Obligations',
    itemsAr: [
      'تضمن أنك المالك القانوني للعقار أو لديك تفويض كتابي بإدارته وعرضه للإيجار.',
      'تلتزم بجميع التراخيص المطلوبة (تراخيص السياحة، الحي، البلدية) والقوانين الضريبية.',
      'تُدرج معلومات دقيقة وصادقة عن العقار: الوصف، الصور الحديثة، عدد الغرف، المرافق، السعر، الموقع، والحد الأقصى للنزلاء.',
      'تلتزم بتسليم العقار في الموعد المُتفق عليه وبالحالة الموصوفة، وبالإجابة على رسائل الضيوف خلال وقت معقول.',
      'يُحظر عليك التفاوض أو تحصيل أي مبالغ خارج المنصة من الضيوف القادمين عبرها.',
      'يُحظر التمييز بين الضيوف على أساس الدين، الجنس، العرق، الجنسية، أو الحالة العائلية.',
      'تكرار الإلغاء، عدم الرد، أو خداع الضيوف يُعرّض حسابك للتعليق الفوري ومصادرة العمولة.',
      'أي ضرر يلحق بالمستخدمين بسبب تقصيرك أو مخالفتك يُعدّ مسؤوليتك الشخصية دون أي تحمّل من المنصة.',
    ],
    itemsEn: [
      'You warrant that you are the legal owner of the property or hold written authorisation to manage and list it.',
      'You will comply with all required licences (tourism, zoning, municipality) and tax laws.',
      'You will list accurate and truthful information: description, recent photos, rooms, amenities, price, location and maximum occupancy.',
      'You will honour the agreed check-in, deliver the property as described, and respond to guest messages within a reasonable time.',
      'You are strictly prohibited from negotiating or collecting any payment off-platform from guests introduced through it.',
      'You may not discriminate against guests on the basis of religion, gender, race, nationality or family status.',
      'Repeated cancellations, non-responsiveness, or misrepresentation will result in immediate suspension and forfeiture of commission.',
      'Any damage suffered by users due to your negligence or breach is your sole responsibility, with no liability on the Platform.',
    ],
  ),

  // ──────────────────────── 7. Guest Obligations ────────────────────
  _Section(
    numAr: '٧', numEn: '7',
    titleAr: 'التزامات الضيف',
    titleEn: 'Guest Obligations',
    itemsAr: [
      'تستخدم العقار للغرض السكني / السياحي المُتفق عليه فقط، ولا تستخدمه لأي نشاط تجاري أو حفلات أو فعاليات دون موافقة كتابية من المالك.',
      'لا تتجاوز عدد الأشخاص المذكور في الحجز، ولا تُدخل حيوانات أليفة بدون إذن.',
      'تلتزم بمواعيد الوصول والمغادرة وبقواعد المنزل المُعلنة من المالك.',
      'تعتني بالعقار بعناية الشخص العادي، وتُبلّغ المالك فوراً عن أي تلف قبل أو أثناء إقامتك.',
      'تتحمل كامل قيمة الأضرار الناتجة عن سوء الاستخدام أو الإهمال، وللمالك الحق في المطالبة بها خلال 72 ساعة من تسجيل خروجك.',
      'يُحظر القيام بأي نشاط غير قانوني داخل العقار، ويُعدّ ذلك إخلالاً جسيماً يُعرّضك للإنهاء الفوري والإبلاغ للسلطات.',
      'أي مبالغ مستحقة عن ضرر ولم تُسدَّد خلال 7 أيام تُخصم من محفظتك أو يتم التقاضي بشأنها.',
    ],
    itemsEn: [
      'You will use the property solely for the agreed residential/tourism purpose; no commercial use, parties, or events without the Host\'s written consent.',
      'You will not exceed the occupancy stated in the Booking, nor bring pets without permission.',
      'You will respect the announced check-in/out times and the Host\'s house rules.',
      'You will take reasonable care of the property and notify the Host immediately of any damage before or during your stay.',
      'You are fully liable for the cost of damage caused by misuse or negligence. The Host may file a claim within 72 hours of your check-out.',
      'Any illegal activity inside the property is a material breach that triggers immediate termination and reporting to the authorities.',
      'Unpaid damage charges not settled within 7 days may be deducted from your wallet or pursued legally.',
    ],
  ),

  // ──────────────────────── 8. Bookings & Payments ────────────────
  _Section(
    numAr: '٨', numEn: '8',
    titleAr: 'الحجوزات، الدفع، والعمولة',
    titleEn: 'Bookings, Payments & Commission',
    itemsAr: [
      'يتم الدفع حصراً داخل المنصة عبر بوابات الدفع المعتمدة؛ ولا تتحمل المنصة أي مسؤولية عن مبالغ مُحوَّلة خارجها.',
      'إتمام الدفع يُعدّ قبولاً نهائياً لتفاصيل الحجز وشروط الإلغاء.',
      'تُحتسب عمولة المنصة بنسبة 10% من قيمة الإيجار وتُخصم من حصة المالك (قابلة للتعديل بإشعار مسبق).',
      'تُضاف رسوم معالجة البطاقة بشكل منفصل على المستخدم حسب البوابة.',
      'يُحوَّل مستحق المالك بعد مرور 24 ساعة من بداية إقامة الضيف، ما لم يُفتح نزاع.',
      'يحق للمنصة تجميد أي مبالغ متنازَع عليها لحين الفصل فيها بناءً على الأدلة والمراسلات داخل التطبيق.',
      'عملة الحجز: الجنيه المصري (EGP). فروق أسعار صرف البطاقات الأجنبية على مسؤولية الضيف.',
    ],
    itemsEn: [
      'All payments are exclusively processed inside the Platform through approved gateways; the Platform bears no liability for funds transferred off-platform.',
      'Completing payment is final acceptance of the booking details and cancellation policy.',
      'The Platform charges a 10% commission on the rental value, deducted from the Host\'s payout (subject to change with prior notice).',
      'Card processing fees may be added separately depending on the gateway.',
      'Host payout is released 24 hours after the start of the Guest\'s stay, unless a dispute is opened.',
      'The Platform may freeze disputed funds until the matter is resolved based on evidence and in-app correspondence.',
      'Booking currency: Egyptian Pound (EGP). FX differences on foreign cards are the Guest\'s responsibility.',
    ],
  ),

  // ──────────────────────── 9. Cancellation ────────────────────────
  _Section(
    numAr: '٩', numEn: '9',
    titleAr: 'الإلغاء والاسترداد',
    titleEn: 'Cancellations & Refunds',
    itemsAr: [
      'إلغاء الضيف — قبل 14 يوماً أو أكثر من الوصول: استرداد 100%.',
      'إلغاء الضيف — قبل 7 إلى 13 يوماً: استرداد 50%.',
      'إلغاء الضيف — قبل 3 إلى 6 أيام: استرداد 25%.',
      'إلغاء الضيف — أقل من 48 ساعة أو عدم الحضور: لا استرداد.',
      'إلغاء المالك: استرداد 100% فوري للضيف، وقد تُضاف قسيمة تعويض داخلية حسب تقدير المنصة.',
      'تكرار إلغاء المالك لأكثر من مرتين خلال 30 يوماً يؤدي لتعليق حسابه تلقائياً.',
      'الحالات القهرية المُوثّقة (وفاة، مرض جسيم، كارثة طبيعية، قرار حكومي يمنع السفر) قد تُمنح فيها استرداداً خارج الجدول بعد تقديم مستند رسمي، ويُترك القرار النهائي للمنصة.',
    ],
    itemsEn: [
      'Guest cancellation ≥14 days before check-in: 100% refund.',
      'Guest cancellation 7–13 days: 50% refund.',
      'Guest cancellation 3–6 days: 25% refund.',
      'Guest cancellation <48 hours or no-show: no refund.',
      'Host cancellation: immediate 100% refund to Guest, possibly with a goodwill voucher at the Platform\'s discretion.',
      'More than two host cancellations within 30 days triggers automatic account suspension.',
      'Documented force-majeure events (death, serious illness, natural disaster, government travel ban) may qualify for an off-schedule refund upon official evidence; the final decision rests with the Platform.',
    ],
  ),

  // ──────────────────────── 10. Taxes ───────────────────────────────
  _Section(
    numAr: '١٠', numEn: '10',
    titleAr: 'الضرائب والالتزامات التجارية',
    titleEn: 'Taxes & Commercial Obligations',
    itemsAr: [
      'يتحمل المالك وحده أي ضريبة دخل، ضريبة قيمة مضافة، أو رسوم سياحية مترتبة على الدخل المحقق من الإيجار.',
      'يلتزم المالك بتقديم إقراراته الضريبية وفق القانون المصري، والمنصة غير مسؤولة عن أي مخالفات ضريبية.',
      'قد تُصدر المنصة تقارير مبيعات للمُلّاك عند طلبها من مصلحة الضرائب المصرية.',
      'يحق للمنصة استقطاع أي مبالغ تفرضها الجهات الضريبية المصرية عند الحاجة.',
      'لا تُقدّم المنصة أي استشارة ضريبية، وعلى كل مستخدم الرجوع لمستشاره الخاص.',
    ],
    itemsEn: [
      'The Host alone is liable for any income tax, VAT, or tourism fees arising from rental income.',
      'The Host must file tax returns under Egyptian law; the Platform is not responsible for any tax violations.',
      'The Platform may issue sales reports to Hosts upon request from the Egyptian Tax Authority.',
      'The Platform may withhold any amounts required by Egyptian tax authorities.',
      'The Platform provides no tax advice; each user should consult their own advisor.',
    ],
  ),

  // ──────────────────────── 11. Damage & Insurance ─────────────────
  _Section(
    numAr: '١١', numEn: '11',
    titleAr: 'الضرر والتأمين',
    titleEn: 'Damage & Insurance',
    itemsAr: [
      'أي ضرر يلحق بالعقار نتيجة الضيف هو مسؤولية مالية كاملة على الضيف.',
      'على المالك رفع مطالبة الضرر مع أدلة مصوّرة خلال 72 ساعة من خروج الضيف.',
      'تتولى المنصة دور الوسيط المحايد، ولها القرار النهائي بعد مراجعة الأدلة وسجل المحادثات داخل التطبيق.',
      'لا تعمل المنصة كشركة تأمين، ولا تضمن سداد أي مبالغ تتجاوز قيمة الحجز أو قيمة التأمين الاختياري إن وُجد.',
      'النزاعات التي تتجاوز الحد الأقصى المحدد للتأمين تُحال إلى القضاء المصري المختص.',
    ],
    itemsEn: [
      'Any damage to the property caused by the Guest is the Guest\'s full financial responsibility.',
      'Hosts must file damage claims with photographic evidence within 72 hours of check-out.',
      'The Platform acts as a neutral mediator and has the final decision after reviewing evidence and in-app chat history.',
      'The Platform does NOT act as an insurer and does not guarantee payment of amounts exceeding the booking value or optional coverage if offered.',
      'Disputes exceeding any set insurance cap shall be referred to the competent Egyptian courts.',
    ],
  ),

  // ──────────────────────── 12. Prohibited Conduct ─────────────────
  _Section(
    numAr: '١٢', numEn: '12',
    titleAr: 'السلوك المحظور',
    titleEn: 'Prohibited Conduct',
    itemsAr: [
      'أي نشاط غير قانوني أو ينتهك القوانين المصرية.',
      'الاحتيال، التحايل على الرسوم، أو تقديم معلومات مزوّرة.',
      'التحرش، الكراهية، العنصرية، أو التهديد عبر الرسائل.',
      'نشر محتوى يخالف الآداب العامة أو ينتهك حقوق الملكية الفكرية.',
      'محاولة اختراق المنصة أو عمل هندسة عكسية أو سكرابينج آلي دون إذن.',
      'الترويج لسلع أو خدمات غير ذات صلة، أو إرسال سبام.',
      'استخدام أكثر من حساب للتحايل على الحظر أو الرسوم.',
    ],
    itemsEn: [
      'Any illegal activity or violation of Egyptian law.',
      'Fraud, fee circumvention, or submission of falsified information.',
      'Harassment, hate speech, racism, or threats via messaging.',
      'Posting content that violates public decency or intellectual-property rights.',
      'Attempting to hack, reverse-engineer, or perform automated scraping without authorisation.',
      'Promoting unrelated goods or services, or sending spam.',
      'Using multiple accounts to circumvent bans or fees.',
    ],
  ),

  // ──────────────────────── 13. User Content & License ─────────────
  _Section(
    numAr: '١٣', numEn: '13',
    titleAr: 'محتوى المستخدم والترخيص',
    titleEn: 'User Content & Licence',
    itemsAr: [
      'تظل ملكية ما تنشره (صور، أوصاف، تقييمات) عائدةً إليك.',
      'تمنح المنصة ترخيصاً دائماً، عالمياً، مجانياً، قابلاً للتنازل عنه، وغير حصري لاستخدام هذا المحتوى في تشغيل التطبيق والترويج له وتحسينه.',
      'تُقرّ بأنك تملك كامل الحقوق اللازمة لمنح هذا الترخيص، وأن المحتوى لا ينتهك حقوق الغير.',
      'يحق للمنصة تعديل أو حذف أي محتوى يُخالف هذه الشروط أو القانون.',
      'تحتفظ المنصة بالحق في استخدام تقييمات موجزة وصور معتمدة في التسويق دون دفع مقابل إضافي.',
    ],
    itemsEn: [
      'You retain ownership of the content you post (photos, descriptions, reviews).',
      'You grant the Platform a perpetual, worldwide, royalty-free, sublicensable, non-exclusive licence to use that content for operating, promoting and improving the Platform.',
      'You represent that you hold all necessary rights to grant this licence and that the content does not infringe third-party rights.',
      'The Platform may edit or remove any content that breaches these Terms or applicable law.',
      'The Platform may use short reviews and approved photos in marketing without additional compensation.',
    ],
  ),

  // ──────────────────────── 14. Reviews ────────────────────────────
  _Section(
    numAr: '١٤', numEn: '14',
    titleAr: 'التقييمات والمراجعات',
    titleEn: 'Reviews',
    itemsAr: [
      'يجب أن تكون التقييمات صادقة ومستندة إلى تجربة حقيقية.',
      'يُمنع التلاعب بالتقييمات أو تبادل المصالح للحصول على تقييم أعلى.',
      'يحق للمنصة حذف أي تقييم يُخالف هذه السياسات أو يحتوي على إساءات.',
      'تحتفظ المنصة بحقها في تلخيص التقييمات أو تصنيفها لأغراض إحصائية.',
    ],
    itemsEn: [
      'Reviews must be truthful and based on a genuine experience.',
      'Manipulation of reviews or mutual-benefit schemes to obtain higher ratings is prohibited.',
      'The Platform may remove any review that breaches these policies or contains abuse.',
      'The Platform may summarise or classify reviews for statistical purposes.',
    ],
  ),

  // ──────────────────────── 15. Termination ────────────────────────
  _Section(
    numAr: '١٥', numEn: '15',
    titleAr: 'الإنهاء والتعليق',
    titleEn: 'Termination & Suspension',
    itemsAr: [
      'يحق للمنصة تعليق أو إنهاء أي حساب في أي وقت وبمحض اختيارها عند الاشتباه في مخالفة هذه الشروط أو أي قانون، أو لحماية سلامة المستخدمين.',
      'عند الإنهاء، قد تُلغى الحجوزات المعلّقة وتُردّ المبالغ وفق سياسة الإلغاء.',
      'المبالغ المُصادَرة بسبب المخالفات غير قابلة للاسترداد.',
      'استمرار بعض البنود (كالتعويض وحدود المسؤولية والخصوصية) يبقى سارياً حتى بعد إنهاء الحساب.',
    ],
    itemsEn: [
      'The Platform may suspend or terminate any account at any time and at its sole discretion where it suspects breach of these Terms or any law, or to protect user safety.',
      'Upon termination, pending bookings may be cancelled and refunds issued per the cancellation policy.',
      'Amounts forfeited due to violations are non-refundable.',
      'Certain provisions (indemnification, limitation of liability, privacy) survive termination of the account.',
    ],
  ),

  // ──────────────────────── 16. Disclaimers (CRITICAL) ─────────────
  _Section(
    numAr: '١٦', numEn: '16',
    titleAr: 'إخلاء المسؤولية ⚠️ بند جوهري',
    titleEn: 'Disclaimers ⚠️ Key Provision',
    itemsAr: [
      'تُقدَّم المنصة "كما هي" و"كما هي متاحة" دون أي ضمانات صريحة أو ضمنية.',
      'لا نضمن خلو التطبيق من الأعطال أو أن يكون آمناً دائماً أو متاحاً 24/7.',
      'لا نضمن صلاحية أي عقار، سلامته، جودته، أو مطابقته لأي وصف.',
      'لا نضمن هوية أو سلوك أو نوايا أي مستخدم.',
      'أي استخدام أو اعتماد على محتوى المنصة يكون على مسؤوليتك الكاملة.',
      'إلى أقصى حد يسمح به القانون المصري، نتنصّل من جميع الضمانات الضمنية بالرواج، الملاءمة لغرض معين، أو عدم الانتهاك.',
    ],
    itemsEn: [
      'The Platform is provided "AS IS" and "AS AVAILABLE" without any express or implied warranties.',
      'We do not warrant that the app will be free of defects, secure at all times, or available 24/7.',
      'We do not warrant the suitability, safety, quality or conformity of any property.',
      'We do not warrant the identity, conduct or intent of any user.',
      'Any use of or reliance on the Platform\'s content is entirely at your own risk.',
      'To the maximum extent permitted by Egyptian law, we disclaim all implied warranties of merchantability, fitness for a particular purpose, and non-infringement.',
    ],
  ),

  // ──────────────────────── 17. Limitation of Liability (CRITICAL) ─
  _Section(
    numAr: '١٧', numEn: '17',
    titleAr: 'تحديد المسؤولية ⚠️ بند جوهري',
    titleEn: 'Limitation of Liability ⚠️ Key Provision',
    itemsAr: [
      'إلى أقصى حد يسمح به القانون، لا تُسأل المنصة ولا مُلّاكها ولا موظفوها ولا شركاؤها عن أي أضرار غير مباشرة، تبعية، خاصة، عرضية، أو عقابية.',
      'لا نُسأل عن أي خسارة أرباح، إيرادات، بيانات، سمعة، أو فرصة تجارية.',
      'لا نُسأل عن أي إصابات شخصية، وفاة، تلف ممتلكات، سرقة، أو مرض يحدث داخل أو بسبب أي عقار مُدرج.',
      'لا نُسأل عن تصرفات أو إهمال أي مستخدم، أو أي نزاع بين المستخدمين.',
      'لا نُسأل عن انقطاع الخدمة، فقد البيانات، أو الهجمات السيبرانية خارج سيطرتنا المعقولة.',
      'في جميع الأحوال، الحد الأقصى للمسؤولية التراكمية لا يتجاوز إجمالي عمولة المنصة المدفوعة من المستخدم خلال الـ 3 أشهر السابقة للمطالبة، أو 1,000 جنيه مصري، أيهما أقل.',
    ],
    itemsEn: [
      'To the maximum extent permitted by law, the Platform, its owners, employees and partners shall not be liable for any indirect, consequential, special, incidental or punitive damages.',
      'We are not liable for any loss of profits, revenue, data, goodwill or business opportunity.',
      'We are not liable for any personal injury, death, property damage, theft or illness occurring in or in connection with any listed property.',
      'We are not liable for the acts or omissions of any user, or any dispute between users.',
      'We are not liable for service interruptions, data loss or cyber-attacks beyond our reasonable control.',
      'In all cases, our aggregate liability is capped at the total Platform commission paid by the user in the 3 months preceding the claim, or EGP 1,000, whichever is lower.',
    ],
  ),

  // ──────────────────────── 18. Indemnification ────────────────────
  _Section(
    numAr: '١٨', numEn: '18',
    titleAr: 'التعويض',
    titleEn: 'Indemnification',
    itemsAr: [
      'توافق على تعويض المنصة ومُلّاكها وموظفيها وحمايتهم من أي مطالبة، مسؤولية، ضرر، خسارة، أو نفقة (بما في ذلك أتعاب المحاماة) تنشأ عن:',
      'استخدامك للمنصة أو إساءة استخدامها.',
      'إخلالك بهذه الشروط أو أي قانون معمول به.',
      'المحتوى الذي ترفعه أو تنشره.',
      'أي نزاع بينك وبين أي مستخدم آخر.',
      'انتهاكك لحقوق أي طرف ثالث (بما فيها حقوق الملكية الفكرية والخصوصية).',
    ],
    itemsEn: [
      'You agree to indemnify, defend and hold harmless the Platform, its owners and employees from any claim, liability, damage, loss or expense (including legal fees) arising from:',
      'Your use or misuse of the Platform.',
      'Your breach of these Terms or any applicable law.',
      'The content you upload or post.',
      'Any dispute between you and another user.',
      'Your violation of any third-party rights (including IP and privacy rights).',
    ],
  ),

  // ──────────────────────── 19. Force Majeure ──────────────────────
  _Section(
    numAr: '١٩', numEn: '19',
    titleAr: 'القوة القاهرة',
    titleEn: 'Force Majeure',
    itemsAr: [
      'لا يُسأل أي طرف عن التأخر أو الإخفاق في التنفيذ الناتج عن أحداث خارج سيطرته المعقولة، ومنها:',
      'الأوبئة والجوائح والحجر الصحي.',
      'الحرب، الاضطرابات المدنية، أو قرارات الطوارئ.',
      'الكوارث الطبيعية (زلزال، فيضان، حريق).',
      'قرارات الجهات الحكومية أو التنظيمية التي تعرقل التشغيل.',
      'انقطاع الإنترنت، الاتصالات، الكهرباء، أو خدمات بوابات الدفع.',
    ],
    itemsEn: [
      'Neither party is liable for any delay or failure in performance caused by events beyond reasonable control, including:',
      'Pandemics, epidemics and quarantine orders.',
      'War, civil unrest, or emergency declarations.',
      'Natural disasters (earthquake, flood, fire).',
      'Governmental or regulatory orders impeding operation.',
      'Outages of internet, telecommunications, electricity, or payment-gateway services.',
    ],
  ),

  // ──────────────────────── 20. Governing Law ──────────────────────
  _Section(
    numAr: '٢٠', numEn: '20',
    titleAr: 'القانون الحاكم والاختصاص القضائي',
    titleEn: 'Governing Law & Jurisdiction',
    itemsAr: [
      'تخضع هذه الشروط وتُفسَّر وفقاً لقوانين جمهورية مصر العربية.',
      'أي نزاع لم يتم حلّه ودياً خلال 30 يوماً من التواصل الأول مع خدمة العملاء، يحال إلى الاختصاص الحصري لمحاكم القاهرة المختصة.',
      'يجوز للطرفين الاتفاق كتابياً على اللجوء للتحكيم بدلاً من القضاء.',
      'لا يُعدّ التوجه للمحاكم تنازلاً عن أي حقوق أخرى منصوص عليها في هذه الشروط.',
    ],
    itemsEn: [
      'These Terms are governed by and construed in accordance with the laws of the Arab Republic of Egypt.',
      'Any dispute not amicably resolved within 30 days of the first contact with customer service shall be submitted to the exclusive jurisdiction of the competent courts of Cairo.',
      'The parties may agree in writing to arbitration instead of litigation.',
      'Recourse to the courts does not waive any other rights provided under these Terms.',
    ],
  ),

  // ──────────────────────── 21. Arbitration ────────────────────────
  _Section(
    numAr: '٢١', numEn: '21',
    titleAr: 'التحكيم الاختياري',
    titleEn: 'Optional Arbitration',
    itemsAr: [
      'يحق للمنصة — بناءً على تقديرها وباتفاق مكتوب — إحالة أي نزاع إلى التحكيم أمام مركز القاهرة الإقليمي للتحكيم التجاري الدولي (CRCICA) وفق قواعده السارية.',
      'يكون التحكيم بمحكم فرد، ولغة الإجراءات العربية ومقرّها القاهرة.',
      'قرار التحكيم ملزم ونهائي للطرفين ولا يقبل الطعن إلا وفق القانون.',
      'إلى أقصى حد يسمح به القانون، يتنازل الطرفان عن الحق في الانضمام لأي دعوى جماعية أو تمثيلية.',
    ],
    itemsEn: [
      'The Platform may, at its discretion and by written agreement, refer any dispute to arbitration before the Cairo Regional Centre for International Commercial Arbitration (CRCICA) under its rules in force.',
      'The arbitration shall be conducted by a sole arbitrator, in Arabic, seated in Cairo.',
      'The arbitral award is binding and final on both parties and may only be challenged as provided by law.',
      'To the maximum extent permitted by law, the parties waive any right to join any class or representative action.',
    ],
  ),

  // ──────────────────────── 22. Privacy (Egyptian Law 151/2020) ────
  _Section(
    numAr: '٢٢', numEn: '22',
    titleAr: 'الخصوصية وحماية البيانات — قانون 151 لسنة 2020',
    titleEn: 'Privacy & Data Protection — Egyptian Law 151/2020',
    itemsAr: [
      'نجمع بياناتك الشخصية ونعالجها وفقاً لقانون حماية البيانات الشخصية المصري رقم 151 لسنة 2020.',
      'فئات البيانات: الهوية (الاسم، الرقم القومي، الهاتف، البريد)، سجل الحجوزات، رموز الدفع (لا نخزّن بيانات البطاقة الكاملة)، الموقع التقريبي، بيانات الجهاز، والمحادثات.',
      'أغراض المعالجة: إدارة الحساب، تنفيذ الحجوزات، منع الاحتيال، التحليلات الإحصائية، الدعم الفني، والامتثال القانوني.',
      'الأسس القانونية: تنفيذ العقد، الموافقة، الالتزام القانوني، والمصلحة المشروعة.',
      'المشاركة: بوابات الدفع (مثل Paymob)، خدمات الاستضافة السحابية، مزودو التحليلات، والجهات الرسمية بناءً على طلب قانوني. لا نبيع بياناتك أبداً.',
      'مدة الاحتفاظ: ما دام الحساب نشطاً، زائد 5 سنوات للسجلات المالية والقانونية وفق القانون المصري.',
      'حقوقك: الوصول، التصحيح، الحذف، النقل، الاعتراض، سحب الموافقة. أرسل طلبك إلى: privacy@talaa.app.',
      'قد نسجّل المحادثات داخل التطبيق لأغراض السلامة وحل النزاعات.',
      'جميع بيانات الدفع مُشفّرة طبقاً لمعايير PCI-DSS.',
    ],
    itemsEn: [
      'We collect and process your personal data in accordance with Egyptian Personal Data Protection Law No. 151/2020.',
      'Data categories: identity (name, national ID, phone, email), booking history, payment tokens (full card data is not stored), approximate location, device info, and messages.',
      'Processing purposes: account management, booking fulfilment, fraud prevention, analytics, support and legal compliance.',
      'Legal bases: contract performance, consent, legal obligation, and legitimate interest.',
      'Sharing: payment processors (e.g. Paymob), cloud-hosting providers, analytics vendors, and authorities upon lawful request. We never sell your data.',
      'Retention: for as long as your account is active, plus 5 years for financial/legal records as required by Egyptian law.',
      'Your rights: access, rectification, deletion, portability, objection, withdrawal of consent. Send requests to: privacy@talaa.app.',
      'We may record in-app conversations for safety and dispute-resolution purposes.',
      'All payment data is encrypted to PCI-DSS standards.',
    ],
  ),

  // ──────────────────────── 23. Intellectual Property ──────────────
  _Section(
    numAr: '٢٣', numEn: '23',
    titleAr: 'الملكية الفكرية',
    titleEn: 'Intellectual Property',
    itemsAr: [
      'جميع حقوق الملكية الفكرية للمنصة (الاسم، الشعار، البرمجيات، التصميم، قواعد البيانات) ملك Talaa Trip.',
      'يُحظر النسخ، الهندسة العكسية، أو إنشاء أعمال مشتقة، أو الاستخدام التجاري دون إذن كتابي مسبق.',
      'أي علامات تجارية أو شعارات لأطراف ثالثة تظهر في المنصة هي ملك لأصحابها وتُستخدم بإذنهم.',
      'الإخلال بحقوق الملكية الفكرية يُعرّضك للملاحقة القانونية وفق القانون المصري والاتفاقيات الدولية.',
    ],
    itemsEn: [
      'All intellectual-property rights in the Platform (name, logo, software, design, databases) belong to Talaa Trip.',
      'Copying, reverse-engineering, creating derivative works, or commercial use without prior written permission is prohibited.',
      'Any third-party trademarks or logos displayed on the Platform remain the property of their owners and are used with permission.',
      'Breach of IP rights will expose you to legal action under Egyptian law and international conventions.',
    ],
  ),

  // ──────────────────────── 24. Amendments ─────────────────────────
  _Section(
    numAr: '٢٤', numEn: '24',
    titleAr: 'تعديل السياسة',
    titleEn: 'Amendments',
    itemsAr: [
      'يحق للمنصة تعديل هذه الشروط في أي وقت لمواءمة متطلبات التشغيل أو القانون.',
      'التعديلات الجوهرية يتم الإخطار بها داخل التطبيق قبل 30 يوماً من سريانها.',
      'استمرار الاستخدام بعد مرور 30 يوماً من الإخطار يُعدّ قبولاً ضمنياً للتعديلات.',
      'في حال رفض التعديلات، يجب عليك التوقف عن الاستخدام وحذف الحساب.',
    ],
    itemsEn: [
      'The Platform may amend these Terms at any time to align with operational or legal requirements.',
      'Material changes will be announced in-app at least 30 days before they take effect.',
      'Continued use beyond 30 days after notice constitutes implied acceptance of the changes.',
      'If you reject the changes, you must stop using the Platform and delete your account.',
    ],
  ),

  // ──────────────────────── 25. General Provisions ─────────────────
  _Section(
    numAr: '٢٥', numEn: '25',
    titleAr: 'أحكام عامة',
    titleEn: 'General Provisions',
    itemsAr: [
      'قابلية الفصل: إذا اعتُبر أي بند باطلاً، تظل باقي البنود سارية وقابلة للتنفيذ.',
      'عدم التنازل: عدم ممارسة المنصة لأي حق لا يُعدّ تنازلاً عنه.',
      'الاتفاق الكامل: هذه الشروط + سياسة الخصوصية + السياسات الفرعية تمثّل الاتفاق الكامل بين الطرفين.',
      'الحوالة: لا يحق لك نقل حقوقك أو التزاماتك للغير دون موافقة كتابية من المنصة، ويحق للمنصة نقل حقوقها في حالات الاندماج أو الاستحواذ.',
      'اللغة: في حال وجود تعارض بين النسخة العربية والإنجليزية، تسود النسخة العربية داخل مصر.',
      'الإخطارات: نتواصل معك عبر البريد الإلكتروني أو الهاتف المسجَّلين في الحساب أو عبر الإشعارات داخل التطبيق.',
      'التواصل: support@talaa.app للدعم الفني، privacy@talaa.app للخصوصية، legal@talaa.app للمسائل القانونية.',
    ],
    itemsEn: [
      'Severability: if any provision is held invalid, the remaining provisions stay in full force and effect.',
      'No Waiver: failure to exercise any right does not constitute a waiver of that right.',
      'Entire Agreement: these Terms, the Privacy Policy and any sub-policies constitute the entire agreement between the parties.',
      'Assignment: you may not assign your rights or obligations without the Platform\'s written consent; the Platform may assign its rights in connection with a merger or acquisition.',
      'Language: in the event of conflict between the Arabic and English versions, the Arabic version prevails within Egypt.',
      'Notices: we contact you via the email or phone registered in the account or via in-app notifications.',
      'Contact: support@talaa.app for support, privacy@talaa.app for privacy, legal@talaa.app for legal matters.',
    ],
  ),
];
