// ═══════════════════════════════════════════════════════════════
//  TALAA — سياسة الاستخدام والخصوصية
//  Full terms of service & privacy policy (read-only view)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../widgets/constants.dart';

const _kOcean = Color(0xFF1565C0);

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: Text('سياسة الاستخدام والخصوصية',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          _header(context),
          const SizedBox(height: 24),
          ..._buildSections(context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), _kOcean],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        const Icon(Icons.verified_user_rounded,
            color: Colors.white, size: 36),
        const SizedBox(height: 10),
        const Text('Talaa Trip',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text('سياسة الاستخدام والخصوصية',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8))),
        const SizedBox(height: 4),
        Text('آخر تحديث: 2025',
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.6))),
      ]),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    return _sections.map((s) {
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
                color: _kOcean.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(s.number,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _kOcean)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: context.kText)),
            ),
          ]),
          const SizedBox(height: 12),
          ...s.items.map((item) => Padding(
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
                          color: _kOcean,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.7,
                              color: context.kSub,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              )),
        ]),
      );
    }).toList();
  }
}

// ── Sections data ────────────────────────────────────────────

class _Section {
  final String number;
  final String title;
  final List<String> items;
  const _Section(this.number, this.title, this.items);
}

const _sections = [
  _Section('١', 'التعريفات', [
    'المنصة: تطبيق Talaa Trip وجميع خدماته الإلكترونية.',
    'الحساب: بيانات الدخول التي يُنشئها المستخدم للوصول للمنصة.',
    'المستخدم: كل شخص يستخدم التطبيق سواء كان ضيفاً أو مالكاً.',
    'المالك: الشخص الذي يعرض عقاراً أو وحدة للإيجار عبر المنصة.',
    'الضيف: الشخص الذي يقوم بالحجز أو الدفع من خلال المنصة.',
    'الحجز: الاتفاق الإلكتروني بين المالك والضيف لإتمام عملية الإيجار.',
    'المعاملات المالية: أي مدفوعات تتم داخل التطبيق.',
    'الدعم الفني: فريق خدمة العملاء التابع لمنصة Talaa Trip.',
  ]),
  _Section('٢', 'الأهلية والتسجيل', [
    'يجب ألا يقل عمر المستخدم عن 18 عاماً.',
    'يلتزم المستخدم بإدخال بيانات صحيحة وحديثة.',
    'مسؤولية الحفاظ على سرية الحساب تقع بالكامل على المستخدم.',
    'يحق للمنصة تعليق أو حذف أي حساب يقدّم بيانات مضللة.',
    'يمنع امتلاك أكثر من حساب واحد غير مصرح به.',
    'أي نشاط يتم عبر الحساب يُعد مسؤولية صاحبه.',
  ]),
  _Section('٣', 'مسؤوليات المالك', [
    'يقر المالك بأنه المالك القانوني للعقار أو المفوض بإدارته.',
    'يلتزم المالك بتقديم معلومات دقيقة حول العقار (صور — خدمات — أسعار — موقع).',
    'الصور يجب أن تعكس الحالة الواقعية للعقار.',
    'يمنع تغيير الأسعار أو الاتفاقيات خارج المنصة للضيوف القادمين منها.',
    'تلتزم بتسليم العقار في الموعد المتفق عليه وبنفس المواصفات.',
    'يتحمل المالك رسوم الاسترداد كاملة في حالة إلغاء الحجز.',
    'تكرار إلغاء الحجز أكثر من مرتين خلال 30 يوماً يؤدي لتعليق الحساب.',
    'تحتفظ المنصة بحق حذف أو إخفاء أي عقار غير مطابق للمعايير.',
  ]),
  _Section('٤', 'مسؤوليات الضيف', [
    'يستخدم الضيف العقار للأغراض السكنية والسياحية فقط.',
    'يتحمل مسؤولية أي تلفيات تحدث أثناء فترة الإقامة.',
    'يمنع إدخال أعداد تتجاوز الطاقة الاستيعابية المتفق عليها.',
    'يلتزم الضيف بمواعيد الدخول والخروج المُحددة من المالك.',
    'ممنوع إقامة أي نشاط غير قانوني داخل العقار.',
    'يجب التواصل مع الدعم قبل مغادرة العقار في حال وجود شكوى.',
  ]),
  _Section('٥', 'الحجوزات والمدفوعات', [
    'الدفع يتم فقط عبر وسائل الدفع المفعلة داخل Talaa Trip.',
    'إتمام الدفع يُعد موافقة كاملة على شروط الحجز.',
    'يتم تحويل المبلغ للمالك بعد 24 ساعة من تسجيل دخول الضيف للعقار.',
    'تُخصم عمولة المنصة 8% تلقائياً من قيمة الحجز.',
    'المعاملات خارج التطبيق لا تتحمل المنصة أي مسؤولية عنها.',
    'في حالة النزاعات يحق للمنصة تجميد المبالغ لحين الفصل فيها.',
    'يمكن طلب مستندات إثبات من المالك أو الضيف قبل اتخاذ قرار نهائي.',
  ]),
  _Section('٦', 'سياسة الإلغاء والاسترداد — إلغاء الضيف', [
    'قبل 14 يوم أو أكثر من موعد الوصول: استرداد كامل 100%.',
    'قبل 7–13 يوم: استرداد 50%.',
    'قبل 3–6 أيام: استرداد 25%.',
    'قبل أقل من 48 ساعة: لا يوجد استرداد (إلا في حالات قهرية مثبتة مثل: وفاة — حادث — تقرير طبي رسمي).',
    'عدم الحضور (No-Show): لا يوجد استرداد.',
  ]),
  _Section('٧', 'سياسة الإلغاء — إلغاء المالك', [
    'استرداد 100% للضيف فوراً.',
    'تعويض إضافي للضيف داخل التطبيق عند الإلغاء المتكرر.',
    'تعليق حساب المالك تلقائياً عند تكرار الإلغاء أكثر من مرتين خلال 30 يوم.',
    'يحق للمنصة منع المالك من إضافة عقارات جديدة عند المخالفة.',
  ]),
  _Section('٨', 'حدود مسؤولية المنصة', [
    'لا تتحمل المنصة مسؤولية أي خلافات بين الضيف والمالك بعد استلام العقار.',
    'لا تتحمل مسؤولية جودة العقار في ظروف قهرية.',
    'لا تتحمل مسؤولية أي إصابات أو خسائر مادية داخل العقار.',
    'لا تتحمل مسؤولية انقطاع الخدمة الناتج عن أعطال خارجية.',
    'لا تتحمل مسؤولية المعاملات التي تتم خارج المنصة.',
    'تقتصر مسؤولية Talaa Trip على: توفير بيئة آمنة للحجز والدفع، الاحتفاظ بالمبالغ وتحويلها وفق السياسات، والتوسط بشكل محايد في النزاعات.',
  ]),
  _Section('٩', 'المحتوى والسلوك المحظور', [
    'يُمنع نشر أي بيانات كاذبة أو مضللة.',
    'يُمنع استخدام الشات في الإساءة أو التحرش.',
    'يُمنع محاولة اختراق النظام أو التحايل عليه.',
    'يُمنع نشر صور أو محتوى غير لائق أو مخالف للقانون المصري.',
    'يُمنع استخدام Bots أو أدوات تلقائية بدون إذن.',
    'المخالفة قد تؤدي إلى حذف الحساب فوراً دون استرداد أي مبالغ.',
  ]),
  _Section('١٠', 'الخصوصية وحماية البيانات', [
    'تلتزم المنصة بحماية بيانات المستخدمين وفق القانون المصري ومعايير الأمان الدولية.',
    'لا يتم مشاركة البيانات مع أي جهة خارجية إلا عند وجود التزام قانوني.',
    'يمكن استخدام بيانات الاستخدام لتحسين جودة الخدمة فقط.',
    'يحق للمستخدم طلب حذف بياناته في أي وقت.',
    'جميع بيانات الدفع مشفرة بالكامل.',
    'قد تتم مراجعة المحادثات لضمان الالتزام بسياسات الاستخدام.',
    'لا يتم تخزين البيانات الحساسة إلا بشكل مشفر وبأعلى درجات الأمان.',
  ]),
  _Section('١١', 'الملكية الفكرية', [
    'جميع الحقوق محفوظة لـ Talaa Trip بما في ذلك التصميم، الكود، الاسم التجاري، والشعار.',
    'يمنع نسخ أو إعادة نشر أي جزء من المنصة بدون موافقة مكتوبة.',
    'الصور المرفوعة من المالك تظل ملكاً له، لكنه يمنح المنصة حق استخدامها في التسويق.',
  ]),
  _Section('١٢', 'تسوية النزاعات', [
    'التواصل مع فريق الدعم أولاً لمحاولة الحل الودي خلال 7 أيام.',
    'إذا تعذر الحل، يتم إحالة النزاع للجهات القضائية المختصة داخل مصر.',
    'تخضع هذه السياسة بالكامل للقانون المصري.',
  ]),
  _Section('١٣', 'التعديلات', [
    'تحتفظ المنصة بحق تعديل البنود في أي وقت.',
    'يتم إشعار المستخدم داخل التطبيق عند وجود تحديث.',
    'استمرار استخدام المنصة بعد التعديل يُعد موافقة ضمنية على السياسة الجديدة.',
  ]),
  _Section('١٤', 'التواصل والدعم', [
    'داخل التطبيق: قسم المساعدة والدعم.',
    'وقت الرد: خلال 24 ساعة في أيام العمل.',
  ]),
];
