# Audit fixes — Implementation Plan

> Executed inline with TDD (superpowers:executing-plans + test-driven-development). Findings, evidence and the
> Cal AI comparison are in `docs/AUDIT_2026-10-07.md`.

**Goal:** Fix the confirmed bugs and the most important gaps found in the 2026-10-07 audit, without new
dependencies or production changes.

## Global constraints

- No commits, pushes, deploys or live Supabase changes; preserve all existing uncommitted work.
- No new dependencies. Keep Flutter / Supabase / HealthKit architecture.
- Values that reach the cloud must satisfy the schema: servings 0–100, ≤ 5,000 kcal per serving.
- Format Dart with `dart format --line-length 120`.

## Tasks

1. **Describe-meal amounts** — `MealDescription.parse` rejects non-finite, zero and out-of-range amounts
   ("1/0 cup rice" → Infinity, "0/0" → NaN, "99999 cups") and reports them as `unclearAmounts`; the editor says
   "Check the amount" instead of adding them. Tests: test/domain/meal_description_test.dart, describe widget test.
2. **Photo-estimate servings** — `EstimatedFood.toItem` splits very large amounts into equal servings so no
   serving exceeds 5,000 kcal (otherwise the meal can never sync). Test: photo_estimate_test.
3. **Apple Health on edit/delete** — `HealthService.deleteMeal`; `HealthController` deletes and rewrites an
   already-written meal when its nutrition or time changes, and deletes it when the meal is deleted.
   `MealLogController` reports the previous version and deletions. Tests: health controller + meal log.
4. **Coach request intake** — check sign-in before reading the body; cap the body while streaming
   (same pattern as `scan-photo`). Tests: coach_function_test.
5. **History day picker accessibility** — button role, selected state and a spoken date/calories label.
   Test: widget.
6. **Verify** — format, analyze, all suites, simulator build; self-review; report.

## Review focus

- A typed amount can never produce a meal that crashes on save or can't sync.
- Editing a meal never doubles its nutrition in Apple Health; deleting removes only that meal's samples.
- Coach: an unsigned caller's body is never read.
