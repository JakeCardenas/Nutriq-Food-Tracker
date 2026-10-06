import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/buttons.dart';
import '../profile/profile_fields.dart';
import '../starting_point/starting_point_view.dart';

/// Edit every profile field in one place, then optionally recalculate.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late UserProfile _draft = AppScope.of(context).profile.profile ?? const UserProfile();
  late bool _noHealth = _draft.health.isEmpty && AppScope.of(context).profile.profile != null;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    var profile = _draft;
    // Safeguards: drop calculated targets that no longer apply.
    if (profile.isMinor) {
      profile = profile.copyWith(calorieGoal: null, proteinTargetG: null);
    } else if (profile.hasHealthConsideration && !(profile.calorieGoal?.custom ?? true)) {
      profile = profile.copyWith(calorieGoal: null);
    }
    await AppScope.of(context).profile.saveProfile(profile);
    if (!mounted) return;
    if (profile.dietingGuidanceRestricted) {
      Navigator.pop(context);
      showToast(context, 'Profile saved');
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StartingPointScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(NqSpace.page, 0, NqSpace.page, NqSpace.xxxl),
          children: [
            const FieldLabel('Goal'),
            GoalPicker(
              selected: _draft.goal,
              onChanged: (g) => setState(() => _draft = _draft.copyWith(goal: g)),
            ),
            const FieldLabel('About you'),
            ListenableBuilder(
              listenable: settings,
              builder: (context, _) => AboutYouFields(
                profile: _draft,
                units: settings.settings.units,
                onChanged: (p) => setState(() => _draft = p),
                onUnitsChanged: (u) => settings.updateSettings(settings.settings.copyWith(units: u)),
              ),
            ),
            const FieldLabel('Activity'),
            ActivityPicker(
              selected: _draft.activity,
              workoutDays: _draft.workoutDaysPerWeek,
              onChanged: (a) => setState(() => _draft = _draft.copyWith(activity: a)),
              onWorkoutDays: (d) => setState(() => _draft = _draft.copyWith(workoutDaysPerWeek: d)),
            ),
            const FieldLabel('Health check'),
            const WhyText('If any of these apply, Nutriq won’t calculate calorie targets for you.'),
            const SizedBox(height: NqSpace.sm),
            HealthCheck(
              selected: _draft.health,
              noneChosen: _noHealth,
              onChanged: (s, {required none}) => setState(() {
                _draft = _draft.copyWith(health: s);
                _noHealth = none;
              }),
            ),
            const SizedBox(height: NqSpace.xxl),
            PrimaryButton(label: 'Save profile', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// Recalculate the starting point from the saved profile.
class StartingPointScreen extends StatelessWidget {
  const StartingPointScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).profile;
    final profile = controller.profile ?? const UserProfile();
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NqSpace.page, 0, NqSpace.page, NqSpace.xxxl),
        children: [
          StartingPointView(
            profile: profile,
            skipLabel: profile.calorieGoal == null
                ? 'Continue without a calorie goal'
                : 'Keep my current goal',
            onBack: () =>
                Navigator.of(context)
                    .pushReplacement(MaterialPageRoute(builder: (_) => const ProfileEditScreen())),
            onUse: (range, protein) async {
              await controller.saveProfile(profile.copyWith(calorieGoal: range, proteinTargetG: protein));
              if (context.mounted) {
                Navigator.pop(context);
                showToast(context, 'Goal updated');
              }
            },
            onSkip: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
