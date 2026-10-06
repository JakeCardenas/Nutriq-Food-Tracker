import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/ids.dart';
import '../../domain/models/food_item.dart';
import '../../widgets/pressable.dart';
import '../../widgets/sheet.dart';
import 'food_item_form.dart';

/// Add a food: pick from My foods / recent foods, or enter it manually.
Future<FoodItem?> showAddFoodSheet(BuildContext context, {bool startManual = false}) {
  return showModalBottomSheet<FoodItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AddFoodSheet(startManual: startManual),
  );
}

class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet({required this.startManual});

  final bool startManual;

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  late bool _manual = widget.startManual;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final log = AppScope.of(context).log;
    if (_manual) {
      return SheetBody(
        title: 'Add an ingredient',
        child: FoodItemForm(submitLabel: 'Add to meal', onSubmit: (item) => Navigator.pop(context, item)),
      );
    }

    final q = _query.trim().toLowerCase();
    bool matches(FoodItem f) => q.isEmpty || f.name.toLowerCase().contains(q);
    final saved = log.savedFoods.map((s) => s.item).where(matches).toList();
    final savedNames = saved.map((f) => f.name.toLowerCase()).toSet();
    final recent = log.recentFoods().where((f) => matches(f) && !savedNames.contains(f.name.toLowerCase())).toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(NqSpace.page, 0, NqSpace.page, NqSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Add an ingredient', style: NqText.title),
                  const SizedBox(height: NqSpace.md),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search My foods and recent',
                      prefixIcon: Icon(Icons.search_rounded, color: NqColors.textTertiary),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(NqSpace.page, 0, NqSpace.page, NqSpace.xxl),
                children: [
                  _ManualRow(onTap: () => setState(() => _manual = true), query: _query),
                  if (saved.isNotEmpty) ...[
                    _header('My foods'),
                    for (final f in saved) _FoodPick(item: f, onTap: () => _pick(f)),
                  ],
                  if (recent.isNotEmpty) ...[
                    _header('Recent'),
                    for (final f in recent) _FoodPick(item: f, onTap: () => _pick(f)),
                  ],
                  if (saved.isEmpty && recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: NqSpace.xxl),
                      child: Text(
                        q.isEmpty
                            ? 'Foods you save or log will show up here for quick re-use.'
                            : 'No matches. Enter it manually — it only takes a moment.',
                        style: NqText.callout,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pick(FoodItem f) => Navigator.pop(context, f.copyWith(id: newId()));

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, NqSpace.xl, 4, NqSpace.sm),
    child: Text(text, style: NqText.subhead.copyWith(color: NqColors.textSecondary)),
  );
}

class _ManualRow extends StatelessWidget {
  const _ManualRow({required this.onTap, required this.query});

  final VoidCallback onTap;
  final String query;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: NqColors.fill, borderRadius: BorderRadius.circular(NqRadius.tile)),
      child: const Row(
        children: [
          Icon(Icons.edit_note_rounded, color: NqColors.ink),
          SizedBox(width: 12),
          Expanded(child: Text('Enter manually', style: NqText.headline)),
          Icon(Icons.chevron_right_rounded, color: NqColors.textTertiary),
        ],
      ),
    ),
  );
}

class _FoodPick extends StatelessWidget {
  const _FoodPick({required this.item, required this.onTap});

  final FoodItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: NqText.body),
                Text('${fmtAmount(item.servings)} × ${item.servingLabel}', style: NqText.footnote),
              ],
            ),
          ),
          Text('${fmtKcal(item.totals.calories)} kcal', style: NqText.numberSmall),
          const SizedBox(width: 8),
          const Icon(Icons.add_circle_rounded, color: NqColors.ink, size: 24),
        ],
      ),
    ),
  );
}
