# Nutriq v0.2 — Accounts, cloud sync, Apple Health, light redesign

Date: 2026-10-06 · Builds on `2026-10-06-nutriq-mvp-design.md` (all MVP behavior and safeguards stay).

## 1. What exists today (inspected)

| Area | State |
|---|---|
| Name / ids | `AppConfig.appName = 'Nutriq'`, iOS bundle `com.prodbyjake.nutriq`, Android `com.prodbyjake.nutriq` |
| Storage | One local SQLite file `nutriq.db` (tables `kv`, `meals` [items as JSON], `saved_foods`, `scan_feedback`); photos in `Documents/meal_photos/` stored as relative paths |
| State | `ProfileController`, `MealLogController`, `CoachController` behind `AppScope` |
| Demo-only | `DemoFoodAnalysisService` (sample meals), `DemoCoachService` (scripted) |
| Not present | Auth, cloud, HealthKit, coach-history persistence (coach chats stay in memory → **not** synced) |
| Bug to fix | Range editors allow a low end of 1,200 even when the calculator floor is max(1,200, resting energy); the "no deficit" maintain range can also dip below that floor |

## 2. Decisions

- **Local-first stays.** SQLite remains the UI's source of truth. Cloud is an optional sync target.
- **Account-scoped local files.** Local-only mode keeps `nutriq.db`. Each signed-in account gets
  `nutriq_<auth-user-id>.db` and its own photo folder `accounts/<id>/meal_photos/`. Switching or signing
  out can't expose another account's rows because they live in a different file.
- **Explicit import.** On sign-in, if local-only data exists and wasn't imported to this account, show an
  import sheet (counts + what uploads, photos stay on device). Import copies rows into the account file as
  pending changes; uploads are idempotent upserts keyed by `(user_id, id)`, so retries never duplicate.
  Local-only data is never deleted automatically.
- **Sync engine.** Rows carry `updated_at` (client ms), `dirty`, `deleted` (tombstone in account files).
  Push first via security-invoker RPCs that refuse stale writes (`client_updated_at` older than the server's)
  and return the server row; then pull rows whose server `updated_at` is newer than the last pull.
  Stale pushes become **visible conflicts** (Settings → Sync) with "Restore my version". Offline errors
  keep changes pending and retry with backoff. Status: synced / syncing / offline / error / pending count.
- **Cloud schema.** `profiles` (1 row per user, PK = `auth.users.id`), `meals` + `meal_items`
  (composite FK `(user_id, meal_id) → meals(user_id, id)` so an item can't attach to another user's meal),
  `saved_foods`, `scan_feedback`. RLS on every table: owner-only select/insert/update/delete via
  `(select auth.uid())`. No photo columns — photos never upload. No coach history. No HealthKit data.
- **Deletion.** "Delete cloud data" = RPC deleting the caller's rows (RLS). "Delete account" = Edge Function
  `delete-account` using the server-only service-role key (auth cascade removes rows). If it isn't deployed
  the app says so instead of pretending.
- **Auth.** Supabase email/password (confirmation, resend, reset via PKCE deep link
  `com.prodbyjake.nutriq://login-callback`), Google native (google_sign_in 7 → `signInWithIdToken`),
  Apple native on iOS only (`sign_in_with_apple`, SHA-256 nonce → raw nonce to Supabase). Apple is hidden on
  Android (no browser OAuth). Apple name saved only when Apple returns it. New linked identities are surfaced
  in a one-time notice; in-app linking uses `linkIdentityWithIdToken`.
- **Config.** `--dart-define-from-file=config/nutriq.json` (gitignored; example committed). Missing values →
  cloud features hidden, app runs local-only. iOS xcconfig `ios/Flutter/Nutriq.xcconfig` (gitignored) supplies
  the Google reversed client id and, for paid teams, the Sign in with Apple entitlements file.
- **Entitlements.** Default `Runner.entitlements` = HealthKit only (supported for free Personal Teams per
  Apple's capability table). `RunnerAppleSignIn.entitlements` adds Sign in with Apple (paid team only).
- **HealthKit.** `health` package. Read steps, workouts, active energy, body weight — requested only when the
  user turns Apple Health on in Settings. Separate opt-in to write nutrition (one HealthKit food entry per meal,
  recorded in `health_writes` so it's never written twice; Nutriq never reads nutrition back → no loops).
  Data stays on device. Unknown read permission is reported as "no data found" with guidance, not as "denied".
- **Scan drafts.** A capture becomes a persisted draft card on Today (analyzing → ready → reviewed/failed).
  Drafts survive restarts; interrupted analyses offer Retry. Nothing is logged until the user reviews.
- **Calorie floor.** One function `CalorieBounds.floorFor(profile)` = ceil50(max(1,200, resting energy)) used by
  the calculator, both range editors and `ProfileController.setCalorieGoal` (which rejects lower values).

## 3. Visual system (from the Cal AI references)

Studied: gallery screens 1–7 (gender choice, pace slider, Apple Health connect, plan loader, paywall, camera,
home) and App Store screenshots 1–4 (home "eaten/goal", camera, Nutrition results, Progress).

Recreated composition (Nutriq name, mark and copy):
- Light canvas `#F7F7F9`, white cards (radius 20, hairline `#EEEEF2`, soft shadow), near-black ink `#111114`,
  gray secondary `#8A8A93`. Black pill primary buttons (56 pt), light-gray option tiles that turn black when
  selected, circular back button + thin black progress bar in onboarding, bold 30–34 pt titles.
- Home: brand row (mark + "Nutriq", streak pill), week strip with dashed/colored day rings, white calorie card
  ("1,250 / 2,750–3,000 · Calories eaten" + black ring with flame), three macro cards with colored rings
  (protein salmon, carbs tan, fat blue), "Recently logged" photo cards, floating pill tab bar + black "+" button.
- Camera: full-bleed preview, rounded white corner brackets, close/help circles, mark + name title, flash,
  white shutter, library button. Only implemented modes are shown (no barcode/label).
- Nutrition review: full-bleed photo header with overlaid circle buttons, white rounded sheet, time pill,
  name + portion stepper, calories card with flame tile, macro mini-cards, ingredients list with "+ Add",
  bottom outlined + black buttons.

Deliberately not copied: logo/wordmark, illustrations, food photos, marketing copy, paywall, ad-tracking
prompt, "reach your goal in N months" pace predictions (conflict with Nutriq's no-guarantee rule).

## 4. Testing

Unit: calorie floor regression, sync push/pull/offline/stale-conflict/tombstones, import idempotency,
account isolation (separate stores per user), auth error mapping + Apple name + provider visibility,
health availability/permission/no-data/write-once, scan drafts (restart recovery). Widget: onboarding,
Today, review, settings sign-in gating. SQL: two-user RLS isolation script run against a local Postgres
with Supabase `auth` stubs. iOS Simulator visual pass. Real HealthKit/Apple/Google flows need a physical
device + dashboard credentials → documented, not claimed.
