import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../data/cloud_repository.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/units.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/controls.dart';
import '../../widgets/sheet.dart';
import '../../widgets/surfaces.dart';
import '../coach/ai_consent.dart';
import '../goals/goal_actions.dart';
import '../shell/home_shell.dart';
import 'account_section.dart';
import 'data_screens.dart';
import 'health_section.dart';
import 'personal_details_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.profile, scope.log, scope.sessions]),
      builder: (context, _) {
        final profile = scope.profile.profile;
        final settings = scope.profile.settings;
        final minor = profile?.isMinor ?? false;
        final account = scope.session.isAccount;
        final padding = MediaQuery.paddingOf(context);
        return ListView(
          padding: EdgeInsets.fromLTRB(NqSpace.page, padding.top + 8, NqSpace.page, HomeShell.bottomInset(context)),
          children: [
            const Text('Settings', style: NqText.largeTitle),
            const SizedBox(height: NqSpace.lg),
            const AccountSection(),
            NqGroup(
              header: 'Profile',
              children: [
                NqRow(
                  icon: Icons.badge_outlined,
                  title: 'Personal details',
                  subtitle: _profileSummary(profile, settings.units),
                  onTap: () => _push(context, const PersonalDetailsScreen()),
                ),
              ],
            ),
            NqGroup(
              header: 'Goals',
              footer: 'Goals are estimates you can change any time — not medical advice.',
              children: [
                NqRow(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Calorie goal',
                  value: minor
                      ? 'Not offered'
                      : profile?.calorieGoal == null
                      ? 'Not set'
                      : '${fmtKcal(profile!.calorieGoal!.min)}–${fmtKcal(profile.calorieGoal!.max)}',
                  onTap: () => editCalorieGoal(context),
                ),
                if (!minor)
                  NqRow(
                    icon: Icons.egg_alt_outlined,
                    title: 'Protein reference',
                    value: profile?.proteinTargetG == null ? 'Not set' : '${profile!.proteinTargetG} g',
                    onTap: () => editProteinTarget(context),
                  ),
                if (!(profile?.dietingGuidanceRestricted ?? false))
                  NqRow(
                    icon: Icons.calculate_outlined,
                    title: 'Recalculate starting plan',
                    onTap: () => _push(context, const StartingPlanScreen()),
                  ),
              ],
            ),
            NqGroup(
              header: 'Preferences',
              children: [
                NqRow(
                  icon: Icons.straighten_rounded,
                  title: 'Units',
                  showChevron: false,
                  trailing: SegmentedPill<UnitSystem>(
                    options: const [UnitSystem.metric, UnitSystem.imperial],
                    selected: settings.units,
                    labelOf: (u) => u == UnitSystem.metric ? 'Metric' : 'Imperial',
                    onChanged: (u) => scope.profile.updateSettings(settings.copyWith(units: u)),
                  ),
                ),
                NqRow(
                  icon: Icons.bedtime_outlined,
                  title: 'Day starts at',
                  value: _hourLabel(settings.dayStartHour),
                  onTap: () => _dayStartSheet(context),
                ),
              ],
            ),
            const HealthSection(),
            NqGroup(
              header: 'Logging',
              children: [
                NqRow(
                  icon: Icons.bookmark_border_rounded,
                  title: 'My foods',
                  value: '${scope.log.savedFoods.length}',
                  onTap: () => _push(context, const SavedFoodsScreen()),
                ),
                NqRow(
                  icon: Icons.thumbs_up_down_outlined,
                  title: 'Scan feedback',
                  subtitle: 'Too high, about right, or too low?',
                  onTap: () => _push(context, const ScanFeedbackScreen()),
                ),
              ],
            ),
            if (scope.coach.aiAvailable)
              ListenableBuilder(
                listenable: scope.coach,
                builder: (context, _) => NqGroup(
                  header: 'Coach',
                  footer:
                      'Sends your questions, goals and a summary of recent meals to Claude (Anthropic) through '
                      'Nutriq’s server. Never photos or Apple Health data. Up to 30 messages a day.',
                  children: [
                    NqRow(
                      icon: Icons.auto_awesome_outlined,
                      title: 'AI coach',
                      trailing: Switch.adaptive(
                        value: scope.coach.aiEnabled,
                        onChanged: (on) => setAiCoachFromSettings(context, scope.coach, on),
                      ),
                    ),
                  ],
                ),
              ),
            NqGroup(
              header: 'Privacy & data',
              footer: account
                  ? 'Meal photos and Apple Health data never leave this phone. Meals, goals, saved foods and scan '
                        'ratings sync to your account.'
                  : 'Everything is stored on this phone: no account, no analytics, no uploads.',
              children: [
                NqRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'What Nutriq stores',
                  onTap: () => showInfoDialog(
                    context,
                    title: 'What Nutriq stores',
                    message: account
                        ? 'In your account (Supabase, protected so only you can read it): your profile and goals, '
                              'meals and their foods, saved foods and scan ratings.\n\nOnly on this phone: meal photos, '
                              'Apple Health data, scans that are still drafts, and coach chats (which aren’t saved at '
                              'all). Photo recognition (Apple’s built-in recognizer), describing meals (Nutriq’s food '
                              'list) and the demo coach all run on this phone.\n\nIf you turn on the AI '
                              'coach, each question is sent with your goals and a summary of recent meals to Anthropic '
                              '(Claude) through Nutriq’s server to get an answer. Nutriq keeps only a daily count of '
                              'messages, never what they say.'
                        : 'On this phone only: your optional profile and goals, meals and their photos, saved foods '
                              'and scan ratings. Coach chats aren’t saved. Nothing is sent anywhere — photo recognition, '
                              'describing meals and the demo coach all run on this phone.',
                  ),
                ),
                NqRow(
                  icon: Icons.person_remove_outlined,
                  title: 'Delete profile',
                  subtitle: 'Keeps your meals',
                  destructive: true,
                  onTap: profile == null ? null : () => _deleteProfile(context, account),
                ),
                NqRow(
                  icon: Icons.no_meals_outlined,
                  title: 'Delete all meals',
                  destructive: true,
                  onTap: scope.log.meals.isEmpty ? null : () => _deleteMeals(context, account),
                ),
                if (!account)
                  NqRow(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete all data on this phone',
                    subtitle: 'Start over from the welcome screen',
                    destructive: true,
                    onTap: () => _deleteLocal(context),
                  )
                else ...[
                  NqRow(
                    icon: Icons.phonelink_erase_rounded,
                    title: 'Remove account from this phone',
                    subtitle: 'Signs out and deletes this phone’s copy. Your account keeps its data.',
                    destructive: true,
                    onTap: () => _removeFromPhone(context),
                  ),
                  NqRow(
                    icon: Icons.cloud_off_outlined,
                    title: 'Delete synced data',
                    subtitle: 'From the server and this phone. Keeps your sign-in.',
                    destructive: true,
                    onTap: () => _deleteCloudData(context),
                  ),
                  NqRow(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete account',
                    subtitle: 'Permanently deletes your account and all of its data',
                    destructive: true,
                    onTap: () => _deleteAccount(context),
                  ),
                ],
              ],
            ),
            NqGroup(
              header: 'About',
              footer:
                  '${AppConfig.estimateDisclaimer} ${AppConfig.appName} doesn’t diagnose or treat any '
                  'condition. For medical or dietary advice, talk to a qualified professional.',
              children: [
                NqRow(
                  title: 'Food analysis',
                  value: scope.analysis.isDemo ? 'Demo · sample results' : scope.analysis.label,
                ),
                ListenableBuilder(
                  listenable: scope.coach,
                  builder: (context, _) =>
                      NqRow(title: 'Coach', value: scope.coach.aiEnabled ? 'AI · Claude' : 'Demo · scripted'),
                ),
                NqRow(title: 'Accounts & sync', value: scope.auth.isConfigured ? 'Configured' : 'Not set up'),
                const NqRow(title: 'Version', value: AppConfig.version),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _profileSummary(UserProfile? p, UnitSystem units) {
    if (p == null) return 'Add details for a personal starting point';
    final parts = [
      if (p.goal != null) p.goal!.title,
      if (p.age != null) '${p.age} y',
      if (p.heightCm != null) formatHeight(p.heightCm!, units),
      if (p.weightKg != null) formatWeight(p.weightKg!, units),
    ];
    return parts.isEmpty ? 'Tap to add details' : parts.join(' · ');
  }

  static String _hourLabel(int h) => h == 0 ? 'Midnight' : '$h AM';

  static void _dayStartSheet(BuildContext context) {
    final controller = AppScope.of(context).profile;
    showNqSheet<void>(
      context,
      title: 'Day starts at',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'For late nights and night shifts: meals logged before this time count toward the previous day.',
            style: NqText.callout,
          ),
          const SizedBox(height: NqSpace.lg),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => ChoiceChips<int>(
              options: const [0, 2, 3, 4, 5, 6],
              selected: controller.settings.dayStartHour,
              labelOf: _hourLabel,
              onSelected: (h) => controller.updateSettings(controller.settings.copyWith(dayStartHour: h)),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _deleteProfile(BuildContext context, bool account) async {
    final scope = AppScope.of(context);
    final ok = await confirmAction(
      context,
      title: 'Delete your profile?',
      message:
          'Your age, body measurements, goal and targets will be removed${account ? ' from this phone and your account' : ''}. '
          'Meals stay in your log.',
      confirmLabel: 'Delete profile',
    );
    if (ok) await scope.profile.clearProfile();
  }

  static Future<void> _deleteMeals(BuildContext context, bool account) async {
    final scope = AppScope.of(context);
    final ok = await confirmAction(
      context,
      title: 'Delete all meals?',
      message: account
          ? 'Every logged meal will be deleted from your account on every device, and meal photos removed from '
                'this phone.'
          : 'Every logged meal and its photo will be permanently removed from this phone.',
      confirmLabel: 'Delete meals',
    );
    if (ok) await scope.log.deleteAllMeals();
  }

  static Future<void> _deleteLocal(BuildContext context) async {
    final sessions = AppScope.of(context).sessions;
    final ok = await confirmAction(
      context,
      title: 'Delete all data on this phone?',
      message:
          'Your profile, meals, photos, saved foods, drafts and ratings will be permanently removed from this phone.',
      confirmLabel: 'Delete everything',
    );
    if (!ok) return;
    await sessions.deleteLocalData();
    sessions.announce('All data on this phone was deleted.');
  }

  static Future<void> _removeFromPhone(BuildContext context) async {
    final sessions = AppScope.of(context).sessions;
    final pending = await sessions.pendingChanges();
    if (!context.mounted) return;
    final ok = await confirmAction(
      context,
      title: 'Remove account from this phone?',
      message: pending > 0
          ? '$pending ${pending == 1 ? 'change hasn’t' : 'changes haven’t'} synced yet and will be lost. Everything '
                'already synced stays in your account. Meal photos on this phone will be deleted.'
          : 'You’ll be signed out and this phone’s copy (including meal photos, which are never uploaded) will be '
                'deleted. Your account keeps its synced data.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    await sessions.removeAccountFromPhone();
    sessions.announce('Signed out. This phone’s copy of your account was removed.');
  }

  static Future<void> _deleteCloudData(BuildContext context) async {
    final sessions = AppScope.of(context).sessions;
    final ok = await confirmAction(
      context,
      title: 'Delete synced data?',
      message:
          'Your profile, goals, meals, saved foods and ratings will be permanently deleted from Nutriq’s server and '
          'from this phone, including meal photos. Your account and sign-in stay.',
      confirmLabel: 'Delete data',
    );
    if (!ok || !context.mounted) return;
    try {
      await sessions.deleteCloudData();
      sessions.announce('Your synced data was deleted from the server and this phone.');
    } catch (e) {
      if (context.mounted) await _deleteFailed(context, e);
    }
  }

  static Future<void> _deleteAccount(BuildContext context) async {
    final sessions = AppScope.of(context).sessions;
    final ok = await confirmAction(
      context,
      title: 'Delete your account?',
      message:
          'Your account and everything in it will be permanently deleted, then you’ll be signed out and this '
          'phone’s copy removed. This can’t be undone.',
      confirmLabel: 'Delete account',
    );
    if (!ok || !context.mounted) return;
    try {
      await sessions.deleteAccount();
      sessions.announce('Your account was deleted.');
    } catch (e) {
      if (context.mounted) await _deleteFailed(context, e);
    }
  }

  static Future<void> _deleteFailed(BuildContext context, Object e) => showInfoDialog(
    context,
    title: 'Nothing was deleted',
    message: switch (e) {
      CloudNotConfiguredException() =>
        'Account deletion isn’t set up on the server yet (the delete-account function hasn’t been deployed). '
            'Your data is unchanged.',
      CloudOfflineException() => 'You’re offline. Connect to the internet and try again. Your data is unchanged.',
      CloudAuthException() => 'Please sign in again, then try again. Your data is unchanged.',
      _ => 'Something went wrong ($e). Your data is unchanged.',
    },
  );
}
