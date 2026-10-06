import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/pressable.dart';
import '../coach/coach_screen.dart';
import '../history/history_screen.dart';
import '../scan/meal_flows.dart';
import '../settings/settings_screen.dart';
import '../today/today_screen.dart';

/// Lets screens switch tabs (e.g. Today → Coach with a suggested prompt).
class HomeShellScope extends InheritedWidget {
  const HomeShellScope({super.key, required this.selectTab, required this.openCoach, required super.child});

  final ValueChanged<int> selectTab;
  final void Function(String? prompt) openCoach;

  static HomeShellScope? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<HomeShellScope>();

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) => false;
}

/// Four tabs in a floating pill bar, plus the black “+” button for logging.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const tabToday = 0;
  static const tabHistory = 1;
  static const tabCoach = 2;
  static const tabSettings = 3;

  /// Space screens leave at the bottom so content clears the floating bar.
  static double bottomInset(BuildContext context) => MediaQuery.paddingOf(context).bottom + 96;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    (label: 'Today', icon: Icons.home_outlined, active: Icons.home_rounded),
    (label: 'History', icon: Icons.bar_chart_rounded, active: Icons.bar_chart_rounded),
    (label: 'Coach', icon: Icons.chat_bubble_outline_rounded, active: Icons.chat_bubble_rounded),
    (label: 'Settings', icon: Icons.settings_outlined, active: Icons.settings_rounded),
  ];

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() => _index = i);
  }

  void _openCoach(String? prompt) {
    if (prompt != null) AppScope.of(context).coach.prefill(prompt);
    _select(HomeShell.tabCoach);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return HomeShellScope(
      selectTab: _select,
      openCoach: _openCoach,
      child: ToastInset(
        bottom: HomeShell.bottomInset(context) - MediaQuery.paddingOf(context).bottom,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    TickerMode(
                      enabled: i == _index,
                      child: switch (i) {
                        0 => const TodayScreen(),
                        1 => const HistoryScreen(),
                        2 => const CoachScreen(),
                        _ => const SettingsScreen(),
                      },
                    ),
                ],
              ),
              // Soft fade under the status bar so content doesn't collide with it.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.paddingOf(context).top + 10,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.65, 1],
                        colors: [NqColors.canvas, Color(0x00F6F6F8)],
                      ),
                    ),
                  ),
                ),
              ),
              // Fade content out behind the floating bar.
              if (!keyboard)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: HomeShell.bottomInset(context),
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, 0.45],
                          colors: [Color(0x00F6F6F8), NqColors.canvas],
                        ),
                      ),
                    ),
                  ),
                ),
              // The Coach tab has its own composer at the bottom; hide the bar while typing.
              if (!keyboard)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomBar(index: _index, onSelect: _select, onAdd: () => showAddMenu(context)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect, required this.onAdd});

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom - 6 : 14),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: NqColors.card.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: NqColors.hairline),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < _HomeShellState._tabs.length; i++)
                        Expanded(
                          child: _TabButton(
                            label: _HomeShellState._tabs[i].label,
                            icon: i == index ? _HomeShellState._tabs[i].active : _HomeShellState._tabs[i].icon,
                            selected: i == index,
                            onTap: () => onSelect(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            key: const ValueKey('log-meal-button'),
            button: true,
            label: 'Log a meal',
            child: Pressable(
              onTap: () {
                HapticFeedback.lightImpact();
                onAdd();
              },
              scale: 0.92,
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: NqColors.inkSoft,
                  shape: BoxShape.circle,
                  boxShadow: NqShadow.floating,
                ),
                child: const Icon(Icons.add_rounded, color: NqColors.onInk, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NqColors.ink : NqColors.textTertiary;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label tab',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: NqText.caption.copyWith(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The “+” menu: four ways to log, shown as tiles above the button.
Future<void> showAddMenu(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, _) => _AddMenu(hostContext: context),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AddMenu extends StatelessWidget {
  const _AddMenu({required this.hostContext});

  /// The shell's context: actions run there after the menu closes.
  final BuildContext hostContext;

  void _run(BuildContext context, Future<void> Function(BuildContext) action) {
    Navigator.pop(context);
    action(hostContext);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final items = <({IconData icon, String label, Future<void> Function(BuildContext) action})>[
      (icon: Icons.photo_camera_outlined, label: 'Scan food', action: MealFlows.openCamera),
      (
        icon: Icons.photo_library_outlined,
        label: 'Photo library',
        action: (BuildContext c) => MealFlows.pickFromLibrary(c).then((_) {}),
      ),
      (icon: Icons.edit_note_rounded, label: 'Log manually', action: MealFlows.openManual),
      (icon: Icons.bookmark_border_rounded, label: 'My foods', action: MealFlows.openMyFoods),
    ];
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, (bottom > 0 ? 0 : 14) + 84),
          child: Material(
            type: MaterialType.transparency,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final item in items)
                  Pressable(
                    onTap: () => _run(context, item.action),
                    semanticLabel: item.label,
                    child: Container(
                      decoration: BoxDecoration(
                        color: NqColors.card,
                        borderRadius: BorderRadius.circular(NqRadius.card),
                        boxShadow: NqShadow.floating,
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item.icon, size: 26, color: NqColors.ink),
                            const SizedBox(height: 8),
                            Text(item.label, style: NqText.subhead),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
