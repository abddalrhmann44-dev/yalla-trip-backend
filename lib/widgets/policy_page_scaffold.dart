// ═══════════════════════════════════════════════════════════════
//  TALAA — Policy / Info Page Scaffold
//
//  Shared visual frame for the legal & informational pages
//  (Terms, Privacy, Refund, About, Contact).  Keeps the brand
//  header gradient, section cards and contact footer consistent
//  across all of them so the UX feels like one cohesive set.
//
//  Uses `appSettings` so toggling AR/EN refreshes the page
//  without having to reopen it.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../main.dart' show appSettings;
import '../utils/brand_contact.dart';
import 'constants.dart';

const Color kPolicyBrand = Color(0xFFFF6B35);
const Color kPolicyBrandDark = Color(0xFFE85A24);

/// One bullet section in a policy page.
class PolicySection {
  final String numAr;
  final String numEn;
  final String titleAr;
  final String titleEn;
  final List<String> itemsAr;
  final List<String> itemsEn;

  const PolicySection({
    required this.numAr,
    required this.numEn,
    required this.titleAr,
    required this.titleEn,
    required this.itemsAr,
    required this.itemsEn,
  });
}

/// Reusable scaffold that renders:
///   1. Branded gradient header with title + last-updated badge
///   2. A list of bullet sections (`PolicySection`)
///   3. Optional contact footer with email + WhatsApp
///   4. Optional extra widgets (e.g. an address card in Contact Us)
class PolicyPageScaffold extends StatelessWidget {
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final IconData icon;
  final String? lastUpdatedAr;
  final String? lastUpdatedEn;
  final List<PolicySection> sections;

  /// Optional widgets injected *above* the section list (e.g. a
  /// hero stats card on the About page).
  final List<Widget> headerExtras;

  /// Optional widgets injected *below* the section list (e.g. a
  /// CTA card in Contact Us).
  final List<Widget> footerExtras;

  /// Show the standard "Legal contact" footer (email + WhatsApp).
  /// Set to `false` on the Contact Us page (which already
  /// renders the contact information itself).
  final bool showContactFooter;

  const PolicyPageScaffold({
    super.key,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.icon,
    this.lastUpdatedAr,
    this.lastUpdatedEn,
    this.sections = const [],
    this.headerExtras = const [],
    this.footerExtras = const [],
    this.showContactFooter = true,
  });

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
              ar ? titleAr : titleEn,
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
              ...headerExtras,
              ...sections.map((s) => _sectionCard(context, ar, s)),
              ...footerExtras,
              if (showContactFooter) _contactFooter(context, ar),
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
          colors: [kPolicyBrandDark, kPolicyBrand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: kPolicyBrand.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: [
        Icon(icon, color: Colors.white, size: 38),
        const SizedBox(height: 10),
        const Text('Talaa Trip',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(
          ar ? subtitleAr : subtitleEn,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9)),
        ),
        if (lastUpdatedAr != null && lastUpdatedEn != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ar ? lastUpdatedAr! : lastUpdatedEn!,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _sectionCard(BuildContext context, bool ar, PolicySection s) {
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
              color: kPolicyBrand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: kPolicyBrand)),
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
                        color: kPolicyBrand,
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

  Widget _contactFooter(BuildContext context, bool ar) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPolicyBrand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPolicyBrand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.support_agent_rounded,
                size: 18, color: kPolicyBrand),
            const SizedBox(width: 8),
            Text(
              ar ? 'هل تحتاج مساعدة؟' : 'Need help?',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: context.kText),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            ar
                ? 'فريق الدعم متواجد للإجابة عن أي سؤال يخص هذه السياسة:'
                : 'Our support team is here to help with any questions:',
            style: TextStyle(fontSize: 12, color: context.kSub, height: 1.6),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => BrandContact.openExternal(BrandContact.mailtoUrl),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: const [
                Icon(Icons.alternate_email_rounded,
                    size: 16, color: kPolicyBrand),
                SizedBox(width: 8),
                Text(
                  BrandContact.email,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kPolicyBrand,
                      decoration: TextDecoration.underline,
                      decorationColor: kPolicyBrand),
                ),
              ]),
            ),
          ),
          InkWell(
            onTap: () => BrandContact.openExternal(BrandContact.whatsappUrl),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const Text('💬', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  ar
                      ? 'واتساب: ${BrandContact.phoneDisplay}'
                      : 'WhatsApp: ${BrandContact.phoneDisplay}',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kPolicyBrand,
                      decoration: TextDecoration.underline,
                      decorationColor: kPolicyBrand),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
