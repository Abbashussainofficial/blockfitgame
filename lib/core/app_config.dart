/// App-level identifiers and links. Edit these before release.
abstract final class AppConfig {
  static const String packageName = 'com.adivantech.blockfit';

  /// Keep in sync with `version:` in pubspec.yaml.
  static const String version = '1.0.1';

  static const String contactEmail = 'contact@adivantech.com';

  /// Public copy of store/privacy_policy.md. The same URL goes in Play
  /// Console and the AdMob consent message.
  static const String privacyPolicyUrl =
      'https://adivantech.com/privacypolicy-blockfit';

  /// Opens the Play Store app directly; falls back to the web listing.
  static const String playStoreMarketUrl = 'market://details?id=$packageName';
  static const String playStoreWebUrl =
      'https://play.google.com/store/apps/details?id=$packageName';

  /// Minimum time the splash screen stays up, so it never just flickers.
  static const Duration splashMinDuration = Duration(milliseconds: 1400);
}
