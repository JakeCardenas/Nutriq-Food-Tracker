import 'package:flutter/material.dart';

import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/food_catalog.dart';
import '../../domain/models/food_item.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/sheet.dart';

/// Choose how much of a food from Nutriq's list was eaten before it's added.
/// The starting amount is only a suggested serving; nutrition is an estimate
/// from typical values.
Future<FoodItem?> showServingSheet(BuildContext context, CatalogFood food) =>
    showNqSheetWith<FoodItem>(context, builder: (_) => _ServingSheet(food: food));

class _ServingSheet extends StatefulWidget {
  const _ServingSheet({required this.food});

  final CatalogFood food;

  @override
  State<_ServingSheet> createState() => _ServingSheetState();
}

class _ServingSheetState extends State<_ServingSheet> {
  late String _unit = widget.food.defaultUnit;
  double _amount = 1;

  String _portionText(Portion p) => '${p.label} (${fmtAmount(p.grams)} ${widget.food.liquid ? 'ml' : 'g'})';

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final item = food.item(quantity: _amount, unit: _unit);
    final t = item.totals;
    return SheetBody(
      key: const ValueKey('serving-sheet'),
      title: food.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Suggested serving — change it to match what you ate.', style: NqText.footnote),
          const SizedBox(height: NqSpace.md),
          if (food.portions.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: unit, value: portion) in food.portions.entries)
                  ChoiceChip(
                    label: Text(_portionText(portion)),
                    selected: unit == _unit,
                    showCheckmark: false,
                    selectedColor: NqColors.inkSoft,
                    backgroundColor: NqColors.fill,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    labelStyle: NqText.subhead.copyWith(color: unit == _unit ? NqColors.onInk : NqColors.ink),
                    onSelected: (_) => setState(() => _unit = unit),
                  ),
              ],
            )
          else
            Text(_portionText(food.portions[_unit]!), style: NqText.body),
          const SizedBox(height: NqSpace.md),
          Row(
            children: [
              StepperControl(value: _amount, onChanged: (v) => setState(() => _amount = v), suffix: '×'),
              const SizedBox(width: 10),
              Expanded(child: Text(food.portions[_unit]!.label, style: NqText.footnote)),
            ],
          ),
          const SizedBox(height: NqSpace.lg),
          _Estimate(kcal: t.calories, protein: t.protein, carbs: t.carbs, fat: t.fat),
          const SizedBox(height: NqSpace.lg),
          PrimaryButton(label: 'Add to meal', onPressed: () => Navigator.pop(context, item)),
        ],
      ),
    );
  }
}

class _Estimate extends StatelessWidget {
  const _Estimate({required this.kcal, required this.protein, required this.carbs, required this.fat});

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: NqColors.fill, borderRadius: BorderRadius.circular(NqRadius.tile)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('≈ ${fmtKcal(kcal)} kcal', style: NqText.headline),
        const SizedBox(height: 2),
        Text('${protein.round()} g protein · ${carbs.round()} g carbs · ${fat.round()} g fat', style: NqText.footnote),
        const SizedBox(height: 6),
        Text('An estimate from typical values — recipes, oil and exact amounts change it.', style: NqText.caption),
      ],
    ),
  );
}
