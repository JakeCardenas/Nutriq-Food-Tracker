import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/app_config.dart';
import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/references.dart';
import '../../domain/streak.dart';
import '../../state/health_controller.dart';
import '../../state/sync_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/labels.dart';
import '../../widgets/meal_cards.dart';
import '../../widgets/nutriq_mark.dart';
import '../../widgets/pressable.dart';
import '../../widgets/rings.dart';
import '../../widgets/surfaces.dart';
import '../../widgets/week_strip.dart';
import '../goals/goal_actions.dart';
import '../scan/meal_flows.dart';
import '../shell/home_shell.dart';

/// The daily dashboard: week strip, calories against the goal range, macro
/// rings, Apple Health activity (when connected), scan drafts and meals.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final sync = scope.sync;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.profile, scope.log, scope.scans, scope.health, scope.sessions, ?sync]),
      builder: (context, _) {
        final log = scope.log;
        final profile = scope.profile.profile;
        final minor = profile?.isMinor ?? false;
        final today = log.today();
        final selected = _selected == null || _selected!.isAfter(today) ? today : _selected!;
        final isToday = selected == today;
        final meals = log.mealsForDay(selected).reversed.toList();
        final totals = log.totalsForDay(selected);
        final range = minor ? null : profile?.calorieGoal;
        final weekStart = DateTime(today.year, today.month, today.day - today.weekday % 7);
        final week = log.summariesEnding(DateTime(weekStart.year, weekStart.month, weekStart.day + 6));
        final streak = loggingStreak(log.meals.map(log.dayOf).toSet(), today);
        final drafts = isToday ? scope.scans.drafts : const [];
        final health = scope.health;
        final insight = scope.coach.service.insight(scope.coach.currentContext());
        final padding = MediaQuery.paddingOf(context);

        return ListView(
          padding: EdgeInsets.fromLTRB(NqSpace.page, padding.top + 8, NqSpace.page, HomeShell.bottomInset(context)),
          children: [
            _Header(streak: streak, sync: sync),
            if (scope.sessions.linkNotice != null) ...[
              const SizedBox(height: NqSpace.md),
              NoticeCard(
                icon: Icons.link_rounded,
                title: 'New sign-in method on your account',
                message: scope.sessions.linkNotice!,
                onDismiss: scope.sessions.dismissLinkNotice,
              ),
            ],
            if (sync != null && sync.state == SyncState.error && sync.message != null) ...[
              const SizedBox(height: NqSpace.md),
              NoticeCard(
                tone: NoticeTone.caution,
                icon: Icons.cloud_off_rounded,
                title: 'Sync needs attention',
                message: sync.message!,
                action: QuietButton(label: 'Try again', onPressed: sync.syncNow),
              ),
            ],
            const SizedBox(height: NqSpace.md),
            WeekStrip(
              days: week,
              selected: selected,
              today: today,
              range: range,
              onSelect: (d) => setState(() => _selected = d),
            ),
            const SizedBox(height: NqSpace.md),
            if (!isToday)
              Row(
                children: [
                  Expanded(child: Text(dayLabel(selected, today), style: NqText.headline)),
                  QuietButton(label: 'Back to today', onPressed: () => setState(() => _selected = null)),
                ],
              ),
            CalorieSummaryCard(
              calories: totals.calories,
              range: range,
              onTap: minor ? null : () => editCalorieGoal(context),
            ),
            if (range == null && !minor)
              Align(
                alignment: Alignment.centerLeft,
                child: QuietButton(
                  label: 'Set a calorie goal',
                  icon: Icons.add_rounded,
                  onPressed: () => editCalorieGoal(context),
                ),
              ),
            const SizedBox(height: 10),
            _NutritionPager(
              macros: MacroRingRow(totals: totals, references: MacroReferences.forProfile(profile)),
              health: health,
              isToday: isToday,
            ),
            if (drafts.isNotEmpty) ...[
              const SectionHeader('Scanning'),
              for (final d in drafts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DraftCard(
                    key: ValueKey('draft-${d.id}'),
                    draft: d,
                    onReview: () => MealFlows.reviewDraft(context, d),
                    onRetry: () => scope.scans.retry(d.id),
                    onManual: () => MealFlows.manualFromDraft(context, d),
                    onDiscard: () => MealFlows.discardDraft(context, d),
                  ),
                ),
            ],
            const SizedBox(height: NqSpace.md),
            _CoachCard(
              text: insight.text,
              isDemo: scope.coach.service.isDemo,
              onTap: () => HomeShellScope.maybeOf(context)?.openCoach(insight.suggestedPrompt),
            ),
            SectionHeader(isToday ? 'Recently logged' : 'Meals'),
            if (meals.isEmpty)
              _EmptyMeals(
                isToday: isToday,
                onAdd: () => isToday
                    ? showAddMenu(context)
                    : MealFlows.openManual(context, at: DateTime(selected.year, selected.month, selected.day, 12)),
              )
            else
              for (final m in meals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MealCard(meal: m, onTap: () => MealFlows.openMeal(context, m)),
                ),
            const SizedBox(height: NqSpace.lg),
            Text(AppConfig.estimateDisclaimer, style: NqText.caption, textAlign: TextAlign.center),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.streak, required this.sync});

  final int streak;
  final SyncController? sync;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const NutriqMark(size: 30, color: NqColors.ink),
      const SizedBox(width: 8),
      Text('Nutriq', style: NqText.title.copyWith(fontSize: 26, letterSpacing: -0.8)),
      const Spacer(),
      if (sync != null) ...[_SyncChip(sync: sync!), const SizedBox(width: 8)],
      Semantics(
        label: streak == 1 ? '1 day logging streak' : '$streak day logging streak',
        excludeSemantics: true,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: NqColors.card,
            borderRadius: BorderRadius.circular(999),
            boxShadow: NqShadow.card,
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: streak > 0 ? NqColors.flame : NqColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text('$streak', style: NqText.numberSmall),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.sync});
  final SyncController sync;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (sync.state) {
      SyncState.syncing => (Icons.sync_rounded, 'Syncing'),
      SyncState.offline => (Icons.cloud_off_rounded, 'Offline'),
      SyncState.error => (Icons.error_outline_rounded, 'Sync issue'),
      SyncState.synced || SyncState.idle =>
        sync.pending > 0 ? (Icons.cloud_upload_outlined, 'Pending') : (Icons.cloud_done_outlined, 'Synced'),
    };
    final color = sync.state == SyncState.error ? NqColors.danger : NqColors.textSecondary;
    return Pressable(
      onTap: () => HomeShellScope.maybeOf(context)?.selectTab(HomeShell.tabSettings),
      semanticLabel: 'Sync status: $label. Opens Settings.',
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: NqColors.card,
          borderRadius: BorderRadius.circular(999),
          boxShadow: NqShadow.card,
        ),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: NqText.caption.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Macro rings, and — where Apple Health exists — a second page with today's
/// activity. Swipes with native page physics; dots show where you are.
class _NutritionPager extends StatefulWidget {
  const _NutritionPager({required this.macros, required this.health, required this.isToday});

  final Widget macros;
  final HealthController health;
  final bool isToday;

  @override
  State<_NutritionPager> createState() => _NutritionPagerState();
}

class _NutritionPagerState extends State<_NutritionPager> {
  final _pages = PageController();
  int _page = 0;

  /// Natural height of each page; the pager uses the taller one so neither
  /// page stretches or clips.
  final _heights = <int, double>{};

  Widget _measured(int index, Widget page) => OverflowBox(
    alignment: Alignment.center,
    minHeight: 0,
    maxHeight: double.infinity,
    child: _MeasureHeight(
      onHeight: (h) {
        if (mounted && _heights[index] != h) setState(() => _heights[index] = h);
      },
      child: page,
    ),
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.health.status == HealthStatus.unsupported) return widget.macros;
    // The pager takes the macro cards' natural height (measured), so nothing
    // stretches; the estimate only covers the very first frame.
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final measured = [?_heights[0], ?_heights[1]];
    final height = measured.isEmpty ? 150 + 40 * (textScale - 1) : measured.reduce(math.max);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView(
            key: const ValueKey('nutrition-pager'),
            controller: _pages,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              _measured(0, widget.macros),
              _measured(1, _ActivityPage(health: widget.health, isToday: widget.isToday)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _PageDots(
          key: const ValueKey('page-dots'),
          count: 2,
          index: _page,
          onTap: (i) => _pages.animateToPage(
            i,
            duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          ),
        ),
        if (_page == 1 && widget.health.isConnected && widget.health.message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Text(widget.health.message!, style: NqText.caption, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

/// Reports its child's laid-out height after each layout that changes it.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasureHeight renderObject) => renderObject.onHeight = onHeight;
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height != _last) {
      _last = height;
      WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
    }
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({super.key, required this.count, required this.index, required this.onTap});

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Page ${index + 1} of $count',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == index ? NqColors.ink : NqColors.textTertiary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Today's activity from Apple Health — read on this phone only, never synced.
class _ActivityPage extends StatelessWidget {
  const _ActivityPage({required this.health, required this.isToday});

  final HealthController health;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    if (!health.isConnected) {
      // Opening Settings asks for nothing: permission is only requested there.
      return NqCard(
        radius: 18,
        onTap: () => HomeShellScope.maybeOf(context)?.selectTab(HomeShell.tabSettings),
        semanticLabel: 'See your activity here. Opens Settings to connect Apple Health.',
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: NqColors.fill, shape: BoxShape.circle),
              child: const Icon(Icons.favorite_rounded, color: NqColors.danger, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('See your activity here', style: NqText.headline),
                  const SizedBox(height: 3),
                  Text(
                    'Optional steps and active energy from Apple Health, kept on this phone.',
                    style: NqText.footnote,
                  ),
                  const SizedBox(height: 8),
                  const Text('Open Settings', style: NqText.subhead),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: NqColors.textTertiary),
          ],
        ),
      );
    }
    final snap = isToday ? health.today : null;
    final workouts = snap?.workouts ?? const [];
    final minutes = workouts.fold<int>(0, (sum, w) => sum + w.duration.inMinutes);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ActivityCard(
            value: snap?.steps == null ? '—' : fmtKcal(snap!.steps!),
            label: 'Steps today',
            icon: Icons.directions_walk_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActivityCard(
            value: snap?.activeEnergyKcal == null ? '—' : fmtKcal(snap!.activeEnergyKcal!),
            label: 'Active kcal',
            icon: Icons.local_fire_department_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActivityCard(
            value: workouts.isEmpty ? '—' : '$minutes min',
            label: workouts.length == 1 ? '1 workout' : '${workouts.length} workouts',
            icon: Icons.fitness_center_rounded,
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value, from Apple Health',
    excludeSemantics: true,
    child: NqCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      radius: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: NqText.metric),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, style: NqText.caption, maxLines: 1),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: NqColors.track, width: 7),
              ),
              child: Icon(icon, size: 20, color: NqColors.ink),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.text, required this.isDemo, required this.onTap});

  final String text;
  final bool isDemo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NqCard(
    onTap: onTap,
    semanticLabel: 'Coach: $text',
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: NqColors.fill, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome_outlined, color: NqColors.ink, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Coach', style: NqText.footnote.copyWith(fontWeight: FontWeight.w600)),
                  if (isDemo) ...[const SizedBox(width: 6), const DemoBadge()],
                ],
              ),
              const SizedBox(height: 3),
              Text(text, style: NqText.subhead.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded, color: NqColors.textTertiary),
      ],
    ),
  );
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals({required this.isToday, required this.onAdd});

  final bool isToday;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => NqCard(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
    child: Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: NqColors.fill, shape: BoxShape.circle),
          child: const Icon(Icons.restaurant_rounded, color: NqColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Text(isToday ? 'No meals logged yet' : 'Nothing logged this day', style: NqText.headline),
        const SizedBox(height: 4),
        Text(
          isToday
              ? 'Tap + to photograph a meal or add one by hand. You check every estimate before it’s saved.'
              : 'You can still add a meal for this day.',
          style: NqText.footnote,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: isToday ? 'Log a meal' : 'Add a meal',
          icon: Icons.add_rounded,
          height: 46,
          onPressed: onAdd,
        ),
      ],
    ),
  );
}
