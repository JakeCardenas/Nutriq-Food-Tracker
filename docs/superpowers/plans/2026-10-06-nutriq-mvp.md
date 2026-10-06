# Nutriq MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> Execution method chosen: **Native** (implemented in-session; the owner asked for no stop-and-ask gates).

**Goal:** A free, local-first Flutter app (Nutriq) for iOS/Android: onboarding → starting point → scan/manual → review/edit → daily log → demo coach.

**Architecture:** Plain Flutter + ChangeNotifier controllers exposed through an `AppScope` InheritedWidget; pure-Dart domain logic (starting point, day boundary, units); `LocalStore` interface backed by sqflite; `FoodAnalysisService` / `CoachService` interfaces with clearly-labeled demo implementations.

**Tech Stack:** Flutter 3.47.5 / Dart 3.13.4, sqflite 2.4.x, image_picker 1.2.x, path_provider 2.1.x, intl 0.20.x; dev: flutter_lints, sqflite_common_ffi, flutter_launcher_icons.

**Spec:** `docs/superpowers/specs/2026-10-06-nutriq-mvp-design.md`

## Global Constraints

- App name lives in `lib/app/app_config.dart` only (plus the two native home-screen labels, documented in README).
- Bundle/application id: `com.prodbyjake.nutriq`.
- No network calls, analytics, logins, ads or paywalls. No API keys anywhere in the app.
- Every nutrition number shown to the user is labeled as an estimate (badge, "est." or "≈").
- Demo analyzer and demo coach are labeled "Demo" wherever their output appears; demo never claims to recognize a photo.
- No calorie targets or dieting coaching when age < 18; no personalized targets with pregnancy/breastfeeding/medical condition.
- Dark graphite theme tokens exactly as in spec §6; system fonts; touch targets ≥ 44pt.
- `flutter analyze` clean and `flutter test` green before claiming done.

## Review Focus

1. Late-night meal with "Day starts at 4 AM" → appears on the previous day in Today/History (test in Task 2 + Task 5).
2. Editing servings to 0 or typing non-numeric text in a nutrient field → no crash; validation message; totals never NaN (Task 7 tests).
3. User skips every onboarding field → lands on Today with no goal and no crash; gauge shows "No calorie goal" (Task 9 widget test).
4. Under-18 user asks coach "how do I lose weight fast" → safety reply, no numbers (Task 4 test).
5. Deleting a meal also deletes its photo file; "Delete everything" returns to onboarding (Task 5 + Task 11).

---

### Task 1: Scaffold, config, theme, dependencies
**Files:** `pubspec.yaml`, `lib/app/app_config.dart`, `lib/app/theme.dart`, `analysis_options.yaml`, iOS `Info.plist`, Android manifest, launch screens.
- [ ] `flutter create --org com.prodbyjake --project-name nutriq --platforms ios,android .`
- [ ] Add dependencies; set display names, camera/photo usage strings, portrait-only iPhone, dark launch background.
- [ ] `flutter analyze` clean.

### Task 2: Domain — units, day boundary, models
**Files:** `lib/domain/units.dart`, `lib/domain/day_boundary.dart`, `lib/domain/models/*.dart`
**Produces:** `cmToFeetInches(double) → (int ft, int inch)`, `feetInchesToCm(int,int)`, `kgToLb`, `lbToKg`;
`DateTime logicalDay(DateTime t, int startHour)`, `DateTimeRange dayRange(DateTime day, int startHour)`;
`FoodItem`, `Meal`, `NutritionTotals`, `SavedFood`, `ScanFeedback`, `UserProfile`, `AppSettings`, enums
`FitnessGoal`, `ActivityLevel`, `SexForEstimate`, `HealthConsideration`, `MealType`, `MealSource`, `UnitSystem`, `FeedbackRating`.
Tests (write first, watch fail):
- [ ] `logicalDay(2026-10-07 02:30, 4)` → 2026-10-06; `logicalDay(2026-10-07 04:00, 4)` → 2026-10-07; startHour 0 → same date.
- [ ] `dayRange(2026-10-06, 4)` → start 2026-10-06 04:00, end 2026-10-07 04:00.
- [ ] `cmToFeetInches(180)` → (5, 11); `feetInchesToCm(5, 11)` ≈ 180.34; `kgToLb(80)` ≈ 176.37; rollover `cmToFeetInches(182.8)` → (6, 0).
- [ ] FoodItem servings 1.5 × 200 kcal → 300; servings 0 → 0 (no NaN); Meal totals sum items; JSON roundtrip equality for Meal, UserProfile, AppSettings.
- [ ] `MealType.suggestFor(DateTime)`: 08:00 breakfast, 12:30 lunch, 15:30 snack, 19:00 dinner, 23:30 snack.

### Task 3: Domain — starting point
**Files:** `lib/domain/starting_point.dart`, test `test/domain/starting_point_test.dart`
**Produces:** `StartingPoint.calculate(UserProfile) → StartingPointResult` with `eligibility`, `missing`, `bmr`,
`maintenance`, `range (CalorieRange{min,max})`, `proteinReferenceG`, `sexMidpointUsed`, `uncertaintyKcal`,
`deficitNotSuggested`, `lowGoalWeightNote`, `assumptions`.
Tests:
- [ ] male 30y 180cm 80kg moderate: bmr 1780, maintenance 2760; loseFat 2250–2500; gainMuscle 2900–3100; maintain 2650–2850; buildStrength 2750–3000; protein gainMuscle 130, maintain 95.
- [ ] female same: maintenance 2500. sex omitted: maintenance 2630, `sexMidpointUsed`, uncertainty 130.
- [ ] female 60y 155cm 50kg sedentary loseFat → `deficitNotSuggested`, range = maintain range.
- [ ] age 16 → `under18`, no range/protein. Pregnant → `healthConsideration`, no range.
- [ ] missing weight + activity → `needsMoreInfo`, missing lists both.
- [ ] goal weight 50 kg at 180 cm → `lowGoalWeightNote` true; 70 kg → false.

### Task 4: Services — analysis + coach
**Files:** `lib/services/food_analysis/{food_analysis_service,demo_food_analysis_service,demo_samples}.dart`,
`lib/services/coach/{coach_service,demo_coach_service,coach_safety}.dart`
**Produces:** `FoodAnalysisService`, `FoodAnalysisResult{items,isDemo,sampleName}`, `FoodAnalysisException`;
`CoachService`, `CoachContext`, `CoachReply{text,isDemo,kind}`, `CoachInsight{text,suggestedPrompt}`, `CoachSafety.check(String, CoachContext) → CoachReply?`.
Tests:
- [ ] Demo analyzer: same bytes → same sample; result `isDemo`; ≥1 item; empty bytes → `FoodAnalysisException`.
- [ ] Coach: "How am I doing with my protein today?" with 62 g logged and 130 g target → text contains "62" and "130"; no meals → mentions logging first.
- [ ] Safety: "I want to eat 600 calories a day" → kind `safety`; "how do I purge" → kind `safety`; "do I have diabetes" → `medical`; age 16 + "how do I lose weight fast" → `safety`, contains "under 18"; "how fast will I lose 10 kg" → `prediction`.
- [ ] Every DemoCoach reply `isDemo == true`; unknown topic → fallback listing supported topics.

### Task 5: Data — LocalStore + SQLite
**Files:** `lib/data/local_store.dart`, `lib/data/sqlite_local_store.dart`, `test/support/memory_local_store.dart`, `test/data/sqlite_local_store_test.dart`
**Produces:** `LocalStore` with `loadProfile/saveProfile/clearProfile`, `loadSettings/saveSettings`, `allMeals/upsertMeal/deleteMeal/deleteAllMeals`,
`savedFoods/addSavedFood/deleteSavedFood`, `feedback/addFeedback`, `wipe()`.
Tests (sqflite ffi, in-memory DB):
- [ ] upsert meal → allMeals returns equal meal; upsert again with new loggedAt updates; delete removes.
- [ ] profile save/load/clear; settings default when empty; wipe clears all tables.

### Task 6: State controllers + photo service
**Files:** `lib/state/{profile_controller,meal_log_controller,coach_controller}.dart`, `lib/services/photo_service.dart`
Tests with `MemoryLocalStore`:
- [ ] MealLogController: meal at 02:30 with dayStart 4 appears in `mealsForDay(previous day)`; moving loggedAt moves it; delete calls photo deleter with photoPath.
- [ ] ProfileController: `completeOnboarding(profile, goal)` persists and sets `onboardingComplete`; `clearProfile` keeps meals; `resetAll` clears everything and `onboardingComplete == false`.
- [ ] CoachController: `send` appends user + coach messages; `draft` set by `prefill`.

### Task 7: Shared widgets + meal editor
**Files:** `lib/widgets/*`, `lib/features/meal_editor/*`
- [ ] Widget test: editor with demo items shows "Demo" banner and "Estimate"; tapping + on servings updates total kcal; Save to log adds a meal; "Save foods without logging" adds saved foods and no meal; invalid calorie text shows validation, no crash.

### Task 8: Scan flow
**Files:** `lib/features/scan/scan_screen.dart`
- [ ] Handles cancel / permission denied / no camera / analysis error / empty result with manual fallback (widget test with fake PhotoService + fake analyzer that throws).

### Task 9: Onboarding + starting point view
**Files:** `lib/features/onboarding/*`, `lib/features/starting_point/starting_point_view.dart`
- [ ] Widget test: first launch shows Welcome; "Skip" → Today with "No calorie goal"; full path with valid inputs shows "Your starting point" and "estimate".

### Task 10: Today, History, Coach screens, shell
**Files:** `lib/features/{today,history,coach,shell}/*`
- [ ] Widget test: Today shows Scan meal; logged meal kcal appears; Coach tab shows "Demo coach" label and suggested prompts.

### Task 11: Settings, privacy & feedback
**Files:** `lib/features/settings/*`
- [ ] Widget test: "Delete everything" confirm → onboarding Welcome shown.

### Task 12: Icon, README, device run
- [ ] Generate icon PNG via `flutter test tool/generate_icon_test.dart`, then `dart run flutter_launcher_icons`.
- [ ] README: run on Simulator/iPhone, demo vs real, TestFlight + Android internal testing, tester questions.
- [ ] Build & launch on iOS Simulator; screenshot each main screen; fix issues.
