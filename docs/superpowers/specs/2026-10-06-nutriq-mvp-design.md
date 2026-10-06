# Nutriq MVP — Design Spec

Date: 2026-10-06 · Status: approved by brief (owner asked for decisions without a Q&A round)

## 1. Intent (what success looks like)

The owner wants a **free, iPhone-first Flutter app called Nutriq** that friends can install and try:
photo (or manual) → editable nutrition estimate → daily log → a supportive coach, with a short
onboarding that produces an honest, editable "starting point".

Success for this MVP = a friend can install a build on their phone, finish onboarding in under a minute,
log a meal from a photo or by hand, correct it easily, see it on Today/History, chat with the coach,
and clearly understand what is an estimate and what is demo-only.

**Said by the owner:** free, no paywall/ads; local-first; no login; demo analyzer and demo coach when
no backend; label estimates; editable foods/portions/date/time; save foods without logging; under-18 and
health-condition safeguards; CoachService + FoodAnalysisService interfaces; no API keys in the app;
dark graphite look; README with device + TestFlight + Android internal testing steps.

**Assumed by me (owner can override later):**
- Bundle id `com.prodbyjake.nutriq` (unique, easy to change).
- Calorie formula: Mifflin–St Jeor. The sex term is asked for and **optional**; if skipped we use the
  midpoint of the two constants and say so.
- A "Day starts at" setting (default midnight) so night-shift meals can count toward the previous day.
- Coach chat is kept in memory only (cleared when the app closes) — less data stored, simpler privacy story.
- iPhone portrait only; Android adapts with Material components.
- No custom fonts: system font (SF Pro on iOS, Roboto on Android) for native feel.

## 2. Platform & delivery plan (how the owner runs it and shares it)

| Goal | Path | Cost | Notes |
|---|---|---|---|
| Try on Mac | iOS Simulator (`flutter run`) | free | Camera unavailable in Simulator — use "Choose photo". |
| Own iPhone | Xcode → Signing → Personal Team, Developer Mode on phone, `flutter run --release` | free | Free-team builds expire after 7 days; max 3 apps. |
| A friend nearby, free | Plug their iPhone into the Mac, same as above | free | Their device gets registered to your personal team; 7-day expiry. |
| Friends anywhere (iOS) | Apple Developer Program → App Store Connect → `flutter build ipa` → TestFlight | $99/yr | Internal testers instantly; external testers after a light beta review; public link. |
| Friends (Android) | Install Android Studio/SDK → `flutter build apk --release` → send APK, or Play Console internal testing | free / $25 once | SDK not installed on this Mac yet. |

## 3. Architecture

Plain Flutter, minimal dependencies, layered:

```
UI (features/*, widgets/*)
  ↓ reads/writes via
State (ChangeNotifier controllers: ProfileController, MealLogController, CoachController)
  ↓ uses
Services (FoodAnalysisService, CoachService, PhotoService)   Domain (models, StartingPoint, DayBoundary, Units)
  ↓
Data (LocalStore interface → SqliteLocalStore)
```

- **DI:** an `AppScope` InheritedWidget exposes controllers and services. Screens rebuild with
  `ListenableBuilder`. No state-management package (keeps the dependency surface tiny for friends' builds).
- **Persistence:** `sqflite`. Tables: `meals` (items as JSON column), `saved_foods`, `scan_feedback`,
  `kv` (profile JSON, settings JSON). Photos copied into the app's documents folder; deleted with their meal.
- **Dependencies:** `sqflite`, `path`, `path_provider`, `image_picker`, `intl`.
  Dev: `flutter_lints`, `sqflite_common_ffi` (DB tests on macOS), `flutter_launcher_icons`.
- **App name:** `lib/app/app_config.dart` (`AppConfig.appName`). Home-screen labels live in
  `ios/Runner/Info.plist` (`CFBundleDisplayName`) and `android/app/src/main/AndroidManifest.xml` (`android:label`) — README says so.

## 4. Domain rules

### 4.1 Starting point (`lib/domain/starting_point.dart`)
- Inputs: age, sex-for-estimate (optional), height cm, weight kg, activity level, goal, health considerations.
- **Eligibility, in order:**
  1. `age < 18` → `under18`: no calorie numbers, no protein reference, explain why; logging still works.
  2. any of pregnant / breastfeeding / relevant medical condition → `healthConsideration`: no numbers;
     suggest a qualified professional; adults may enter a professional-given range later in Settings.
  3. missing age, height, weight or activity → `needsMoreInfo` listing exactly what's missing.
  4. otherwise `eligible`.
- BMR = 10·kg + 6.25·cm − 5·age + s, s = +5 (male), −161 (female), −78 (not provided → midpoint).
- Maintenance = BMR × activity (1.2 / 1.375 / 1.55 / 1.725 / 1.9), rounded to nearest 10.
- Goal range (rounded to nearest 50):
  - lose body fat: low = max(floor, M−500), high = max(low+100, M−250), floor = max(1200, BMR).
    If M−250 < floor, **no deficit is suggested**: use the maintain range and explain.
  - maintain / general fitness / eat consistently: M−100 … M+100.
  - gain muscle: M+150 … M+350. build strength: M … M+250.
- Protein reference (rounded to 5 g): 1.6 g/kg for lose fat, gain muscle, build strength; 1.2 g/kg otherwise.
- When sex is not provided, report the uncertainty: ±round10(83 × activity factor) kcal.
- Goal weight: if it implies BMI < 18.5, show a gentle note suggesting a professional (no blocking).
- All results carry a human-readable list of assumptions for the "How we estimated this" panel.

### 4.2 Day boundary (`lib/domain/day_boundary.dart`)
- `logicalDay(t, startHour)` = calendar date of `t − startHour` hours (computed with DateTime field
  arithmetic to be DST-safe). `dayRange(day, startHour)` = `[day@startHour, day+1@startHour)`.

### 4.3 Meals
- `FoodItem`: id, name, servings (multiplier), servingLabel, per-serving kcal/protein/carbs/fat, optional confidence.
  Totals = per-serving × servings.
- `Meal`: id, loggedAt (editable), type (breakfast/lunch/dinner/snack, suggested from time), photoPath?,
  source (demoScan / scan / manual), items, note?.
- `SavedFood`: a FoodItem template saved without logging.
- `ScanFeedback`: mealId?, rating (tooHigh / aboutRight / tooLow), note?, createdAt.

## 5. Services
- `FoodAnalysisService { bool isDemo; Future<FoodAnalysisResult> analyze(Uint8List bytes); }`
  - `DemoFoodAnalysisService`: picks one of 8 sample meals **deterministically from the photo bytes**
    (same photo → same sample), simulated delay, `isDemo = true`, never uploads anything.
- `CoachService { bool isDemo; Future<CoachReply> reply(...); CoachInsight insight(CoachContext); }`
  - `DemoCoachService`: rule-based replies computed from the real profile/log; every reply runs through
    `CoachSafety` first (eating-disorder cues, extreme restriction, medical/diagnosis, guaranteed predictions,
    under-18 dieting, health-flag dieting). Labeled "Demo coach — scripted replies, not live AI".
- `PhotoService`: wraps image_picker; maps cancel / permission denied / no camera / unknown to typed failures;
  copies picked photos into app storage.

A real backend later = implement the two interfaces against **your own server** (which holds the AI
provider key). Nothing secret ships in the app.

## 6. UX & visual system

- **Theme:** graphite `#0F1012` background, surfaces `#18191C` / `#212327`, hairlines `#2B2D31`, warm-white
  text `#F5F5F2`, secondary `#A3A6AB`, tertiary `#6E7277`; accents: sage green `#8BD8A0` (primary, protein),
  warm amber `#F0B357` (carbs, demo/estimate badges, above-range state), periwinkle `#9DB4F0` (fat),
  coral `#F07A6A` (destructive only). Big numbers: system font, w600, tabular figures, negative tracking.
- **Signature visual:** a 240° open **range gauge** — the goal is drawn as a *band* on the arc rather than a
  single target, reinforcing "estimate + range", not a pass/fail number.
- **Navigation:** 4 tabs — Today, History, Coach, Settings. iOS: translucent blurred tab bar;
  Android: Material 3 NavigationBar. Scan opens as a full-screen modal; edits use bottom sheets.
- **Today:** large-title date → range gauge → macro split bar + P/C/F → **Scan meal** (primary) + Add manually →
  coach insight card → today's meals.
- **Scan:** demo notice, Take photo / Choose photo, then selected image with an analyzing state
  (reduced-motion aware). Errors offer retry and manual entry.
- **Review/Edit (one editor for new and saved meals):** demo banner, photo, estimated totals with Estimate badge,
  editable food cards (servings stepper, edit sheet, swipe/remove, save-to-My-foods), add food (My foods, recent,
  manual), date/time + meal type, Save to log, "Save foods without logging". Unsaved-changes guard.
- **History:** week navigator + 7-day bar chart with the goal band, tap a day, meal list, meal detail
  (edit, change date/time, delete, rate estimate).
- **Coach:** demo label, chat bubbles, suggested prompts, composer; prompts can be pre-filled from Today.
- **Settings:** profile (edit/recalculate), goals (range + protein, custom range for eligible adults),
  units, day start, My foods, scan feedback (rate + copy summary), privacy & data (what's stored, delete profile,
  delete meals, delete everything), about + disclaimers.
- **Onboarding (6 steps, all optional after Welcome):** Welcome → Goal → About you (age, sex-for-formula, units,
  height, weight, goal weight) → Activity (+ workout days) → Health check → Your starting point.
- **Motion/feel:** press feedback on touch-down (scale 0.97), light haptics on steppers, success haptic on save,
  respects reduced motion; 44pt+ touch targets; safe areas everywhere.

## 7. Error handling
- Photo: cancel → stay, no error; permission denied → explain how to enable in Settings + manual entry;
  no camera → suggest library; unknown → retry + manual.
- Analysis: exception → error card with retry + manual; empty result → editor opens with "add what you ate".
- Storage: load failures surface a simple error screen with retry (startup) rather than crashing.
- Forms: inline validation (age 13–100, height 100–250 cm, weight 30–300 kg, calories 0–5000 per serving).

## 8. Testing
- Unit (TDD): starting point (formula, ranges, floor, eligibility), day boundary, units, meal totals + JSON,
  demo analyzer determinism, coach safety + intents, controllers with an in-memory store, SQLite store roundtrip (ffi).
- Widget: first launch → onboarding; skip → Today; review edits change totals and save to log; coach shows demo label.
- Manual: run on iOS Simulator; screenshot each main screen.

## 9. Out of scope (this version)
Barcode scanning, social, wearables, workout planning, meal plans, accounts/sync, analytics, real AI backends.
