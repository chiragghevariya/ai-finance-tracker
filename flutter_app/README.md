# AI Finance Tracker — Flutter app (Phase 3)

The mobile front-end for the Laravel API built in Phases 1 & 2.

Stack: **Flutter 3.x · Provider · Dio · fl_chart · camera · image_picker**

## What's inside

```
lib/
  config/        api_config.dart (base URL + endpoints), app_theme.dart (colors)
  models/        user, category, transaction, summary  (match the API JSON)
  services/      api_service.dart  (Dio + automatic JWT header)
  providers/     auth_provider.dart, transaction_provider.dart
  screens/       splash, login, register, home + tabs/(dashboard, transactions, ai_chat, profile)
  widgets/       transaction_card, balance_card, category_pie_chart, add_transaction_sheet
  utils/         parsers, color_utils, formatters
```

## Setup & run

This folder holds the source (`lib/`, `pubspec.yaml`). You first need the
platform folders (`android/`, `ios/`, …), which Flutter generates for you.

**1. Generate the platform folders (without touching the Dart code):**
```bash
cd flutter_app
flutter create --platforms=android,ios,web .
```
> The `--platforms` form *adds* platform support to this existing project and
> leaves `lib/` and `pubspec.yaml` alone. (If you ever run a plain
> `flutter create .` and it overwrites `lib/main.dart` or `pubspec.yaml`, just
> restore the versions from this folder — they are the source of truth.)

**2. Install packages and run:**
```bash
flutter pub get
flutter run
```

## Point the app at your backend

Edit `lib/config/api_config.dart` → `baseUrl`. Pick the host for where you run:

| Running on            | baseUrl                                   |
|-----------------------|-------------------------------------------|
| Android emulator      | `http://10.0.2.2:8000/api`  (default)     |
| iOS simulator         | `http://127.0.0.1:8000/api`               |
| Real phone (same wifi)| `http://<your-PC-LAN-IP>:8000/api`        |

Start the backend first:
```bash
# in the Laravel project root
php artisan serve            # serves on http://127.0.0.1:8000
```

### ⚠️ Android: allow local HTTP (cleartext)

Android 9+ blocks plain `http://` by default. After step 1, open
`android/app/src/main/AndroidManifest.xml` and add `usesCleartextTraffic` to the
`<application>` tag so the emulator can reach `http://10.0.2.2:8000`:

```xml
<application
    android:label="ai_finance_tracker"
    android:usesCleartextTraffic="true"
    ... >
```

## Demo login

Phase 1's seeder creates a demo user:

- **email:** `test@example.com`
- **password:** `password`

Or tap **Register** to make a new account.

## Notes

- **AI features (Phase 4) are wired up:** the **AI Chat** tab posts to
  `/api/ai/chat`; the add-transaction sheet's camera button scans receipts via
  `/api/receipt/scan` and auto-fills the form; and typing a description triggers
  auto-categorize (`/api/transactions/auto-categorize`) after a 1-second debounce.
  All of them show a friendly message (not a crash) if the backend's
  `OPENAI_API_KEY` is unset.
- Profile → monthly budget is saved on-device for now (the backend has no
  update-profile endpoint yet — a small `PUT /api/profile` would persist it).

### Camera / photo permissions (needed for the receipt scanner)

`image_picker` needs these once you actually open the camera/gallery:

**iOS** — add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Scan receipts to add transactions.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Pick a receipt photo to add a transaction.</string>
```

**Android** — the default camera/gallery pickers use the system picker, so no
extra manifest permission is required. Just keep `compileSdk` recent.
```
