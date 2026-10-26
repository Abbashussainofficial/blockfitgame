import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/strings.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/consent_service.dart';
import 'services/feedback_service.dart';
import 'services/purchase_service.dart';
import 'services/storage_service.dart';
import 'ui/providers/monetization_provider.dart';
import 'ui/providers/theme_provider.dart';
import 'ui/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final storage = await StorageService.create();
  // Sounds load in the background; the game is playable before they finish.
  final audio = AudioService();
  unawaited(audio.init());
  final purchases = PurchaseService(storage);
  final consent = ConsentService();
  final ads = AdService(purchases, consent);
  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        audioServiceProvider.overrideWithValue(audio),
        purchaseServiceProvider.overrideWithValue(purchases),
        consentServiceProvider.overrideWithValue(consent),
        adServiceProvider.overrideWithValue(ads),
      ],
      child: const BlockFitApp(),
    ),
  );
  // After the first frame: sync purchases, then ask for GDPR consent (UMP
  // shows its form if needed) and start AdMob. Nothing here blocks play.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(purchases.init());
    unawaited(ads.init());
  });
}

/// Root widget: applies the active theme and starts on the splash screen.
class BlockFitApp extends ConsumerWidget {
  const BlockFitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: AppStrings.appName,
    debugShowCheckedModeBanner: false,
    theme: ref.watch(gameThemeProvider).toMaterial(),
    home: const SplashScreen(),
  );
}
