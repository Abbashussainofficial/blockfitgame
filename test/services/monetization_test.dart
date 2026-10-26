import 'package:block_fit/core/ad_config.dart';
import 'package:block_fit/services/ad_service.dart';
import 'package:block_fit/services/storage_service.dart';
import 'package:block_fit/ui/providers/monetization_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = StorageService(await SharedPreferences.getInstance());
  final c = ProviderContainer(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('interstitial frequency', () {
    bool show(int count, {int last = 0, bool removed = false}) =>
        AdService.shouldShowInterstitial(
          gameOverCount: count,
          lastShownAt: last,
          adsRemoved: removed,
        );

    test('every 3rd game over', () {
      expect(AdConfig.interstitialEveryNGameOvers, 3);
      expect(
        [for (var i = 0; i <= 9; i++) show(i)],
        [
          false, false, false, true, false, false, true, false, false, true, //
        ],
      );
    });

    test('never twice for the same game over', () {
      expect(show(3, last: 3), isFalse);
      expect(show(6, last: 3), isTrue);
    });

    test('never after Remove Ads', () {
      expect(show(3, removed: true), isFalse);
      expect(show(6, removed: true), isFalse);
    });
  });

  test('ads stay off where unsupported, rewarded still grants', () async {
    final c = await _container();
    final ads = c.read(adServiceProvider);
    await ads.init();
    expect(ads.ready, isFalse);
    expect(c.read(monetizationProvider).showBanner, isFalse);
    expect(await ads.showRewarded(), RewardOutcome.earned);
    await ads.maybeShowInterstitial(3); // no-op, must not throw
  });

  test('Remove Ads ownership is cached and hides banners', () async {
    final c = await _container({'ads_removed': true});
    final state = c.read(monetizationProvider);
    expect(state.adsRemoved, isTrue);
    expect(state.showBanner, isFalse);
    expect(c.read(adServiceProvider).adsRemoved, isTrue);
  });

  test('store reports unavailable where billing is unsupported', () async {
    final c = await _container();
    final purchases = c.read(purchaseServiceProvider);
    final messages = purchases.messages.toList();
    await purchases.init();
    await purchases.buyRemoveAds();
    await purchases.restore();
    purchases.dispose();
    expect(await messages, hasLength(2));
    expect(purchases.adsRemoved, isFalse);
  });
}
