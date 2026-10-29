import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Every ad and in-app purchase identifier lives here, so going live is a
/// matter of editing this one file (plus the App ID in AndroidManifest.xml).
///
/// Release builds use the real Block Fit ad units. Debug and profile builds
/// use Google's official TEST units, which always fill and never pay out:
/// clicking real ads on your own device can get the AdMob account suspended.
abstract final class AdConfig {
  /// AdMob App ID (also in AndroidManifest.xml).
  static const String androidAppId = 'ca-app-pub-9602784303443487~6212205964';

  /// Home screen banner (adaptive).
  static const String bannerUnitId = kReleaseMode
      ? 'ca-app-pub-9602784303443487/7178015302'
      : 'ca-app-pub-3940256099942544/9214589741';

  /// Interstitial shown after every [interstitialEveryNGameOvers] game overs.
  static const String interstitialUnitId = kReleaseMode
      ? 'ca-app-pub-9602784303443487/6671582999'
      : 'ca-app-pub-3940256099942544/1033173712';

  /// Rewarded ad for Revive and extra Undo.
  static const String rewardedUnitId = kReleaseMode
      ? 'ca-app-pub-9602784303443487/4551851963'
      : 'ca-app-pub-3940256099942544/5224354917';

  static const int interstitialEveryNGameOvers = 3;

  /// Undos granted by one rewarded ad.
  static const int undosPerReward = 1;

  /// Hashed device IDs that should always get test ads (Logcat prints yours
  /// as "Use RequestConfiguration.Builder().setTestDeviceIds(...)").
  static const List<String> testDeviceIds = [];

  /// Set to true to preview the GDPR consent form outside the EEA. Only
  /// takes effect in debug builds.
  static const bool debugForceEeaConsent = false;

  /// Google Play product ID of the one-time "Remove Ads" purchase. Create a
  /// managed (non-consumable) in-app product with this ID in Play Console.
  static const String removeAdsProductId = 'remove_ads';

  /// Ads and Play Billing are only wired up on Android. On other platforms
  /// (e.g. the macOS desktop preview, or unit tests) they are disabled and
  /// rewarded features are granted directly so the game stays testable.
  static bool get monetizationSupported => !kIsWeb && Platform.isAndroid;
}
