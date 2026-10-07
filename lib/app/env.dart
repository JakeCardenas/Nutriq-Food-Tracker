/// Build-time configuration, supplied with
/// `flutter run --dart-define-from-file=config/nutriq.json`.
///
/// Only public client values belong here: the Supabase project URL and its
/// publishable/anon key (safe to ship — Row Level Security protects the data)
/// and OAuth *client IDs*. Never put a service-role key, Google client secret,
/// Apple private key or AI-provider key in this file or anywhere in the app.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'com.prodbyjake.nutriq://login-callback',
  );
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const appleSignInEnabled = bool.fromEnvironment('APPLE_SIGN_IN_ENABLED');

  /// Offer the AI coach to signed-in people. Turn on only after the `coach`
  /// Edge Function is deployed with its key (docs/SETUP_AND_TESTING.md §7).
  static const aiCoachEnabled = bool.fromEnvironment('AI_COACH_ENABLED');

  /// True when real Supabase values were supplied (not the example placeholders).
  static bool get cloudConfigured =>
      supabaseUrl.startsWith('https://') &&
      !supabaseUrl.contains('YOUR-PROJECT') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.startsWith('YOUR-');
}
