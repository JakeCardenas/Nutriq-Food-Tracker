# Scan accuracy, safe matching and photo deletion — Implementation Plan

> Executed inline (superpowers:executing-plans) with TDD. Builds on partial work another tool left in
> `scan-photo/index.ts`, `photo_estimate_card.dart` and `camera_screen.dart` (snapshot kept outside the repo);
> the user stopped that tool and asked me to continue on top of it.

**Goal:** Better food coverage and honest matching in photo estimates, plus a clear way to delete a photo
after capture and from any scan draft.

**Spec:** the user's brief of 2026-10-07 ("Improve Nutriq's food photo scanning accuracy and food coverage, and add
a clear way to delete a photo after capture").

## Global constraints

- No deploys, live provider calls, Supabase data changes, secrets, billing, or photos in the repo. No commits.
- The model never supplies calories or protein; nutrition comes from Nutriq's list or USDA FDC (CC0).
- Hidden/inferred ingredients are never counted unless the person includes them.
- Keep consent, metadata removal, size limits, auth, rate limits, fallbacks, manual entry and review as they are.
- Production model stays `gemini-3.5-flash-lite` unless a labelled comparison shows a meaningful gain.
- Keys stay in Supabase secrets; nothing new in Flutter config.
- Format Dart with `dart format --line-length 120` (repo style).

## Findings that drive the changes (code + docs inspection; no labelled photos exist)

| Area | Limitation found | Change |
|---|---|---|
| Recognition | Ambiguity only expressible for the whole dish; a single food had to be named precisely | Per-food `alternatives` (≤ 2); the review lets the person switch |
| Recognition | Old cap of 6 components counted hidden items too (fixed by the other tool: 8 visible + 4 inferred) | Keep; test it |
| Portions | A range like 250–250 g reads as an exact weight | Server widens ranges narrower than ±10 % around the same midpoint |
| Matching | Generic food-list aliases ("chicken", "fish", "egg", "rice", "vegetables"…) turn a generic photo label into one specific food | Photo matching ignores generic aliases; typed descriptions keep them |
| Matching | Common Filipino spellings missing for foods already in the list | Add genuine aliases only (no new nutrition data) |
| Matching | FDC docs say `dataType` must be an array; we sent a comma string in a GET | POST JSON body with `dataType` array |
| Matching | The other tool made a "clear" USDA match require identical descriptions, so same-nutrition variants (long- vs short-grain rice) always ask the person | Ruling: keep the deployed rule (all fully matching entries agree on kcal/protein) |
| Model | Comparison model may think by default and hit the output cap | `maxOutputTokens` 4096; `thinkingLevel: "low"` only for the comparison model |
| Photo quality | 1024 px JPEG upload; Gemini docs recommend the default media resolution unless testing shows a gain | No change; listed for evaluation |
| Honesty | Camera tips say the photo is "never uploaded" even with cloud estimates on | Conditional copy |
| Today | Draft totals counted hidden ingredients | Exclude inferred foods from the summary |
| Deletion | Discard only on failed drafts; capture saved immediately; temp copies left behind | Post-capture Retake / Discard / Use photo; discard (with confirmation) on every draft; temp removed via PhotoService; never delete a photo a logged meal uses |
| Feedback | Existing flow is one rating + note, synced to a `scan_feedback` table whose `rating` is constrained | Not changed here (needs a hosted schema + RPC change); documented as next step |

## Tasks

1. **scan-photo function** — per-food alternatives, range widening, output budget/thinking, FDC POST, matching rule,
   tests updated for the other tool's prompt/limits. (`supabase/functions/scan-photo/index.ts`,
   `supabase/tests/scan_photo_function_test.ts`)
2. **Photo matching** — generic aliases excluded from `MealDescription.exactMatch`; genuine Filipino aliases.
   (`lib/domain/meal_description.dart`, `lib/domain/food_catalog.dart`, domain tests)
3. **Estimate model + review** — `alternatives` on `EstimatedFood`; resolver switch to an alternative; card shows
   "Could also be"; Today summary excludes inferred; tests updated for the other tool's "Include in estimate".
4. **Post-capture review** — finish the other tool's in-place review (`_CapturedPhotoActions`), route temp deletion
   through `PhotoService`, delete temp after `persist`, test seam for widget tests; camera tips copy.
5. **Draft discard** — compact discard on every `DraftCard` state, confirmation, `ScanController` guard for photos
   used by logged meals, in-flight test.
6. **Evaluation** — `docs/PHOTO_ESTIMATE_EVALUATION.md` and `tool/photo_eval.dart` (scores a labelled CSV:
   precision/recall, gram error, kcal/protein MAE and bias, per category) with tests; README/setup updates.
7. **Verify** — format, analyze, all suites, simulator build, self-review, report.

## Review focus

- Discard while analyzing: a late result must not recreate the draft.
- A draft whose photo is already used by a logged meal: discarding keeps the file.
- Retake / Discard never create a draft or upload; only Use photo continues.
- Inferred foods never reach a total or "Add N foods" without Include.
- Generic labels ("chicken") no longer silently become a specific food.
