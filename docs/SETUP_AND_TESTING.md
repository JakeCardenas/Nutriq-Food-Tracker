# Nutriq — setup and testing guide

A step-by-step guide for setting Nutriq up from scratch, written for someone new to Flutter and Supabase. Every step
says where to click and what you should see. Commands are run in **Terminal** from the project folder:

```bash
cd ~/Documents/Nutriq
```

**Golden rules**

- The app only ever contains *public* values: the Supabase project URL and its **publishable** (or legacy **anon**)
  key, and OAuth **client IDs**.
- Never put a **secret / service-role key**, a **Google client secret**, an **Apple `.p8` private key** or an
  **AI-provider key** in the app, in `config/nutriq.json`, in chat, or in git. Secrets belong only in the Supabase,
  Google or Apple dashboards.
- `config/nutriq.json` and `ios/Flutter/Nutriq.xcconfig` are git-ignored. Keep it that way.

---

## 1. What you need

| Tool | Why | Check |
|---|---|---|
| Flutter 3.47+ | builds the app | `flutter --version` |
| Xcode | iOS Simulator, iPhone builds | `xcodebuild -version` |
| A Supabase account | accounts + sync (optional) | supabase.com |
| Apple ID | run on your own iPhone (free) | Xcode → Settings → Accounts |
| Apple Developer Program ($99/yr) | only for TestFlight and Sign in with Apple | developer.apple.com |
| Android Studio | only for Android builds | `flutter doctor` |

Install packages and run the tests once:

```bash
flutter pub get
```

```bash
flutter test
```

All tests should pass. They use fakes for Supabase, Google, Apple and Apple Health, so they never touch your real
project.

---

## 2. Run it in local-only mode (no accounts)

```bash
open -a Simulator
```

```bash
flutter run
```

You'll see the welcome screen. Go through onboarding or tap **Skip setup**. Everything you log stays on the
device. Settings shows “On this phone only — accounts and sync aren't set up in this build.”

The Simulator has no camera: **+ → Scan food** shows “Camera isn't available” with **Choose from library**.
Food recognition is a **demo** — it returns a sample meal, not an analysis of your photo, and says “Demo” on the
camera, on the scan card and on the review screen.

---

## 3. Create the Supabase project and database

1. supabase.com → **New project**.
   - **Name:** `Nutriq`. **Database password:** click *Generate a password* and save it in your password manager
     (the app never uses it).
   - **Region:** the one closest to your users (can't be changed later).
   - **Security:** keep **Enable Data API** on; turn **Automatically expose new tables** off; turn **Enable automatic
     RLS** on.
2. Wait for the project to finish setting up.
3. **SQL Editor → New query.** Copy the whole migration file to your clipboard:
   ```bash
   pbcopy < supabase/migrations/20261006000000_nutriq_schema.sql
   ```
   Paste it into the editor (⌘V) — the first line reads `-- Nutriq cloud schema v1` — and click **Run**.
   You should see **“Success. No rows returned.”** Run it **once**; running it again fails with “already exists”.
4. **Table Editor** should now list `profiles`, `meals`, `meal_items`, `saved_foods` and `scan_feedback`.

What the migration does: every row belongs to one user (`user_id`), Row Level Security lets each signed-in user
read and change only their own rows, meal items can only attach to the same user's meals, logged-out requests are
refused, and the database rejects calorie goals outside 1,200–6,000 kcal or any targets for under-18s.

**Optional local check** (needs Postgres installed, e.g. `brew install postgresql@17`): creates a throwaway database,
signs in as two different users and tries to read/write each other's data.

```bash
bash supabase/tests/run_rls_tests_locally.sh
```

It should end with “All RLS isolation checks passed.”

---

## 4. Authentication settings

In your project: **Authentication**.

1. **Sign In / Providers → Email:** enabled by default. Keep **Confirm email** on.
2. **URL Configuration → Redirect URLs → Add URL:**
   ```
   com.prodbyjake.nutriq://login-callback
   ```
   Leave **Site URL** as it is. This lets confirmation and password-reset emails open the app.

On a real iPhone the email link opens Nutriq directly. If you open it on a Mac, the browser says it can't open the
page — that's expected; the account is still confirmed and you can sign in in the app.

---

## 5. Connect the app to your project

1. Create your local config:
   ```bash
   cp config/nutriq.example.json config/nutriq.json
   ```
2. In Supabase: **Project Settings → API Keys** → copy the **Publishable key** (`sb_publishable_…`). If you only see
   “Legacy API keys”, use **anon public**. Do **not** use the secret key.
3. Open `config/nutriq.json` and set:
   - `SUPABASE_URL` → `https://<your-project-ref>.supabase.co`
   - `SUPABASE_ANON_KEY` → the publishable key
   Leave the other values as they are for now.
4. Run with the config:
   ```bash
   flutter run --dart-define-from-file=config/nutriq.json
   ```
   Without `--dart-define-from-file`, the app quietly stays in local-only mode.

**Try it:** Welcome → **Already have an account? Sign in** → **New here? Create an account** → enter an email and a
new password → “Check your email” → click the link in the email → back in the app, **Sign in**. Log a meal; the
header chip shows **Synced**, and the meal appears in Supabase **Table Editor → meals** (with its foods in
`meal_items`). Photos are never uploaded.

If you used Nutriq before signing in, the app asks whether to **import** that data into the account. Nothing is
uploaded unless you say yes. You can import later from **Settings → Account**.

---

## 6. Account deletion (Edge Function)

**Settings → Delete account** calls a small server function that deletes the account using a server-only key.
Until it's deployed, the app truthfully says “Nothing was deleted”.

1. **Edge Functions → Deploy a new function → Via Editor.**
2. **Function name:** `delete-account` (exactly).
3. Copy the code and paste it over the editor's contents:
   ```bash
   pbcopy < supabase/functions/delete-account/index.ts
   ```
   The first line reads `// Supabase Edge Function: delete-account`. Click **Deploy function**.
4. On the function's **Settings** tab turn **off** “Verify JWT with legacy secret” → **Save changes**. The function
   checks the caller's sign-in itself; a request without a valid sign-in gets “Not signed in”.

You never copy the service-role key: Supabase gives it to the function automatically.

(With the Supabase CLI instead: `supabase functions deploy delete-account --no-verify-jwt`.)

**Delete synced data** (keeps the account) and **Remove account from this phone** don't need the function.

---

## 7. Sign in with Google and Apple (optional)

The buttons stay hidden until these are configured. Nothing here goes in git.

### Google

1. **Google Cloud Console → APIs & Services → Credentials → Create credentials → OAuth client ID.** Create:
   - a **Web application** client — its client ID and **client secret** go into **Supabase → Authentication →
     Sign In / Providers → Google** (the secret stays in Supabase only);
   - an **iOS** client with bundle ID `com.prodbyjake.nutriq`;
   - (Android later) an **Android** client with package `com.prodbyjake.nutriq` and your signing SHA-1.
2. In Supabase's Google provider, enable it and put the Web and iOS client IDs in **Client IDs** (comma-separated).
   If iOS sign-in fails with a nonce error, turn on **Skip nonce checks** there.
3. In `config/nutriq.json`: `GOOGLE_WEB_CLIENT_ID` = the Web client ID, `GOOGLE_IOS_CLIENT_ID` = the iOS client ID.
4. For the iOS URL scheme, create `ios/Flutter/Nutriq.xcconfig` from the example and set
   `GOOGLE_REVERSED_CLIENT_ID` to the iOS client ID reversed (e.g. `com.googleusercontent.apps.123-abc`):
   ```bash
   cp ios/Flutter/Nutriq.example.xcconfig ios/Flutter/Nutriq.xcconfig
   ```

### Apple (iOS only, paid Apple Developer Program)

1. developer.apple.com → **Identifiers** → your App ID `com.prodbyjake.nutriq` → enable **Sign in with Apple**.
2. Supabase → **Sign In / Providers → Apple** → enable it and add `com.prodbyjake.nutriq` to **Client IDs**
   (native sign-in only needs the bundle ID; a `.p8` key is only for the web flow and stays in Supabase).
3. In `ios/Flutter/Nutriq.xcconfig` set `NUTRIQ_ENTITLEMENTS = Runner/RunnerWithApple.entitlements`, and in
   `config/nutriq.json` set `"APPLE_SIGN_IN_ENABLED": true`.

Apple only shares a person's name the first time they sign in; Nutriq saves it when it's provided. Android doesn't
show the Apple button.

If the same verified email signs in with a different method, Supabase links it to the same account, and Nutriq shows
a one-time notice about the new sign-in method.

---

## 8. Apple Health (iOS)

Optional and off by default; it has nothing to do with Supabase.

1. Run on a Simulator or iPhone, open **Settings → Apple Health → Connect Apple Health**. Apple's sheet asks to
   read steps, workouts, active energy and weight.
2. **Today:** swipe the macro cards left to see **Steps today**, **Active kcal** and workouts.
3. **Add meals to Apple Health** is a separate switch; each meal is written once (calories, protein, carbs, fat).
4. iOS never tells apps whether reading was allowed, so if the numbers stay “—”, check **Health app → your profile →
   Apps → Nutriq**. On the Simulator you can add sample data in the Health app.
5. **Disconnect** stops reading and writing. Apple Health data is never uploaded.

The free Personal Team can sign HealthKit builds. Android Health Connect isn't supported in this version.

---

## 9. Testing checklist and troubleshooting

**Automated**

```bash
dart format --line-length 120 lib test
```

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter build ios --release --no-codesign --dart-define-from-file=config/nutriq.json
```

**By hand (Simulator or iPhone)**

- [ ] Onboarding: answers save; an under-18 age gives no calorie targets; “Pregnant” gives no calculated targets.
- [ ] Today: + → Photo library → “Estimate ready” card → review shows “Demo result” → **Log meal**.
- [ ] Sheets: drag one down slowly and let go before halfway — it settles back; flick it down — it closes.
- [ ] Settings → Reduce Motion (iOS Settings → Accessibility → Motion) on: sheets fade instead of sliding.
- [ ] Signed in: log a meal → “Synced”; delete it → it disappears from Supabase too.
- [ ] Airplane mode: log a meal → chip shows “Offline”; back online → syncs.
- [ ] Two devices / two installs: edit the same meal → the older edit appears under Settings → Account to restore.
- [ ] Sign out with unsynced changes → the app warns first.

**Troubleshooting**

| Symptom | Fix |
|---|---|
| No sign-in options at all | You ran without `--dart-define-from-file=config/nutriq.json`, or the values are still placeholders |
| “permission denied” when syncing | Run the migration (section 3) — it grants signed-in users access to their own rows |
| Email link says “can't open page” on a Mac | Expected; sign in in the app. On an iPhone the link opens Nutriq |
| Delete account says “Nothing was deleted … not deployed” | Deploy the function (section 6) |
| Delete account says “Please sign in again” | The session expired: sign out and in, then retry |
| Google button missing | Both `GOOGLE_*_CLIENT_ID` values must be set (section 7) |
| Apple button missing | iOS only, and `APPLE_SIGN_IN_ENABLED` must be `true` with the paid-team entitlements |
| Apple Health numbers stay “—” | Check Health app → Profile → Apps → Nutriq; add sample data on the Simulator |
| Personal Team app stops opening after 7 days | Re-run it from Xcode/Flutter (free provisioning expires) |
