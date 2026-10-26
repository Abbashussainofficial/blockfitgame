import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Every ad and in-app purchase identifier lives here, so going live is a
/// matter of editing this one file (plus the App ID in AndroidManifest.xml).
///
/// The IDs below are Google's official TEST IDs. They always fill and never
/// pay out, and using them is the only safe way to test: clicking real ads on
/// your own device can get your AdMob account suspended.
///
/// TODO(release): replace every `ca-app-pub-3940256099942544` value with your
/// own IDs from https://apps.admob.com, and set the same App ID in
/// android/app/src/main/AndroidManifest.xml
/// (com.google.android.gms.ads.APPLICATION_ID).
abstract final class AdConfig {
  /// AdMob App ID (also in AndroidManifest.xml).
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';

  /// Home screen banner (adaptive).
  static const String bannerUnitId = 'ca-app-pub-3940256099942544/9214589741';

  /// Interstitial shown after every [interstitialEveryNGameOvers] game overs.
  static const String interstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Rewarded ad for Revive and extra Undo.
  static const String rewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

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
