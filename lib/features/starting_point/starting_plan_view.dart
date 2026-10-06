import 'package:flutter/material.dart';

import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/references.dart';
import '../../domain/starting_point.dart';
import '../../widgets/labels.dart';
import '../../widgets/pressable.dart';
import '../../widgets/rings.dart';
import '../../widgets/surfaces.dart';
import '../goals/goal_editors.dart';

/// The edited plan the person accepts (or null values when skipped).
class PlanChoice {
  const PlanChoice({this.range, this.proteinG});
  final CalorieRange? range;
  final int? proteinG;
}

/// "Your starting point": estimated maintenance, an editable goal range and
/// macro references as rings — or a clear reason why no numbers are shown.
/// Buttons live with the caller (onboarding bottom bar or a screen).
class StartingPlanView extends StatefulWidget {
  const StartingPlanView({super.key, required this.profile, required this.onChanged});

  final UserProfile profile;

  /// Called with the current (possibly edited) plan; null range when not eligible.
  final ValueChanged<PlanChoice> onChanged;

  @override
  State<StartingPlanView> createState() => StartingPlanViewState();
}

class StartingPlanViewState extends State<StartingPlanView> {
  late StartingPointResult _result;
  CalorieRange? _range;
  int? _protein;
  bool _showMethod = false;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void didUpdateWidget(StartingPlanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) _recalculate();
  }

  void _recalculate() {
    _result = StartingPoint.calculate(widget.profile);
    _range = _result.range;
    _protein = _result.proteinReferenceG;
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _emit() {
    if (mounted) widget.onChanged(PlanChoice(range: _range, proteinG: _protein));
  }

  StartingPointResult get result => _result;

  Future<void> _editRange() async {
    final edit = await showCalorieRangeEditor(context, profile: widget.profile, initial: _range!);
    if (edit?.range == null) return;
    setState(() => _range = edit!.range);
    _emit();
  }

  Future<void> _editProtein() async {
    final grams = await showProteinEditor(context, initial: _protein ?? 100);
    if (grams == null || grams == 0) return;
    setState(() => _protein = grams);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (r.eligibility) {
        TargetEligibility.eligible => _plan(r),
        TargetEligibility.under18 => [
          const NoticeCard(
            icon: Icons.favorite_border_rounded,
            tone: NoticeTone.success,
            title: 'Calorie targets aren’t offered under 18',
            message:
                'Growing bodies have different needs, so Nutriq won’t suggest calorie targets or dieting advice for '
                'people under 18. You can still log meals and see your totals. A doctor or registered dietitian can '
                'help with personal questions.',
          ),
        ],
        TargetEligibility.healthConsideration => [
          const NoticeCard(
            icon: Icons.favorite_border_rounded,
            tone: NoticeTone.success,
            title: 'We won’t suggest calorie targets',
            message:
                'Because you noted pregnancy, breastfeeding, or a medical condition, a general formula may not fit '
                'you. A doctor or registered dietitian can suggest a safe target — you can add it later in Settings → '
                'Goals. Meal logging works as usual.',
          ),
        ],
        TargetEligibility.needsMoreInfo => [
          NoticeCard(
            icon: Icons.edit_note_rounded,
            title: 'Add a few details for an estimate',
            message:
                'We need your ${_list(r.missing.map((m) => m.label).toList())} to estimate a calorie reference. '
                'That’s optional — you can log meals without one and add details later in Settings.',
          ),
        ],
      },
    );
  }

  List<Widget> _plan(StartingPointResult r) {
    final range = _range!;
    final refs = MacroReferences.forProfile(widget.profile.copyWith(calorieGoal: range, proteinTargetG: _protein));
    return [
      NqCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Daily reference', style: NqText.headline)),
                const EstimateBadge(),
              ],
            ),
            const SizedBox(height: 2),
            Text('Tap a value to adjust it.', style: NqText.footnote),
            const SizedBox(height: NqSpace.lg),
            Row(
              children: [
                Expanded(
                  child: _PlanTile(
                    macro: Macro.calories,
                    value: '${fmtKcal(range.min)}–${fmtKcal(range.max)}',
                    unit: 'kcal',
                    onTap: _editRange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlanTile(macro: Macro.protein, value: '${_protein ?? '—'}', unit: 'g', onTap: _editProtein),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PlanTile(macro: Macro.carbs, value: '${refs.carbs ?? '—'}', unit: 'g'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlanTile(macro: Macro.fat, value: '${refs.fat ?? '—'}', unit: 'g'),
                ),
              ],
            ),
            const SizedBox(height: NqSpace.lg),
            Row(
              children: [
                Expanded(
                  child: Text('Estimated maintenance ≈ ${fmtKcal(r.maintenance!)} kcal/day', style: NqText.subhead),
                ),
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
      if (r.deficitNotSuggested) ...[
        const SizedBox(height: NqSpace.md),
        const NoticeCard(
          icon: Icons.favorite_border_rounded,
          tone: NoticeTone.success,
          title: 'No lower range suggested',
          message:
              'Your estimated maintenance is already close to a minimum we’d suggest, so this shows a maintenance '
              'range. A doctor or registered dietitian can help you plan safely.',
        ),
      ],
      if (r.lowGoalWeightNote) ...[
        const SizedBox(height: NqSpace.md),
        const NoticeCard(
          icon: Icons.favorite_border_rounded,
          tone: NoticeTone.success,
          title: 'About your goal weight',
          message:
              'It’s below the range generally considered healthy for your height. Consider talking with a doctor '
              'or registered dietitian before working toward it.',
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
              for (final a in [
                ...r.assumptions,
                'Carbs and fat references split the calories left after protein about 55 % / 45 % — a common, '
                    'flexible starting point.',
              ])
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
        title: 'An estimate, not medical advice',
        message:
            'Bodies vary and no result is guaranteed. Use this as a starting reference and adjust based on how you '
            'feel and your trend over a few weeks.',
      ),
    ];
  }

  static String _list(List<String> items) =>
      items.length == 1 ? items.first : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.macro, required this.value, required this.unit, this.onTap});

  final Macro macro;
  final String value;
  final String unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(color: NqColors.fill, borderRadius: BorderRadius.circular(NqRadius.tile)),
      child: Column(
        children: [
          Row(
            children: [
              Icon(macro.icon, size: 16, color: macro.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(macro.label, style: NqText.footnote.copyWith(color: NqColors.ink)),
              ),
              if (onTap != null) const Icon(Icons.edit_outlined, size: 16, color: NqColors.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedRing(
            progress: 0.78,
            color: macro.color,
            size: 76,
            stroke: 7,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: NqText.numberSmall.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(unit, style: NqText.caption),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '${macro.label}: $value $unit${onTap == null ? ', derived' : ', tap to adjust'}',
      excludeSemantics: true,
      child: onTap == null ? tile : Pressable(onTap: onTap, child: tile),
    );
  }
}
