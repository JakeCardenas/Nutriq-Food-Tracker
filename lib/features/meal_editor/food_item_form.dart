import 'package:flutter/material.dart';

import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/ids.dart';
import '../../domain/models/food_item.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/sheet.dart';

double? parseNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

/// Name, portion and per-serving nutrition for one food.
class FoodItemForm extends StatefulWidget {
  const FoodItemForm({super.key, this.initial, required this.submitLabel, required this.onSubmit, this.secondary});

  final FoodItem? initial;
  final String submitLabel;
  final ValueChanged<FoodItem> onSubmit;

  /// Extra actions under the submit button (save to My foods, remove…).
  final Widget? secondary;

  @override
  State<FoodItemForm> createState() => _FoodItemFormState();
}

class _FoodItemFormState extends State<FoodItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _serving = TextEditingController(text: widget.initial?.servingLabel ?? '1 serving');
  late final _kcal = TextEditingController(text: _num(widget.initial?.caloriesPerServing));
  late final _protein = TextEditingController(text: _num(widget.initial?.proteinPerServing));
  late final _carbs = TextEditingController(text: _num(widget.initial?.carbsPerServing));
  late final _fat = TextEditingController(text: _num(widget.initial?.fatPerServing));
  late double _servings = widget.initial?.servings ?? 1;

  static String _num(double? v) => v == null ? '' : fmtAmount(double.parse(v.toStringAsFixed(1)));

  @override
  void dispose() {
    for (final c in [_name, _serving, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Add a name' : null;

  String? Function(String?) _number({required double max, bool required = false}) => (v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return required ? 'Enter a number' : null;
    final n = parseNumber(text);
    if (n == null) return 'Enter a number';
    if (n < 0 || n > max) return 'Enter 0–${fmtKcal(max)}';
    return null;
  };

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    double value(TextEditingController c) => parseNumber(c.text) ?? 0;
    widget.onSubmit(
      FoodItem(
        id: widget.initial?.id ?? newId(),
        name: _name.text.trim(),
        servings: _servings,
        servingLabel: _serving.text.trim().isEmpty ? '1 serving' : _serving.text.trim(),
        caloriesPerServing: value(_kcal),
        proteinPerServing: value(_protein),
        carbsPerServing: value(_carbs),
        fatPerServing: value(_fat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Food name'),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: NqSpace.md),
          TextFormField(
            controller: _serving,
            decoration: const InputDecoration(labelText: 'Serving description', hintText: 'e.g. 1 cup, 120 g'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: NqSpace.md),
          Row(
            children: [
              const Expanded(child: Text('Servings eaten', style: NqText.body)),
              StepperControl(value: _servings, onChanged: (v) => setState(() => _servings = v)),
            ],
          ),
          const SizedBox(height: NqSpace.lg),
          Text('Nutrition per serving — your best estimate', style: NqText.subhead),
          const SizedBox(height: NqSpace.sm),
          TextFormField(
            controller: _kcal,
            decoration: const InputDecoration(labelText: 'Calories per serving', suffixText: 'kcal'),
            keyboardType: numberKeyboard,
            textInputAction: TextInputAction.next,
            validator: _number(max: 5000, required: true),
          ),
          const SizedBox(height: NqSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, controller) in [('Protein', _protein), ('Carbs', _carbs), ('Fat', _fat)]) ...[
                if (label != 'Protein') const SizedBox(width: NqSpace.sm),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(labelText: label, suffixText: 'g'),
                    keyboardType: numberKeyboard,
                    textInputAction: TextInputAction.next,
                    validator: _number(max: 1000),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: NqSpace.xl),
          PrimaryButton(label: widget.submitLabel, onPressed: _submit),
          if (widget.secondary != null) ...[const SizedBox(height: NqSpace.sm), widget.secondary!],
        ],
      ),
    );
  }
}

enum FoodSheetAction { update, remove }

class FoodSheetResult {
  const FoodSheetResult(this.action, [this.item]);
  final FoodSheetAction action;
  final FoodItem? item;
}

/// Bottom sheet to edit one food in the meal.
Future<FoodSheetResult?> showFoodItemSheet(
  BuildContext context, {
  required FoodItem item,
  required Future<void> Function(FoodItem) onSaveToMyFoods,
}) {
  return showModalBottomSheet<FoodSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SheetBody(
      title: 'Edit ingredient',
      child: FoodItemForm(
        initial: item,
        submitLabel: 'Done',
        onSubmit: (updated) => Navigator.pop(context, FoodSheetResult(FoodSheetAction.update, updated)),
        secondary: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: _SaveToMyFoodsButton(onSave: () => onSaveToMyFoods(item))),
            QuietButton(
              label: 'Remove',
              icon: Icons.delete_outline_rounded,
              color: NqColors.danger,
              onPressed: () => Navigator.pop(context, const FoodSheetResult(FoodSheetAction.remove)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Saves the food to My foods once, then confirms in place (a snackbar would
/// hide behind the sheet).
class _SaveToMyFoodsButton extends StatefulWidget {
  const _SaveToMyFoodsButton({required this.onSave});

  final Future<void> Function() onSave;

  @override
  State<_SaveToMyFoodsButton> createState() => _SaveToMyFoodsButtonState();
}

class _SaveToMyFoodsButtonState extends State<_SaveToMyFoodsButton> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) => QuietButton(
    label: _saved ? 'Saved to My foods' : 'Save to My foods',
    icon: _saved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
    onPressed: _saved
        ? null
        : () async {
            await widget.onSave();
            if (mounted) setState(() => _saved = true);
          },
  );
}
