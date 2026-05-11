"""Public legal & informational pages — Wave 31.

Serves the same five policy / info pages that exist inside the
Flutter app (Terms, Privacy, Refund, About, Contact) as
**public HTML URLs** so they can be linked from:

* App Store Connect / Google Play Console (Privacy Policy URL is
  mandatory for store submission).
* Facebook Login & Google OAuth consent screens.
* The mobile app itself (where we can deep-link to a stable URL).
* Email signatures, marketing material, etc.

Endpoints
---------
* ``GET /legal``            – Index page listing all five.
* ``GET /legal/terms``      – Terms & Conditions.
* ``GET /legal/privacy``    – Privacy Policy.
* ``GET /legal/refund``     – Cancellation & Refund Policy.
* ``GET /legal/about``      – About Us.
* ``GET /legal/contact``    – Contact Us.

All endpoints accept ``?lang=ar`` (default) or ``?lang=en`` and
return cached, mobile-friendly HTML.  Content is intentionally
mirrored from the Flutter pages to stay consistent — when a
clause changes, update **both** sides (single source of truth in
the future is tracked as TODO).
"""

from __future__ import annotations

import html
from typing import Optional

from fastapi import APIRouter, Query
from fastapi.responses import HTMLResponse

router = APIRouter(prefix="/legal", tags=["legal"])

# ── Brand contact (mirrors lib/utils/brand_contact.dart) ──────
SUPPORT_EMAIL = "talaa.support@gmail.com"
SUPPORT_PHONE = "+201070771908"
WHATSAPP_URL = "https://wa.me/201070771908"
LAST_UPDATED_AR = "آخر تحديث: مايو 2026"
LAST_UPDATED_EN = "Last updated: May 2026"

# ══════════════════════════════════════════════════════════════
#  HTML layout
# ══════════════════════════════════════════════════════════════

_BASE_CSS = """
:root {
  --brand: #FF6B35;
  --brand-dark: #E85A24;
  --bg: #FFF8F2;
  --card: #FFFFFF;
  --text: #1F2937;
  --sub: #6B7280;
  --border: #E5E7EB;
}
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Cairo",
    Tahoma, Arial, sans-serif;
  background: var(--bg);
  color: var(--text);
  line-height: 1.7;
  -webkit-font-smoothing: antialiased;
}
.wrap { max-width: 820px; margin: 0 auto; padding: 24px 18px 60px; }
header.brand {
  background: linear-gradient(135deg, var(--brand-dark), var(--brand));
  color: #fff;
  padding: 36px 22px;
  border-radius: 22px;
  text-align: center;
  box-shadow: 0 8px 28px rgba(255, 107, 53, .25);
  margin-bottom: 28px;
}
header.brand .logo { font-size: 28px; font-weight: 900; letter-spacing: 1px; }
header.brand h1 { margin: 8px 0 4px; font-size: 22px; font-weight: 800; }
header.brand p { margin: 0; opacity: .92; font-size: 14px; font-weight: 500; }
header.brand .badge {
  display: inline-block;
  margin-top: 12px;
  padding: 5px 12px;
  background: rgba(255,255,255,.18);
  border-radius: 10px;
  font-size: 11px;
  font-weight: 700;
}
.lang-switch {
  text-align: end;
  margin-bottom: 12px;
  font-size: 13px;
}
.lang-switch a {
  color: var(--brand);
  text-decoration: none;
  font-weight: 700;
  padding: 4px 10px;
  border-radius: 8px;
  border: 1px solid var(--brand);
}
.lang-switch a:hover { background: var(--brand); color: #fff; }
.section {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 18px;
  padding: 22px 22px 14px;
  margin-bottom: 16px;
}
.section h2 {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0 0 14px;
  font-size: 17px;
  font-weight: 800;
  color: var(--text);
}
.section h2 .num {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  background: rgba(255, 107, 53, .12);
  color: var(--brand);
  border-radius: 10px;
  font-size: 13px;
  font-weight: 900;
}
.section ul { margin: 0; padding-inline-start: 22px; }
.section li {
  margin: 0 0 8px;
  color: var(--sub);
  font-size: 14px;
  line-height: 1.85;
}
.section li::marker { color: var(--brand); }
.section p {
  color: var(--sub);
  font-size: 14px;
  line-height: 1.85;
  margin: 0 0 10px;
}
.contact-card {
  background: rgba(255, 107, 53, .06);
  border: 1px solid rgba(255, 107, 53, .25);
  border-radius: 14px;
  padding: 18px;
  margin-top: 8px;
}
.contact-card h3 {
  margin: 0 0 8px;
  font-size: 15px;
  font-weight: 800;
}
.contact-card a {
  color: var(--brand);
  text-decoration: none;
  font-weight: 700;
}
.contact-card a:hover { text-decoration: underline; }
.contact-card .row { margin: 6px 0; }
.toc {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 18px;
  padding: 18px 22px;
  margin-bottom: 24px;
}
.toc h3 { margin: 0 0 10px; font-size: 15px; font-weight: 800; }
.toc a {
  display: block;
  padding: 10px 12px;
  margin: 4px 0;
  border-radius: 10px;
  color: var(--text);
  text-decoration: none;
  font-weight: 600;
  font-size: 14px;
  background: rgba(255, 107, 53, .04);
  border: 1px solid rgba(255, 107, 53, .12);
  transition: background .15s ease;
}
.toc a:hover { background: rgba(255, 107, 53, .12); }
footer.legal-foot {
  margin-top: 28px;
  text-align: center;
  font-size: 12px;
  color: var(--sub);
}
footer.legal-foot a { color: var(--brand); text-decoration: none; }
@media (max-width: 480px) {
  header.brand { padding: 28px 16px; }
  header.brand h1 { font-size: 18px; }
  .section { padding: 18px 16px 8px; }
  .section h2 { font-size: 15px; }
}
"""


def _layout(
    *,
    title: str,
    subtitle: str,
    body: str,
    lang: str,
    last_updated: str | None = None,
    show_badge: bool = True,
) -> str:
    """Render the shared HTML chrome around a page body."""
    direction = "rtl" if lang == "ar" else "ltr"
    other_lang = "en" if lang == "ar" else "ar"
    other_label = "English" if lang == "ar" else "العربية"
    badge_html = (
        f'<div class="badge">{html.escape(last_updated)}</div>'
        if (show_badge and last_updated)
        else ""
    )
    return f"""<!DOCTYPE html>
<html lang="{lang}" dir="{direction}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{html.escape(title)} — Talaa Trip</title>
  <meta name="description" content="{html.escape(subtitle)}">
  <meta property="og:title" content="{html.escape(title)} — Talaa Trip">
  <meta property="og:description" content="{html.escape(subtitle)}">
  <meta property="og:type" content="article">
  <meta name="robots" content="index, follow">
  <style>{_BASE_CSS}</style>
</head>
<body>
  <div class="wrap">
    <div class="lang-switch">
      <a href="?lang={other_lang}">{other_label}</a>
    </div>
    <header class="brand">
      <div class="logo">Talaa Trip</div>
      <h1>{html.escape(title)}</h1>
      <p>{html.escape(subtitle)}</p>
      {badge_html}
    </header>
    {body}
    <footer class="legal-foot">
      <p>© 2026 Talaa Trip · <a href="/legal?lang={lang}">
      {"كل السياسات" if lang == "ar" else "All Policies"}
      </a></p>
    </footer>
  </div>
</body>
</html>"""


def _section(num: str, title: str, items: list[str]) -> str:
    items_html = "\n".join(
        f"      <li>{html.escape(it)}</li>" for it in items
    )
    return f"""    <section class="section">
      <h2><span class="num">{html.escape(num)}</span>{html.escape(title)}</h2>
      <ul>
{items_html}
      </ul>
    </section>"""


def _contact_footer(lang: str) -> str:
    if lang == "ar":
        return f"""    <div class="contact-card">
      <h3>📞 هل تحتاج مساعدة؟</h3>
      <p>فريق الدعم متواجد للإجابة عن أي سؤال:</p>
      <div class="row">📧 <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a></div>
      <div class="row">💬 <a href="{WHATSAPP_URL}">واتساب: {SUPPORT_PHONE}</a></div>
    </div>"""
    return f"""    <div class="contact-card">
      <h3>📞 Need help?</h3>
      <p>Our support team is here to answer any question:</p>
      <div class="row">📧 <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a></div>
      <div class="row">💬 <a href="{WHATSAPP_URL}">WhatsApp: {SUPPORT_PHONE}</a></div>
    </div>"""


# ══════════════════════════════════════════════════════════════
#  Content (mirrors Flutter pages — keep both sides in sync)
# ══════════════════════════════════════════════════════════════

# ── Privacy ────────────────────────────────────────────────
_PRIVACY_AR = [
    ("١", "نطاق هذه السياسة", [
        "تشرح هذه السياسة كيف تجمع منصة Talaa Trip بياناتك الشخصية وتستخدمها وتحميها.",
        "تنطبق على كل المستخدمين: الضيوف، مُلّاك العقارات، الزوار، وأي طرف يستخدم تطبيقاتنا أو موقعنا.",
        "هذه السياسة جزء لا يتجزأ من شروط الاستخدام، وقبولك لشروط الاستخدام يُعدّ قبولاً لهذه السياسة.",
        "نلتزم بقانون حماية البيانات الشخصية المصري رقم 151 لسنة 2020 ولوائحه التنفيذية.",
    ]),
    ("٢", "فئات البيانات التي نجمعها", [
        "بيانات الهوية: الاسم الكامل، الرقم القومي / جواز السفر، تاريخ الميلاد.",
        "بيانات التواصل: رقم الهاتف، البريد الإلكتروني، عنوان المراسلة.",
        "بيانات الحساب: اسم المستخدم، كلمة السر المُجزّأة، صور الملف الشخصي.",
        "بيانات الحجوزات والمدفوعات: سجل الحجوزات، رموز الدفع (لا نخزّن بيانات البطاقة الكاملة)، الفواتير.",
        "بيانات الاستخدام: نوع الجهاز، نظام التشغيل، عنوان IP، الصفحات التي تزورها.",
        "الموقع: موقع تقريبي مبني على عنوان IP، ولا نتتبع الموقع الدقيق إلا بإذنك الصريح.",
        "المحادثات: رسائل التفاوض مع الطرف الآخر داخل التطبيق.",
    ]),
    ("٣", "أغراض المعالجة والأساس القانوني", [
        "إنشاء وإدارة حسابك (الأساس: تنفيذ العقد).",
        "تنفيذ الحجوزات وتحويل المدفوعات (الأساس: تنفيذ العقد).",
        "منع الاحتيال والتحقق من الهوية (الأساس: المصلحة المشروعة + الالتزام القانوني).",
        "الدعم الفني والرد على الاستفسارات (الأساس: تنفيذ العقد).",
        "تحسين الخدمة عن طريق التحليلات الإحصائية المجمّعة (الأساس: المصلحة المشروعة).",
        "إرسال عروض تسويقية — يتطلب موافقتك الصريحة، ويمكنك سحبها في أي وقت.",
        "الامتثال للالتزامات القانونية والضريبية.",
    ]),
    ("٤", "مشاركة البيانات مع أطراف ثالثة", [
        "لا نبيع بياناتك الشخصية أبداً لأي طرف ثالث.",
        "بوابات الدفع (مثل Paymob / Fawry) — للقدر اللازم لتنفيذ المعاملة.",
        "مزودو الاستضافة السحابية لتشغيل الخوادم وقواعد البيانات.",
        "مزودو خدمات SMS و WhatsApp — لإرسال أكواد التحقق والإشعارات.",
        "الجهات الحكومية والقضائية — فقط بناءً على طلب قانوني رسمي.",
    ]),
    ("٥", "مدة الاحتفاظ بالبيانات", [
        "بيانات الحساب النشط: ما دام الحساب مفتوحاً.",
        "سجلات الحجوزات والفواتير: 5 سنوات بعد إغلاق الحساب وفقاً للقانون التجاري والضريبي المصري.",
        "سجلات الاحتيال أو الإساءة: حتى 7 سنوات لحماية باقي المستخدمين.",
        "النسخ الاحتياطية: حتى 90 يوماً قبل المحو الكامل.",
    ]),
    ("٦", "حقوقك بصفتك صاحب البيانات", [
        "الوصول: الحصول على نسخة من بياناتك المخزّنة لدينا.",
        "التصحيح: تعديل أي بيانات غير دقيقة أو ناقصة.",
        "الحذف: طلب حذف حسابك وكل بياناتك (يُستثنى ما يُلزمنا القانون بالاحتفاظ به).",
        "النقل: استلام بياناتك بصيغة قابلة للقراءة آلياً.",
        "الاعتراض: رفض المعالجة لأغراض التسويق أو التحليلات.",
        "سحب الموافقة في أي وقت دون أن يؤثر على شرعية المعالجة السابقة.",
        f"لتنفيذ أي حق، أرسل طلباً إلى {SUPPORT_EMAIL} — نرد خلال 30 يوماً.",
    ]),
    ("٧", "الأمن وحماية البيانات", [
        "كل البيانات مشفّرة في النقل (TLS 1.2+) وفي التخزين (AES-256).",
        "كلمات السر مُجزّأة (bcrypt) ولا تُخزَّن أبداً بشكل صريح.",
        "بيانات الدفع تُمرَّر مباشرة لبوابات الدفع المعتمدة وفق معيار PCI-DSS.",
        "صلاحية الوصول داخل فريقنا محدودة بحسب الدور (RBAC).",
        "في حال أي اختراق، نُخطر السلطات المختصة خلال 72 ساعة.",
    ]),
    ("٨", "استخدام القاصرين", [
        "الخدمة موجّهة لمن أتمّوا سن 18 عاماً فقط.",
        "لا نجمع عمداً بيانات من أي شخص تحت سن 18 عاماً.",
        "إذا اكتشفنا أن قاصراً يستخدم الخدمة، نحذف حسابه فوراً.",
    ]),
    ("٩", "ملفات الارتباط (Cookies)", [
        "نستخدم ملفات ارتباط ضرورية لتسجيل الدخول وتذكر تفضيلاتك.",
        "نستخدم ملفات ارتباط تحليلية لقياس الأداء (تتطلب موافقتك على الويب).",
        "لا نستخدم ملفات ارتباط إعلانية لأطراف ثالثة في التطبيق.",
    ]),
    ("١٠", "التعديلات على هذه السياسة", [
        "قد نُحدّث هذه السياسة دورياً لمواكبة التغييرات القانونية أو التشغيلية.",
        "التعديلات الجوهرية تُعلَن داخل التطبيق قبل 30 يوماً على الأقل من سريانها.",
        "تاريخ آخر تحديث ظاهر في رأس هذه الصفحة دائماً.",
    ]),
]

_PRIVACY_EN = [
    ("1", "Scope of this Policy", [
        "This Policy explains how Talaa Trip collects, uses and protects your personal data.",
        "It applies to all users: guests, property owners, visitors and anyone using our apps or website.",
        "This Policy forms an integral part of our Terms of Service.",
        "We comply with Egyptian Personal Data Protection Law No. 151 of 2020.",
    ]),
    ("2", "Categories of Data We Collect", [
        "Identity: full name, national ID / passport, date of birth.",
        "Contact: phone number, email address, mailing address.",
        "Account: username, hashed password, profile photos.",
        "Bookings & payments: booking history, payment tokens, invoices.",
        "Usage: device type, OS, IP address, pages visited.",
        "Location: approximate (IP-based); precise location only with your explicit permission.",
        "Conversations: in-app negotiation messages between guest and host.",
    ]),
    ("3", "Processing Purposes & Legal Basis", [
        "Creating and managing your account (basis: contract performance).",
        "Fulfilling bookings and processing payments (basis: contract performance).",
        "Fraud prevention and identity verification (basis: legitimate interest + legal obligation).",
        "Customer support (basis: contract performance).",
        "Improving the service via aggregated analytics (basis: legitimate interest).",
        "Marketing — only with your explicit consent, withdrawable at any time.",
        "Compliance with legal and tax obligations.",
    ]),
    ("4", "Sharing With Third Parties", [
        "We never sell your personal data to any third party.",
        "Payment processors (Paymob / Fawry) — only as needed to complete the transaction.",
        "Cloud providers — to run servers and databases.",
        "SMS & WhatsApp providers — to deliver verification codes.",
        "Government and judicial bodies — only upon formal lawful request.",
    ]),
    ("5", "Data Retention", [
        "Active account data: as long as the account is open.",
        "Booking and invoice records: 5 years after account closure per Egyptian commercial and tax law.",
        "Fraud / abuse records: up to 7 years to protect other users.",
        "Backups: up to 90 days before full purge.",
    ]),
    ("6", "Your Rights as a Data Subject", [
        "Access: receive a copy of the data we hold about you.",
        "Rectification: correct any inaccurate data.",
        "Erasure: request deletion of your account (subject to legal retention).",
        "Portability: receive your data in a machine-readable format.",
        "Objection: refuse processing for marketing or analytics.",
        "Withdraw consent at any time.",
        f"To exercise any right, email {SUPPORT_EMAIL} — we respond within 30 days.",
    ]),
    ("7", "Security & Data Protection", [
        "All data is encrypted in transit (TLS 1.2+) and at rest (AES-256).",
        "Passwords are hashed (bcrypt) and never stored in plain text.",
        "Payment data is passed directly to certified PCI-DSS gateways.",
        "Internal access is role-based (RBAC).",
        "In case of a breach, we notify the competent authority within 72 hours.",
    ]),
    ("8", "Use by Minors", [
        "The service is intended only for users aged 18+.",
        "We do not knowingly collect data from anyone under 18.",
        "If we discover a minor is using the service, we immediately delete their account.",
    ]),
    ("9", "Cookies & Similar Technologies", [
        "We use strictly necessary cookies for login and preferences.",
        "We use analytics cookies to measure performance (consent required on web).",
        "We do not use third-party advertising cookies inside the app.",
    ]),
    ("10", "Changes to this Policy", [
        "We may update this Policy from time to time.",
        "Material changes are announced in-app at least 30 days before they take effect.",
        "The 'Last updated' date at the top always reflects the latest revision.",
    ]),
]

# ── Refund ─────────────────────────────────────────────────
_REFUND_AR = [
    ("١", "إلغاء الحجز من قِبَل الضيف", [
        "إلغاء قبل 14 يوماً أو أكثر من تاريخ الوصول: استرداد 100% من المبلغ المدفوع.",
        "إلغاء قبل 7 إلى 13 يوماً من الوصول: استرداد 50% من المبلغ المدفوع.",
        "إلغاء قبل أقل من 7 أيام من الوصول أو بعد الوصول: لا يوجد استرداد.",
        "يبدأ احتساب المدة من الساعة 12:00 ظهراً بتوقيت القاهرة.",
    ]),
    ("٢", "إلغاء الحجز من قِبَل المالك", [
        "إذا ألغى المالك حجزاً مؤكَّداً، يُعاد للضيف 100% من المبلغ تلقائياً.",
        "يحق للضيف الحصول على رصيد محفظة إضافي بقيمة 10% كتعويض عن الإزعاج.",
        "الإلغاء المتكرر من نفس المالك يعرّض حسابه للتعليق أو الإغلاق.",
    ]),
    ("٣", "القوة القاهرة", [
        "في حالات القوة القاهرة (أوبئة، كوارث طبيعية، قرارات حكومية) يُسمح بالإلغاء بدون غرامة لأي طرف.",
        "تُراجع المنصة كل حالة على حدة وقد تطلب وثائق رسمية.",
        "يُعاد كامل المبلغ بعد خصم رسوم بوابة الدفع غير المستردة.",
    ]),
    ("٤", "مدة معالجة الاسترداد", [
        "الاسترداد عبر المحفظة الداخلية: فوري.",
        "الاسترداد على البطاقة البنكية: من 5 إلى 14 يوم عمل تبعاً للبنك المُصدر.",
        "الاسترداد عبر فوري / محفظة محمول: من 1 إلى 5 أيام عمل.",
        "تُحتسب أيام العمل من الأحد إلى الخميس باستثناء العطلات الرسمية.",
    ]),
    ("٥", "عناصر غير قابلة للاسترداد", [
        "رسوم بوابة الدفع — تخصمها الجهة المُصدرة وليست المنصة.",
        "رسوم الخدمة المدفوعة على ترويج العقار من قبل المالك.",
        "أي خصومات مكتسبة كرصيد مكافآت لا تُحوَّل إلى نقد.",
    ]),
    ("٦", "النزاعات والشكاوى", [
        "إذا اعتقدت أن استرداداً مستحقاً لم يُنفّذ، تواصل مع الدعم خلال 30 يوماً.",
        "نرد على الشكوى خلال 5 أيام عمل بأقصى تقدير.",
        "إذا استمر النزاع، يُتّبع مسار التحكيم المنصوص عليه في شروط الاستخدام.",
    ]),
]

_REFUND_EN = [
    ("1", "Cancellation by the Guest", [
        "14+ days before arrival: 100% refund of the amount paid.",
        "7–13 days before arrival: 50% refund of the amount paid.",
        "Less than 7 days before arrival, or after arrival: no refund.",
        "Countdown starts at 12:00 noon Cairo time.",
    ]),
    ("2", "Cancellation by the Host", [
        "If the host cancels a confirmed booking, the guest is automatically refunded 100%.",
        "The guest also receives an extra wallet credit equal to 10% as compensation.",
        "Repeated host cancellations may result in account suspension or termination.",
    ]),
    ("3", "Force Majeure", [
        "In force-majeure events (epidemics, natural disasters, government orders) cancellation is allowed without penalty.",
        "The Platform reviews each case individually and may request official documentation.",
        "Full refund except for non-refundable payment-gateway fees.",
    ]),
    ("4", "Refund Processing Time", [
        "In-app wallet refund: instant.",
        "Bank-card refund: 5–14 working days depending on the issuing bank.",
        "Fawry / mobile-wallet refund: 1–5 working days.",
        "Working days are Sunday–Thursday excluding Egyptian public holidays.",
    ]),
    ("5", "Non-Refundable Items", [
        "Payment-gateway fees — withheld by the issuer, not the Platform.",
        "Service fees paid by the host for listing promotions.",
        "Earned reward credits cannot be converted to cash.",
    ]),
    ("6", "Disputes & Complaints", [
        "If a due refund was not processed, contact support within 30 days.",
        "We respond within 5 working days at most.",
        "If the dispute persists, the arbitration path defined in the Terms applies.",
    ]),
]

# ── Terms (condensed top-level — full version is in app) ───
_TERMS_AR = [
    ("١", "مقدمة وقبول الشروط", [
        "تُدار منصة Talaa Trip داخل جمهورية مصر العربية وتُقدّم خدماتها الرقمية من خلال تطبيقات الهاتف والموقع.",
        "تُعدّ المنصة وسيطاً تقنياً فقط، وليست طرفاً في أي عقد إيجار.",
        "باستخدامك للمنصة فأنت توافق على هذه الشروط بصيغتها الكاملة المتاحة داخل التطبيق.",
    ]),
    ("٢", "الأهلية", [
        "يجب ألا يقل عمرك عن 18 عاماً وأن تكون كامل الأهلية القانونية للتعاقد.",
        "تلتزم بتقديم بيانات حقيقية ومتجدّدة.",
    ]),
    ("٣", "دور المنصة", [
        "Talaa Trip وسيط تقني فقط، ولا تمتلك أو تُشغّل أي عقار.",
        "العقد بين الضيف والمالك يخضع لأحكامه المتفق عليها بينهما.",
        "لا تتحمل المنصة مسؤولية الإصابات أو الأضرار التي تقع داخل العقار.",
    ]),
    ("٤", "الحجوزات والدفع والعمولة", [
        "يتم الدفع حصراً داخل المنصة عبر بوابات الدفع المعتمدة.",
        "أي مبالغ مُحوَّلة خارج المنصة لا تتحمل المنصة أي مسؤولية عنها.",
        "تطبق المنصة عمولة خدمة معلنة في تفاصيل كل حجز.",
    ]),
    ("٥", "الإلغاء والاسترداد", [
        "تخضع الإلغاءات لسياسة الإلغاء والاسترداد المنفصلة.",
        f"للاطلاع على التفاصيل: /legal/refund?lang=ar",
    ]),
    ("٦", "السلوك المحظور", [
        "أي نشاط غير قانوني أو ينتهك القوانين المصرية.",
        "محاولة الالتفاف على المنصة وإتمام المعاملات خارجها.",
        "نشر محتوى مسيء، تمييزي، أو غير لائق.",
        "انتحال صفة شخص آخر أو إنشاء حسابات متعددة.",
    ]),
    ("٧", "إخلاء المسؤولية وتحديدها", [
        "تُقدَّم المنصة 'كما هي' دون أي ضمانات صريحة أو ضمنية.",
        "لا نُسأل عن أي إصابات شخصية، تلف ممتلكات، أو سرقة داخل أي عقار.",
        "الحد الأقصى للمسؤولية التراكمية لا يتجاوز إجمالي عمولة المنصة المدفوعة من المستخدم خلال آخر 3 أشهر، أو 1,000 جنيه، أيهما أقل.",
    ]),
    ("٨", "الخصوصية وحماية البيانات", [
        "نلتزم بقانون حماية البيانات الشخصية المصري رقم 151 لسنة 2020.",
        f"للاطلاع على التفاصيل: /legal/privacy?lang=ar",
    ]),
    ("٩", "القانون الحاكم", [
        "تخضع هذه الشروط لقوانين جمهورية مصر العربية.",
        "تختص محاكم القاهرة بالفصل في أي نزاع لم يتم حلّه ودياً.",
        "يجوز اللجوء للتحكيم بدلاً من القضاء بموجب اتفاق مكتوب.",
    ]),
    ("١٠", "التعديلات", [
        "يحق للمنصة تعديل هذه الشروط في أي وقت.",
        "التعديلات الجوهرية يتم الإخطار بها داخل التطبيق قبل 30 يوماً.",
        "استمرار الاستخدام بعد سريان التعديلات يُعدّ قبولاً ضمنياً لها.",
    ]),
    ("١١", "التواصل", [
        f"للاستفسارات القانونية وحماية البيانات: {SUPPORT_EMAIL}",
        f"للدعم العام: واتساب {SUPPORT_PHONE}",
    ]),
]

_TERMS_EN = [
    ("1", "Introduction & Acceptance", [
        "Talaa Trip operates within the Arab Republic of Egypt and delivers its digital services through mobile apps and the website.",
        "The Platform acts as a neutral technology intermediary, not a party to any rental contract.",
        "By using the Platform you accept these Terms in full as available inside the app.",
    ]),
    ("2", "Eligibility", [
        "You must be 18+ and fully legally competent to contract.",
        "You commit to providing accurate and up-to-date information.",
    ]),
    ("3", "Role of the Platform", [
        "Talaa Trip is a technology intermediary only and does not own or operate any property.",
        "The contract between guest and host is governed by terms agreed between them.",
        "The Platform is not liable for injuries or damage occurring inside any property.",
    ]),
    ("4", "Bookings, Payments & Commission", [
        "Payments are processed exclusively in-Platform via certified gateways.",
        "Funds transferred off-Platform are not the Platform's responsibility.",
        "A service commission is disclosed at booking time.",
    ]),
    ("5", "Cancellations & Refunds", [
        "Cancellations are governed by the separate Refund Policy.",
        "Details: /legal/refund?lang=en",
    ]),
    ("6", "Prohibited Conduct", [
        "Any illegal activity or violation of Egyptian law.",
        "Attempting to bypass the Platform and complete transactions off-platform.",
        "Posting offensive, discriminatory or inappropriate content.",
        "Impersonating another person or creating multiple accounts.",
    ]),
    ("7", "Disclaimers & Limitation of Liability", [
        "The Platform is provided 'as is' without express or implied warranties.",
        "We are not liable for personal injury, property damage, or theft within any property.",
        "Aggregate liability is capped at the total Platform commission paid in the last 3 months, or EGP 1,000, whichever is lower.",
    ]),
    ("8", "Privacy & Data Protection", [
        "We comply with Egyptian Personal Data Protection Law No. 151 of 2020.",
        "Details: /legal/privacy?lang=en",
    ]),
    ("9", "Governing Law", [
        "These Terms are governed by the laws of the Arab Republic of Egypt.",
        "The competent courts of Cairo have jurisdiction over any unresolved dispute.",
        "Arbitration may be agreed in writing instead of litigation.",
    ]),
    ("10", "Amendments", [
        "The Platform may amend these Terms at any time.",
        "Material changes are announced in-app at least 30 days before taking effect.",
        "Continued use after the changes take effect constitutes acceptance.",
    ]),
    ("11", "Contact", [
        f"Legal & data-protection enquiries: {SUPPORT_EMAIL}",
        f"General support: WhatsApp {SUPPORT_PHONE}",
    ]),
]

# ── About ──────────────────────────────────────────────────
_ABOUT_AR = [
    ("١", "رسالتنا", [
        "نُسهّل تأجير الشاليهات والفلل واليخوت في مصر بطريقة آمنة وشفافة.",
        "نمنح الضيوف ثقة في كل حجز عبر التحقق من الهوية، الدفع الآمن، والمراجعات الموثَّقة.",
        "نمنح المُلّاك أداة احترافية لإدارة عقاراتهم وزيادة دخلهم بدون تعقيدات.",
        "نهدف إلى رفع جودة السياحة الداخلية المصرية ودعم الاقتصاد المحلي في مناطق الساحل والبحر الأحمر.",
    ]),
    ("٢", "رؤيتنا", [
        "أن نكون المنصة الأولى في مصر والشرق الأوسط للإجارات السياحية قصيرة الأجل.",
        "أن نخلق سوقاً منظَّماً يخدم الملايين من الضيوف وآلاف المُلّاك سنوياً.",
        "أن نُعيد تعريف تجربة الإجازة العائلية في مصر.",
    ]),
    ("٣", "ماذا نقدّم", [
        "استكشاف ذكي للعقارات حسب المنطقة والسعر والمرافق.",
        "تواصل مباشر مع المالك داخل التطبيق وتفاوض على السعر.",
        "دفع آمن: مقدّم وباقي عند الوصول، أو دفع كامل عبر بوابات معتمدة.",
        "محفظة داخلية بمكافآت على كل حجز.",
        "دعم على مدار الساعة قبل وأثناء وبعد الإقامة.",
    ]),
    ("٤", "قيمنا", [
        "الشفافية: لا رسوم خفية، السعر اللي تشوفه هو السعر اللي تدفعه.",
        "الأمان: التحقق من هوية كل مستخدم وتشفير كامل لبياناتك.",
        "الاحترام: مجتمع متنوع نرفض فيه أي شكل من أشكال التمييز.",
        "الجودة: نراجع كل العقارات قبل النشر.",
    ]),
]

_ABOUT_EN = [
    ("1", "Our Mission", [
        "We make renting chalets, villas and yachts in Egypt safe, simple and transparent.",
        "We give guests confidence through identity verification, secure payments and verified reviews.",
        "We give hosts a professional tool to manage their properties — hassle-free.",
        "We aim to elevate Egyptian domestic tourism and empower local economies.",
    ]),
    ("2", "Our Vision", [
        "To be the leading short-stay rental marketplace in Egypt and the Middle East.",
        "To build a trusted marketplace serving millions of guests and thousands of hosts every year.",
        "To redefine the family-vacation experience in Egypt.",
    ]),
    ("3", "What We Offer", [
        "Smart property discovery filtered by area, price and amenities.",
        "Direct in-app chat and price negotiation with the host.",
        "Secure payments: deposit + on-arrival, or full payment via certified gateways.",
        "In-app wallet with rewards on every booking.",
        "24/7 support before, during and after your stay.",
    ]),
    ("4", "Our Values", [
        "Transparency: no hidden fees — the price you see is the price you pay.",
        "Safety: identity-verified users and end-to-end data encryption.",
        "Respect: a diverse community where any form of discrimination is rejected.",
        "Quality: every listing is reviewed before going live.",
    ]),
]


# ══════════════════════════════════════════════════════════════
#  Routes
# ══════════════════════════════════════════════════════════════

def _normalise_lang(lang: Optional[str]) -> str:
    return "en" if (lang or "").lower().startswith("en") else "ar"


def _render_section_page(
    *,
    title_ar: str,
    title_en: str,
    sub_ar: str,
    sub_en: str,
    sections_ar: list[tuple[str, str, list[str]]],
    sections_en: list[tuple[str, str, list[str]]],
    lang: str,
) -> str:
    is_ar = lang == "ar"
    sections = sections_ar if is_ar else sections_en
    body_parts = [_section(num, t, items) for num, t, items in sections]
    body_parts.append(_contact_footer(lang))
    return _layout(
        title=title_ar if is_ar else title_en,
        subtitle=sub_ar if is_ar else sub_en,
        body="\n".join(body_parts),
        lang=lang,
        last_updated=LAST_UPDATED_AR if is_ar else LAST_UPDATED_EN,
    )


def _cache_headers() -> dict[str, str]:
    # 1 hour public cache; legal pages don't change frequently.
    return {"Cache-Control": "public, max-age=3600"}


@router.get("", response_class=HTMLResponse)
@router.get("/", response_class=HTMLResponse)
async def legal_index(
    lang: Optional[str] = Query(default="ar"),
) -> HTMLResponse:
    """Index of all five legal / informational pages."""
    lang = _normalise_lang(lang)
    is_ar = lang == "ar"
    items = [
        ("/legal/terms",   "الشروط والأحكام",        "Terms & Conditions"),
        ("/legal/privacy", "سياسة الخصوصية",         "Privacy Policy"),
        ("/legal/refund",  "سياسة الإلغاء والاسترداد", "Cancellation & Refund Policy"),
        ("/legal/about",   "من نحن",                 "About Us"),
        ("/legal/contact", "تواصل معنا",             "Contact Us"),
    ]
    rows = "\n".join(
        f'      <a href="{href}?lang={lang}">'
        f'{html.escape(ar if is_ar else en)} →</a>'
        for href, ar, en in items
    )
    body = f"""    <div class="toc">
      <h3>{"السياسات والمعلومات" if is_ar else "Policies & Info"}</h3>
{rows}
    </div>
{_contact_footer(lang)}"""
    return HTMLResponse(
        _layout(
            title="Talaa Trip" if not is_ar else "Talaa Trip",
            subtitle=("السياسات والمعلومات الرسمية" if is_ar
                      else "Official policies & information"),
            body=body,
            lang=lang,
            show_badge=False,
        ),
        headers=_cache_headers(),
    )


@router.get("/terms", response_class=HTMLResponse)
async def legal_terms(
    lang: Optional[str] = Query(default="ar"),
) -> HTMLResponse:
    return HTMLResponse(
        _render_section_page(
            title_ar="الشروط والأحكام",
            title_en="Terms & Conditions",
            sub_ar="الإطار القانوني الكامل لاستخدام منصة Talaa Trip",
            sub_en="Full legal framework for using the Talaa Trip platform",
            sections_ar=_TERMS_AR,
            sections_en=_TERMS_EN,
            lang=_normalise_lang(lang),
        ),
        headers=_cache_headers(),
    )


@router.get("/privacy", response_class=HTMLResponse)
async def legal_privacy(
    lang: Optional[str] = Query(default="ar"),
) -> HTMLResponse:
    return HTMLResponse(
        _render_section_page(
            title_ar="سياسة الخصوصية",
            title_en="Privacy Policy",
            sub_ar="حماية بياناتك الشخصية وفق القانون المصري 151/2020",
            sub_en="Your data, protected under Egyptian Law 151/2020",
            sections_ar=_PRIVACY_AR,
            sections_en=_PRIVACY_EN,
            lang=_normalise_lang(lang),
        ),
        headers=_cache_headers(),
    )


@router.get("/refund", response_class=HTMLResponse)
async def legal_refund(
    lang: Optional[str] = Query(default="ar"),
) -> HTMLResponse:
    return HTMLResponse(
        _render_section_page(
            title_ar="سياسة الإلغاء والاسترداد",
            title_en="Cancellation & Refund Policy",
            sub_ar="الشروط الكاملة للإلغاء واسترداد المبالغ",
            sub_en="Full cancellation and refund terms",
            sections_ar=_REFUND_AR,
            sections_en=_REFUND_EN,
            lang=_normalise_lang(lang),
        ),
        headers=_cache_headers(),
    )


@router.get("/about", response_class=HTMLResponse)
async def legal_about(
    lang: Optional[str] = Query(default="ar"),
) -> HTMLResponse:
    return HTMLResponse(
        _render_section_page(
            title_ar="من نحن",
            title_en="About Us",
            sub_ar="منصة مصرية للإجارات السياحية قصيرة الأجل",
            sub_en="Egypt's short-stay rental marketplace",
            sections_ar=_ABOUT_AR,
            sections_en=_ABOUT_EN,
            lang=_normalise_lang(lang),
        ),
        headers=_cache_headers(),
    )


@router.get("/contact", response_class=HTMLResponse)
async def legal_contact(
    lang: Optional[str] = Query(default="ar"),
) -> HTMLResponse:
    lang = _normalise_lang(lang)
    is_ar = lang == "ar"
    intro = (
        "فريق دعم Talaa Trip متاح للرد على كل استفسار يخص حجوزاتك، "
        "دفعاتك، أو أي سؤال عن المنصة. اختر القناة المناسبة لك:"
        if is_ar else
        "The Talaa Trip support team is here to answer any question "
        "about your bookings, payments, or the platform itself. "
        "Pick whichever channel suits you:"
    )
    hours = (
        "<strong>ساعات العمل:</strong><br>"
        "الأحد – الخميس: 9:00 ص – 9:00 م (بتوقيت القاهرة)<br>"
        "الجمعة والسبت: 10:00 ص – 6:00 م<br>"
        "الحالات الطارئة: دعم على مدار 24 ساعة."
        if is_ar else
        "<strong>Business Hours:</strong><br>"
        "Sunday – Thursday: 9:00 AM – 9:00 PM (Cairo time)<br>"
        "Friday & Saturday: 10:00 AM – 6:00 PM<br>"
        "Urgent cases: 24/7 support."
    )
    body = f"""    <section class="section">
      <h2><span class="num">{"📨" if is_ar else "📨"}</span>{
        "قنوات التواصل" if is_ar else "Contact Channels"
      }</h2>
      <p>{html.escape(intro)}</p>
      <ul>
        <li>📧 <strong>{"البريد الإلكتروني" if is_ar else "Email"}:</strong>
            <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a></li>
        <li>💬 <strong>WhatsApp:</strong>
            <a href="{WHATSAPP_URL}">{SUPPORT_PHONE}</a></li>
        <li>📞 <strong>{"اتصال هاتفي" if is_ar else "Phone"}:</strong>
            <a href="tel:{SUPPORT_PHONE}">{SUPPORT_PHONE}</a></li>
      </ul>
    </section>
    <section class="section">
      <h2><span class="num">⏰</span>{
        "أوقات العمل والرد" if is_ar else "Hours & Response Times"
      }</h2>
      <p>{hours}</p>
      <ul>
        <li>{"واتساب: نرد عادةً خلال 30 دقيقة في ساعات العمل." if is_ar
             else "WhatsApp: typically within 30 minutes during business hours."}</li>
        <li>{"البريد الإلكتروني: خلال 24 ساعة كحد أقصى أيام العمل." if is_ar
             else "Email: within 24 hours on business days at most."}</li>
        <li>{"الحالات الطارئة (مشاكل أثناء الإقامة): الأولوية القصوى." if is_ar
             else "Urgent issues during your stay: top priority."}</li>
      </ul>
    </section>"""
    return HTMLResponse(
        _layout(
            title="تواصل معنا" if is_ar else "Contact Us",
            subtitle=("فريق الدعم متواجد لمساعدتك" if is_ar
                      else "Our support team is here to help"),
            body=body,
            lang=lang,
            show_badge=False,
        ),
        headers=_cache_headers(),
    )
