import 'package:flutter/material.dart';

import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/starting_point.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/labels.dart';
import '../../widgets/sheet.dart';

/// Edits a calorie range within the same bounds the calculator uses:
/// low end ≥ max(1,200, resting energy), high end ≤ 6,000, ≥ 100 apart.
/// Returns the edited range, [CalorieRangeEdit.removed] or null (cancelled).
Future<CalorieRangeEdit?> showCalorieRangeEditor(
  BuildContext context, {
  required UserProfile profile,
  required CalorieRange initial,
  bool allowRemove = false,
  String? note,
}) {
  return showNqSheet<CalorieRangeEdit>(
    context,
    title: 'Calorie goal',
    child: _CalorieRangeEditor(profile: profile, initial: initial, allowRemove: allowRemove, note: note),
  );
}

class CalorieRangeEdit {
  const CalorieRangeEdit(this.range);
  static const removed = CalorieRangeEdit(null);
  final CalorieRange? range;
}

class _CalorieRangeEditor extends StatefulWidget {
  const _CalorieRangeEditor({required this.profile, required this.initial, required this.allowRemove, this.note});

  final UserProfile profile;
  final CalorieRange initial;
  final bool allowRemove;
  final String? note;

  @override
  State<_CalorieRangeEditor> createState() => _CalorieRangeEditorState();
}

class _CalorieRangeEditorState extends State<_CalorieRangeEditor> {
  late final int _floor = CalorieBounds.floorFor(widget.profile);
  late int _min = widget.initial.min.clamp(_floor, CalorieBounds.maximum - 100);
  late int _max = widget.initial.max.clamp(_min + 100, CalorieBounds.maximum);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.note ?? 'A range, not a single number — real intake varies day to day. All values are estimates.',
        style: NqText.callout,
      ),
      const SizedBox(height: NqSpace.xl),
      Center(child: Text('${fmtKcal(_min)} – ${fmtKcal(_max)} kcal/day', style: NqText.title)),
      const SizedBox(height: NqSpace.xl),
      _row('Low end', _min, _floor, _max - 100, (v) => setState(() => _min = v)),
      const SizedBox(height: NqSpace.md),
      _row('High end', _max, _min + 100, CalorieBounds.maximum, (v) => setState(() => _max = v)),
      const SizedBox(height: NqSpace.md),
      Text(
        'Nutriq won’t go below ${fmtKcal(_floor)} kcal — the higher of 1,200 and your estimated resting energy.',
        style: NqText.footnote,
      ),
      const SizedBox(height: NqSpace.xl),
      PrimaryButton(
        label: 'Save range',
        onPressed: () => Navigator.pop(context, CalorieRangeEdit(CalorieRange(min: _min, max: _max, custom: true))),
      ),
      if (widget.allowRemove)
        Center(
          child: QuietButton(
            label: 'Remove calorie goal',
            color: NqColors.danger,
            onPressed: () => Navigator.pop(context, CalorieRangeEdit.removed),
          ),
        ),
    ],
  );

  Widget _row(String label, int value, int lower, int upper, ValueChanged<int> onChanged) => Row(
    children: [
      Expanded(child: Text(label, style: NqText.body)),
      StepperControl(
        value: value.toDouble(),
        step: 50,
        min: lower.toDouble(),
        max: upper.toDouble(),
        semanticLabel: '$label, kilocalories',
        format: fmtKcal,
        onChanged: (v) => onChanged(v.round()),
      ),
    ],
  );
}

/// Edits the protein reference (30–300 g). Returns grams, 0 to remove, or null.
Future<int?> showProteinEditor(BuildContext context, {required int initial, bool allowRemove = false}) {
  var grams = initial.clamp(30, 300);
  return showNqSheet<int>(
    context,
    title: 'Protein reference',
    child: StatefulBuilder(
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A daily reference shown on your protein ring. Many sports-nutrition guidelines use about 1.2–1.6 g per kg '
            'of body weight. It’s a reference, not a requirement.',
            style: NqText.callout,
          ),
          const SizedBox(height: NqSpace.xl),
          Row(
            children: [
              const Icon(Icons.egg_alt_rounded, color: NqColors.protein),
              const SizedBox(width: 10),
              const Expanded(child: Text('Grams per day', style: NqText.body)),
              StepperControl(
                value: grams.toDouble(),
                step: 5,
                min: 30,
                max: 300,
                semanticLabel: 'Protein grams per day',
                format: (v) => '${v.round()} g',
                onChanged: (v) => setState(() => grams = v.round()),
              ),
            ],
          ),
          const SizedBox(height: NqSpace.xl),
          PrimaryButton(label: 'Save', onPressed: () => Navigator.pop(context, grams)),
          if (allowRemove)
            Center(
              child: QuietButton(
                label: 'Remove protein reference',
                color: NqColors.danger,
                onPressed: () => Navigator.pop(context, 0),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Shown instead of a calorie editor for people under 18.
class NoTargetsForMinorsNotice extends StatelessWidget {
  const NoTargetsForMinorsNotice({super.key});

  @override
  Widget build(BuildContext context) => const NoticeCard(
    icon: Icons.favorite_border_rounded,
    tone: NoticeTone.success,
    title: 'Not offered under 18',
    message:
        'Nutriq doesn’t set calorie targets for people under 18. You can still log meals and see your totals. '
        'A doctor or registered dietitian can help with personal questions.',
  );
}
