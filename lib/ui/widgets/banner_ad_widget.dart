import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/ad_config.dart';
import '../providers/monetization_provider.dart';

/// Adaptive banner for the Home screen. Takes no space until an ad has
/// loaded, and disappears for players who bought "Remove Ads".
class HomeBannerAd extends ConsumerStatefulWidget {
  const HomeBannerAd({super.key});

  @override
  ConsumerState<HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends ConsumerState<HomeBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  Future<void> _load(double width) async {
    _requested = true;
    try {
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
        width.truncate(),
      );
      if (!mounted || size == null) return;
      final ad = BannerAd(
        adUnitId: AdConfig.bannerUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('Banner failed to load: ${error.message}');
            ad.dispose();
            if (mounted) setState(() => _ad = null);
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (e) {
      debugPrint('Banner error: $e');
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = ref.watch(monetizationProvider.select((s) => s.showBanner));
    if (!show) return const SizedBox.shrink();
    if (!_requested) _load(MediaQuery.sizeOf(context).width);
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
