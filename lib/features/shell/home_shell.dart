import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../coach/coach_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../today/today_screen.dart';

/// Lets screens switch tabs (e.g. Today → Coach with a suggested prompt).
class HomeShellScope extends InheritedWidget {
  const HomeShellScope({super.key, required this.selectTab, required this.openCoach, required super.child});

  final ValueChanged<int> selectTab;
  final void Function(String? prompt) openCoach;

  static HomeShellScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HomeShellScope>();

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) => false;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const tabToday = 0;
  static const tabHistory = 1;
  static const tabCoach = 2;
  static const tabSettings = 3;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    (label: 'Today', icon: Icons.donut_large_outlined, active: Icons.donut_large_rounded),
    (label: 'History', icon: Icons.calendar_month_outlined, active: Icons.calendar_month_rounded),
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
    final cupertino = isCupertino(context);
    return HomeShellScope(
      selectTab: _select,
      openCoach: _openCoach,
      child: Scaffold(
        extendBody: cupertino,
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
            // Scroll-edge fade so content doesn't collide with the status bar.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top + 12,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.7, 1],
                      colors: [NqColors.background, Color(0x000F1012)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: cupertino
            ? _GlassTabBar(index: _index, onSelect: _select)
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                destinations: [
                  for (final t in _tabs)
                    NavigationDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.active, color: NqColors.sage),
                      label: t.label,
                    ),
                ],
              ),
      ),
    );
  }
}

/// iOS-style translucent tab bar; content scrolls underneath it.
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: NqColors.surface.withValues(alpha: 0.82),
            border: const Border(top: BorderSide(color: NqColors.hairline, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  for (var i = 0; i < _HomeShellState._tabs.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        label: '${_HomeShellState._tabs[i].label} tab',
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                i == index ? _HomeShellState._tabs[i].active : _HomeShellState._tabs[i].icon,
                                size: 24,
                                color: i == index ? NqColors.sage : NqColors.textTertiary,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _HomeShellState._tabs[i].label,
                                style: NqText.caption.copyWith(
                                  fontSize: 10.5,
                                  color: i == index ? NqColors.sage : NqColors.textTertiary,
                                ),
                              ),
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
      ),
    );
  }
}
