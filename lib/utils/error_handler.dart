// ═══════════════════════════════════════════════════════════════
//  TALAA — Unified Error Handler
//  Translates API status codes to Arabic user-friendly messages
// ═══════════════════════════════════════════════════════════════

import 'api_client.dart';

class ErrorHandler {
  /// Returns a user-friendly Arabic message for the given [ApiException].
  static String getMessage(ApiException e) {
    switch (e.statusCode) {
      case 400:
        return 'بيانات غير صحيحة';
      case 401:
        return 'يرجى تسجيل الدخول مجدداً';
      case 403:
        return 'غير مصرح لك بهذا الإجراء';
      case 404:
        return 'العنصر غير موجود';
      case 409:
        return 'محجوز مسبقاً في هذه التواريخ';
      case 422:
        return 'تحقق من البيانات المدخلة';
      case 429:
        return 'طلبات كثيرة، حاول بعد دقيقة';
      case 500:
        return 'خطأ في الخادم، حاول لاحقاً';
      default:
        return 'حدث خطأ غير متوقع';
    }
  }

  /// Extracts the backend detail message if available, otherwise
  /// returns a generic Arabic message.
  static String getDetailOrDefault(ApiException e) {
    // Backend often sends bilingual messages like "العقار غير موجود / Property not found"
    final msg = e.message;
    if (msg.isNotEmpty && !msg.startsWith('{')) {
      return msg;
    }
    return getMessage(e);
  }
}
