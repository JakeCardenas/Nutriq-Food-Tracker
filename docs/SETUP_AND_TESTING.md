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
  Google or Apple dashboards (the Anthropic key goes in **Supabase → Edge Functions → Secrets**).
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
On iPhone, Apple's built-in image recognizer looks at the photo **on the phone** (it's never uploaded) and Today
shows “Ready to review · Might include …” (or “No food suggestions”). These are guesses from a general-purpose
recognizer, not a food scanner: in the review, **Add** a suggestion (you choose the serving), **Find** it in the food
list when it could be several foods, or dismiss it, and **describe anything it missed** (“century tuna and 2 cups of
rice” → **Add foods**). Nothing is added until you choose it. On Android the menu says **Take photo**: the photo is
kept and you type what's in it. **+ → Describe meal** works without a photo.

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

## 7. AI coach (optional)

The coach can answer with Anthropic's **Claude Sonnet 5.5**. The app never holds the AI key: it calls the `coach`
Edge Function, which keeps the key in Supabase, checks the person's sign-in, applies Nutriq's safety rules and
allows **30 AI messages per person per day**. Anthropic bills you for usage, so set a spend limit.

It's **off by default**: until you finish these steps and set `AI_COACH_ENABLED`, nobody sees the AI coach offer
and everyone gets the scripted coach.

1. **Get an API key.** Go to console.anthropic.com and sign in. Add a little credit and set a monthly **spend limit**
   in the billing/limits settings. Then **API Keys → Create Key**, name it `nutriq-coach`, and copy it.
   Paste it only in the next step — not in the app, a file, git or chat.
2. **Store it in Supabase.** Your project → **Edge Functions → Secrets** → add a secret named
   `ANTHROPIC_API_KEY` with the key as its value → **Save**.
3. **Create the daily allowance.** **SQL Editor → New query.** Copy the file:
   ```bash
   pbcopy < supabase/migrations/20261007000000_coach_usage.sql
   ```
   Paste (⌘V) — the first line reads `-- Nutriq AI coach: daily message allowance.` — and click **Run**. You should
   see **“Success. No rows returned.”** Run it once.
4. **Deploy the function.** **Edge Functions → Deploy a new function → Via Editor**, name it `coach` (exactly).
   Copy the code:
   ```bash
   pbcopy < supabase/functions/coach/index.ts
   ```
   Paste it over the editor's contents — the first line reads `// Supabase Edge Function: coach` — and click
   **Deploy function**. On the function's **Settings** tab turn **off** “Verify JWT with legacy secret” → **Save**.
   (CLI: `supabase functions deploy coach --no-verify-jwt`.)
5. **Turn it on in the app.** In `config/nutriq.json` set `"AI_COACH_ENABLED": true`, then rebuild.
6. **Try it.** Run the app signed in → **Coach** → **Turn on AI coach** → tap “Suggest a balanced dinner for my
   goal.” The answer streams in and is labelled “AI coach · can make mistakes”.

**What is sent:** the question, the last few chat messages, and a summary: goal, age group (not exact age), calorie
range and protein reference, body weight for adults, today's meals (food names with estimated calories and macros),
the last 7 days' totals and up to 20 saved foods. Never photos, notes, Apple Health data, sex or height. Nothing is
stored except a daily count per person (`coach_usage`), which is deleted with the account.

**Safety:** the phone answers eating-disorder cues, extreme restriction, medical and “how fast will I lose…”
questions itself, without calling the AI. The function repeats those checks, also reads the person's own synced
profile (so under-18 and pregnancy/medical safeguards still apply), and gives Claude a safety-first system prompt.

**Cost and model:** the limit is `v_limit` in the migration's `nutriq_coach_take_turn()` (change it with a new
migration) and `DAILY_LIMIT` in the function. The model is `MODEL` at the top of the function; for lower cost use
`claude-haiku-4-5-20251001`.

---

## 8. Photo estimates (optional — Gemini + USDA)

Off by default. When you set it up, signed-in people can **choose** to send a meal photo for an estimate; everyone
else keeps the free, on-device path (iPhone suggestions, or describing the meal).

**What happens, step by step**

1. After the shutter, the camera shows **Use this photo?** with **Use photo**, **Retake** and **Discard**. Retake and
   Discard (or closing the camera) delete the capture — nothing is saved or sent; only **Use photo** continues.
   The first time someone uses or picks a photo, Nutriq asks **“Get a photo estimate?”** and explains: the photo
   leaves the phone (a smaller copy without location or camera details) and goes through Nutriq's server to Google's
   Gemini; on the free tier, Google's terms let it use what's sent to improve its products and people at Google may
   review it; calories and protein come from food data, not from the AI; Nutriq's server doesn't keep the photo;
   estimates can be wrong; there's a daily limit. **Keep photos on this
   phone** means nothing is ever uploaded (they can turn it on later in **Settings → Photo estimates**).
2. If they agree, the app shrinks the photo to ≤ 1024 px and re-encodes it as a JPEG from its pixels — no EXIF, GPS
   or camera data — and sends it to the `scan-photo` function with their sign-in.
3. The function checks the sign-in **before reading the upload**, then reads at most 2.2 MB of it (a larger declared
   size is refused straight away, and a longer upload is cut off as soon as it passes the limit). It checks the
   consent flag, refuses anything that isn't a JPEG or is over 1.5 MB, strips any remaining metadata, and takes one
   turn from the person's daily scan allowance (separate from the coach's).
4. It asks Gemini (`gemini-3.5-flash-lite`) for **candidates only**: likely dish and alternatives; up to 8 foods it
   can actually see (a mixed dish such as adobo or sinigang is one food), each with up to 2 other names when it
   can't tell which food it is; separately, up to 4 *possible hidden ingredients* (oil, sauce, filling) with no
   amount; a portion range in grams only when one can reasonably be judged; and what a photo can't show. The request
   schema has no calorie, nutrient or confidence fields, and the answer is validated and clamped — duplicates are
   dropped, and a range tighter than about ±10 % is widened around the same middle, because a photo can't give an
   exact weight.
5. Each component is looked up in USDA FoodData Central if `FDC_API_KEY` is set (a POST search with the data types as
   an array, as the FDC guide asks; the key goes in a header). An entry is used only when it's
   clearly the same food: every word of the name appears in USDA's description, and every such entry in the results
   agrees on calories (within 15%) and protein (within 20%). If they disagree (“chicken, fried”: breast or wing?) or
   only part of the name matches, the app gets up to 4 entries to choose from instead; entries that don't share the
   food's main word are never offered. Clear answers are cached by FDC id for 30 days in Postgres (readable only by
   the server); ambiguous ones are looked up again next time.
6. The app matches each component to Nutriq's food list first (exact names only — generic labels such as “chicken”,
   “fish”, “rice” or “vegetables” never match one specific food there), else the USDA entry (shown with
   its USDA name and data type, e.g. “USDA FoodData Central (SR Legacy): …”). When there are several possible
   entries it lists them with their data type and kcal/protein per 100 g; that food isn't counted until the person
   picks one (**Change** undoes a pick), or they can leave it uncounted, **Find** it in Nutriq's list or remove it.
   With nothing at all it shows “No nutrition data found”. Calories and protein are **grams × per-100 g values**,
   shown as “≈ … kcal · … g
   protein” (or “No nutrition counted yet” when nothing could be matched). Every amount says *Estimated from photo*,
   *Typical serving — not from the photo* or, after **Choose amount**, *Starting amount* until the person changes it.
   They can remove foods, look up unmatched ones, describe missed ones, and nothing is added until **Add N foods to
   meal** — or logged until **Log meal**. Tapping **Log meal** while estimated foods are still waiting in the card
   asks first (“Photo estimate not added”), so they aren't silently left out. **Could also be** choices switch a food
   to one of its alternatives (matched again to Nutriq's list; otherwise “No nutrition data found”). **Possible
   ingredients** are listed separately and never counted — not in the card, not on Today — until the person taps
   **Include in estimate**.
7. If anything fails — offline, timeout, the daily limit, Gemini's free quota, not set up — the photo still reaches the
   review with a notice, plus on-device suggestions on iPhone, or the describe box on Android.
8. Every scan on Today — analyzing, ready or failed — has a discard (trash) button. It asks first, then removes the
   unfinished scan and its photo; a result that arrives later doesn't bring it back, and a photo that a logged meal
   uses is never deleted.

The server never stores or logs photos, prompts or Gemini's answers — only status codes, the per-day count and the
public USDA cache.

**Set it up** (Nutriq never needs these keys in the app, a file, git or chat)

1. **Gemini key:** aistudio.google.com → **Get API key** → create a key. The free tier is enough to try it.
2. **USDA key (optional, recommended):** api.data.gov/signup → the key is emailed to you. Without it, only foods in
   Nutriq's own list get nutrition.
3. **Supabase → Edge Functions → Secrets:** add `GEMINI_API_KEY`, and optionally `FDC_API_KEY` and
   `SCAN_DAILY_LIMIT` (photos per person per day, 1–200, default 10) → **Save**.
4. **SQL Editor → New query**, after the coach migration (section 7):
   ```bash
   pbcopy < supabase/migrations/20261007120000_photo_scan.sql
   ```
   Paste — the first line reads `-- Nutriq photo estimates: daily scan allowance and a nutrition lookup cache.` —
   and **Run** once. You should see “Success. No rows returned.”
5. **Edge Functions → Deploy a new function → Via Editor**, name `scan-photo`:
   ```bash
   pbcopy < supabase/functions/scan-photo/index.ts
   ```
   Paste over the editor's contents — the first line reads `// Supabase Edge Function: scan-photo` — and **Deploy
   function**. On its **Settings** tab turn **off** “Verify JWT with legacy secret” → **Save**.
   (CLI: `supabase functions deploy scan-photo --no-verify-jwt`.)
6. In `config/nutriq.json` set `"PHOTO_ESTIMATES_ENABLED": true`, then rebuild the app.
7. **Try it** signed in: **+ → Photo library** → **Send photos for estimates** → Today shows **Photo estimate
   ready** → check each food and amount → **Add N foods to meal** → **Log meal**.

**Free tier, privacy and quotas**

- Free-tier (unpaid) Gemini use: Google uses submitted content and responses to improve its products, and human
  reviewers may read them. Don't encourage sending private photos. On a Cloud project with billing enabled, the paid
  terms apply instead (content isn't used that way); in the EEA, Switzerland and the UK, the paid terms apply to all
  use. Re-check Google's current terms before relying on either.
- Gemini's free tier has per-project rate limits shared by all your users; when they're hit, people see “The photo
  estimate service has reached its free limit for now” and get the on-device fallback.
- USDA FoodData Central allows about 1,000 requests per hour per IP address; the cache keeps repeat foods off it.
- The production model is `MODEL` at the top of `supabase/functions/scan-photo/index.ts`. For a side-by-side
  comparison, the optional secret `GEMINI_MODEL` may be set to the one reviewed alternative (`gemini-3.8-flash`);
  any other value makes the function answer “not set up”. See the evaluation guide before switching.

**Accuracy limits — read before trusting the numbers**

A single photo can't show what's under the top layer, cooking oil, sauces, the recipe, or the real weight. Portion
ranges are visual guesses; USDA entries are generic (and the matching rules above are word-based — they can still
pick a related entry when USDA has only one); Filipino dishes get nutrition only where Nutriq's own list has
them (Nutriq doesn't bundle PhilFCT data). **This hasn't been measured on real meals yet.** To check it: weigh the
foods on a kitchen scale, write down what's really on the plate, take the photo, and compare the suggested foods and
the estimated kcal/protein with your numbers across a few dozen varied meals.


How to measure it — and to compare a candidate model on the same photos — is in
[PHOTO_ESTIMATE_EVALUATION.md](PHOTO_ESTIMATE_EVALUATION.md) (`dart run tool/photo_eval.dart meals.csv` scores it).
---

## 9. Sign in with Google and Apple (optional)

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

## 10. Apple Health (iOS)

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

## 11. Testing checklist and troubleshooting

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
node --test supabase/tests/coach_function_test.ts
```

```bash
node --test supabase/tests/scan_photo_function_test.ts
```

```bash
flutter build ios --release --no-codesign --dart-define-from-file=config/nutriq.json
```

**By hand (Simulator or iPhone)**

- [ ] Onboarding: answers save; an under-18 age gives no calorie targets; “Pregnant” gives no calculated targets.
- [ ] iPhone: photo of a meal → Today says “Ready to review · Might include …” → review: nothing is in Ingredients
      yet; **Add** a suggestion → choose the serving → it appears; dismiss a wrong one; **Log meal** saves only what
      you added. A photo with no food → “No food suggestions” → describe it.
- [ ] Record, for a few real meals, what was on the plate vs. what was suggested — that's the only evidence of how
      useful suggestions are (none has been collected yet).
- [ ] + → Describe meal → type something Nutriq doesn't know → it's listed under “Not found”, nothing is guessed.
- [ ] Close the describe screen after picking a photo → nothing is logged and the photo isn't kept.
- [ ] Sheets: drag one down slowly and let go before halfway — it settles back; flick it down — it closes.
- [ ] Settings → Reduce Motion (iOS Settings → Accessibility → Motion) on: sheets fade instead of sliding.
- [ ] Signed in: log a meal → “Synced”; delete it → it disappears from Supabase too.
- [ ] Airplane mode: log a meal → chip shows “Offline”; back online → syncs.
- [ ] Two devices / two installs: edit the same meal → the older edit appears under Settings → Account to restore.
- [ ] Sign out with unsynced changes → the app warns first.
- [ ] Coach, signed in: “Try the AI coach?” → **Not now** → replies say “Demo coach · scripted”. Settings → **AI
      coach** on (asks first) → replies stream in, labelled “AI coach · can make mistakes”.
- [ ] Coach: “how do I make myself throw up” → a caring safety reply that points to real support, instantly.
- [ ] Coach in airplane mode → scripted reply that says you're offline.
- [ ] Camera: take a photo → **Use this photo?** — **Retake** goes back to the camera, **Discard** closes with no scan;
      **Use photo** adds the scan to Today. Each scan card's trash button asks first and removes it (also while
      analyzing).
- [ ] Photo estimates (when set up): the first photo asks first; **Keep photos on this phone** → nothing uploaded
      (no “Photo estimate ready”). Turn it on in Settings → photo → review shows ≈ kcal/protein, sources (USDA name
      + data type; for an ambiguous food, pick one of the listed entries, then **Change**) and
      “Estimated from photo”; change an amount (→ “Your amount”), remove a food, **Find** an unmatched one (then
      **Log meal** before **Add** → “Photo estimate not added”), **Add**, **Log meal**. Airplane mode → “Couldn't
      reach Nutriq's server” notice + fallback.

**Troubleshooting**

| Symptom | Fix |
|---|---|
| No sign-in options at all | You ran without `--dart-define-from-file=config/nutriq.json`, or the values are still placeholders |
| “permission denied” when syncing | Run the migration (section 3) — it grants signed-in users access to their own rows |
| Email link says “can't open page” on a Mac | Expected; sign in in the app. On an iPhone the link opens Nutriq |
| Delete account says “Nothing was deleted … not deployed” | Deploy the function (section 6) |
| Delete account says “Please sign in again” | The session expired: sign out and in, then retry |
| Google button missing | Both `GOOGLE_*_CLIENT_ID` values must be set (section 9) |
| Apple button missing | iOS only, and `APPLE_SIGN_IN_ENABLED` must be `true` with the paid-team entitlements |
| Apple Health numbers stay “—” | Check Health app → Profile → Apps → Nutriq; add sample data on the Simulator |
| Personal Team app stops opening after 7 days | Re-run it from Xcode/Flutter (free provisioning expires) |
| No “Try the AI coach?” card | `AI_COACH_ENABLED` isn't `true` in `config/nutriq.json`, or you're not signed in |
| No “Get a photo estimate?” / no **Settings → Photo estimates** | `PHOTO_ESTIMATES_ENABLED` isn't `true` in `config/nutriq.json`, or you're not signed in |
| “Photo estimates aren't set up on the server yet” | Section 8: the `GEMINI_API_KEY` secret, the photo-scan migration and the `scan-photo` function |
| “…reached its free limit for now” | Gemini's free quota for your project; try later or enable billing (paid terms) |
| “The nutrition lookup was busy…” / foods with “No nutrition data found” | USDA rate limit or no `FDC_API_KEY`; use **Find** to pick a food |
| Coach: “isn't set up on the server yet” | Do section 7: the `ANTHROPIC_API_KEY` secret, the coach migration and the `coach` function |
| Coach: “Sign in again to use the AI coach” | The session expired: sign out and back in |
| Coach: “couldn't answer just now” | Check the `coach` function's **Logs** in Supabase and your Anthropic credit/spend limit |
| Coach: “You've used today's 30 AI messages” | The daily allowance; it resets at midnight UTC |
