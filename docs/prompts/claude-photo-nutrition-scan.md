# Claude Code Prompt: Nutriq Photo Nutrition Scan

```text
Implement the next Nutriq photo-scan phase: show a useful, editable estimate of the foods, calories, and protein in a meal photo.

First inspect the repo instructions and current scan flow. Preserve the existing uncommitted work from the previous scan-safety changes. Do not reset, revert, overwrite, or commit those changes.

Current behavior to account for:
- iOS uses VNClassifyImageRequest, Apple’s general image classifier.
- The on-device analysis service returns suggestions and no nutrition items.
- Nutrient values come from Nutriq’s food catalog after a person selects a food and serving.
- Android currently uses NoPhotoRecognitionService.
- The existing Supabase coach function demonstrates how this app authenticates a caller and stores an API key server-side.

## Goal

Add an optional image-analysis path that can suggest a dish and its visible components, estimate a serving, and show an approximate calorie/protein result for the person to review. Keep the existing local/manual path working. Never present AI estimates as exact measurements.

## Suggested architecture

1. Add a separate Supabase Edge Function for photo analysis. Use a currently supported image-capable Gemini API model, selected/configured in one place. Keep GEMINI_API_KEY in Supabase Function secrets; never put it in Flutter, app config, logs, Git, or a client-visible response.

2. Follow the existing coach function’s signed-in user validation pattern. Add a separate configurable per-user scan limit and clear handling for missing configuration, timeouts, provider quota errors, and offline use. Do not reuse or weaken the coach limit.

3. Make cloud analysis opt-in. Before the first upload, explain in plain language that the photo will leave the phone and be sent to Google for analysis, and that Google’s unpaid API terms allow submitted content to be used to improve its products. Offer a clear on-device/manual option. Do not enable uploads until the person agrees.

4. Keep image processing minimal: resize/compress before upload, remove photo metadata where possible, enforce a request-size limit, and do not store or log image bytes, prompts, or provider responses. Do not deploy the function, set secrets, call a live provider, or upload a real photo as part of this coding task. Document setup steps for me.

5. Have the vision model return structured candidate data, such as:
   - likely dish name and alternatives;
   - visible ingredient candidates;
   - whether an ingredient is visibly identified or inferred;
   - an editable approximate serving range when it can make a reasonable estimate;
   - uncertainties such as hidden sauce, oil, recipe differences, or unclear portions.

   Do not treat model-generated confidence values as probabilities. Do not ask the model to provide authoritative calories or protein.

6. Calculate nutrition from data, not free-form model guesses. Match candidates against Nutriq’s existing catalog first. Where appropriate, add a server-side USDA FoodData Central lookup using an FDC_API_KEY Supabase secret. Cache successful nutrient lookups by food ID. Keep source metadata so the UI can say where a value came from.

   For Filipino dishes, use existing Nutriq entries where available. Do not scrape, copy, or bundle PhilFCT data without confirming that reuse is permitted. If a food cannot be matched to a trusted nutrition entry, say so and let the person search or correct it rather than inventing exact macros.

7. Compute calories and macros deterministically from the matched per-100-gram nutrition values and the chosen or confirmed grams. The review should show the estimated meal calories and protein promptly, with an editable ingredient/serving breakdown. Keep each amount clearly marked as estimated until the person confirms or edits it. Allow removing wrong suggestions and adding missed foods. Do not log until the person confirms.

8. Keep the current on-device iOS suggestion path when cloud analysis is disabled, declined, unavailable, or out of quota. If cloud analysis is enabled, make the same review flow available on Android. Never show Android photo recognition as working when the cloud path is unavailable.

9. Preserve Nutriq’s name, design, meal history, food editing, and existing age/health safeguards. Keep this task focused on scan analysis. Update the README and setup guide with the data flow, required secrets, consent behavior, free-tier/privacy caveats, fallback behavior, and remaining accuracy limits.

## Completion report

Summarize the files changed, how to configure the optional provider and nutrition lookup, what is sent off-device, and what still needs real-photo validation. Clearly distinguish automated code checks from recognition accuracy. Do not claim that the feature is accurate until it has been compared with real meals whose ingredients and portions are known.
```
