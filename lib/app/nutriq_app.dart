import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/account/account_prompts.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/shell/home_shell.dart';
import '../services/auth/auth_service.dart';
import '../state/session_controller.dart';
import '../widgets/buttons.dart';
import '../widgets/nutriq_mark.dart';
import 'app_config.dart';
import 'app_scope.dart';
import 'theme.dart';

/// Root widget. Each session (local-only or a signed-in account) gets its own
/// [MaterialApp] — keyed by session — so switching accounts can never leave a
/// screen from the previous account on the navigation stack.
class NutriqApp extends StatelessWidget {
  const NutriqApp({super.key, required this.sessions, required this.auth});

  final SessionController sessions;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sessions,
      builder: (context, _) {
        final session = sessions.session;
        if (session == null) return _Splash(error: sessions.error, onRetry: sessions.restartSession);
        return AppScope(
          sessions: sessions,
          session: session,
          auth: auth,
          child: _app(key: ValueKey(session.key), home: const _SessionHome()),
        );
      },
    );
  }
}

MaterialApp _app({Key? key, required Widget home}) => MaterialApp(
  key: key,
  title: AppConfig.appName,
  debugShowCheckedModeBanner: false,
  theme: buildNutriqTheme(),
  themeMode: ThemeMode.light,
  builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
    // Dark status bar on the light UI; the camera and photo headers override it.
    value: SystemUiOverlayStyle.dark,
    child: GestureDetector(
      // iOS number pads have no Done key: tapping outside a field closes the keyboard.
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.35, child: child!),
    ),
  ),
  home: home,
);

/// Onboarding until it's completed, then the main app — plus account prompts
/// (import offer, password reset) that belong to this session.
class _SessionHome extends StatelessWidget {
  const _SessionHome();

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    return AccountPrompts(
      child: ListenableBuilder(
        listenable: profile,
        builder: (context, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: profile.settings.onboardingComplete
              ? const HomeShell(key: ValueKey('home'))
              : const OnboardingFlow(key: ValueKey('onboarding')),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _app(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NutriqMark(size: 64, color: NqColors.ink),
              if (error != null) ...[
                const SizedBox(height: 24),
                const Text('Couldn’t open your data', style: NqText.title),
                const SizedBox(height: 8),
                Text(error!, style: NqText.footnote, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                PrimaryButton(label: 'Try again', onPressed: onRetry),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
