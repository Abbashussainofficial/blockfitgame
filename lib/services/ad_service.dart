import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ad_config.dart';
import 'consent_service.dart';
import 'purchase_service.dart';

/// Outcome of offering a rewarded ad.
enum RewardOutcome {
  /// The player watched it; grant the reward.
  earned,

  /// The ad was closed before the reward.
  skipped,

  /// No ad could be shown (not loaded, offline, consent denied, ...).
  unavailable,
}

/// AdMob: Home banner, interstitial between games, rewarded Revive / Undo.
///
/// Rules:
/// * Nothing is requested until UMP consent allows it.
/// * "Remove Ads" hides banners and interstitials; rewarded ads stay
///   available because the player chooses to watch them.
/// * Interstitials only appear when leaving a Game Over screen, never
///   mid-game.
///
/// Every failure is swallowed: a missing ad must never block play.
class AdService extends ChangeNotifier {
  AdService(this._purchases, this._consent) {
    _purchases.addListener(notifyListeners);
  }

  final PurchaseService _purchases;
  final ConsentService _consent;

  bool _ready = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  int _lastInterstitialAt = 0;

  /// True once consent is resolved and the SDK has initialised.
  bool get ready => _ready;

  bool get adsRemoved => _purchases.adsRemoved;
  bool get showBanner => _ready && !adsRemoved;

  /// Pure frequency rule, separated for unit testing.
  static bool shouldShowInterstitial({
    required int gameOverCount,
    required int lastShownAt,
    required bool adsRemoved,
  }) =>
      !adsRemoved &&
      gameOverCount > 0 &&
      gameOverCount != lastShownAt &&
      gameOverCount % AdConfig.interstitialEveryNGameOvers == 0;

  /// Gathers consent, then initialises the SDK and preloads ads.
  Future<void> init() async {
    if (!AdConfig.monetizationSupported || _ready) return;
    try {
      if (!await _consent.gather()) return;
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: AdConfig.testDeviceIds),
      );
      await MobileAds.instance.initialize();
      _ready = true;
      notifyListeners();
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      debugPrint('Ads init failed: $e');
    }
  }

  // ---- Interstitial --------------------------------------------------------

  /// Call when the player leaves Game Over. Shows an interstitial on every
  /// Nth game over and completes once it is closed (or immediately if
  /// none is shown).
  Future<void> maybeShowInterstitial(int gameOverCount) async {
    final ad = _interstitial;
    if (!_ready ||
        ad == null ||
        !shouldShowInterstitial(
          gameOverCount: gameOverCount,
          lastShownAt: _lastInterstitialAt,
          adsRemoved: adsRemoved,
        )) {
      return;
    }
    _lastInterstitialAt = gameOverCount;
    _interstitial = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: ${error.message}');
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    try {
      await ad.show();
      await closed.future;
    } catch (e) {
      debugPrint('Interstitial error: $e');
    }
    _loadInterstitial();
  }

  void _loadInterstitial() {
    if (!_ready || _loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          debugPrint('Interstitial failed to load: ${error.message}');
        },
      ),
    );
  }

  // ---- Rewarded ------------------------------------------------------------

  /// Whether a rewarded ad can be offered right now.
  bool get rewardedAvailable =>
      !AdConfig.monetizationSupported || _rewarded != null;

  /// Shows a rewarded ad and reports whether the reward was earned.
  ///
  /// On platforms without ads (desktop preview, tests) the reward is
  /// granted directly so those flows can still be exercised.
  Future<RewardOutcome> showRewarded() async {
    if (!AdConfig.monetizationSupported) return RewardOutcome.earned;
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return RewardOutcome.unavailable;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded failed to show: ${error.message}');
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      await closed.future;
    } catch (e) {
      debugPrint('Rewarded error: $e');
    }
    _loadRewarded();
    return earned ? RewardOutcome.earned : RewardOutcome.skipped;
  }

  void _loadRewarded() {
    if (!_ready || _loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _loadingRewarded = false;
          debugPrint('Rewarded failed to load: ${error.message}');
        },
      ),
    );
  }

  @override
  void dispose() {
    _purchases.removeListener(notifyListeners);
    _interstitial?.dispose();
    _rewarded?.dispose();
    super.dispose();
  }
}
