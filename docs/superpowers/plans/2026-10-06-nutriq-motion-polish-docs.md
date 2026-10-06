# Nutriq motion, Cal AI polish, sync fixes and docs — implementation plan

**Goal:** Make Nutriq feel closer to Cal AI's food-tracking UX with fluid, gesture-driven iOS motion, fix the sync/health honesty gaps found in review, and replace the stale README with accurate setup docs.

**Architecture:** Same Flutter app and session/controller layers. One new motion primitive (`NqSheetRoute`, a spring-driven draggable sheet route) replaces `showModalBottomSheet` everywhere. Sync triggers move into `SessionController` (launch + app resume). No new packages.

**Tech stack:** Flutter 3.47 / Dart 3.13, `flutter/physics.dart` springs, Supabase Flutter, sqflite, health.

**Spec:** user brief of 2026-10-06 ("Improve the app in place…"), plus `docs/superpowers/specs/2026-10-06-nutriq-accounts-sync-health-redesign.md`.

## Global constraints

- Keep the name/brand "Nutriq"; no Cal AI logo, images or copied text; free, no paywall or ads.
- Never print, commit or expose `config/nutriq.json`; no service-role key, OAuth secret or AI key in the app.
- Do not apply migrations, change providers, deploy functions, change production data, or push commits.
- Don't weaken RLS. Nutrition numbers stay labelled as estimates; demo analysis/coach stay clearly labelled.
- Minors/health-consideration safeguards unchanged. HealthKit stays opt-in, iOS-only, on-device, separate from sync.
- Motion: critically damped (ζ = 1.0) springs by default; ζ ≈ 0.9 only after a flick; no global BouncingScrollPhysics; respect Reduce Motion; no animation packages.

## Review focus (inputs most likely to bite)

1. Grabbing a sheet mid-animation → it must follow the finger from where it is, not jump.
2. A slow drag released past half / a fast flick from anywhere → dismiss; a short drag → settle back without overshoot.
3. Reduce Motion on → sheets and the + menu cross-fade, no slides or springs.
4. App reopened while signed in → pulls other devices' changes without the person editing anything.
5. Delete account with an expired session → "sign in again", not a numeric error.

## Tasks

### 1. Spring sheet route (`lib/widgets/sheet.dart`)
- `NqSheetRoute<T>` (PopupRoute): scrim fades with progress; sheet translates by `(1 - progress) * height`.
- Drag on the handle/header area (and anywhere when the content isn't scrolled) tracks 1:1; dragging up past fully open rubber-bands.
- Release: project `position + v·0.998/(1-0.998)/1000`; dismiss if projected past 50 % of height or downward velocity > 700 px/s; else settle open.
- Settle with `SpringSimulation(SpringDescription.withDampingRatio(mass: 1, stiffness: …, ratio: 1.0), from, to, velocityNormalized)`; flick dismissal uses ratio 0.9 — no visible overshoot because the sheet leaves the screen.
- Interruptible: pointer down stops the controller and continues from its current value.
- Reduce Motion: 150 ms fade, no translate, drag still dismisses.
- `showNqSheet` + `showNqSheetRaw` (custom chrome) use it; replace the three `showModalBottomSheet` calls.
- Tests: short drag returns; long drag dismisses; fling dismisses; barrier tap dismisses; value resolves through `Navigator.pop`.

### 2. + menu anchored to the button (`home_shell.dart`)
- Tiles grow up and out of the + button (scale from bottom-right) with a critically damped spring curve; fade only with Reduce Motion.

### 3. Today pager like Cal AI (`today_screen.dart`)
- Macro rings and the Activity page sit in a `PageView` (native page physics) with page dots.
- Activity page: Apple Health numbers when on; otherwise a calm card that opens Settings (no permission prompt from Today).
- Tests: dots present; swiping shows the Activity page; no HealthKit request from Today.

### 4. Honest Apple Health copy (`health_section.dart`, Today)
- "Connected" → "Reading turned on" + note that iOS never tells apps whether reading was allowed.

### 5. Demo clarity on the camera (`camera_screen.dart`)
- A visible "Demo analysis" pill on the camera when the analysis service is demo.

### 6. Sync on launch and resume (`session_controller.dart`, `nutriq_app.dart`)
- After the initial session is built for an account, run `syncNow`. `SessionController.appResumed()` syncs the active account; `NutriqApp` calls it from `didChangeAppLifecycleState(resumed)`.
- Tests: restored account syncs at start; `appResumed` pulls server changes.

### 7. Delete-account auth error (`supabase_cloud_repository.dart`)
- 401/403 from the function → `CloudAuthException`; mapping extracted to a pure function with a test.

### 8. Motion audit
- Onboarding step transition: fade-only with Reduce Motion. Keep Pressable/rings as they are (already respect it). Remove redundant haptics on tab switches.

### 9. Docs
- Rewrite `README.md` (local-only vs cloud mode, what syncs, config + `--dart-define-from-file`, email vs Google/Apple, migration + function, demo-only parts).
- Write `docs/SETUP_AND_TESTING.md` (beginner guide, sections 1–9).

### 10. Verification
- `dart format`, `flutter analyze`, `flutter test`, local RLS script, Simulator build + visual pass, `flutter build ios --release --no-codesign`.
