# Nutriq

Snap a meal. Check the estimate. Keep a calm daily log.

Nutriq is a free, local-first food logging app for iPhone (and Android) built with Flutter.
Take or choose a meal photo, review and correct the suggested foods, and save meals to a daily log.
A short optional onboarding creates a personal starting point, and a coach helps with your goal.
No account, no ads, no paywall — and every number is labeled as an estimate.

---

## What's real and what's demo

| Feature | Status |
|---|---|
| Onboarding, starting-point estimate (Mifflin–St Jeor), editable goal range | **Real** — computed on the device |
| Under-18 and health-condition safeguards (no calorie targets) | **Real** |
| Meal log, History, editing foods/portions/date/time, My foods, scan feedback | **Real** — stored on the device (SQLite) |
| Taking/choosing a photo | **Real** — photo is kept on the phone, never uploaded |
| **Food recognition from the photo** | **Demo only.** Returns one of 8 sample meals (same photo → same sample). The app says so on the scan screen and the review screen. It does **not** look at what's in the photo. |
| **Coach** | **Demo only.** Rule-based, scripted replies that use your real profile and log (e.g. protein so far). Labeled "Demo coach — not live AI". Safety rules (extreme restriction, eating-disorder cues, medical questions, predictions, under-18 dieting) are real. |
| Accounts, cloud sync, analytics, barcode scanning | Not included in this version |

To make analysis or coaching real, implement `FoodAnalysisService` / `CoachService` against **your own
backend** (see [Connecting a real AI backend](#connecting-a-real-ai-backend)). Never put AI-provider keys in the app.

---

## Run it

Prerequisites on this Mac: Flutter 3.47+, Xcode (installed). Android needs Android Studio (not installed yet).

```bash
flutter pub get
```

```bash
flutter test
```

### On the iOS Simulator

```bash
open -a Simulator
```

```bash
flutter run
```

The Simulator has no real camera — use **Choose photo** (it includes sample photos).

### On your own iPhone (free, no paid developer account)

1. **Xcode → Settings → Accounts** → add your Apple ID.
2. Open the iOS project:
   ```bash
   open ios/Runner.xcworkspace
   ```
   Select **Runner** → **Signing & Capabilities** → **Team** → *Your Name (Personal Team)*.
   If Xcode says the bundle ID is taken, change `com.prodbyjake.nutriq` to something unique (e.g. `com.yourname.nutriq`).
3. On the iPhone: plug it in with a cable, tap **Trust**, then turn on
   **Settings → Privacy & Security → Developer Mode** (the phone restarts).
4. Find the device and run a release build (release builds keep working after you unplug):
   ```bash
   flutter devices
   ```
   ```bash
   flutter run --release -d <your-device-id>
   ```
5. If iOS blocks the first launch: **Settings → General → VPN & Device Management** → trust your developer profile.

Free "Personal Team" builds **expire after 7 days** — run step 4 again to refresh.
You can do the same for a friend who's sitting next to you: plug their iPhone in and repeat steps 3–5.

---

## Share with friends

### iPhone — TestFlight (recommended)

Needs the **Apple Developer Program** ($99/year).

1. Enroll at developer.apple.com, then set your paid team in Xcode (**Signing & Capabilities → Team**).
2. In **App Store Connect → Apps → +**, create the app with bundle ID `com.prodbyjake.nutriq`
   (App Store names are unique — if "Nutriq" is taken, use something like "Nutriq: Food Log").
3. Each upload needs a higher build number. Bump it in `pubspec.yaml` (e.g. `version: 0.1.0+2`), then:
   ```bash
   flutter build ipa --release
   ```
4. Upload `build/ios/ipa/*.ipa` with Apple's **Transporter** app, or open
   `build/ios/archive/Runner.xcarchive` in Xcode → **Distribute App → App Store Connect**.
5. In **TestFlight**: fill in *Test Information* (description, feedback email).
   - **Internal testers** (people on your App Store Connect team, up to 100) can install right away.
   - **External testers** (anyone, by email or a **public link**) need a quick Beta App Review for the first build.
   Export compliance is pre-answered (`ITSAppUsesNonExemptEncryption = NO` in `Info.plist`).
6. Friends install the **TestFlight** app and open your invite. Builds expire after 90 days.

### Android

Install Android Studio (it installs the Android SDK), then:

```bash
flutter doctor --android-licenses
```

- **Quickest:** build an APK and send it (friends allow "Install unknown apps"):
  ```bash
  flutter build apk --release
  ```
  File: `build/app/outputs/flutter-apk/app-release.apk`. (This uses Flutter's default debug signing — fine for friends, not for the Play Store.)
- **Google Play internal testing** ($25 one-time Play Console fee): create an upload keystore
  (see Flutter's "Build and release an Android app" guide), then upload an app bundle to
  **Testing → Internal testing** and share the opt-in link:
  ```bash
  flutter build appbundle --release
  ```

> The Android project is set up (label, icons, dark launch screen, portrait), but it hasn't been built or run yet
> because this Mac has no Android SDK.

---

## Questions for testers

Ask friends to answer these after a day or two of use (they can also rate scans in **Settings → Scan feedback**
and tap **Copy feedback summary** to send you their ratings):

1. Did the food suggestion look plausible?
2. Was it easy to correct the food and portion?
3. Was the estimate label clear?
4. Did the starting goal feel understandable and editable?
5. Was the coach helpful and relevant?
6. What felt confusing or slow?

Remind them: in this build, photo results and coach replies are **demo samples**, so judge the *flow*, not the accuracy.

---

## Rename the app

- In the app: `lib/app/app_config.dart` → `AppConfig.appName`.
- Home-screen label: `ios/Runner/Info.plist` → `CFBundleDisplayName`, and
  `android/app/src/main/AndroidManifest.xml` → `android:label`.
- App icon: edit `lib/widgets/nutriq_mark.dart`, then regenerate:
  ```bash
  flutter test tool/generate_icon_test.dart && dart run flutter_launcher_icons
  ```

---

## How it works

```
lib/
  app/            config (app name), theme tokens, AppScope (dependency injection), formatting
  domain/         models, StartingPoint (calorie estimate + safeguards), day boundary, units
  data/           LocalStore interface + SQLite implementation
  services/       FoodAnalysisService + demo analyzer, CoachService + demo coach + CoachSafety, PhotoService
  state/          ProfileController, MealLogController, CoachController (ChangeNotifier)
  features/       onboarding, starting_point, today, scan, meal_editor, history, coach, settings, shell
  widgets/        calorie gauge, macro summary, buttons, cards, controls
test/             92 unit + widget tests (domain, services, SQLite store, controllers, screens, app flows)
docs/superpowers/ design spec and implementation plan
```

**Starting point:** resting energy (Mifflin–St Jeor) × activity multiplier = estimated maintenance, then a modest
goal adjustment shown as an editable range (rounded to 50 kcal). Sex is optional; if skipped, the midpoint constant is
used and the extra uncertainty is shown. No targets for people under 18 or anyone who reports pregnancy,
breastfeeding, or a relevant medical condition; a weight-loss range never goes below max(1,200, resting energy).
The "How we estimated this" panel lists every assumption.

**Night shifts:** **Settings → Day starts at** (midnight–6 AM) decides which day a late-night meal counts toward.
Any meal's date and time can also be edited.

**Privacy:** everything is stored on the phone (SQLite + app documents folder for photos). Coach chats aren't saved.
**Settings → Privacy & data** can delete the profile, all meals, or everything.

### Connecting a real AI backend

1. Run a small server you control (e.g. a serverless function). It holds the AI-provider key, rate-limits requests,
   and applies the same safety rules as `lib/services/coach/coach_safety.dart`.
2. Suggested endpoints:
   - `POST /analyze` (JPEG body) → `{ "items": [{ "name", "servingLabel", "servings", "kcal", "protein", "carbs", "fat", "confidence" }] }`
   - `POST /coach` (`{ message, profile, today, recentDays }`) → `{ "text" }`
3. Implement `FoodAnalysisService` and `CoachService` with HTTP calls to that server, set `isDemo` to `false`, and swap
   them in `lib/main.dart`. The UI already shows a "Low confidence — check this" tag when `confidence < 0.6`.
4. Before uploading photos, add a clear consent step and update the privacy copy in Settings.

---

Nutriq is for general wellness. Nutrition values are estimates for information only — not medical advice.
