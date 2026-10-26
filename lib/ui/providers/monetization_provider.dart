import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ad_service.dart';
import '../../services/consent_service.dart';
import '../../services/purchase_service.dart';
import '../../services/storage_service.dart';

/// Service instances. `main()` overrides these with initialised objects;
/// the defaults are inert (used by tests and non-Android previews).
final consentServiceProvider = Provider<ConsentService>(
  (ref) => ConsentService(),
);

final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => PurchaseService(ref.watch(storageServiceProvider)),
);

final adServiceProvider = Provider<AdService>(
  (ref) => AdService(
    ref.watch(purchaseServiceProvider),
    ref.watch(consentServiceProvider),
  ),
);

/// Snapshot of monetization status for the UI.
class MonetizationState {
  const MonetizationState({
    required this.adsRemoved,
    required this.adsReady,
    required this.storeAvailable,
    required this.purchasePending,
    this.price,
  });

  final bool adsRemoved;

  /// Ads SDK initialised (consent resolved).
  final bool adsReady;
  final bool storeAvailable;
  final bool purchasePending;

  /// Localised "Remove Ads" price, when the store has loaded it.
  final String? price;

  bool get showBanner => adsReady && !adsRemoved;
}

/// Mirrors [AdService] and [PurchaseService] into immutable state.
class MonetizationController extends Notifier<MonetizationState> {
  @override
  MonetizationState build() {
    final ads = ref.watch(adServiceProvider);
    final purchases = ref.watch(purchaseServiceProvider);
    void sync() => state = _snapshot(ads, purchases);
    ads.addListener(sync);
    purchases.addListener(sync);
    ref.onDispose(() {
      ads.removeListener(sync);
      purchases.removeListener(sync);
    });
    return _snapshot(ads, purchases);
  }

  static MonetizationState _snapshot(AdService ads, PurchaseService p) =>
      MonetizationState(
        adsRemoved: p.adsRemoved,
        adsReady: ads.ready,
        storeAvailable: p.storeAvailable,
        purchasePending: p.pending,
        price: p.price,
      );
}

final monetizationProvider =
    NotifierProvider<MonetizationController, MonetizationState>(
      MonetizationController.new,
    );
