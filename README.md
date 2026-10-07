# Nutriq

Snap a meal. Check the estimate. Keep a calm daily log.

Nutriq is a free food-logging app for iPhone (and Android) built with Flutter. Photograph a meal, review and
correct the suggested foods and portions, and save it to your daily log. An optional, short onboarding gives you an
editable starting point. Every nutrition number is labelled as an estimate. No ads, no paywall.

**Step-by-step setup (beginner-friendly):** [docs/SETUP_AND_TESTING.md](docs/SETUP_AND_TESTING.md)

---

## Two ways to run it

| | **Local-only mode** | **Cloud-sync mode** |
|---|---|---|
| When | You run without `config/nutriq.json`, or the person doesn't sign in | You build with your Supabase config **and** the person signs in |
| Where data lives | Only on the phone (SQLite + app folder) | On the phone, synced to the person's own rows in your Supabase project |
| Account needed | No | Yes (email; Google/Apple once configured) |

Without the config file the app still works fully; the sign-in options are simply hidden and Settings says
“Accounts and sync aren't set up in this build”.

### What syncs, and what never leaves the phone

| Synced to Supabase (signed in only) | Always stays on the phone |
|---|---|
| Profile answers and goals (calorie range, protein reference) | **Meal photos** (never uploaded) |
| Settings (units, day start) | **Apple Health data** (steps, workouts, energy, weight) |
| Meals and their foods | Scans that are still drafts |
| My foods (saved foods) | Coach chats (not saved anywhere — see the AI coach below for what it sends) |
| Scan ratings | Anything from local-only mode — until the person explicitly taps **Import** after signing in |

**AI coach (signed in, opt-in):** when someone turns it on, each question is sent with the recent chat and a small
summary — goal, age group (not exact age), calorie range, protein reference, body weight for adults, today's meals
and the last 7 days' totals, and up to 20 saved foods — through Nutriq's `coach` server function to Anthropic's
Claude. Never photos, notes, Apple Health data, sex or height. The server stores only a per-day message count.

Each signed-in account has its own database file and photo folder on the device, so switching accounts never shows
another person's meals. Offline edits are kept and sync later; if two devices edit the same thing, the newer edit
wins and the older one is listed under **Settings → Account** where it can be restored.

---

## What's real and what's demo

| Feature | Status |
|---|---|
| Onboarding, starting-point estimate (Mifflin–St Jeor), editable calorie range and protein reference | **Real**, computed on the device |
| Safeguards: no calorie/protein targets under 18; no calculated targets with pregnancy, breastfeeding or a relevant medical condition; ranges never below max(1,200 kcal, resting energy) | **Real.** The under-18 rule and the 1,200–6,000 kcal bounds are also enforced by the database |
| Meal log, History, editing foods/portions/time, My foods, scan ratings, streaks | **Real** |
| Email sign-up/sign-in, confirmation and password-reset links, sync, conflict review, account deletion | **Real** once Supabase is configured (see below) |
| Sign in with Google | Code is ready; needs Google Cloud client IDs and the Supabase Google provider — **off until you configure it** |
| Sign in with Apple | Code is ready, iOS only; needs the paid Apple Developer Program and the Supabase Apple provider — **off by default** |
| Apple Health (read steps, workouts, active energy, weight; optionally write meal nutrition) | **Real, iOS only, opt-in from Settings.** Android Health Connect isn't supported yet. |
| **Describing meals** | **Real, on the device.** Type a meal like “century tuna and 2 cups of rice” and Nutriq's built-in food list (~120 everyday foods, many Filipino staples) fills in typical calories and macros — understood: amounts (2, ½, “two”, “2 and a half”, x3), units (cups, cans, pieces, slices, grams, oz…), brands and small typos. Anything it doesn't know is listed, not guessed. The same list powers **Add an ingredient** search. |
| **Food recognition from photos** | **Real, on the iPhone, free.** Apple's built-in image recognizer (Vision) looks at the photo on the phone — it never leaves the device — and the foods it sees (rice, tuna, fried egg, spaghetti, fried chicken, soup, fruit, ~110 labels) are matched to Nutriq's food list. It can't see brands or amounts, so every food starts at a usual portion, unsure ones say “check this”, and the review offers “Anything missing? Describe it”. No food found → it asks what's in the photo. Android: describe instead. Meals logged earlier with the old sample scanner still show “Demo”. |
| **Coach** | **AI coach (Claude Sonnet 5.5) for signed-in people who turn it on**, through the `coach` Edge Function — **off until you deploy it, add your Anthropic key and set `AI_COACH_ENABLED`** (see below). Replies stream in and are labelled “AI coach · can make mistakes”; 30 messages per person per day. Everyone else — and anyone offline or over the limit — gets the scripted **“Demo coach”**, and the reply says why. The safety rules run on the phone *and* on the server. |

---

## Run it

Prerequisites: Flutter 3.47+, Xcode (for iOS). Android needs Android Studio.

```bash
flutter pub get
```

```bash
flutter test
```

**Local-only mode** (no accounts):

```bash
flutter run
```

**Cloud-sync mode:** create your local config from the example, fill in your project's values, then pass it at
build time. Supabase is only enabled when the values come in through this flag.

```bash
cp config/nutriq.example.json config/nutriq.json
```

```bash
flutter run --dart-define-from-file=config/nutriq.json
```

`config/nutriq.json` is git-ignored. It holds **only public client values**:

| Key | Value |
|---|---|
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | Your project's **publishable** key (`sb_publishable_…`) or legacy **anon** key — never the secret/service-role key |
| `AUTH_REDIRECT_URL` | `com.prodbyjake.nutriq://login-callback` (leave as is) |
| `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID` | OAuth **client IDs** (not secrets). Leave empty to hide Google sign-in |
| `APPLE_SIGN_IN_ENABLED` | `true` only after Sign in with Apple is set up (paid team) |

Never put a service-role/secret key, a Google client secret, an Apple private key (`.p8`) or an AI-provider key in
the app or in git.

Use the same flag for release builds, e.g.:

```bash
flutter build ipa --release --dart-define-from-file=config/nutriq.json
```

The iOS Simulator has no camera: the camera screen offers **Choose from library** instead.

---

## Supabase setup (summary)

Full click-by-click steps are in [docs/SETUP_AND_TESTING.md](docs/SETUP_AND_TESTING.md).

1. **Database:** open `supabase/migrations/20261006000000_nutriq_schema.sql`, paste it into the Supabase **SQL
   Editor** and run it once (or `supabase db push` with the Supabase CLI). It creates five tables, Row Level Security
   (owner-only on every table and operation), sync functions, and grants only signed-in users access to their own
   rows. Logged-out requests are refused.
2. **Auth URLs:** Authentication → URL Configuration → Redirect URLs → add
   `com.prodbyjake.nutriq://login-callback`.
3. **Email:** enabled by default with “Confirm email” on — keep it on.
4. **Account deletion:** deploy `supabase/functions/delete-account` (Edge Functions → Deploy a new function → Via
   Editor, name `delete-account`, paste `index.ts`; or `supabase functions deploy delete-account`). In the
   function's settings turn **off** “Verify JWT with legacy secret” — the function verifies the caller itself.
   It uses the service-role key that Supabase injects on the server; you never copy that key anywhere.
5. **AI coach (optional):** run `supabase/migrations/20261007000000_coach_usage.sql` once, add your Anthropic API
   key as the Edge Function secret `ANTHROPIC_API_KEY` (in the Supabase dashboard only — never in the app, git or
   chat), deploy `supabase/functions/coach` with “Verify JWT with legacy secret” off, then set
   `"AI_COACH_ENABLED": true` in `config/nutriq.json`. Until then nobody is offered the AI coach.
6. **Google / Apple:** see the guide. Until then the buttons stay hidden.

To check the database rules locally against a throwaway Postgres (two users, cross-user access attempts, and the
coach's daily allowance):

```bash
bash supabase/tests/run_rls_tests_locally.sh
```

To test the `coach` function (fake network — no Supabase or Anthropic calls; needs Node 23.6+):

```bash
node --test supabase/tests/coach_function_test.ts
```

---

## Apple Health

Off by default. **Settings → Apple Health → Connect** shows Apple's permission sheet for reading steps, workouts,
active energy and weight. Writing meal calories/macros is a second, separate switch, and each meal is written once.
Read data is shown on Today (swipe the macro cards to the second page) and never leaves the phone. iOS doesn't tell
apps whether reading was allowed, so empty numbers can mean “no data yet” or “not allowed” — the app says so rather
than guessing. **Disconnect** stops reading and writing; full revocation is in the Health app → Profile → Apps → Nutriq.

The free Personal Team can sign HealthKit builds. Sign in with Apple needs a paid team: copy
`ios/Flutter/Nutriq.example.xcconfig` to `ios/Flutter/Nutriq.xcconfig` (git-ignored) and switch the entitlements file
there.

---

## On your own iPhone (free Personal Team)

1. **Xcode → Settings → Accounts** → add your Apple ID.
2. `open ios/Runner.xcworkspace` → **Runner** → **Signing & Capabilities** → **Team** → *Your Name (Personal Team)*.
3. Plug in the iPhone, tap **Trust**, turn on **Settings → Privacy & Security → Developer Mode**.
4. Run a release build:
   ```bash
   flutter devices
   ```
   ```bash
   flutter run --release -d <device-id> --dart-define-from-file=config/nutriq.json
   ```
5. If iOS blocks the first launch: **Settings → General → VPN & Device Management** → trust your profile.

Personal Team builds expire after 7 days — run step 4 again. Email confirmation links open the app directly on a
real iPhone; on a Mac the browser can't open them, but the account is still confirmed and you can sign in.

## Share with friends

- **iPhone — TestFlight** (Apple Developer Program, $99/yr): bump the build number in `pubspec.yaml`,
  `flutter build ipa --release --dart-define-from-file=config/nutriq.json`, upload with **Transporter**, invite
  testers in App Store Connect → TestFlight. Export compliance is pre-answered in `Info.plist`.
- **Android:** install Android Studio, then `flutter build apk --release --dart-define-from-file=config/nutriq.json`
  and share the APK, or use Google Play internal testing. The Android project (deep link, minSdk 26) hasn't been
  built here because this Mac has no Android SDK.

Native apps are distributed through TestFlight / the App Store and Google Play, not web hosts.

### Questions for testers

1. When you described a meal, did Nutriq pick the right foods and portions?
2. Was it easy to correct the food and portion?
3. Was the estimate label clear?
4. Did the starting goal feel understandable and editable?
5. Was the coach helpful and relevant?
6. What felt confusing or slow?

Testers can rate scans in **Settings → Scan feedback** and copy a summary to send you.

---

## How it's built

```
lib/
  app/        env (build-time config), session wiring, AppScope, theme tokens, formatting
  domain/     models, StartingPoint + CalorieBounds, FoodCatalog, MealDescription, PhotoFoodMapper, streak, units
  data/       LocalStore (SQLite, per-account files), sync engine, Supabase repository + mappers, local import
  services/   auth (Supabase, Google, Apple), food analysis (on-device Vision / describe), coach, Apple Health, photos
  state/      session, profile, meal log, scans (drafts), sync, health, coach controllers
  features/   onboarding, account, today, scan (camera), meal editor, history, coach, settings, shell
  widgets/    design system: cards, rings, buttons, controls, spring sheet (NqSheetRoute), week strip
supabase/     migrations, Edge Functions (delete-account, coach), local RLS + coach tests
test/         unit + widget tests (run `flutter test`)
docs/         setup guide, design specs and plans
```

**Motion:** sheets follow the finger 1:1, use the release velocity to decide whether to close, settle with
critically damped springs (no bounce) and rubber-band past the top. Scroll views keep Flutter's native iOS physics.
With **Reduce Motion** on, sheets and menus cross-fade instead of sliding.

**AI coach:** `AiCoachService` runs the on-device safety check, sends `CoachPayload` (chat + minimal context) through
`SupabaseCoachBackend` to `supabase/functions/coach`, and streams the reply. The function checks the caller's
sign-in, re-applies the safety rules (and reads the caller's own profile row, so an under-18 or health flag still
applies), spends one message from `nutriq_coach_take_turn()`, and calls Claude with a safety-first system prompt. The
model is `MODEL` at the top of `supabase/functions/coach/index.ts`.

**Photo recognition:** `OnDeviceFoodAnalysisService` sends the photo bytes over the `com.prodbyjake.nutriq/food_vision`
channel to `FoodVisionPlugin` (in `ios/Runner/AppDelegate.swift`), which runs Apple's `VNClassifyImageRequest` on the
phone; `PhotoFoodMapper` turns its labels into catalog foods (confidence ≥ 0.25, at most 5, general labels like
“fish” dropped when “tuna” is seen). For brand- and portion-level accuracy you'd need a vision model on **your own
server** (which keeps the AI-provider key): implement `FoodAnalysisService` with `isDemo: false` and swap it in
`lib/main.dart`. Add an explicit consent step before any photo is uploaded, and
update the privacy text in Settings. (`DemoFoodAnalysisService` remains only as a test double for the draft flow.)

**Rename:** `lib/app/app_config.dart` (`AppConfig.appName`), `ios/Runner/Info.plist` (`CFBundleDisplayName`),
`android/app/src/main/AndroidManifest.xml` (`android:label`).

---

Nutriq is for general wellness. Nutrition values are estimates for information only — not medical advice.
