# Evaluating photo estimates

**Status:** no labelled meal photos exist yet, so photo-estimate accuracy has **not** been measured. The code
checks (tests) prove the plumbing — consent, what is sent, matching rules, what is counted — not whether Gemini
recognises foods or portions correctly. This guide is how to measure that on real meals.

The method follows Nutrition5k (Thames et al., CVPR 2021): weigh what is really on the plate, compare the
estimate with it, and report errors both in absolute units and as a percentage of the mean.

## 1. Build a labelled set (30+ meals)

Aim for at least 10 meals in each group, so one kind of meal doesn't hide another's errors:

| Category | Examples |
|---|---|
| `simple` | one or two plain foods: a banana, white rice and a fried egg, a slice of bread |
| `mixed` | several foods on one plate, or a composite dish: rice + viand + vegetables, pasta with sauce, salad |
| `filipino` | adobo, sinigang, tapsilog, pancit, kare-kare, longganisa, champorado, lugaw… |

For each meal:

1. **Weigh** each separately served food on a kitchen scale (tare the plate first). Weigh a mixed dish that can't
   be separated (adobo, sinigang) as one food. Write down what it really is, including the cooking method.
2. **Reference nutrition** for the weighed amount: from the package label, or from the USDA FoodData Central
   entry you would choose by hand (fdc.nal.usda.gov), × grams ÷ 100. If there's no trustworthy reference for a
   home-cooked dish, leave kcal and protein **blank** — the meal still counts for food recognition and portions,
   and is left out of the calorie and protein totals. Don't copy values from sources whose terms forbid reuse.
3. **Photograph it** with Nutriq's camera, in good light, whole plate in frame — then also save a copy to Photos so
   the *same* photo can be re-scanned later for another model.
4. **Record what the app shows before you change anything** (see §2).

Keep the photos and the spreadsheet **outside this repository**. Remember that on Gemini's free tier, Google may use
uploaded photos to improve its products — only use meals you're happy to share that way.

## 2. Record the results (CSV)

One row per food. `run` is `truth` for the weighed foods, or a label for the model you scanned with.

```
meal,category,run,food,matches,grams,kcal,protein
m01,filipino,truth,White rice,,200,260,5.4
m01,filipino,truth,Fried egg,,50,98,6.8
m01,filipino,flash-lite,Kanin,White rice,250,325,6.75
m01,filipino,flash-lite,Hotdog,,40,116,4
m01,filipino,flash-lite,Cooking oil,,,,
```

For every suggested food in the **Photo estimate** card, before editing:

- `food`: the name shown; `grams`: the amount shown (the middle of the photo's range); `kcal` / `protein`: the
  "≈ … kcal · … g" shown on that row.
- Leave `kcal` / `protein` **blank** when the app didn't count the food — "Possible ingredients" you didn't include,
  "Several USDA foods could match" you didn't pick, or "No nutrition data found". The scorer reports these as
  *not counted by the app*.
- `matches`: the truth food it corresponds to, even if named differently ("Kanin" → "White rice"). Leave it blank
  when the suggestion is a different food (a false suggestion); the truth food then counts as missed unless another
  suggestion matches it. If one food is split into two suggestions, give both the same `matches`.

## 3. Score it

```bash
dart run tool/photo_eval.dart path/to/meals.csv
```

For each run, overall and per category, it prints:

- **Food items** — precision (suggested foods that were really there), recall (foods on the plate that were
  suggested), the missed foods and the false suggestions.
- **Portions** — for matched foods with an amount: mean absolute error (g), signed bias (g, + = overestimate), and
  mean % error.
- **Meal totals** — calories and protein: mean absolute error, signed bias, and error as a % of the mean weighed
  total. Meals without reference values are skipped here.

## 4. Compare a candidate model on the same photos

The production model stays `gemini-3.5-flash-lite`. `scan-photo` also allows one reviewed comparison model,
`gemini-3.8-flash` (image input, free tier available; it can't use "minimal" thinking, so the function asks it for
"low"). Nothing runs both models on a scan — you switch, re-scan, and switch back:

1. Supabase → Edge Functions → Secrets → add `GEMINI_MODEL` = `gemini-3.8-flash`. Any other value makes the
   function answer "not set up", so a typo can't route photos to an unreviewed model.
2. Re-scan the **same** saved photos from the photo library and record them with `run` = `3.8-flash`.
3. Delete the `GEMINI_MODEL` secret to go back to the production model.

Things to plan around (your decision — nothing here changes them):

- The daily allowance (`SCAN_DAILY_LIMIT`, default 10 per person) also limits evaluation scans. Spread runs over a few
  days rather than raising it; raising it is a separate choice.
- Gemini's free-tier quota is shared by everyone using your project, and the comparison model may count against a
  different quota. Don't enable billing for this unless you decide to.

**What counts as a meaningful improvement:** first re-scan about 5 photos twice with the *same* model to see how
much results vary run to run. Switch the default only if the candidate is better by more than that on the same
photos — higher recall without lower precision, lower calorie error — and not worse in any category, especially
`filipino`. Fewer than ~30 meals is too few to decide.

Other settings worth comparing the same way once the set exists: Gemini's `high` media resolution (more image tokens
per photo; Google recommends starting with the default), and the upload size (1024 px today).

## 5. In-app feedback (next step, not built)

The existing "How did this estimate look?" feedback is one rating (too high / about right / too low) plus a note,
stored on the phone and synced to the `scan_feedback` table, whose `rating` column only accepts those three values.
Separate categories — **wrong food, missing food, wrong portion, wrong nutrition match** — would need a migration
(an `issues` column with those values), a matching change to the `nutriq_push_scan_feedback` function, and optional,
clearly explained chips in the app. They should store no photos and no provider responses. Until then, use the note.

## References

- Nutrition5k: Towards Automatic Nutritional Understanding of Generic Food (Thames et al., CVPR 2021) — weighed
  ground truth; errors reported in absolute terms and as % of the mean; model compared with nutritionists' visual
  estimates.
- Gemini models and pricing: ai.google.dev/gemini-api/docs/models · media resolution:
  ai.google.dev/gemini-api/docs/media-resolution
- USDA FoodData Central API guide: fdc.nal.usda.gov/api-guide (public domain, CC0).
- The AJCN food-image nutrition study linked in an earlier brief couldn't be retrieved (HTTP 403), so it isn't
  summarised here.
