import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/references.dart';
import '../../domain/starting_point.dart';
import '../../domain/models/nutrition.dart';
import '../../widgets/buttons.dart';
import '../../widgets/nutriq_mark.dart';
import '../../widgets/rings.dart';
import '../account/auth_screen.dart';
import '../profile/profile_editors.dart';
import '../starting_point/starting_plan_view.dart';

enum _Step { welcome, goal, sex, age, body, goalWeight, activity, workouts, health, building, plan, account }

/// First launch, one question per screen. Everything after Welcome is optional;
/// each screen says why it asks. Ends with "Your starting point" and, when cloud
/// accounts are configured, an optional "Save your progress".
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _index = 0;
  UserProfile _draft = const UserProfile();
  SexAnswer? _sex;
  bool _noHealth = false;
  int _age = 30;
  double _heightCm = 170;
  double _weightKg = 70;
  double? _goalWeightKg;
  int _workouts = 3;
  PlanChoice _plan = const PlanChoice();
  bool _finishing = false;

  late final List<_Step> _steps = [
    for (final s in _Step.values)
      if (s != _Step.account || _offerAccount) s,
  ];

  bool get _offerAccount {
    final scope = AppScope.of(context);
    return scope.auth.isConfigured && !scope.session.isAccount;
  }

  _Step get _step => _steps[_index];
  int get _progressTotal => _steps.length - 1;

  void _go(int index) {
    FocusScope.of(context).unfocus();
    setState(() => _index = index.clamp(0, _steps.length - 1));
    if (_step == _Step.building) _runBuilding();
  }

  void _next() => _go(_index + 1);

  void _back() {
    var target = _index - 1;
    if (target >= 0 && _steps[target] == _Step.building) target--;
    _go(target);
  }

  void _jumpTo(_Step step) => _go(_steps.indexOf(step));

  Future<void> _runBuilding() async {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    await Future<void>.delayed(Duration(milliseconds: reduceMotion ? 300 : 2400));
    if (mounted && _step == _Step.building) _next();
  }

  UserProfile get _finalProfile {
    final eligible = StartingPoint.calculate(_draft).hasNumbers;
    return _draft.copyWith(
      calorieGoal: eligible ? _plan.range : null,
      proteinTargetG: eligible ? _plan.proteinG : null,
    );
  }

  Future<void> _finish({UserProfile? profile, bool skipped = false}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await AppScope.of(context).profile.completeOnboarding(skipped ? null : (profile ?? _finalProfile));
  }

  void _usePlan({required bool withGoal}) {
    if (!withGoal) _plan = PlanChoice(proteinG: _plan.proteinG);
    if (_steps.contains(_Step.account)) {
      _next();
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = AppScope.of(context).profile.settings.units;
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: NqColors.card,
        body: SafeArea(
          child: _step == _Step.welcome
              ? _Welcome(onStart: _next, offerSignIn: _offerAccount, onSkip: () => _finish(skipped: true))
              : Column(
                  children: [
                    if (_step != _Step.building) _TopBar(progress: _index / _progressTotal, onBack: _back),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(key: ValueKey(_step), child: _body(units)),
                      ),
                    ),
                    _bottomBar(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _body(UnitSystem units) => switch (_step) {
    _Step.goal => _Question(
      title: 'What’s your goal?',
      why: 'It shapes your suggested range and the coach’s tips. You can change it any time.',
      child: GoalChoice(
        selected: _draft.goal,
        onChanged: (g) => setState(() => _draft = _draft.copyWith(goal: g)),
      ),
    ),
    _Step.sex => _Question(
      title: 'Sex for your estimate',
      why:
          'The calorie formula (Mifflin–St Jeor) uses a different constant for male and female bodies. Prefer not to '
          'say? We’ll use the midpoint and show the extra uncertainty.',
      centerChild: true,
      child: SexChoice(
        selected: _sex,
        onChanged: (a) => setState(() {
          _sex = a;
          _draft = _draft.copyWith(sex: sexFromAnswer(a));
        }),
      ),
    ),
    _Step.age => _Question(
      title: 'How old are you?',
      why: 'Age is part of the calorie formula and keeps guidance age-appropriate. Nutriq is for ages 13 and up.',
      centerChild: true,
      child: AgeWheel(age: _age, onChanged: (a) => setState(() => _age = a)),
    ),
    _Step.body => _Question(
      title: 'Height & weight',
      why: 'Used only for your estimate and protein reference. They stay on this phone unless you sign in.',
      centerChild: true,
      child: BodyWheels(
        units: units,
        heightCm: _heightCm,
        weightKg: _weightKg,
        onHeight: (h) => setState(() => _heightCm = h),
        onWeight: (w) => setState(() => _weightKg = w),
        onUnits: (u) {
          final p = AppScope.of(context).profile;
          p.updateSettings(p.settings.copyWith(units: u));
        },
      ),
    ),
    _Step.goalWeight => _Question(
      title: 'Goal weight',
      why: 'Optional context for the coach. Nutriq never predicts when you’ll reach it.',
      centerChild: true,
      child: Center(
        child: WeightWheel(
          units: units,
          kg: _goalWeightKg ?? _draft.weightKg ?? _weightKg,
          onChanged: (w) => setState(() => _goalWeightKg = w),
        ),
      ),
    ),
    _Step.activity => _Question(
      title: 'How active is a typical week?',
      why: 'Activity scales the estimate from resting energy to a full day.',
      child: ActivityChoice(
        selected: _draft.activity,
        onChanged: (a) => setState(() => _draft = _draft.copyWith(activity: a)),
      ),
    ),
    _Step.workouts => _Question(
      title: 'Workouts per week',
      why: 'Helps the coach with consistency tips. It doesn’t change your calorie estimate.',
      centerChild: true,
      child: WorkoutsWheel(days: _workouts, onChanged: (d) => setState(() => _workouts = d)),
    ),
    _Step.health => _Question(
      title: 'Before we suggest numbers',
      why:
          'Do any of these apply? General formulas may not fit these situations, so if any do, we’ll skip calorie '
          'targets — logging still works. Optional, and private.',
      child: HealthChoice(
        selected: _draft.health,
        noneChosen: _noHealth,
        onChanged: (s, {required none}) => setState(() {
          _draft = _draft.copyWith(health: s);
          _noHealth = none;
        }),
      ),
    ),
    _Step.building => const _Building(),
    _Step.plan => _Question(
      title: StartingPoint.calculate(_draft).hasNumbers ? 'Your starting point is ready' : 'Your starting point',
      why: 'A personal reference to begin with — not a prescription.',
      child: StartingPlanView(profile: _draft, onChanged: (p) => _plan = p),
    ),
    _Step.account => _Question(
      title: 'Save your progress',
      why: 'Create a free account to back up your meals and goals and use Nutriq on another device. Optional.',
      child: const _AccountBenefits(),
    ),
    _Step.welcome => const SizedBox.shrink(),
  };

  Widget _bottomBar() {
    if (_step == _Step.building) return const SizedBox(height: 24);
    final wheelStep = const {_Step.age, _Step.body, _Step.goalWeight, _Step.workouts}.contains(_step);
    final hasChoice = switch (_step) {
      _Step.goal => _draft.goal != null,
      _Step.sex => _sex != null,
      _Step.activity => _draft.activity != null,
      _Step.health => _noHealth || _draft.health.isNotEmpty,
      _ => true,
    };

    final List<Widget> buttons;
    if (_step == _Step.plan) {
      final result = StartingPoint.calculate(_draft);
      buttons = result.hasNumbers
          ? [
              PrimaryButton(label: 'Use this plan', busy: _finishing, onPressed: () => _usePlan(withGoal: true)),
              QuietButton(
                label: 'Continue without a calorie goal',
                color: NqColors.textSecondary,
                onPressed: () => _usePlan(withGoal: false),
              ),
            ]
          : [
              PrimaryButton(label: 'Continue', busy: _finishing, onPressed: () => _usePlan(withGoal: false)),
              if (result.eligibility == TargetEligibility.needsMoreInfo)
                QuietButton(label: 'Add details', color: NqColors.textSecondary, onPressed: () => _jumpTo(_Step.age)),
            ];
    } else if (_step == _Step.account) {
      buttons = [
        PrimaryButton(
          label: 'Create a free account',
          busy: _finishing,
          onPressed: () async {
            await _finish();
            if (mounted) unawaited(AuthScreen.open(context, signUp: true, fromOnboarding: true));
          },
        ),
        QuietButton(label: 'Not now — keep it on this phone', color: NqColors.textSecondary, onPressed: _finish),
      ];
    } else {
      buttons = [
        PrimaryButton(
          label: hasChoice ? 'Continue' : 'Skip for now',
          onPressed: () {
            _saveWheel();
            _next();
          },
        ),
        if (wheelStep) QuietButton(label: 'Skip', color: NqColors.textSecondary, onPressed: _skipWheel),
      ];
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), NqColors.card],
          stops: [0, 0.3],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NqSpace.page, NqSpace.lg, NqSpace.page, NqSpace.sm),
        child: Column(mainAxisSize: MainAxisSize.min, children: buttons),
      ),
    );
  }

  void _saveWheel() {
    setState(() {
      switch (_step) {
        case _Step.age:
          _draft = _draft.copyWith(age: _age);
        case _Step.body:
          _draft = _draft.copyWith(heightCm: _heightCm, weightKg: _weightKg);
        case _Step.goalWeight:
          _draft = _draft.copyWith(goalWeightKg: _goalWeightKg ?? _draft.weightKg ?? _weightKg);
        case _Step.workouts:
          _draft = _draft.copyWith(workoutDaysPerWeek: _workouts);
        default:
          break;
      }
    });
  }

  void _skipWheel() {
    setState(() {
      switch (_step) {
        case _Step.age:
          _draft = _draft.copyWith(age: null);
        case _Step.body:
          _draft = _draft.copyWith(heightCm: null, weightKg: null);
        case _Step.goalWeight:
          _draft = _draft.copyWith(goalWeightKg: null);
        case _Step.workouts:
          _draft = _draft.copyWith(workoutDaysPerWeek: null);
        default:
          break;
      }
    });
    _next();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.progress, required this.onBack});

  final double progress;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(NqSpace.page, 8, NqSpace.page + 8, 0),
    child: Row(
      children: [
        CircleButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: onBack),
        const SizedBox(width: 20),
        Expanded(
          child: Semantics(
            label: 'Progress ${(progress * 100).round()} percent',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress.clamp(0.02, 1.0)),
                duration: const Duration(milliseconds: 300),
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  color: NqColors.ink,
                  backgroundColor: NqColors.track,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Question extends StatelessWidget {
  const _Question({required this.title, required this.why, required this.child, this.centerChild = false});

  final String title;
  final String why;
  final Widget child;
  final bool centerChild;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(NqSpace.page, NqSpace.xxl, NqSpace.page, NqSpace.lg),
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: NqText.largeTitle),
              const SizedBox(height: NqSpace.sm),
              Text(why, style: NqText.callout.copyWith(fontSize: 16)),
              if (centerChild) ...[
                const Spacer(),
                child,
                const Spacer(flex: 2),
              ] else ...[
                const SizedBox(height: NqSpace.xxl),
                child,
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _Building extends StatefulWidget {
  const _Building();

  @override
  State<_Building> createState() => _BuildingState();
}

class _BuildingState extends State<_Building> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final v = Curves.easeInOut.transform(_c.value);
      final items = ['Calorie reference', 'Protein', 'Carbs & fat', 'Safety checks'];
      return Padding(
        padding: const EdgeInsets.all(NqSpace.page),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                '${(v * 100).round()}%',
                style: NqText.heroNumber.copyWith(fontSize: 56),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: NqSpace.sm),
            const Text('Setting up your starting point', style: NqText.title, textAlign: TextAlign.center),
            const SizedBox(height: NqSpace.xl),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    const ColoredBox(color: NqColors.track, child: SizedBox.expand()),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [NqColors.protein, NqColors.carbs, NqColors.fat]),
                        ),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: NqSpace.xxl),
            Text('Daily reference for', style: NqText.headline),
            const SizedBox(height: NqSpace.sm),
            for (final (i, item) in items.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text('• $item', style: NqText.body),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: v > (i + 1) / (items.length + 1) ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.check_circle_rounded, color: NqColors.ink, size: 22),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart, required this.offerSignIn, required this.onSkip});

  final VoidCallback onStart;
  final bool offerSignIn;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(NqSpace.page, NqSpace.lg, NqSpace.page, NqSpace.lg),
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const NutriqMark(size: 30, color: NqColors.ink),
                  const SizedBox(width: 8),
                  Text(AppConfig.appName, style: NqText.title),
                ],
              ),
              const SizedBox(height: NqSpace.xxl),
              const _PreviewStack(),
              const SizedBox(height: NqSpace.xxl),
              Text('Snap a meal.\nSee the estimate.', style: NqText.largeTitle.copyWith(fontSize: 34)),
              const SizedBox(height: NqSpace.sm),
              Text(
                'Fix any food or portion in a tap. Free — no ads, no paywall — and private by default.',
                style: NqText.callout.copyWith(fontSize: 16),
              ),
              const Spacer(),
              const SizedBox(height: NqSpace.xl),
              PrimaryButton(label: 'Get started', onPressed: onStart),
              if (offerSignIn)
                Center(
                  child: QuietButton(
                    label: 'Already have an account? Sign in',
                    color: NqColors.textSecondary,
                    onPressed: () => AuthScreen.open(context),
                  ),
                ),
              Center(
                child: QuietButton(
                  label: 'Skip setup — just start logging',
                  color: NqColors.textSecondary,
                  onPressed: onSkip,
                ),
              ),
              const SizedBox(height: NqSpace.sm),
              Text(
                'Nutriq is for general wellness. ${AppConfig.estimateDisclaimer}',
                style: NqText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// An example of the dashboard (labelled), built from the real widgets.
class _PreviewStack extends StatelessWidget {
  const _PreviewStack();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: NqColors.canvas, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Example', style: NqText.caption),
          const SizedBox(height: 8),
          const IgnorePointer(child: CalorieSummaryCard(calories: 1250, range: CalorieRange(min: 2000, max: 2200))),
          const SizedBox(height: 10),
          const IgnorePointer(
            child: MacroRingRow(
              totals: NutritionTotals(calories: 1250, protein: 75, carbs: 138, fat: 35),
              references: MacroReferences(protein: 130, carbs: 240, fat: 70),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AccountBenefits extends StatelessWidget {
  const _AccountBenefits();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (icon, title, text) in const [
        (Icons.cloud_done_outlined, 'Back up meals and goals', 'Synced securely to your private account.'),
        (Icons.devices_outlined, 'Use another device', 'Sign in on a new phone and pick up where you left off.'),
        (Icons.photo_outlined, 'Photos stay on this phone', 'Meal photos are never uploaded.'),
        (Icons.money_off_rounded, 'Still free', 'No subscription, no ads, no paywall.'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: NqSpace.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: NqColors.fill, shape: BoxShape.circle),
                child: Icon(icon, color: NqColors.ink, size: 22),
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
        ),
    ],
  );
}
