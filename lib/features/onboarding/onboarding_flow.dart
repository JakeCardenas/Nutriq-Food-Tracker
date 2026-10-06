import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/user_profile.dart';
import '../../widgets/buttons.dart';
import '../../widgets/nutriq_mark.dart';
import '../profile/profile_fields.dart';
import '../starting_point/starting_point_view.dart';

/// First launch: welcome → goal → about you → activity → health check →
/// your starting point. Everything after Welcome is optional.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _steps = 5; // excluding Welcome
  final _aboutFormKey = GlobalKey<FormState>();
  int _step = 0; // 0 = Welcome
  UserProfile _draft = const UserProfile();
  bool _noHealthConsiderations = false;
  bool _finishing = false;

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step.clamp(0, _steps));
  }

  void _next() {
    if (_step == 2 && !(_aboutFormKey.currentState?.validate() ?? true)) return;
    _go(_step + 1);
  }

  Future<void> _finish(UserProfile? profile) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await AppScope.of(context).profile.completeOnboarding(profile);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).profile;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _go(_step - 1);
        },
        child: Scaffold(
          body: SafeArea(
            child: _step == 0
                ? _Welcome(onSetUp: () => _go(1), onSkip: () => _finish(null))
                : Column(
                    children: [
                      _TopBar(
                        step: _step,
                        total: _steps,
                        onBack: () => _go(_step - 1),
                        onSkip: _step < _steps ? () => _go(_step + 1) : null,
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: ListView(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(
                                NqSpace.page,
                                NqSpace.lg,
                                NqSpace.page,
                                NqSpace.xxl,
                              ),
                              children: [_stepBody(settings.settings.units)],
                            ),
                          ),
                        ),
                      ),
                      if (_step < _steps)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            NqSpace.page,
                            NqSpace.sm,
                            NqSpace.page,
                            NqSpace.md,
                          ),
                          child: PrimaryButton(label: 'Continue', onPressed: _next),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(UnitSystem units) {
    final scope = AppScope.of(context);
    return switch (_step) {
      1 => _StepFrame(
        title: 'What are you working toward?',
        why: 'Your goal shapes the suggested range and the coach’s tips. You can change it later.',
        child: GoalPicker(
          selected: _draft.goal,
          onChanged: (g) => setState(() => _draft = _draft.copyWith(goal: g)),
        ),
      ),
      2 => _StepFrame(
        title: 'About you',
        why: 'Optional. These let us estimate a personal calorie reference. Skip anything you’d rather not share.',
        child: Form(
          key: _aboutFormKey,
          child: AboutYouFields(
            profile: _draft,
            units: units,
            onChanged: (p) => setState(() => _draft = p),
            onUnitsChanged: (u) => scope.profile.updateSettings(scope.profile.settings.copyWith(units: u)),
          ),
        ),
      ),
      3 => _StepFrame(
        title: 'How active is a typical week?',
        why: 'Optional. Used to scale the estimate from resting energy to a full day.',
        child: ActivityPicker(
          selected: _draft.activity,
          workoutDays: _draft.workoutDaysPerWeek,
          onChanged: (a) => setState(() => _draft = _draft.copyWith(activity: a)),
          onWorkoutDays: (d) => setState(() => _draft = _draft.copyWith(workoutDaysPerWeek: d)),
        ),
      ),
      4 => _StepFrame(
        title: 'Before we suggest numbers',
        why:
            'Do any of these apply? General calorie formulas may not fit these situations, so if any do, '
            'we’ll skip targets — you can still log everything. Optional, and stored only on this phone.',
        child: HealthCheck(
          selected: _draft.health,
          noneChosen: _noHealthConsiderations,
          onChanged: (s, {required none}) => setState(() {
            _draft = _draft.copyWith(health: s);
            _noHealthConsiderations = none;
          }),
        ),
      ),
      _ => StartingPointView(
        profile: _draft,
        onBack: () => _go(2),
        onUse: (range, protein) => _finish(_draft.copyWith(calorieGoal: range, proteinTargetG: protein)),
        onSkip: () => _finish(_draft),
      ),
    };
  }
}

class _StepFrame extends StatelessWidget {
  const _StepFrame({required this.title, required this.why, required this.child});

  final String title;
  final String why;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: NqText.largeTitle),
      const SizedBox(height: NqSpace.sm),
      Text(why, style: NqText.callout),
      const SizedBox(height: NqSpace.xl),
      child,
    ],
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, required this.total, required this.onBack, required this.onSkip});

  final int step;
  final int total;
  final VoidCallback onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: onBack,
        ),
        Expanded(
          child: Semantics(
            label: 'Step $step of $total',
            child: Row(
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= step ? NqColors.sage : NqColors.raised,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(
          width: 64,
          child: onSkip == null
              ? null
              : QuietButton(label: 'Skip', color: NqColors.textSecondary, onPressed: onSkip),
        ),
      ],
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSetUp, required this.onSkip});

  final VoidCallback onSetUp;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(NqSpace.page, 56, NqSpace.page, NqSpace.xxl),
    children: [
      const Align(alignment: Alignment.centerLeft, child: NutriqMark(size: 72)),
      const SizedBox(height: NqSpace.xxl),
      Text(AppConfig.appName, style: NqText.largeTitle.copyWith(fontSize: 44, letterSpacing: -1.4)),
      const SizedBox(height: NqSpace.sm),
      Text(AppConfig.tagline, style: NqText.body.copyWith(color: NqColors.textSecondary)),
      const SizedBox(height: 40),
      const _Point(
        icon: Icons.photo_camera_outlined,
        title: 'Photo or manual logging',
        text: 'Snap a meal, then fix any food or portion in a tap.',
      ),
      const _Point(
        icon: Icons.tune_rounded,
        title: 'Honest estimates',
        text: 'Every number is labeled as an estimate — and it’s always editable.',
      ),
      const _Point(
        icon: Icons.lock_outline_rounded,
        title: 'No account, no ads, free',
        text: 'Your data stays on this phone. Delete it any time.',
      ),
      const SizedBox(height: 40),
      PrimaryButton(label: 'Set up my starting point', onPressed: onSetUp),
      const SizedBox(height: NqSpace.sm),
      Center(
        child: QuietButton(
          label: 'Skip — just start logging',
          color: NqColors.textSecondary,
          onPressed: onSkip,
        ),
      ),
      const SizedBox(height: NqSpace.lg),
      Text(
        'Nutriq is for general wellness. ${AppConfig.estimateDisclaimer}',
        style: NqText.caption,
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: NqSpace.xl),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: NqColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: NqColors.sage, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NqText.headline),
              const SizedBox(height: 2),
              Text(text, style: NqText.callout),
            ],
          ),
        ),
      ],
    ),
  );
}
