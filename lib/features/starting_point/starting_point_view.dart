import 'package:flutter/material.dart';

import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/starting_point.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/labels.dart';
import '../../widgets/surfaces.dart';

/// "Your starting point": the goal, an estimated maintenance reference and
/// an editable goal range — or a clear reason why no numbers are shown.
class StartingPointView extends StatefulWidget {
  const StartingPointView({
    super.key,
    required this.profile,
    required this.onUse,
    required this.onSkip,
    this.onBack,
    this.skipLabel = 'Continue without a calorie goal',
  });

  final UserProfile profile;

  /// Called with the (possibly edited) range and protein reference.
  final void Function(CalorieRange range, int? proteinG) onUse;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final String skipLabel;

  @override
  State<StartingPointView> createState() => _StartingPointViewState();
}

class _StartingPointViewState extends State<StartingPointView> {
  late StartingPointResult _result = StartingPoint.calculate(widget.profile);
  late int? _min = _result.range?.min;
  late int? _max = _result.range?.max;
  late int? _protein = _result.proteinReferenceG;
  bool _showMethod = false;

  @override
  void didUpdateWidget(StartingPointView old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile) {
      _result = StartingPoint.calculate(widget.profile);
      _min = _result.range?.min;
      _max = _result.range?.max;
      _protein = _result.proteinReferenceG;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final goal = widget.profile.goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Your starting point', style: NqText.largeTitle),
        const SizedBox(height: NqSpace.sm),
        Text(
          'A personal reference to begin with — not a prescription. You can change it any time.',
          style: NqText.callout,
        ),
        const SizedBox(height: NqSpace.xl),
        NqCard(
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, color: NqColors.sage),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your goal', style: NqText.footnote),
                    Text(goal?.title ?? 'No goal chosen', style: NqText.headline),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: NqSpace.md),
        ...switch (r.eligibility) {
          TargetEligibility.eligible => _numbers(r),
          TargetEligibility.under18 => _noNumbers(
            'Calorie targets aren’t offered under 18',
            'Growing bodies have different needs, so Nutriq won’t suggest calorie targets or dieting '
                'advice for people under 18. You can still log meals and see your totals. A doctor or '
                'registered dietitian can help with personal questions.',
          ),
          TargetEligibility.healthConsideration => _noNumbers(
            'We won’t suggest calorie targets',
            'Because you noted pregnancy, breastfeeding, or a medical condition, a general formula may '
                'not fit you. A doctor or registered dietitian can suggest a safe target — you can add it '
                'later in Settings → Goals. Meal logging works as usual.',
          ),
          TargetEligibility.needsMoreInfo => _needsMore(r),
        },
      ],
    );
  }

  List<Widget> _numbers(StartingPointResult r) {
    final goalName = (widget.profile.goal ?? FitnessGoal.maintain).title.toLowerCase();
    final min = _min!, max = _max!;
    return [
      NqCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Estimated maintenance', style: NqText.footnote)),
                const EstimateBadge(),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '≈ ${fmtKcal(r.maintenance!)}',
                      style: NqText.heroNumber.copyWith(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('kcal/day', style: NqText.callout),
              ],
            ),
            if (r.sexMidpointUsed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Could be about ±${r.uncertaintyKcal} kcal off because sex wasn’t provided.',
                  style: NqText.footnote,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: NqSpace.md),
      NqCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suggested range to $goalName', style: NqText.footnote),
            const SizedBox(height: 4),
            Text('${fmtKcal(min)} – ${fmtKcal(max)} kcal/day', style: NqText.metric),
            const SizedBox(height: NqSpace.md),
            _editRow('Low end', min, (v) => setState(() => _min = v), lower: 1200, upper: max - 50, step: 50),
            const SizedBox(height: NqSpace.sm),
            _editRow(
              'High end',
              max,
              (v) => setState(() => _max = v),
              lower: min + 50,
              upper: 6000,
              step: 50,
            ),
            if (_protein != null) ...[
              const Divider(height: 28),
              _editRow(
                'Protein reference',
                _protein!,
                (v) => setState(() => _protein = v),
                lower: 30,
                upper: 300,
                step: 5,
                unit: ' g',
              ),
            ],
          ],
        ),
      ),
      if (r.deficitNotSuggested) ...[
        const SizedBox(height: NqSpace.md),
        const NoticeCard(
          icon: Icons.favorite_border_rounded,
          color: NqColors.sage,
          title: 'No lower range suggested',
          message:
              'Your estimated maintenance is already close to a minimum we’d suggest, so this shows a '
              'maintenance range. A doctor or registered dietitian can help you plan safely.',
        ),
      ],
      if (r.lowGoalWeightNote) ...[
        const SizedBox(height: NqSpace.md),
        const NoticeCard(
          icon: Icons.favorite_border_rounded,
          color: NqColors.sage,
          title: 'About your goal weight',
          message:
              'It’s below the range generally considered healthy for your height. Consider talking with '
              'a doctor or registered dietitian before working toward it.',
        ),
      ],
      const SizedBox(height: NqSpace.md),
      NqCard(
        onTap: () => setState(() => _showMethod = !_showMethod),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('How we estimated this', style: NqText.headline)),
                Icon(
                  _showMethod ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: NqColors.textSecondary,
                ),
              ],
            ),
            if (_showMethod) ...[
              const SizedBox(height: NqSpace.sm),
              for (final a in r.assumptions)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('• $a', style: NqText.footnote),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: NqSpace.md),
      const NoticeCard(
        icon: Icons.info_outline_rounded,
        color: NqColors.textSecondary,
        title: 'An estimate, not medical advice',
        message:
            'Bodies vary and no result is guaranteed. Use this as a starting reference and adjust based on '
            'how you feel and your trend over a few weeks.',
      ),
      const SizedBox(height: NqSpace.xl),
      PrimaryButton(
        label: 'Use this range',
        onPressed: () {
          final suggested = r.range!;
          final edited = min != suggested.min || max != suggested.max;
          widget.onUse(CalorieRange(min: min, max: max, custom: edited), _protein);
        },
      ),
      const SizedBox(height: NqSpace.sm),
      Center(
        child: QuietButton(label: widget.skipLabel, color: NqColors.textSecondary, onPressed: widget.onSkip),
      ),
    ];
  }

  List<Widget> _noNumbers(String title, String message) => [
    NoticeCard(icon: Icons.favorite_border_rounded, color: NqColors.sage, title: title, message: message),
    const SizedBox(height: NqSpace.xl),
    PrimaryButton(label: 'Start logging', onPressed: widget.onSkip),
  ];

  List<Widget> _needsMore(StartingPointResult r) {
    final missing = r.missing.map((m) => m.label).toList();
    final list = missing.length == 1
        ? missing.first
        : '${missing.sublist(0, missing.length - 1).join(', ')} and ${missing.last}';
    return [
      NoticeCard(
        icon: Icons.edit_note_rounded,
        color: NqColors.sage,
        title: 'Add a few details for an estimate',
        message:
            'We need your $list to estimate a calorie reference. That’s optional — you can log meals '
            'without one and add details later in Settings.',
      ),
      const SizedBox(height: NqSpace.xl),
      if (widget.onBack != null) ...[
        SecondaryButton(label: 'Add details', icon: Icons.arrow_back_rounded, onPressed: widget.onBack),
        const SizedBox(height: NqSpace.md),
      ],
      PrimaryButton(label: widget.skipLabel, onPressed: widget.onSkip),
    ];
  }

  Widget _editRow(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    required int lower,
    required int upper,
    required int step,
    String unit = '',
  }) => Row(
    children: [
      Expanded(child: Text(label, style: NqText.body)),
      StepperControl(
        value: value.toDouble(),
        step: step.toDouble(),
        min: lower.toDouble(),
        max: upper.toDouble(),
        semanticLabel: label,
        format: (v) => '${fmtKcal(v)}$unit',
        onChanged: (v) => onChanged(v.round()),
      ),
    ],
  );
}
