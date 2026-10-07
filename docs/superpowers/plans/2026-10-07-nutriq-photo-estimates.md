# Nutriq optional photo estimates — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (native) — tasks are tightly coupled, so
> they run in this session with TDD, then one whole-branch review.

**Goal:** An opt-in cloud path that turns a meal photo into an editable estimate — likely dish, visible/inferred
components, an approximate portion range, and calories/protein computed deterministically from trusted per-100 g data
— while the on-device/manual path keeps working.

**Architecture:** The app prepares a small, metadata-free JPEG and (only after explicit consent) sends it to a new
Supabase Edge Function `scan-photo`. The function checks the caller's sign-in, takes one turn from a separate daily
scan allowance, asks Gemini (`gemini-3.5-flash-lite`, stateless `generateContent`, JSON schema output) for *candidates
only* (no calories, no confidence), and looks each component up in USDA FoodData Central (optional `FDC_API_KEY`,
cached by FDC ID in Postgres). The app resolves each component catalog-first → FDC → "no match", computes
`grams × per-100 g` itself, and shows a staging card in the review; nothing is added or logged until the person
confirms. Any failure falls back to on-device suggestions (iOS) or describing the meal (Android), with a notice.

**Tech:** Flutter/Dart (`image` 4.x for resize/re-encode in an isolate), supabase_flutter `functions.invoke`, Deno
Edge Function (plain `fetch`, no npm), Postgres (RLS, security-definer allowance), Gemini API, USDA FDC API.

**Verified API facts (2026-10-07 docs):** `gemini-3.5-flash-lite` is Stable, takes images, supports structured
outputs and has a free tier whose content is "used to improve our products"; Gemini's unpaid-services terms say
Google uses submitted content and responses to improve products and human reviewers may read it.
`POST /v1beta/models/{model}:generateContent` with `generationConfig.responseMimeType` + `responseJsonSchema`; the
Interactions API stores requests by default (1 day free / 55 days paid) so the stateless endpoint is used. FDC:
`GET /fdc/v1/foods/search?api_key=…&query=…&dataType=Foundation,SR Legacy,Survey (FNDDS)&pageSize=…`, values per
100 g, 1,000 requests/hour/IP, 429 when exceeded, CC0 public domain.

## Global constraints

- Preserve the uncommitted scan-safety work; never reset, revert or commit.
- `GEMINI_API_KEY`, `FDC_API_KEY` only as Supabase function secrets — never in Flutter, config, logs, Git or responses.
- Don't deploy, set secrets, call a live provider or upload a real photo. Document setup for the user.
- Upload only after explicit opt-in that says the photo leaves the phone, goes to Google, and that Google's unpaid
  terms allow using it to improve products; offer on-device/manual instead.
- Resize (≤ 1024 px), re-encode JPEG without metadata, enforce size limits client- and server-side; never store or
  log image bytes, prompts or provider responses.
- The model gives candidates only. Calories/macros come from catalog or FDC per-100 g data × grams. Model "confidence"
  is not requested or shown. Unmatched foods are shown as unmatched, never given invented macros.
- Every amount is marked estimated until the person edits/confirms it; nothing is logged until they confirm.
- Separate per-user scan limit (configurable, `SCAN_DAILY_LIMIT`, default 10); coach limit untouched.
- Android shows photo recognition only when the cloud path is enabled and consented.
- Keep Nutriq's name, design, history/editing, safeguards and unrelated features.

## Review focus

- Cloud failure mid-flow (offline, timeout, 429 provider quota, daily limit, 404/503 not set up) → draft still
  reviewable with an honest notice, on-device suggestions on iOS, describe on Android.
- Consent declined → no upload ever happens, even if the build flag and backend exist.
- A component with no catalog/FDC match → no nutrition shown for it, clearly marked, searchable.
- Photo with EXIF/GPS → uploaded bytes contain no EXIF/XMP segment; oversize input → refused before upload.
- Model returns junk/oversized/negative grams or extra calorie fields → server clamps/drops; client never shows them.

## File map

| File | Responsibility |
|---|---|
| `supabase/migrations/20261007120000_photo_scan.sql` | `scan_usage` + `nutriq_scan_take_turn(p_limit)`; `fdc_food_cache`, `fdc_query_cache` (service role only) |
| `supabase/tests/photo_scan_test.sql` (+ runner, stub `service_role`) | allowance + cache privileges |
| `supabase/functions/scan-photo/index.ts` | auth, consent flag, size/JPEG checks, metadata strip, allowance, Gemini, validation, FDC + cache |
| `supabase/tests/scan_photo_function_test.ts` | Node tests with fake `fetch` |
| `lib/services/food_analysis/photo_upload.dart` | `preparePhotoForUpload` (isolate; resize, orientation, no metadata, ≤ 900 KB) |
| `lib/domain/models/photo_estimate.dart` | `PhotoEstimate`, `EstimatedFood` (JSON, per-100 g, grams, source) |
| `lib/domain/photo_estimate_resolver.dart` | server JSON → `PhotoEstimate`, catalog-first matching |
| `lib/services/food_analysis/photo_estimate_backend.dart` | interface, failures, Supabase implementation + error mapping |
| `lib/state/photo_analysis_controller.dart` | consent state (meta `scan_cloud`), cloud-or-on-device routing, fallback notices |
| `lib/features/meal_editor/photo_estimate_card.dart` | staging card: dish, total ≈ kcal/protein, rows with grams, sources, remove/find, add |
| `lib/features/scan/photo_consent.dart` | consent copy + sheet; Settings switch helper |
| existing: `scan_draft.dart`, `food_analysis_service.dart`, `scan_controller.dart`, `session.dart`, `main.dart`, `env.dart`, `meal_flows.dart`, `meal_editor_screen.dart`, `meal_cards.dart`, `settings_screen.dart`, `meal_description.dart` (public exact match), docs | wiring |

## Tasks (each: failing test → code → green → full suite)

1. **SQL** — scan allowance (fresh, counts, refuses at limit, limit clamped 1–200, separate from coach, anon refused,
   cascade) and caches (authenticated/anon can't read or write).
2. **Edge function** — 405/401/400/413; consent required; JPEG check; EXIF/XMP/COM stripped before upload; 503 when
   `GEMINI_API_KEY` or allowance function missing; 429 daily limit (+resetsAt, limit); Gemini request shape (model,
   key header, inlineData, schema, no calories asked); provider 429 → `provider_quota`, 5xx → `provider_error`,
   timeout → 504; output validated (caps, clamps, drops unknown fields); FDC mapping (energy 208/1008, else
   957/958 Atwater; protein 203; carbs 205; fat 204), query + food cache read/write, no FDC key → `fdc: null`;
   nothing image-related logged.
3. **Upload prep** — decodes, bakes orientation, longest side ≤ 1024, output JPEG with no `Exif`/`XMP` bytes,
   ≤ 900 KB, rejects non-images.
4. **Estimate domain** — resolver: catalog match (exact aliases, local name first), else FDC, else none; grams =
   photo-range midpoint, else catalog typical portion (flagged "not from the photo"), else needs amount; totals =
   Σ grams × per-100 g / 100 over foods with nutrition and an amount; `toItem` FoodItems; JSON round trip; ScanDraft
   carries `estimate` + `notice` (old drafts still load).
5. **Backend + controller** — status/error mapping; consent states persisted per account; cloud only when backend +
   consent; fallback with notices; upload prep failure → fallback; Android-style service without recognition only
   recognises photos when cloud is on.
6. **UI** — consent sheet before the first upload (decline → on-device, never uploads); Settings switch (asks before
   on); review card (≈ total, rows: source line, "Estimated"/"Your amount", photo range, inferred tag, grams stepper,
   remove, Find for unmatched, uncertainties, "Add N foods to meal"); Today card copy; notice card; nothing logged
   before Log meal.
7. **Docs** — README + setup guide: data flow, secrets, consent, free-tier/privacy caveats, fallbacks, limits.
8. **Verify** — format, analyze, full Flutter suite, Node tests, SQL tests, iOS build; whole-branch code review.
