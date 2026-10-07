# Nutriq "describe your meal" — implementation plan

**Problem:** "Scan food" returned one of 8 sample meals chosen from the photo's bytes (e.g. spaghetti for tuna and
rice). It never looked at the photo. Real photo recognition needs a paid vision model (the user postponed the API
key), so this plan makes logging accurate without AI.

**Approach:** A built-in food list (typical values per 100 g with named portions) and an on-device parser that turns
"century tuna and 2 cups of rice" into foods with portions. After a photo, Nutriq stops inventing a meal and asks
"What's in this photo?". The food list also powers search in "Add an ingredient".

## Constraints

- Nutrition stays labelled as estimates; values are typical references, editable per item.
- Photos stay on the phone. A photo whose meal is cancelled is deleted.
- Keep the analysis interface so a real photo recogniser can be plugged in later (`recognizesPhotos`).
- No new packages, no network.

## Tasks

1. `lib/domain/food_catalog.dart` — `CatalogFood` (per-100 g values, aliases, brand aliases, portions in grams,
   default portion), ~100 everyday foods incl. Filipino staples; `FoodCatalog.search`. Test data sanity (kcal ≈
   4P + 4C + 9F, unique aliases, default portions exist).
2. `lib/domain/meal_description.dart` — `MealDescription.parse(text)` → items + unmatched text. Quantities (2, 1/2,
   1 1/2, ½, "two", "half", "2 and a half", "x2"), units (cup, can, piece, slice, bowl, plate, tbsp, tsp, g, kg,
   ml, oz, glass, pack, sachet, scoop), separators (and, with, comma, plus, &), lead-ins ("I had…"), plurals, typos.
3. `FoodAnalysisService.recognizesPhotos`; `NoPhotoRecognitionService` (app default); `MealFlows` sends photos to
   the editor's describe step when nothing recognises photos; camera hint; "+ → Describe meal"; "Log manually" opens
   the describe step.
4. `DescribeMealCard` in the meal editor (shown for new meals with no foods); catalog results in the add-food sheet.
5. Copy: Settings → About / What Nutriq stores, README, setup guide checklist.

## Review focus

- Text with no known food → nothing added, the text is shown as "not found" with a way to add it by hand.
- Cancelling the editor after a photo deletes that photo.
- "coffee with milk" / "mac and cheese" stay one food (separator words inside names).
- Existing meals logged as demo scans still show their demo label.
