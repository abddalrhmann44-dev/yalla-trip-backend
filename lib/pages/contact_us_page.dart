// ═══════════════════════════════════════════════════════════════
//  TALAA — Contact Us
//
//  Dedicated contact page surfaced from the profile menu so the
//  user does not have to scroll to the bottom of the Terms page
//  to find support details.  Exposes:
//    • Email   — mailto: deep-link
//    • WhatsApp — wa.me deep-link
//    • Phone   — tel: deep-link to the same support number
//    • Address — Cairo, Egypt
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../main.dart' show appSettings;
import '../utils/brand_contact.dart';
import '../widgets/constants.dart';
import '../widgets/policy_page_scaffold.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PolicyPageScaffold(
      titleAr: 'تواصل معنا',
      titleEn: 'Contact Us',
      subtitleAr: 'فريق الدعم متواجد لمساعدتك',
      subtitleEn: 'Our support team is here to help',
      icon: Icons.support_agent_rounded,
      // The page itself surfaces the contact info as primary
      // content, so we suppress the duplicate footer the scaffold
      // would normally render.
      showContactFooter: false,
      headerExtras: [
        _IntroCard(),
        const SizedBox(height: 18),
        _ContactCard(
          icon: Icons.alternate_email_rounded,
          titleAr: 'البريد الإلكتروني',
          titleEn: 'Email',
          value: BrandContact.email,
          ctaAr: 'إرسال رسالة',
          ctaEn: 'Send email',
          onTap: () =>
              BrandContact.openExternal(BrandContact.mailtoUrl),
        ),
        const SizedBox(height: 12),
        _ContactCard(
          icon: Icons.chat_rounded,
          titleAr: 'واتساب',
          titleEn: 'WhatsApp',
          value: BrandContact.phoneDisplay,
          ctaAr: 'فتح واتساب',
          ctaEn: 'Open WhatsApp',
          onTap: () =>
              BrandContact.openExternal(BrandContact.whatsappUrl),
        ),
        const SizedBox(height: 12),
        _ContactCard(
          icon: Icons.phone_rounded,
          titleAr: 'اتصال هاتفي',
          titleEn: 'Phone Call',
          value: BrandContact.phoneDisplay,
          ctaAr: 'اتصل الآن',
          ctaEn: 'Call now',
          onTap: () => BrandContact.openExternal(BrandContact.telUrl),
        ),
        const SizedBox(height: 12),
        _AddressCard(),
        const SizedBox(height: 18),
        _HoursCard(),
        const SizedBox(height: 16),
      ],
      sections: const [
        // FAQ-style guidance so the user knows what to expect.
        PolicySection(
          numAr: '١', numEn: '1',
          titleAr: 'أوقات الرد',
          titleEn: 'Response Times',
          itemsAr: [
            'واتساب: نرد عادةً خلال 30 دقيقة في ساعات العمل.',
            'البريد الإلكتروني: نرد خلال 24 ساعة كحد أقصى أيام العمل.',
            'الحالات الطارئة (مشاكل أثناء الإقامة): الأولوية القصوى ونتعامل معها فوراً.',
          ],
          itemsEn: [
            'WhatsApp: typically replies within 30 minutes during business hours.',
            'Email: replies within 24 hours on business days at most.',
            'Urgent issues (during your stay): highest priority, handled immediately.',
          ],
        ),
        PolicySection(
          numAr: '٢', numEn: '2',
          titleAr: 'قبل التواصل',
          titleEn: 'Before You Reach Out',
          itemsAr: [
            'تأكَّد من رقم الحجز إذا كانت رسالتك تخص حجزاً قائماً.',
            'أرفق صور للمشكلة إن أمكن (للحجز أو العقار).',
            'راجع سياسة الإلغاء قبل طلب الاسترداد.',
          ],
          itemsEn: [
            'Have your booking number ready if your message is about a current booking.',
            'Attach photos of the issue when possible (for the booking or property).',
            'Review the Cancellation Policy before requesting a refund.',
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Header extras
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
                ? 'فريق دعم Talaa Trip متاح للرد على كل استفسار يخص حجوزاتك، '
                    'دفعاتك، أو أي سؤال عن المنصة. اختر القناة المناسبة لك '
                    'من الخيارات أدناه — كلها تصل لنفس الفريق وكلها بنفس '
                    'سرعة الاستجابة.'
                : 'The Talaa Trip support team is here to answer any question '
                    'about your bookings, payments, or the platform itself. '
                    'Pick whichever channel suits you below — all of them '
                    'reach the same team with the same response speed.',
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

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String titleAr;
  final String titleEn;
  final String value;
  final String ctaAr;
  final String ctaEn;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.titleAr,
    required this.titleEn,
    required this.value,
    required this.ctaAr,
    required this.ctaEn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (_, __) {
        final ar = appSettings.arabic;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.kCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.kBorder),
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kPolicyBrand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(icon, color: kPolicyBrand, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          ar ? titleAr : titleEn,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: context.kText)),
                      const SizedBox(height: 2),
                      Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: kPolicyBrand)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPolicyBrand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(ar ? ctaAr : ctaEn,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _AddressCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (_, __) {
        final ar = appSettings.arabic;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.kBorder),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kPolicyBrand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: kPolicyBrand, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ar ? 'العنوان' : 'Address',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: context.kText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ar ? 'القاهرة، مصر' : 'Cairo, Egypt',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kPolicyBrand),
                  ),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _HoursCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (_, __) {
        final ar = appSettings.arabic;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kPolicyBrand.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: kPolicyBrand.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.schedule_rounded,
                    color: kPolicyBrand, size: 18),
                const SizedBox(width: 8),
                Text(
                  ar ? 'ساعات العمل' : 'Business Hours',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: context.kText),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                ar
                    ? 'الأحد – الخميس: 9:00 صباحاً – 9:00 مساءً (بتوقيت القاهرة).\n'
                        'الجمعة والسبت: 10:00 صباحاً – 6:00 مساءً.\n'
                        'الحالات الطارئة: ندعمك على مدار 24 ساعة.'
                    : 'Sunday – Thursday: 9:00 AM – 9:00 PM (Cairo time).\n'
                        'Friday & Saturday: 10:00 AM – 6:00 PM.\n'
                        'Urgent cases: 24/7 support.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: context.kSub,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}
