import 'package:flutter/material.dart';

import '../features/onboarding/onboarding_flow.dart';
import '../features/shell/home_shell.dart';
import 'app_config.dart';
import 'app_scope.dart';
import 'theme.dart';

class NutriqApp extends StatelessWidget {
  const NutriqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildNutriqTheme(),
      themeMode: ThemeMode.dark,
      // Keep layouts intact at very large text sizes while still honouring Dynamic Type.
      builder: (context, child) => GestureDetector(
        // iOS number pads have no Done key: tapping outside a field closes the keyboard.
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.35, child: child!),
      ),
      home: const _RootGate(),
    );
  }
}

/// Shows onboarding until it's completed (or after a full reset).
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: profile.settings.onboardingComplete
            ? const HomeShell(key: ValueKey('home'))
            : const OnboardingFlow(key: ValueKey('onboarding')),
      ),
    );
  }
}
