import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/ad_config.dart';
import 'storage_service.dart';

/// Results surfaced to the UI as a short message.
enum PurchaseMessage {
  purchased,
  restored,
  nothingToRestore,
  failed,
  unavailable,
}

/// One-time "Remove Ads" purchase through Google Play Billing.
///
/// Ownership is cached locally so the app stays ad-free offline, and is
/// re-synced from Play on every launch (covers reinstalls / new devices).
///
/// Note: purchases are trusted as reported by Play. For stronger protection
/// against tampering, verify `purchase.verificationData` on a server.
class PurchaseService extends ChangeNotifier {
  PurchaseService(this._storage);

  final StorageService _storage;
  InAppPurchase get _iap => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final StreamController<PurchaseMessage> _messages =
      StreamController.broadcast();

  ProductDetails? _product;
  bool _available = false;
  bool _pending = false;
  bool _restoring = false;
  bool _restoredSomething = false;

  bool get adsRemoved => _storage.adsRemoved;
  bool get storeAvailable => _available && _product != null;
  bool get pending => _pending;

  /// Localised price from Play, e.g. "$1.99" (null until loaded).
  String? get price => _product?.price;

  /// One-off outcomes for snackbars.
  Stream<PurchaseMessage> get messages => _messages.stream;

  Future<void> init() async {
    if (!AdConfig.monetizationSupported) return;
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('Purchase stream error: $e'),
      );
      final response = await _iap.queryProductDetails({
        AdConfig.removeAdsProductId,
      });
      if (response.error != null) {
        debugPrint('Product query failed: ${response.error}');
      }
      _product = response.productDetails.isEmpty
          ? null
          : response.productDetails.first;
      notifyListeners();
      // Silently re-sync ownership; results arrive on the purchase stream.
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Billing init failed: $e');
    }
  }

  /// Starts the Play purchase sheet. The result arrives via [messages].
  Future<void> buyRemoveAds() async {
    final product = _product;
    if (!_available || product == null) {
      _messages.add(PurchaseMessage.unavailable);
      return;
    }
    try {
      _pending = true;
      notifyListeners();
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      debugPrint('Purchase failed to start: $e');
      _pending = false;
      notifyListeners();
      _messages.add(PurchaseMessage.failed);
    }
  }

  /// User-initiated restore (Settings → Restore Purchases).
  Future<void> restore() async {
    if (!_available) {
      _messages.add(PurchaseMessage.unavailable);
      return;
    }
    _restoring = true;
    _restoredSomething = false;
    try {
      await _iap.restorePurchases();
      // Play delivers restored items on the stream; give it a moment.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!_restoredSomething) _messages.add(PurchaseMessage.nothingToRestore);
    } catch (e) {
      debugPrint('Restore failed: $e');
      _messages.add(PurchaseMessage.failed);
    } finally {
      _restoring = false;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != AdConfig.removeAdsProductId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          _pending = true;
        case PurchaseStatus.purchased:
          await _grant();
          _messages.add(PurchaseMessage.purchased);
        case PurchaseStatus.restored:
          final wasRemoved = adsRemoved;
          await _grant();
          _restoredSomething = true;
          if (_restoring || !wasRemoved) {
            _messages.add(PurchaseMessage.restored);
          }
        case PurchaseStatus.error:
          _pending = false;
          debugPrint('Purchase error: ${p.error}');
          _messages.add(PurchaseMessage.failed);
        case PurchaseStatus.canceled:
          _pending = false;
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('completePurchase failed: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> _grant() async {
    _pending = false;
    await _storage.setAdsRemoved(true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _messages.close();
    super.dispose();
  }
}
