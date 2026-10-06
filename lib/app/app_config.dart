/// The one place to rename the app inside Flutter.
///
/// The home-screen label is set natively (Flutter can't change it at runtime):
/// - iOS: `ios/Runner/Info.plist` → `CFBundleDisplayName`
/// - Android: `android/app/src/main/AndroidManifest.xml` → `android:label`
abstract final class AppConfig {
  static const appName = 'Nutriq';
  static const tagline = 'Snap a meal. Check the estimate. Keep a calm daily log.';
  static const version = '0.1.0';

  static const estimateDisclaimer =
      'Nutrition values are estimates for information only — not medical advice.';
}
