Add a new project to my portfolio: **Nutriq**. Match the layout and style my other projects already use (card on
the projects list + a case-study page if my site has them). Use only the facts below — don't invent numbers,
users, ratings, App Store links or accuracy claims.

## Project card

- **Name:** Nutriq
- **One-liner:** A free, privacy-first food logging app for iPhone — snap, describe or search a meal, review it,
  and track calories and macros against an honest daily range.
- **Tags:** Flutter · Dart · iOS · Supabase · PostgreSQL · Apple HealthKit · Swift (platform channel) · Edge Functions (TypeScript)
- **Links:** Code: https://github.com/JakeCardenas/Nutriq-Food-Tracker — no App Store link (it runs as a personal
  build on my iPhone; not published).
- **Images** (in this order; I'll attach them): `nutriq-icon.png` (app icon, 1024×1024), `nutriq-today-top.png`
  (hero/thumbnail — Today screen top), `nutriq-today.png`, `nutriq-add-menu.png`, `nutriq-meal.png`,
  `nutriq-history.png` (iPhone screenshots, 1206×2622). Show screenshots in phone-shaped frames or rounded cards.

## Case study

**Overview.** Nutriq is a solo project — product, design and development — built in Flutter for iPhone. It works
fully offline on the phone; signing in adds an account with sync across devices. It's free, with no ads or tracking.

**What it does**
- **Log meals four ways:** take or pick a photo, describe it in plain words ("2 cups kanin and adobong manok"),
  search Nutriq's food list (~145 everyday foods, including many Filipino dishes), or reuse saved "My foods".
- **Photo logging that stays honest:** every photo becomes a draft first (so nothing is lost if analysis fails), the
  person reviews and corrects every food before anything is logged, and a photo can be retaken, discarded or deleted
  at any point. On iPhone, Apple's on-device Vision framework suggests foods. An optional, opt-in cloud estimate
  (Gemini through a Supabase Edge Function) suggests the foods and portion ranges — calories always come from food
  data (Nutriq's list or USDA FoodData Central), never from the AI, and hidden ingredients aren't counted unless the
  person includes them.
- **Today:** a calorie ring against a daily range, protein/carbs/fat rings, a week strip and a logging streak.
- **History:** weekly calorie chart with the goal range, averages and streaks.
- **Apple Health (opt-in):** reads steps, workouts, active energy and weight; can write meal nutrition back.
- **Safeguards:** no calorie or macro targets for people under 18, or during pregnancy, breastfeeding or relevant
  medical conditions; nutrition is always labelled as an estimate.
- **Coach tab:** short, safety-checked guidance (an AI coach is built but switched off).

**How it's built**
- Flutter 3.47 / Dart 3.13, local-first SQLite storage, custom design system with spring-based sheets and
  Reduce Motion support.
- Supabase: Auth, PostgreSQL with row-level security on every table, and TypeScript Edge Functions (photo estimates,
  account deletion, coach) that check sign-in before doing any work and keep API keys server-side.
- Two-way offline sync with stale-write detection — conflicts are kept visible instead of silently overwritten.
- Swift platform channel to Apple Vision for on-device photo suggestions; HealthKit integration.
- Photos are resized and stripped of location/camera metadata before any (opt-in) upload; consent is asked first.

**Engineering highlights**
- Testing: 395 Flutter unit/widget tests, 47 Edge Function tests, and SQL test suites that prove users can only
  ever read their own data.
- Accessibility: VoiceOver labels and actions on custom controls, Dynamic Type support, Reduce Motion fallbacks.
- Local foods: the meal-description parser understands Filipino names and spellings (kanin, sinangag, adobong
  manok, pritong itlog…).
- Built an evaluation method (weighed meals, precision/recall, portion and calorie error) before making any
  accuracy claims.

**Honest notes (keep these in the copy)**
- Photo estimates are estimates; their accuracy hasn't been measured yet on real, weighed meals.
- Not published on the App Store.

## Don't

- Don't compare Nutriq to, or name, other calorie apps.
- Don't describe the photo feature as "accurate", "AI-powered calorie counting" or similar — say the person
  reviews every estimate.
- Don't add a download button or App Store badge.
