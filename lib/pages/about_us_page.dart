// ═══════════════════════════════════════════════════════════════
//  TALAA — About Us
//
//  Brand storytelling page: who we are, what we do, our mission &
//  vision, and the values that drive Talaa Trip.  Bilingual (AR
//  primary, EN mirror) and styled to match Terms / Privacy /
//  Refund pages so the legal+info bundle feels cohesive.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../main.dart' show appSettings;
import '../widgets/constants.dart';
import '../widgets/policy_page_scaffold.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PolicyPageScaffold(
      titleAr: 'من نحن',
      titleEn: 'About Us',
      subtitleAr: 'منصة مصرية للإجارات السياحية قصيرة الأجل',
      subtitleEn: 'Egypt\'s short-stay rental marketplace',
      icon: Icons.beach_access_rounded,
      headerExtras: [
        _IntroCard(),
        const SizedBox(height: 16),
        _StatsCard(),
        const SizedBox(height: 16),
      ],
      sections: _sections,
    );
  }
}

const _sections = <PolicySection>[
  // 1. Mission ───────────────────────────────────────────────
  PolicySection(
    numAr: '١', numEn: '1',
    titleAr: 'رسالتنا',
    titleEn: 'Our Mission',
    itemsAr: [
      'نُسهّل تأجير الشاليهات والفلل واليخوت في مصر بطريقة آمنة وشفافة.',
      'نمنح الضيوف ثقة في كل حجز عبر التحقق من الهوية، الدفع الآمن، والمراجعات الموثَّقة.',
      'نمنح المُلّاك أداة احترافية لإدارة عقاراتهم وزيادة دخلهم بدون تعقيدات.',
      'نهدف إلى رفع جودة السياحة الداخلية المصرية ودعم الاقتصاد المحلي في مناطق الساحل والبحر الأحمر.',
    ],
    itemsEn: [
      'We make renting chalets, villas and yachts in Egypt safe, simple and transparent.',
      'We give guests confidence in every booking through identity verification, secure payments and verified reviews.',
      'We give hosts a professional tool to manage their properties and grow their income — hassle-free.',
      'Our goal is to elevate Egyptian domestic tourism and empower local economies along the North Coast and Red Sea.',
    ],
  ),

  // 2. Vision ────────────────────────────────────────────────
  PolicySection(
    numAr: '٢', numEn: '2',
    titleAr: 'رؤيتنا',
    titleEn: 'Our Vision',
    itemsAr: [
      'أن نكون المنصة الأولى في مصر والشرق الأوسط للإجارات السياحية قصيرة الأجل.',
      'أن نخلق سوقاً منظَّماً يُعتمد عليه يخدم الملايين من الضيوف وآلاف المُلّاك سنوياً.',
      'أن نُعيد تعريف تجربة الإجازة العائلية في مصر — من اللحظة التي تبحث فيها عن مكان حتى لحظة عودتك للبيت.',
    ],
    itemsEn: [
      'To be the leading short-stay rental marketplace in Egypt and the Middle East.',
      'To build a trusted, organized marketplace serving millions of guests and thousands of hosts every year.',
      'To redefine the family-vacation experience in Egypt — from the moment you start searching to the moment you return home.',
    ],
  ),

  // 3. What we do ────────────────────────────────────────────
  PolicySection(
    numAr: '٣', numEn: '3',
    titleAr: 'ماذا نقدّم',
    titleEn: 'What We Offer',
    itemsAr: [
      'استكشاف ذكي: ابحث وفلتر العقارات حسب المنطقة، السعر، عدد الغرف، والمرافق.',
      'تفاوض مباشر: تواصل مع المالك داخل التطبيق وتفاوض على السعر بطريقة منظَّمة.',
      'دفع آمن: ادفع جزء من السعر كمقدّم وادفع الباقي عند الوصول، أو ادفع بالكامل بأمان عبر بوابات معتمدة.',
      'محفظة داخلية: احصل على مكافآت عند كل حجز واستخدمها لخصومات على حجوزاتك القادمة.',
      'دعم على مدار الساعة: فريقنا متاح للرد على استفساراتك قبل وأثناء وبعد الإقامة.',
      'حماية الضيف والمالك: نظام تقييم ثنائي وسياسة استرداد واضحة تحمي الطرفين.',
    ],
    itemsEn: [
      'Smart discovery: search and filter properties by area, price, room count, and amenities.',
      'Direct negotiation: chat with the host inside the app and negotiate the price in a structured way.',
      'Secure payments: pay a deposit and the rest on arrival, or pay in full via certified gateways.',
      'In-app wallet: earn rewards on every booking and apply them as discounts on future trips.',
      '24/7 support: our team is available before, during and after your stay.',
      'Guest & host protection: two-way reviews and a clear refund policy that safeguard both parties.',
    ],
  ),

  // 4. Values ────────────────────────────────────────────────
  PolicySection(
    numAr: '٤', numEn: '4',
    titleAr: 'قيمنا',
    titleEn: 'Our Values',
    itemsAr: [
      'الشفافية: لا رسوم خفية، السعر اللي تشوفه هو السعر اللي تدفعه.',
      'الأمان: التحقق من هوية كل مستخدم وتشفير كامل لبياناتك.',
      'الاحترام: مجتمع متنوع نرفض فيه أي شكل من أشكال التمييز.',
      'الجودة: نراجع كل العقارات قبل النشر ونتعامل بسرعة مع أي شكوى.',
      'الابتكار: نطوّر التطبيق باستمرار بناءً على ملاحظاتكم.',
    ],
    itemsEn: [
      'Transparency: no hidden fees — the price you see is the price you pay.',
      'Safety: identity-verified users and end-to-end data encryption.',
      'Respect: a diverse community where any form of discrimination is rejected.',
      'Quality: every listing is reviewed before going live and complaints are handled quickly.',
      'Innovation: we continuously evolve the app based on your feedback.',
    ],
  ),

  // 5. Story ─────────────────────────────────────────────────
  PolicySection(
    numAr: '٥', numEn: '5',
    titleAr: 'قصتنا',
    titleEn: 'Our Story',
    itemsAr: [
      'بدأت Talaa Trip من فكرة بسيطة: لازم يكون فيه طريقة أسهل لحجز الشاليهات والفلل في مصر.',
      'لاحظنا إن الناس بتعتمد على مجموعات Facebook ومحادثات WhatsApp غير منظَّمة — بدون أمان أو ضمان.',
      'فأنشأنا منصة تجمع كل ده في تجربة واحدة: بحث ذكي، تواصل مباشر، دفع آمن، ودعم حقيقي.',
      'اليوم Talaa Trip منصة مصرية بهدف عربي، نخدم العائلات والمسافرين ونساعد المُلّاك على بناء أعمالهم.',
    ],
    itemsEn: [
      'Talaa Trip started from a simple idea: there has to be an easier way to book chalets and villas in Egypt.',
      'We saw people relying on disorganized Facebook groups and WhatsApp chats — with no safety or guarantees.',
      'So we built a platform that brings it all together: smart search, direct chat, secure payments, and real support.',
      'Today Talaa Trip is an Egyptian platform with a regional ambition, serving families and travellers and helping hosts grow their business.',
    ],
  ),
];

// ═══════════════════════════════════════════════════════════════
//  Header extras: intro paragraph + stats card
// ═══════════════════════════════════════════════════════════════

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (_, __) {
        final ar = appSettings.arabic;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.kBorder),
          ),
          child: Text(
            ar
                ? 'Talaa Trip منصة مصرية بتربط بين المسافرين ومُلّاك الشاليهات والفلل واليخوت في مختلف أنحاء مصر — '
                    'الساحل الشمالي، رأس سدر، العين السخنة، الغردقة، شرم الشيخ والمزيد. '
                    'نُقدِّم تجربة حجز سريعة، آمنة، وشفافة لكل العائلات المصرية والعربية.'
                : 'Talaa Trip is an Egyptian marketplace connecting travellers with chalet, villa and yacht hosts '
                    'across Egypt — North Coast, Ras Sudr, Ain Sokhna, Hurghada, Sharm El-Sheikh and more. '
                    'We deliver a fast, safe and transparent booking experience for Egyptian and Arab families.',
            style: TextStyle(
                fontSize: 13,
                height: 1.85,
                color: context.kSub,
                fontWeight: FontWeight.w500),
          ),
        );
      },
    );
  }
}

class _StatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (_, __) {
        final ar = appSettings.arabic;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: kPolicyBrand.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: kPolicyBrand.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat(context,
                  ar ? 'الساحل الشمالي' : 'North Coast', '✦',
                  ar ? 'وأكثر' : '& more'),
              _divider(context),
              _stat(context, ar ? 'دفع آمن' : 'Secure Pay', '🔒',
                  ar ? 'PCI-DSS' : 'PCI-DSS'),
              _divider(context),
              _stat(context, ar ? 'دعم 24/7' : '24/7 Support', '💬',
                  ar ? 'واتساب' : 'WhatsApp'),
            ],
          ),
        );
      },
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 32,
        color: context.kBorder,
      );

  Widget _stat(BuildContext context, String label, String emoji,
      String sub) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        const SizedBox(height: 2),
        Text(sub,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: context.kSub)),
      ],
    );
  }
}
