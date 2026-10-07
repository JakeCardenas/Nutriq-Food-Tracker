# Nutriq AI coach — implementation plan

**Goal:** Replace the scripted coach with a real AI coach (Claude Sonnet 5.5) for signed-in users, without
putting any AI key in the app and without weakening Nutriq's safety rules.

**Architecture:** The app calls a new Supabase Edge Function `coach` with the person's question, recent chat and a
minimal summary of their goals and meals. The function checks the caller's sign-in, re-applies the safety rules,
takes one turn from a per-user daily allowance (SQL function, 30/day), and streams Claude's reply back as
server-sent events. The Anthropic key exists only as the Supabase secret `ANTHROPIC_API_KEY`. The app keeps its
on-device safety pre-check and falls back to the clearly labelled demo coach when the AI isn't available.

**Tech:** Flutter / supabase_flutter `functions.invoke` (SSE stream), Deno Edge Function (no npm deps, plain
`fetch`), Postgres function + RLS, Anthropic Messages API (`claude-sonnet-5-5`, `stream: true`).

## Global constraints

- No AI-provider key, service-role key or other secret in the app, repo or chat.
- Don't apply migrations, set secrets, deploy functions or push — the user does that.
- Don't modify the applied migration `20261006000000_nutriq_schema.sql`; add a new one.
- AI coach only after explicit, per-account opt-in on this phone; off → demo coach (labelled).
- Never send meal photos or Apple Health data to the AI. Send age group, not exact age; no sex/height.
- Keep CoachSafety pre-checks (client) and mirror them server-side. No targets/weight-loss advice for under-18s or
  pregnancy/breastfeeding/medical conditions; no diagnosis/medication; no extreme restriction; supportive referral
  for eating-disorder signs; numbers are estimates.
- Label AI replies "AI coach · can make mistakes"; label fallbacks as scripted and say why.
- Chats stay in memory only; the server stores only a daily message count per user.

## Tasks

1. **Migration `20261007000000_coach_usage.sql`:** `coach_usage(user_id, day, count)` with owner-only select
   RLS and no client write grants; `nutriq_coach_take_turn()` (security definer, `auth.uid()`, limit 30/UTC day,
   returns remaining or −1). SQL test `supabase/tests/coach_usage_test.sql` run by `run_rls_tests_locally.sh`.
2. **Edge Function `supabase/functions/coach/index.ts`:** exported pure `handle(req, deps)` + helpers
   (`validateRequest`, `safetyReply`, `systemPrompt`, `translateAnthropicStream`); `Deno.serve` only when running
   under Deno. Node test `supabase/tests/coach_function_test.ts` with a fake `fetch`.
3. **App service layer:** `CoachContext` gains today's meals, saved foods and units; `CoachReply`/`ChatMessage`
   gain `notice`; `reply()` gains `onPartial`. New `CoachPayload` (minimal JSON), `CoachBackend` +
   `CoachBackendException`, `AiCoachService` (safety → stream → tidy, falls back to demo with a notice),
   `SupabaseCoachBackend` (SSE decoder + status mapping).
4. **Controller + wiring:** `CoachController` loads/stores the opt-in (`coach_ai` meta), exposes `aiAvailable`,
   `needsAiChoice`, `streamingText`, `setAiEnabled`; `SessionServices.coachBackend` only for signed-in sessions.
5. **UI:** consent card on Coach; streaming bubble; AI/demo labels and captions; Settings switch (with confirm) and
   updated "What Nutriq stores" + About row.
6. **Docs:** README coach section; SETUP_AND_TESTING section "AI coach" (key → secret → migration → deploy).

## Review focus

- Offline mid-stream: partial text is kept and marked as cut off, never silently lost.
- Signed out / expired session → scripted fallback with "sign in again", no crash.
- Function not deployed (404) or key/migration missing (503) → "not set up yet" fallback.
- Daily limit → message with local reset time; server never calls Anthropic past the limit.
- Restricted profile edited on another device → server reads `profiles` row and still restricts.
