# Talaa — Build & Deploy Runbook

This doc covers **production** builds and the security-hardening
checklist that every release must pass.

---

## 1. Flutter Release Builds

### 1.1 Android — obfuscated APK / AAB

Always ship release binaries with code obfuscation so an attacker
unzipping your APK can't read class names, method names or string
constants.

```powershell
# Bump versions in pubspec.yaml first, then:

flutter build apk --release `
    --obfuscate `
    --split-debug-info=build/symbols/android

# …or the Play Store bundle:
flutter build appbundle --release `
    --obfuscate `
    --split-debug-info=build/symbols/android
```

* `--obfuscate` renames symbols in the compiled Dart AOT snapshot.
* `--split-debug-info=<dir>` writes the un-obfuscation symbols to
  the given directory so Sentry / crash reports can still be
  symbolicated.
* **Commit `build/symbols/android` to a private artefact store** —
  never to the public git repo — so you can de-obfuscate stack
  traces from users later.

### 1.2 iOS — obfuscated IPA

```powershell
flutter build ipa --release `
    --obfuscate `
    --split-debug-info=build/symbols/ios
```

Same rules about keeping the symbols directory private.

### 1.3 Never ship debug builds

Release builds strip `assert()` calls, disable the Dart VM service,
and remove debug logs.  Debug builds expose an observatory port and
are trivially attachable with `flutter attach`.

---

## 2. Backend — Production Config

The backend refuses to start in production with insecure defaults.
Every variable below **must** be set before the first boot.

| Variable | Purpose | How to generate |
|---|---|---|
| `APP_ENV=production` | Enables HSTS, HTTPS redirect, proxy-header trust, and the safety gate. | — |
| `DEBUG=false` | Disables verbose errors. | — |
| `SECRET_KEY` | Signs JWTs. Must be ≥ 32 chars, must not be `"change-me"`. | `python -c "import secrets; print(secrets.token_urlsafe(48))"` |
| `ALLOWED_ORIGINS` | Exact CORS origins (no `*`). | e.g. `["https://talaa.app","https://admin.talaa.app"]` |
| `ALLOW_UNVERIFIED_WALLET_TOPUP=false` | Forces wallet top-ups through the Paymob webhook. | — |
| `DATABASE_URL` | Async Postgres DSN. | — |
| `REDIS_URL` | Rate limiter + cache. | — |
| `FIREBASE_CREDENTIALS_JSON` | Service-account JSON (single line). | Firebase console → Project settings → Service accounts |
| `PAYMOB_HMAC_SECRET` / `FAWRY_SECRET_KEY` | Webhook signature verification. | Gateway dashboards |

If any of the production safety checks fail, the app logs the full
list of problems and exits **before** binding the HTTP port.

---

## 3. Security Checklist (pre-release)

Run through this before every store upload.

### Mobile

- [ ] `flutter analyze` passes with zero issues.
- [ ] Release build uses `--obfuscate --split-debug-info=…`.
- [ ] App requests only the permissions it actually uses.
- [ ] Tokens are stored via `SecureTokenStorage` (verified by
      inspecting `lib/utils/api_client.dart`).
- [ ] Sentry breadcrumb filter masks `authorization`, `token`,
      `refresh_token`, `fcm_token` (see `sentry_service.dart`).
- [ ] Android `android:allowBackup="false"` in `AndroidManifest.xml`.
- [ ] iOS `Info.plist` has `NSAppTransportSecurity` without arbitrary
      loads.

### Backend

- [ ] `pytest` green (including `test_security_headers.py`).
- [ ] `SECRET_KEY` is a freshly generated 48-char token.
- [ ] `ALLOWED_ORIGINS` lists the exact front-end origin(s) — no `*`.
- [ ] `APP_ENV=production`, `DEBUG=false`.
- [ ] Rate limits tuned: `RATE_LIMIT_PER_MINUTE`, `/auth`, `/payments`.
- [ ] Firebase service account has `check_revoked=True` verified.
- [ ] Paymob & Fawry webhook URLs registered with HTTPS only.
- [ ] `ALLOW_UNVERIFIED_WALLET_TOPUP=false`.
- [ ] Sentry DSN set and alerts routed to on-call.
- [ ] Database backups scheduled (daily snapshot, 7-day retention
      at minimum).

---

## 4. Local Dev — quick start

```powershell
# Backend
cd yalla_trip_backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload

# Mobile
cd ..
flutter pub get
flutter run
```

Local dev runs with `APP_ENV=development` so the safety gate is
off, HSTS is off, HTTPS redirect is off — everything works on
plain `http://localhost:8000`.
