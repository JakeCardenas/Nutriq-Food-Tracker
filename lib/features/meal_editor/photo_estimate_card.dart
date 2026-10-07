import 'package:flutter/material.dart';

import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/photo_estimate.dart';
import '../../domain/photo_estimate_resolver.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';

/// The optional cloud photo estimate, as a staging area: a likely dish, the
/// estimated meal total, and each food with its nutrition source and an
/// editable amount. When USDA has several possible entries for a food, the
/// person picks one (or none) — it isn't counted until they do. Nothing is
/// added to the meal until "Add N foods".
class PhotoEstimateCard extends StatefulWidget {
  const PhotoEstimateCard({super.key, required this.estimate, required this.onAdd, required this.onFind});

  final PhotoEstimate estimate;
  final ValueChanged<List<FoodItem>> onAdd;

  /// Look a food up by hand; true when the person picked a replacement.
  final Future<bool> Function(EstimatedFood food) onFind;

  @override
  State<PhotoEstimateCard> createState() => PhotoEstimateCardState();
}

class _Row {
  _Row(this.original)
    : food = original,
      confirmed = !original.inferred,
      grams = original.inferred || !original.hasNutrition ? null : original.suggestedGrams;

  /// As the estimate came; [food] may carry the USDA entry the person picked.
  final EstimatedFood original;
  EstimatedFood food;
  double? grams;
  bool confirmed;

  /// The person changed the amount.
  bool edited = false;

  /// The amount is a 100 g starting point the person asked for, not yet adjusted.
  bool starting = false;
}

class PhotoEstimateCardState extends State<PhotoEstimateCard> {
  late final List<_Row> _rows = [for (final f in widget.estimate.foods) _Row(f)];

  List<_Row> get _ready => [
    for (final r in _rows)
      if (r.food.hasNutrition && r.grams != null && (!r.food.inferred || r.confirmed)) r,
  ];

  /// Foods with nutrition and an amount that haven't been added to the meal yet.
  int get readyCount => _ready.length;

  void _remove(_Row row) => setState(() => _rows.remove(row));

  void _confirm(_Row row) => setState(() {
    row.confirmed = true;
    if (row.food.hasNutrition && row.grams == null) row.grams = row.food.suggestedGrams;
  });

  /// Uses the USDA entry the person picked, or ([usda] null) goes back to the options.
  void _pick(_Row row, UsdaFood? usda) => setState(() {
    row.food = usda == null ? row.original : row.original.withUsda(usda);
    row.grams = !row.confirmed || usda == null ? null : row.food.suggestedGrams;
    row.edited = false;
    row.starting = false;
  });

  /// Switches a food to one of its alternatives, or back to the name the estimate gave.
  void _switch(_Row row, String name) => setState(() {
    row.food = name == row.original.name ? row.original : PhotoEstimateResolver.alternative(row.original, name);
    row.grams = (row.food.inferred && !row.confirmed) || !row.food.hasNutrition ? null : row.food.suggestedGrams;
    row.edited = false;
    row.starting = false;
  });

  Future<void> _find(_Row row) async {
    if (await widget.onFind(row.food) && mounted) setState(() => _rows.remove(row));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.estimate;
    final total = PhotoEstimate.totalFor([for (final r in _rows) (r.food, r.grams)]);
    final ready = _ready;
    final notCounted = _rows.length - ready.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
      decoration: BoxDecoration(
        color: NqColors.card,
        borderRadius: BorderRadius.circular(NqRadius.tile),
        border: Border.all(color: NqColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Photo estimate', style: NqText.headline),
          if (e.dish != null) ...[
            const SizedBox(height: 2),
            Text(
              'Looks like: ${e.dish}${e.alternatives.isEmpty ? '' : ' (or ${e.alternatives.join(', ')})'}',
              style: NqText.footnote,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            ready.isEmpty
                ? 'No nutrition counted yet'
                : '≈ ${fmtKcal(total.calories)} kcal · ${total.protein.round()} g protein',
            style: NqText.title,
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              'Estimated from the photo — check each food and amount.'
              '${notCounted == 0 ? '' : ' $notCounted ${notCounted == 1 ? 'food isn’t' : 'foods aren’t'} counted yet.'}',
              style: NqText.caption,
            ),
          ),
          const SizedBox(height: 6),
          for (final r in _rows.where((r) => !r.food.inferred))
            PhotoEstimateRow(
              key: ObjectKey(r),
              food: r.food,
              grams: r.grams,
              edited: r.edited,
              starting: r.starting,
              confirmed: true,
              onChooseAmount: () => setState(() {
                r.grams = 100;
                r.starting = true;
              }),
              onGrams: (g) => setState(() {
                r.grams = g;
                r.edited = true;
                r.starting = false;
              }),
              onRemove: () => _remove(r),
              onFind: () => _find(r),
              onPickUsda: (usda) => _pick(r, usda),
              onChangePick: () => _pick(r, null),
              names: [r.original.name, ...r.original.alternatives],
              onSwitchName: (name) => _switch(r, name),
            ),
          if (_rows.any((r) => r.food.inferred)) ...[
            const SizedBox(height: 10),
            Text('Possible ingredients', style: NqText.subhead),
            const SizedBox(height: 2),
            Text(
              'These aren’t visible in the photo. Confirm one before its nutrition is counted.',
              style: NqText.caption,
            ),
            for (final r in _rows.where((r) => r.food.inferred))
              PhotoEstimateRow(
                key: ObjectKey(r),
                food: r.food,
                grams: r.grams,
                edited: r.edited,
                starting: r.starting,
                confirmed: r.confirmed,
                onConfirm: () => _confirm(r),
                onChooseAmount: () => setState(() {
                  r.grams = 100;
                  r.starting = true;
                }),
                onGrams: (g) => setState(() {
                  r.grams = g;
                  r.edited = true;
                  r.starting = false;
                }),
                onRemove: () => _remove(r),
                onFind: () => _find(r),
                onPickUsda: (usda) => _pick(r, usda),
                onChangePick: () => _pick(r, null),
                names: [r.original.name, ...r.original.alternatives],
                onSwitchName: (name) => _switch(r, name),
              ),
          ],
          if (e.uncertainties.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('A photo can’t show', style: NqText.subhead),
            for (final u in e.uncertainties) Text('•  $u', style: NqText.footnote),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: PrimaryButton(
              label: ready.isEmpty
                  ? 'Nothing to add yet'
                  : 'Add ${ready.length} ${ready.length == 1 ? 'food' : 'foods'} to meal',
              height: 48,
              onPressed: ready.isEmpty ? null : () => widget.onAdd([for (final r in ready) r.food.toItem(r.grams!)]),
            ),
          ),
        ],
      ),
    );
  }
}

/// One estimated food: source, amount (estimated until the person changes it), remove / find.
class PhotoEstimateRow extends StatelessWidget {
  const PhotoEstimateRow({
    super.key,
    required this.food,
    required this.grams,
    required this.edited,
    this.starting = false,
    this.confirmed = true,
    this.onConfirm,
    required this.onChooseAmount,
    required this.onGrams,
    required this.onRemove,
    required this.onFind,
    required this.onPickUsda,
    required this.onChangePick,
    this.names = const [],
    this.onSwitchName,
  });

  final EstimatedFood food;
  final double? grams;
  final bool edited;

  /// A 100 g starting point the person hasn't adjusted yet.
  final bool starting;
  final bool confirmed;
  final VoidCallback? onConfirm;
  final VoidCallback onChooseAmount;
  final ValueChanged<double> onGrams;
  final VoidCallback onRemove;
  final VoidCallback onFind;

  /// The person picked one of the food's possible USDA entries.
  final ValueChanged<UsdaFood> onPickUsda;

  /// Back to the possible USDA entries.
  final VoidCallback onChangePick;

  /// The estimate's name for this food and its alternatives; shown as choices when there's more than one.
  final List<String> names;
  final ValueChanged<String>? onSwitchName;

  @override
  Widget build(BuildContext context) {
    final f = food;
    final grams = this.grams;
    final totals = grams == null || (f.inferred && !confirmed) ? null : f.totalsFor(grams);
    final usda = f.dataType == null ? 'USDA FoodData Central' : 'USDA FoodData Central (${f.dataType})';
    final choosing = !f.hasNutrition && f.usdaOptions.isNotEmpty;
    final source = switch (f.source) {
      NutritionSource.catalog => 'Nutriq food list: ${f.matchName}',
      NutritionSource.usda when f.pickedByPerson => '$usda, your pick: ${f.matchName}',
      NutritionSource.usda => '$usda: ${f.matchName}',
      NutritionSource.none when choosing =>
        'Several USDA foods could match — pick the one that fits, or leave it uncounted.',
      NutritionSource.none => 'No nutrition data found — find it in the food list or enter it by hand.',
    };
    final status = edited
        ? 'Your amount'
        : starting
        ? 'Starting amount — adjust it to match your plate'
        : f.gramsFromPhoto
        ? 'Estimated from photo (${f.photoLow!.round()}–${f.photoHigh!.round()} g)'
        : 'Typical serving — not from the photo';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(f.displayName, style: NqText.body)),
              if (totals != null)
                Text(
                  '≈ ${fmtKcal(totals.calories)} kcal · ${totals.protein.round()} g',
                  style: NqText.footnote.copyWith(color: NqColors.ink),
                ),
              IconButton(
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18, color: NqColors.textSecondary),
              ),
            ],
          ),
          if (f.inferred)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                confirmed ? 'Possible ingredient — you confirmed it' : 'Possible ingredient — not counted yet',
                style: NqText.caption,
              ),
            ),
          if (f.inferred && !confirmed)
            Align(
              alignment: Alignment.centerLeft,
              child: QuietButton(label: 'Include in estimate', icon: Icons.check_rounded, onPressed: onConfirm),
            ),
          if (names.length > 1 && onSwitchName != null) ...[
            Text('Could also be', style: NqText.caption),
            const SizedBox(height: 4),
            ChoiceChips<String>(options: names, selected: f.name, labelOf: _capitalized, onSelected: onSwitchName!),
            const SizedBox(height: 6),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(source, style: NqText.caption),
          ),
          if (choosing && (!f.inferred || confirmed))
            for (final option in f.usdaOptions) _UsdaOptionTile(option: option, onTap: () => onPickUsda(option)),
          if (f.pickedByPerson && (!f.inferred || confirmed))
            QuietButton(label: 'Change', icon: Icons.swap_horiz_rounded, onPressed: onChangePick),
          const SizedBox(height: 6),
          if (f.inferred && !confirmed)
            const SizedBox.shrink()
          else if (!f.hasNutrition)
            QuietButton(label: 'Find', icon: Icons.search_rounded, onPressed: onFind)
          else if (grams == null)
            QuietButton(label: 'Choose amount', icon: Icons.scale_outlined, onPressed: onChooseAmount)
          else
            Row(
              children: [
                StepperControl(
                  value: grams,
                  step: 10,
                  min: 10,
                  max: 2000,
                  semanticLabel: 'Grams of ${f.displayName}',
                  format: (v) => '${v.round()} g',
                  onChanged: onGrams,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(status, style: NqText.caption.copyWith(color: edited ? NqColors.ink : NqColors.demoInk)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One possible USDA entry for a food: its name, data type and per-100 g values.
class _UsdaOptionTile extends StatelessWidget {
  const _UsdaOptionTile({required this.option, required this.onTap});

  final UsdaFood option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = option.dataType == null ? '' : '${option.dataType} · ';
    return Semantics(
      button: true,
      label: 'Use USDA entry: ${option.description}',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 6, right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: NqColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(option.description, style: NqText.footnote.copyWith(color: NqColors.ink)),
              const SizedBox(height: 2),
              Text(
                '$type${fmtKcal(option.kcal100)} kcal · ${option.protein100.round()} g protein per 100 g',
                style: NqText.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
