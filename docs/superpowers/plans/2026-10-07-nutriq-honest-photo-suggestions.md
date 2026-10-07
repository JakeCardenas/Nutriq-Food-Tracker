# Nutriq honest photo suggestions — plan

**Problem (verified in code, not assumed):**

- `FoodVisionPlugin` (ios/Runner/AppDelegate.swift) runs Apple's general-purpose `VNClassifyImageRequest` (1,303
  scene/object labels, not a food model) and returns every label scoring ≥ 0.05.
- `PhotoFoodMapper` keeps any mapped label scoring ≥ 0.25 — a raw score, not a calibrated probability — and turns it
  into a specific dish at a catalog default portion, including unsafe mappings ("fish" → fried tilapia, "paella" /
  "biryani" / "risotto" → fried rice, "poultry" → chicken breast, "vegetable" → chopsuey, "cereal" → corn flakes).
- The score is stored as `FoodItem.confidence`, so the editor shows "Low confidence — check this" for < 0.6.
- The review opens with those foods already in the meal; one tap on "Log meal" saves portions the photo never
  measured. Today's card says "Foods found". Android has no recognition but the menu still says "Scan food".

**Approach:** labels become *suggestions*, never ingredients.

1. Swift also reports whether each label meets Apple's own per-label precision curve at precision 0.7
   (`hasMinimumRecall(0.01, forPrecision: 0.7)`); only those can become suggestions (raw score is used for order only).
2. `PhotoFoodMapper.suggestions` → at most 3 `PhotoSuggestion`s: a direct catalog match only where the label names
   the same food (banana, fried egg, hamburger…); otherwise a search term ("tuna", "rice", "coffee"); broad or
   different-dish labels are dropped. Synonyms and general/specific pairs are deduplicated.
3. `FoodAnalysisResult` / `ScanDraft` carry `suggestions` (JSON, backward compatible). On-device recognition returns
   no items.
4. Review: "Might be in your photo" card with Add / Find / dismiss per suggestion; Add opens a serving sheet
   ("Suggested serving — change it to match what you ate", estimate shown) — nothing is added without it. Catalog
   picks in "Add an ingredient" go through the same sheet. Ingredients start empty.
5. Copy: Today card "Ready to review · Might include …", "No food suggestions"; neutral "Check this food" badge;
   menu says "Take photo" where photos aren't recognised; Settings and docs describe suggestions honestly.

**Out of scope:** paid/remote vision, new packages, new catalog foods, describe-meal parsing.
