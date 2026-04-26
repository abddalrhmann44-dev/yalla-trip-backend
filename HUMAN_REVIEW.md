# Talaa / Yalla Trip — Human Review & Production Checklist

> Generated: 2026-04-26 · Audit scope: full Flutter app + FastAPI backend
> Goal: list everything that is **good as is**, what is **broken in code**
> (already fixed), and what **MUST be done outside the app** before
> shipping to real users.

---

## ✅ ما اللى معمول جوّا الكود (ما يحتاجش حاجة منك)

### الـ Branding & UI
- ✅ اللون الأساسى دلوقتى **برتقالى Talaa** `#FF6B35` فى كل مكان.
- ✅ شيلت كل ثوابت الـ navy / blue من `constants.dart` و `main.dart`.
- ✅ 61 reference لـ HEX زرقاء (`0xFF1565C0`, `0xFF0D47A1`, إلخ) اتـ
  استبدلوا بـ orange equivalents فى الكود.
- ✅ الـ category colors (beach / aquapark) بقت أوامر برتقالية مش زرقاء.
- ✅ كل الـ Dark mode neutrals بقت warm browns بدلاً من navy slate.
- ✅ Splash screen اتشال (Flutter + Android + iOS).
- ✅ Material `ColorScheme.fromSeed` مع `primary` pinned للـ exact brand
  orange — مفيش تذبذب من Material3.

### الأخطاء (Friendly Error UI)
- ✅ `lib/widgets/app_snack.dart` — toast helper موحّد بيعرض:
  - icon ملوّن صغير + title واضح + رسالة + chip بكود الخطأ.
  - بدل الـ `Colors.red` block الكبير القديم.
  - 4 أنواع: `error / success / warning / info` كل واحد له لون و haptic.
- ✅ `lib/utils/error_handler.dart` بيترجم HTTP codes لرسائل عربية.
- ⚠️ ملحوظة: لسه فيه ~15 `backgroundColor: Colors.red` SnackBars قديمة فى:
  `admin_payouts_page.dart`, `admin_promo_codes_page.dart`,
  `admin_reports_page.dart`, `owner_add_property_page.dart`,
  `report_sheet.dart`, `host_payouts_page.dart`, `owner_dashboard_page.dart`.
  دى **مش breaking** بس لو عايز تعمم الـ AppSnack helper كل مكان قول.

### Hybrid Payment + Disburse
- ✅ Deposit + cash-on-arrival مع double-confirmation وحماية no-show.
- ✅ Commission 10% مطبّقة فى `PLATFORM_FEE_PERCENT=10.0`.
- ✅ Disburse gateway (mock + Kashier) + reconciliation scheduler كل ساعة.
- ✅ 13/13 pytest disburse + 14/14 pytest payouts كلهم passed.

### Image Upload
- ✅ 6–40 صورة من gallery / camera، `imageQuality: 80` (HEIC→JPEG تلقائياً).
- ✅ Backend بيرفض الـ MIME الغلط بـ 400 صريحة بدل silent skip.
- ✅ S3 شغّال — `BucketOwnerEnforced` issue اتحل بإزالة `ACL=public-read`.
- ✅ `INTERNET` permission مضافة فى Android manifest لرليز builds.

---

## 🔧 ما اللى محتاج يتظبط **خارج** الأبلكيشن

### 1. ⚠️ AWS S3 (إعداد جزئى — محتاج CORS لو الويب لاحقاً)
- ✅ Bucket: `yalla-trip-media` فى `eu-south-1`
- ✅ Public-read bucket policy موجودة و شغّالة
- ✅ Credentials محطوطة فى `.env`
- ❌ **CORS rules** ناقصة — لو هتبنى Flutter Web لاحقاً، الـ images
  هيـ block بـ CORS error. أضف هذه CORS rule فى bucket settings:
  ```json
  [{
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedOrigins": ["*"],
    "MaxAgeSeconds": 3600
  }]
  ```
- ❌ **Lifecycle rule** ناقصة — صور العقارات المحذوفة بتفضل فى S3
  للأبد. ضيف rule يحذف objects أكبر من 30 يوم فى folder `properties/_trash/`.
- ❌ **CloudFront** غير مفعّل — كل صورة بتـ load من `eu-south-1` Milan.
  للمستخدمين فى مصر/الخليج هياخد 200-400ms. ضيف CloudFront distribution
  هيقلل لـ 30-60ms.

### 2. 🔴 Kashier Disbursement (إعداد ناقص بالكامل)
- ✅ Skeleton موجود فى `app/services/disburse/kashier.py`
- ✅ `DISBURSE_PROVIDER=mock` دلوقتى — آمن للـ dev
- ❌ المتغيرات دى **فاضية** فى `.env` — لازم تتملى من Kashier dashboard:
  ```
  KASHIER_DISBURSE_MERCHANT_ID=
  KASHIER_DISBURSE_API_KEY=
  KASHIER_DISBURSE_SECRET=
  ```
- ❌ 5 مكان عليه `# TODO(KASHIER)` فى `kashier.py` محتاجين تأكيد من Kashier docs:
  - exact endpoint path للـ initiate
  - field names للـ amount / account / channel
  - signature header name + algorithm
  - webhook payload structure
  - status codes mapping
- ❌ بعد ملا تتملى، غيّر `DISBURSE_PROVIDER=kashier` فى `.env`
- ❌ اعمل sandbox transfer واحد قبل ما تروح production

### 3. 🟡 Paymob (Customer Payments)
- ❌ كل المتغيرات دى فاضية فى `.env` — payments مقفلة دلوقتى:
  ```
  PAYMOB_API_KEY=
  PAYMOB_HMAC_SECRET=
  PAYMOB_IFRAME_ID=
  PAYMOB_INTEGRATION_CARD=
  PAYMOB_INTEGRATION_WALLET=
  ```
- ❌ `PAYMENTS_MOCK_MODE=False` فى prod — لو فيه حد بيدفع وأنت مش متأكد
  من keys، خلّيها `True` أولاً.
- ❌ Paymob webhooks بتيجى على `POST /payments/webhook` — لازم ال URL ده
  يكون **public HTTPS** ومسجّل فى Paymob dashboard.

### 4. 🟡 Firebase (FCM Notifications + Auth)
- ✅ `FIREBASE_CREDENTIALS_JSON` متملى (service account)
- ❌ `FCM_SERVER_KEY` متملى لكن قديم — Firebase deprecated الـ legacy
  HTTP API فى **June 2024**. لازم تنتقل لـ FCM HTTP v1 (يستعمل service
  account JSON بدلاً من server key). الكود بيستعمل V1 بالفعل، فأنت آمن
  بس امسح الـ FCM_SERVER_KEY من الـ config لأنه مش مستخدم.
- ❌ Firebase project configs (`google-services.json` لـ Android +
  `GoogleService-Info.plist` لـ iOS) — تأكد إنهم محطوطين فى:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- ❌ Push notification entitlement فى Xcode — لازم يتفعّل manual:
  Xcode → Signing & Capabilities → + Push Notifications.

### 5. 🟡 Sentry (Error Tracking)
- ❌ `SENTRY_DSN=` فاضى — مفيش error tracking فى production. لو
  حد قابل crash، مش هتعرف ولا هتاخد stack trace. اعمل Sentry account
  مجانى وحط الـ DSN.
- ❌ `SENTRY_TRACES_SAMPLE_RATE=0.0` — يفضّل 0.1 (10%) فى prod للـ
  performance traces.

### 6. 🟡 Database (PostgreSQL)
- ✅ Migrations كلها up-to-date
- ❌ Database **مش backed up** — لو الـ container اتحذف، كل الحجوزات راحوا.
  حلول:
  - أبسط: cron يعمل `pg_dump` كل يوم لـ S3
  - مدفوع: AWS RDS managed PostgreSQL مع automated daily snapshots
- ❌ Connection pooling مش متظبّط للـ scale — `DATABASE_URL` مفيها
  pool params. لـ >100 concurrent users ضيف:
  `?pool_size=20&max_overflow=10&pool_pre_ping=true`

### 7. 🟡 Backend Deployment
- ❌ الباك إند شغّال فى Docker على جهازك — للـ public access محتاج:
  1. **VPS or cloud host** (DigitalOcean droplet $6/mo، AWS EC2 t3.small،
     Hetzner CX11 €5/mo) — أرخص خيار = Hetzner.
  2. **Domain name** (e.g., `api.talaa.app`) → DNS → IP الـ VPS.
  3. **HTTPS certificate** — استعمل `caddy` (auto-cert من Let's Encrypt)
     أو `nginx + certbot`. الـ `caddy` أسهل.
  4. **Reverse proxy config**:
     ```
     api.talaa.app {
         reverse_proxy localhost:8000
         request_body {
             max_size 100MB  # عشان upload 40 صورة
         }
     }
     ```
- ❌ `APP_BASE_URL=` فاضى — لازم يبقى `https://api.talaa.app` فى prod
  لأن Paymob redirects و push notification deep links بتعتمد عليه.
- ❌ `ALLOWED_ORIGINS` فيها `localhost` بس — ضيف الـ Flutter web origin
  لو هتطلق ويب.

### 8. 🟡 Mobile App Stores
#### Google Play Store
- ❌ `IOS_APP_ID` فاضى — متهيألى ده اسمه غلط، ده فعلاً `IOS_APP_STORE_ID`
- ❌ `IOS_TEAM_ID` فاضى
- ❌ Keystore لـ Android signing — `android/app/upload-keystore.jks` مش
  موجود. اعمله:
  ```bash
  keytool -genkey -v -keystore android/app/upload-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
  واحفظ الـ password فى `android/key.properties` (مش commit للـ git).
- ❌ App icons (1024x1024) + screenshots (5 على الأقل) — مطلوبين فى
  Play Console قبل النشر.
- ❌ Privacy policy URL — مطلوب من Google. اعمل صفحة على `talaa.app/privacy`
  واربطها فى Play Console.
- ❌ Data Safety form — مطلوب وصف صريح لكل البيانات اللى الأبلكيشن بيجمعها
  (location, photos, payment data).

#### Apple App Store
- ❌ Apple Developer Program ($99/year) — مطلوب للنشر.
- ❌ App Store Connect listing — متطلباته أكتر من Google: app preview
  video، 6.5" screenshots، iPad screenshots لو بتدعم iPad.
- ❌ App Tracking Transparency prompt — مطلوب iOS 14.5+. لسه مش
  implemented فى الـ app.

### 9. � Legal — معمول بشكل احترافى (تصحيح للنسخة السابقة)
- ✅ **Terms of Service**: `lib/pages/terms_page.dart` — 831 سطر، 25 بند
  bilingual (AR/EN) بنمط Airbnb. تشمل دور المنصة كـ neutral intermediary،
  Limitation of Liability capped at EGP 1,000، Force Majeure، Indemnification،
  وCRCICA arbitration اختيارى.
- ✅ **Privacy Policy** مدمجة فى نفس الصفحة (البند 22) — متوافقة مع
  **قانون حماية البيانات الشخصية المصرى رقم 151/2020**، PCI-DSS encryption،
  ومدة احتفاظ 5 سنوات للسجلات المالية.
- ✅ **سياسة الإلغاء والاسترداد** كاملة (البند 9):
  - ≥14 يوم: 100% استرداد
  - 7–13 يوم: 50%
  - 3–6 أيام: 25%
  - <48 ساعة أو عدم حضور: 0%
  - إلغاء المالك: 100% فورى للضيف
- ✅ **3 cancellation tiers** (flexible/moderate/strict) implemented فى
  `lib/models/refund_quote.dart` ومتطابقة مع backend.
- ✅ **Acceptance Gate**: `lib/pages/terms_acceptance_page.dart` بتظهر
  **إجبارياً** قبل دخول الأبلكيشن (mounted فى `main.dart:420`)، فيها
  checkbox عمر 18+ ولا يكمل المستخدم بدون قبول صريح.
- ⚠️ **النواقص البسيطة الوحيدة:**
  - مفيش صفحة web `talaa.app/privacy` (مطلوبة فى Play Console + App Store
    Connect — حتى لو كانت نفس النص فى صفحة HTML واحدة).
  - الـ emails (`legal@talaa.app`, `privacy@talaa.app`, `support@talaa.app`)
    لازم تكون نشطة فعلاً مع mailbox شغّال — مش مجرد placeholders.
  - مراجعة محامى مصرى **اختيارية** (النص قوى لكن مراجعة بشرية تحمى من
    تفاصيل دقيقة فى قانون السياحة المصرى).

### 10. 🟢 الإعدادات اللى تمام دلوقتى
- `PLATFORM_FEE_PERCENT=10.0` ✅ (Wave 25)
- `PAYOUT_HOLD_DAYS=1` ✅
- `DISBURSE_SLA_HOURS=48` ✅
- `DISBURSE_RECONCILE_INTERVAL_MIN=60` ✅
- `RATE_LIMIT_PER_MINUTE=100` ✅
- `JWT_EXPIRE_MINUTES=1440` (24h) ✅
- `WALLET_MAX_REDEEM_PERCENT=50.0` ✅
- `REFERRAL_REWARD_AMOUNT=100.0` ✅

---

## 🚦 ترتيب الأولويات قبل الـ Soft Launch

### قبل ما تجرّب على ٥ مستخدمين حقيقيين
1. ✅ S3 شغّال (تم)
2. ✅ Backend شغّال locally (تم)
3. ❌ نشر backend على VPS مع HTTPS
4. ❌ Sentry DSN
5. ❌ Database backup cron

### قبل ما تروح Public Beta
6. ❌ Paymob production keys + sandbox test
7. ❌ Firebase google-services files
8. ❌ Privacy + Terms مكتوبين بشكل صح
9. ❌ Android keystore + Play Store listing
10. ❌ S3 lifecycle + CORS

### قبل ما تروح Production كامل
11. ❌ Kashier disbursement مفعّل ومُختبر
12. ❌ App Store listing
13. ❌ CloudFront للـ S3 (latency)
14. ❌ Database connection pooling
15. ❌ Load testing (e.g., k6 with 100 concurrent bookings)

---

## 📊 إحصائيات سريعة من الـ codebase

| المؤشر | القيمة |
|---|---|
| Flutter pages | 70+ |
| FastAPI routers | 25+ |
| Backend tests passing | 27/27 |
| Lines of Dart | ~50,000 |
| Lines of Python | ~15,000 |
| Database tables | 30+ |
| Alembic migrations | 30+ |
| Languages supported | 2 (ar, en) |
| Brand color refs cleaned today | 61 |

---

## 🆘 لو حاجة كسرت

1. Backend مش بيـ start: `docker compose logs api --tail=50`
2. الصور مش بترفع: شغّل `python scripts/check_s3.py` (موجود فى الـ backend)
3. Disburse مش شغّال: `pytest tests/test_disburse.py -v`
4. الألوان عادت أزرق: `git diff lib/widgets/constants.dart` — لازم
   `AppColors.primary = Color(0xFFFF6B35)`.

---

**آخر تحديث:** 2026-04-26 · بعد اعتماد البرتقالى وإصلاح S3 و disbursement.
