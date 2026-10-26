/// App-level identifiers and links. Edit these before release.
abstract final class AppConfig {
  static const String packageName = 'com.adivantech.blockfit';

  /// Keep in sync with `version:` in pubspec.yaml.
  static const String version = '1.0.0';

  static const String contactEmail = 'contact@adivantech.com';

  /// TODO(release): host store/privacy_policy.md (Phase 7) and put its public
  /// URL here. Google Play requires a reachable privacy policy URL.
  static const String privacyPolicyUrl =
      'https://adivantech.com/blockfit/privacy-policy';

  /// Opens the Play Store app directly; falls back to the web listing.
  static const String playStoreMarketUrl = 'market://details?id=$packageName';
  static const String playStoreWebUrl =
      'https://play.google.com/store/apps/details?id=$packageName';

  /// Minimum time the splash screen stays up, so it never just flickers.
  static const Duration splashMinDuration = Duration(milliseconds: 1400);
}
