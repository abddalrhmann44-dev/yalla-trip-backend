// ═══════════════════════════════════════════════════════════════
//  TALAA — Privacy Policy (standalone)
//
//  Mirrors Section 22 of `terms_page.dart` (Egyptian Personal Data
//  Protection Law 151/2020) plus a few extra clarifying bullets so
//  the page can stand on its own when linked from the App Store /
//  Play Store / website footer.  The wording is consistent with
//  the unified Terms document.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../widgets/policy_page_scaffold.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyPageScaffold(
      titleAr: 'سياسة الخصوصية',
      titleEn: 'Privacy Policy',
      subtitleAr: 'حماية بياناتك الشخصية وفق القانون المصري 151/2020',
      subtitleEn: 'Your data, protected under Egyptian Law 151/2020',
      icon: Icons.shield_rounded,
      lastUpdatedAr: 'آخر تحديث: مايو 2026',
      lastUpdatedEn: 'Last updated: May 2026',
      sections: _sections,
    );
  }
}

const _sections = <PolicySection>[
  // 1. Scope ─────────────────────────────────────────────────
  PolicySection(
    numAr: '١', numEn: '1',
    titleAr: 'نطاق هذه السياسة',
    titleEn: 'Scope of this Policy',
    itemsAr: [
      'تشرح هذه السياسة كيف تجمع منصة Talaa Trip ("المنصة" / "نحن") بياناتك الشخصية وتستخدمها وتحميها.',
      'تنطبق على كل المستخدمين: الضيوف، مُلّاك العقارات، الزوار، وأي طرف يستخدم تطبيقاتنا أو موقعنا.',
      'هذه السياسة جزء لا يتجزأ من شروط الاستخدام، وقبولك لشروط الاستخدام يُعدّ قبولاً لهذه السياسة.',
      'نلتزم بقانون حماية البيانات الشخصية المصري رقم 151 لسنة 2020 ولوائحه التنفيذية.',
    ],
    itemsEn: [
      'This Policy explains how Talaa Trip ("Platform" / "we") collects, uses and protects your personal data.',
      'It applies to all users: guests, property owners, visitors and anyone using our apps or website.',
      'This Policy forms an integral part of our Terms of Service; accepting the Terms constitutes acceptance of this Policy.',
      'We comply with Egyptian Personal Data Protection Law No. 151 of 2020 and its executive regulations.',
    ],
  ),

  // 2. Categories ────────────────────────────────────────────
  PolicySection(
    numAr: '٢', numEn: '2',
    titleAr: 'فئات البيانات التي نجمعها',
    titleEn: 'Categories of Data We Collect',
    itemsAr: [
      'بيانات الهوية: الاسم الكامل، الرقم القومي / جواز السفر، تاريخ الميلاد.',
      'بيانات التواصل: رقم الهاتف، البريد الإلكتروني، عنوان المراسلة.',
      'بيانات الحساب: اسم المستخدم، كلمة السر المُجزّأة (hashed)، صور الملف الشخصي.',
      'بيانات الحجوزات والمدفوعات: سجل الحجوزات، رموز الدفع (لا نخزّن بيانات البطاقة الكاملة)، الفواتير.',
      'بيانات الاستخدام: نوع الجهاز، نظام التشغيل، عنوان IP، الصفحات التي تزورها، أوقات الاستخدام.',
      'الموقع: موقع تقريبي مبني على عنوان IP، ولا نتتبع الموقع الدقيق إلا بإذنك الصريح.',
      'المحادثات: رسائل التفاوض مع الطرف الآخر (ضيف ↔ مالك) داخل التطبيق.',
      'بيانات التسويق: تفضيلاتك بخصوص رسائل البريد والإشعارات.',
    ],
    itemsEn: [
      'Identity: full name, national ID / passport, date of birth.',
      'Contact: phone number, email address, mailing address.',
      'Account: username, hashed password, profile photos.',
      'Bookings & payments: booking history, payment tokens (full card data is not stored), invoices.',
      'Usage: device type, OS, IP address, pages visited, session times.',
      'Location: approximate (IP-based); precise location is only used with your explicit permission.',
      'Conversations: in-app negotiation messages between guest ↔ owner.',
      'Marketing: your preferences regarding promotional emails and notifications.',
    ],
  ),

  // 3. Purposes ──────────────────────────────────────────────
  PolicySection(
    numAr: '٣', numEn: '3',
    titleAr: 'أغراض المعالجة والأساس القانوني',
    titleEn: 'Processing Purposes & Legal Basis',
    itemsAr: [
      'إنشاء وإدارة حسابك (الأساس: تنفيذ العقد).',
      'تنفيذ الحجوزات وتحويل المدفوعات (الأساس: تنفيذ العقد).',
      'منع الاحتيال والتحقق من الهوية (الأساس: المصلحة المشروعة + الالتزام القانوني).',
      'الدعم الفني والرد على استفساراتك (الأساس: تنفيذ العقد).',
      'تحسين الخدمة عن طريق التحليلات الإحصائية المجمّعة (الأساس: المصلحة المشروعة).',
      'إرسال إشعارات عملية (تأكيدات، تذكيرات حجز) — لا تتطلب موافقة منفصلة.',
      'إرسال عروض تسويقية — يتطلب موافقتك الصريحة، ويمكنك سحبها في أي وقت.',
      'الامتثال للالتزامات القانونية والضريبية (الأساس: الالتزام القانوني).',
    ],
    itemsEn: [
      'Creating and managing your account (basis: contract performance).',
      'Fulfilling bookings and processing payments (basis: contract performance).',
      'Fraud prevention and identity verification (basis: legitimate interest + legal obligation).',
      'Customer support and responding to your queries (basis: contract performance).',
      'Improving the service via aggregated analytics (basis: legitimate interest).',
      'Operational notifications (booking confirmations, reminders) — no separate consent required.',
      'Marketing communications — only with your explicit consent, withdrawable at any time.',
      'Compliance with legal and tax obligations (basis: legal obligation).',
    ],
  ),

  // 4. Sharing ───────────────────────────────────────────────
  PolicySection(
    numAr: '٤', numEn: '4',
    titleAr: 'مشاركة البيانات مع أطراف ثالثة',
    titleEn: 'Sharing With Third Parties',
    itemsAr: [
      'لا نبيع بياناتك الشخصية أبداً لأي طرف ثالث.',
      'بوابات الدفع (مثل Paymob / Fawry) — للقدر اللازم لتنفيذ المعاملة.',
      'مزودو الاستضافة السحابية (Railway / AWS / Google Cloud) — لتشغيل الخوادم وقواعد البيانات.',
      'مزودو خدمات SMS و WhatsApp — لإرسال أكواد التحقق والإشعارات.',
      'مزودو التحليلات (Firebase Analytics / Sentry) — بيانات مجمّعة بدون معرفات شخصية.',
      'الجهات الحكومية والقضائية — فقط بناءً على طلب قانوني رسمي.',
      'المُشتري في حال الاستحواذ أو الاندماج — بشرط التزام المُشتري بنفس مستوى الحماية.',
    ],
    itemsEn: [
      'We never sell your personal data to any third party.',
      'Payment processors (e.g. Paymob / Fawry) — only as needed to complete the transaction.',
      'Cloud providers (Railway / AWS / Google Cloud) — to run servers and databases.',
      'SMS & WhatsApp providers — to deliver verification codes and notifications.',
      'Analytics providers (Firebase Analytics / Sentry) — aggregated data without personal identifiers.',
      'Government and judicial bodies — only upon formal lawful request.',
      'Acquirer in case of merger or acquisition — subject to equivalent protection commitments.',
    ],
  ),

  // 5. Retention ─────────────────────────────────────────────
  PolicySection(
    numAr: '٥', numEn: '5',
    titleAr: 'مدة الاحتفاظ بالبيانات',
    titleEn: 'Data Retention',
    itemsAr: [
      'بيانات الحساب النشط: ما دام الحساب مفتوحاً.',
      'سجلات الحجوزات والفواتير: لمدة 5 سنوات بعد إغلاق الحساب وفقاً للقانون التجاري والضريبي المصري.',
      'سجلات الاحتيال أو الإساءة: حتى 7 سنوات لحماية باقي المستخدمين.',
      'بيانات التسويق: حتى تسحب موافقتك أو تطلب الحذف.',
      'النسخ الاحتياطية: حتى 90 يوماً قبل أن يُمحى السجل بالكامل من النسخ التشغيلية والاحتياطية.',
    ],
    itemsEn: [
      'Active account data: as long as the account is open.',
      'Booking and invoice records: up to 5 years after account closure per Egyptian commercial and tax law.',
      'Fraud / abuse records: up to 7 years to protect other users.',
      'Marketing data: until you withdraw consent or request deletion.',
      'Backups: up to 90 days before a record is fully purged from operational and backup copies.',
    ],
  ),

  // 6. Your Rights ───────────────────────────────────────────
  PolicySection(
    numAr: '٦', numEn: '6',
    titleAr: 'حقوقك بصفتك صاحب البيانات',
    titleEn: 'Your Rights as a Data Subject',
    itemsAr: [
      'الوصول: الحصول على نسخة من بياناتك المخزّنة لدينا.',
      'التصحيح: تعديل أي بيانات غير دقيقة أو ناقصة.',
      'الحذف: طلب حذف حسابك وكل بياناتك (يُستثنى ما يُلزمنا القانون بالاحتفاظ به).',
      'النقل: استلام بياناتك بصيغة قابلة للقراءة آلياً (JSON).',
      'الاعتراض: رفض المعالجة لأغراض التسويق أو التحليلات.',
      'سحب الموافقة: في أي وقت ودون أن يؤثر ذلك على شرعية المعالجة السابقة.',
      'تقديم شكوى: للمركز الوطني المصري لحماية البيانات الشخصية.',
      'لتنفيذ أي حق من هذه الحقوق، أرسل طلباً إلى support@talaa-trip.com — نرد خلال 30 يوماً كحد أقصى.',
    ],
    itemsEn: [
      'Access: receive a copy of the data we hold about you.',
      'Rectification: correct any inaccurate or incomplete data.',
      'Erasure: request deletion of your account and data (subject to legal retention requirements).',
      'Portability: receive your data in a machine-readable format (JSON).',
      'Objection: refuse processing for marketing or analytics purposes.',
      'Withdraw consent: at any time, without affecting the legality of prior processing.',
      'File a complaint: with the Egyptian Personal Data Protection Centre.',
      'To exercise any of these rights, send a request to support@talaa-trip.com — we respond within 30 days maximum.',
    ],
  ),

  // 7. Security ──────────────────────────────────────────────
  PolicySection(
    numAr: '٧', numEn: '7',
    titleAr: 'الأمن وحماية البيانات',
    titleEn: 'Security & Data Protection',
    itemsAr: [
      'كل البيانات مشفّرة في النقل (TLS 1.2+) وفي التخزين (AES-256).',
      'كلمات السر مُجزّأة (bcrypt) ولا تُخزَّن أبداً بشكل صريح.',
      'بيانات الدفع تُمرَّر مباشرة لبوابات الدفع المعتمدة وفق معيار PCI-DSS.',
      'صلاحية الوصول للبيانات داخل فريقنا محدودة بحسب الدور (RBAC) وتُسجَّل كل المحاولات.',
      'في حال أي اختراق يهدد بياناتك، نُخطر السلطات المختصة خلال 72 ساعة ونُخطركم بأقرب وقت ممكن.',
    ],
    itemsEn: [
      'All data is encrypted in transit (TLS 1.2+) and at rest (AES-256).',
      'Passwords are hashed (bcrypt) and never stored in plain text.',
      'Payment data is passed directly to certified PCI-DSS gateways.',
      'Internal access is role-based (RBAC) and every attempt is logged.',
      'In case of a breach affecting your data, we notify the competent authority within 72 hours and you as soon as practicable.',
    ],
  ),

  // 8. Children ──────────────────────────────────────────────
  PolicySection(
    numAr: '٨', numEn: '8',
    titleAr: 'استخدام القاصرين',
    titleEn: 'Use by Minors',
    itemsAr: [
      'الخدمة موجّهة لمن أتمّوا سن 18 عاماً فقط.',
      'لا نجمع عمداً بيانات من أي شخص تحت سن 18 عاماً.',
      'إذا اكتشفنا أو أبلغنا أن قاصراً يستخدم الخدمة، نحذف حسابه فوراً.',
    ],
    itemsEn: [
      'The service is intended only for users aged 18+.',
      'We do not knowingly collect data from anyone under 18.',
      'If we discover or are informed that a minor is using the service, we immediately delete their account.',
    ],
  ),

  // 9. Cookies ───────────────────────────────────────────────
  PolicySection(
    numAr: '٩', numEn: '9',
    titleAr: 'ملفات الارتباط (Cookies) والتقنيات المماثلة',
    titleEn: 'Cookies & Similar Technologies',
    itemsAr: [
      'نستخدم ملفات ارتباط ضرورية لتسجيل الدخول وتذكر تفضيلاتك (لا تتطلب موافقة).',
      'نستخدم ملفات ارتباط تحليلية لقياس الأداء (تتطلب موافقتك على الويب).',
      'يمكنك إدارة ملفات الارتباط من إعدادات المتصفح، وتعطيلها قد يحدّ من بعض المزايا.',
      'لا نستخدم ملفات ارتباط إعلانية لأطراف ثالثة في التطبيق.',
    ],
    itemsEn: [
      'We use strictly necessary cookies for login and preferences (no consent required).',
      'We use analytics cookies to measure performance (consent required on web).',
      'You can manage cookies from your browser settings; disabling them may limit some features.',
      'We do not use third-party advertising cookies inside the app.',
    ],
  ),

  // 10. Updates ──────────────────────────────────────────────
  PolicySection(
    numAr: '١٠', numEn: '10',
    titleAr: 'التعديلات على هذه السياسة',
    titleEn: 'Changes to this Policy',
    itemsAr: [
      'قد نُحدّث هذه السياسة دورياً لمواكبة التغييرات القانونية أو التشغيلية.',
      'التعديلات الجوهرية تُعلَن داخل التطبيق قبل 30 يوماً على الأقل من سريانها.',
      'تاريخ آخر تحديث ظاهر في رأس هذه الصفحة دائماً.',
      'استمرارك في استخدام الخدمة بعد سريان التعديلات يُعدّ قبولاً لها.',
    ],
    itemsEn: [
      'We may update this Policy from time to time to reflect legal or operational changes.',
      'Material changes are announced in-app at least 30 days before they take effect.',
      'The "Last updated" date at the top of this page always reflects the latest revision.',
      'Continued use of the service after the changes take effect constitutes acceptance.',
    ],
  ),
];
