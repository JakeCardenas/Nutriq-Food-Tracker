import 'package:flutter/material.dart';

import '../app/format.dart';
import '../app/theme.dart';
import '../domain/models/nutrition.dart';

/// Macro balance at a glance: one split bar (share of calories) and three
/// values. Protein shows progress toward its reference when one is set.
class MacroSummary extends StatelessWidget {
  const MacroSummary({super.key, required this.totals, this.proteinTarget});

  final NutritionTotals totals;
  final int? proteinTarget;

  @override
  Widget build(BuildContext context) {
    final split = totals.calorieSplit;
    String share(double? v) => v == null ? '—' : '${(v * 100).round()}% of kcal';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: split == null
                ? const ColoredBox(color: NqColors.raised, child: SizedBox.expand())
                : Row(
                    children: [
                      _segment(split.protein, NqColors.protein),
                      const SizedBox(width: 2),
                      _segment(split.carbs, NqColors.carbs),
                      const SizedBox(width: 2),
                      _segment(split.fat, NqColors.fat),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: NqSpace.lg),
        Row(
          children: [
            Expanded(
              child: _MacroValue(
                label: 'Protein',
                color: NqColors.protein,
                value: fmtGrams(totals.protein),
                detail: proteinTarget == null ? share(split?.protein) : 'of $proteinTarget g ref.',
              ),
            ),
            Expanded(
              child: _MacroValue(
                label: 'Carbs',
                color: NqColors.carbs,
                value: fmtGrams(totals.carbs),
                detail: share(split?.carbs),
              ),
            ),
            Expanded(
              child: _MacroValue(
                label: 'Fat',
                color: NqColors.fat,
                value: fmtGrams(totals.fat),
                detail: share(split?.fat),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _segment(double share, Color color) => Expanded(
    flex: (share * 1000).round().clamp(1, 1000),
    child: ColoredBox(color: color, child: const SizedBox.expand()),
  );
}

class _MacroValue extends StatelessWidget {
  const _MacroValue({required this.label, required this.color, required this.value, required this.detail});

  final String label;
  final Color color;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value, $detail, estimated',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: NqText.footnote),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: NqText.metric),
        const SizedBox(height: 2),
        Text(detail, style: NqText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}
