import 'package:block_fit/core/app_config.dart';
import 'package:block_fit/core/game_theme.dart';
import 'package:block_fit/core/strings.dart';
import 'package:block_fit/game/game_controller.dart';
import 'package:block_fit/main.dart';
import 'package:block_fit/services/storage_service.dart';
import 'package:block_fit/ui/providers/settings_provider.dart';
import 'package:block_fit/ui/providers/theme_provider.dart';
import 'package:block_fit/ui/screens/about_screen.dart';
import 'package:block_fit/ui/screens/game_screen.dart';
import 'package:block_fit/ui/screens/home_screen.dart';
import 'package:block_fit/ui/screens/settings_screen.dart';
import 'package:block_fit/ui/screens/themes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [home] (or the whole app) on a phone-sized screen.
Future<(ProviderContainer, StorageService)> _pump(
  WidgetTester tester, {
  Widget? home,
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final storage = StorageService(await SharedPreferences.getInstance());
  final c = ProviderContainer(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: home == null ? const BlockFitApp() : MaterialApp(home: home),
    ),
  );
  return (c, storage);
}

void main() {
  testWidgets('splash leads to home', (tester) async {
    await _pump(tester);
    expect(find.text(AppStrings.loading), findsOneWidget);
    await tester.pump(AppConfig.splashMinDuration);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(AppStrings.play), findsOneWidget);
    expect(find.text(AppStrings.continueGame), findsNothing);
  });

  testWidgets('home shows the high score', (tester) async {
    await _pump(tester, home: const HomeScreen(), prefs: {'best_score': 777});
    expect(find.text('777'), findsOneWidget);
  });

  testWidgets('Continue appears for a game in progress and resumes it', (
    tester,
  ) async {
    final (c, _) = await _pump(tester, home: const HomeScreen());
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.place(0, 0, 0); // first tray piece always fits on an empty board
    await tester.pumpAndSettle();
    final score = c.read(gameControllerProvider).score;

    expect(find.text(AppStrings.continueGame), findsOneWidget);
    expect(find.text(AppStrings.newGame), findsOneWidget);

    await tester.tap(find.text(AppStrings.continueGame));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    expect(c.read(gameControllerProvider).score, score);
  });

  testWidgets('New Game from home starts fresh', (tester) async {
    final (c, _) = await _pump(tester, home: const HomeScreen());
    c.read(gameControllerProvider.notifier).place(0, 0, 0);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.newGame));
    await tester.pumpAndSettle();
    expect(c.read(gameControllerProvider).score, 0);
    expect(c.read(gameControllerProvider).board.isEmpty, isTrue);
  });

  group('pause', () {
    Future<ProviderContainer> openGame(WidgetTester tester) async {
      final (c, _) = await _pump(tester, home: const HomeScreen());
      await tester.tap(find.text(AppStrings.play));
      await tester.pumpAndSettle();
      c.read(gameControllerProvider.notifier).place(0, 0, 0);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(AppStrings.pause));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.paused), findsOneWidget);
      return c;
    }

    testWidgets('Resume keeps the game', (tester) async {
      final c = await openGame(tester);
      final score = c.read(gameControllerProvider).score;
      await tester.tap(find.text(AppStrings.resume));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.paused), findsNothing);
      expect(c.read(gameControllerProvider).score, score);
    });

    testWidgets('Restart resets the game', (tester) async {
      final c = await openGame(tester);
      await tester.tap(find.text(AppStrings.restart));
      await tester.pumpAndSettle();
      expect(c.read(gameControllerProvider).score, 0);
      expect(find.byType(GameScreen), findsOneWidget);
    });

    testWidgets('Home returns to the menu with Continue', (tester) async {
      await openGame(tester);
      await tester.tap(find.text(AppStrings.home));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(AppStrings.continueGame), findsOneWidget);
    });

    testWidgets('Android back opens pause', (tester) async {
      final (_, _) = await _pump(tester, home: const HomeScreen());
      await tester.tap(find.text(AppStrings.play));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.paused), findsOneWidget);
      expect(find.byType(GameScreen), findsOneWidget);
    });
  });

  group('themes', () {
    testWidgets('locked themes cannot be selected', (tester) async {
      final (c, _) = await _pump(tester, home: const ThemesScreen());
      await tester.tap(find.text(GameTheme.neon.name));
      await tester.pump();
      expect(find.text(AppStrings.themeLocked), findsOneWidget);
      expect(
        find.text(AppStrings.unlockAt(GameTheme.neon.unlockScore)),
        findsOneWidget,
      );
      expect(c.read(gameThemeProvider).id, GameTheme.classicDark.id);
    });

    testWidgets('unlocked themes are selected and saved', (tester) async {
      final (c, storage) = await _pump(
        tester,
        home: const ThemesScreen(),
        prefs: {'best_score': 3000},
      );
      await tester.tap(find.text(GameTheme.neon.name));
      await tester.pumpAndSettle();
      expect(c.read(gameThemeProvider).id, GameTheme.neon.id);
      expect(storage.themeId, GameTheme.neon.id);
      expect(find.text(AppStrings.selected), findsOneWidget);
    });

    testWidgets('a saved theme that is locked falls back', (tester) async {
      final (c, _) = await _pump(
        tester,
        home: const ThemesScreen(),
        prefs: {'theme_id': GameTheme.neon.id},
      );
      expect(c.read(gameThemeProvider).id, GameTheme.classicDark.id);
    });
  });

  testWidgets('settings toggles persist', (tester) async {
    final (c, storage) = await _pump(tester, home: const SettingsScreen());
    expect(c.read(settingsProvider).soundOn, isTrue);
    await tester.tap(find.text(AppStrings.sound));
    await tester.tap(find.text(AppStrings.vibration));
    await tester.pumpAndSettle();
    expect(storage.soundOn, isFalse);
    expect(storage.vibrationOn, isFalse);
  });

  testWidgets('settings offers Remove Ads and Restore', (tester) async {
    await _pump(tester, home: const SettingsScreen());
    expect(find.text(AppStrings.removeAds), findsOneWidget);
    expect(find.text(AppStrings.restorePurchases), findsOneWidget);
    await tester.tap(find.text(AppStrings.removeAds));
    await tester.pump();
    expect(find.text(AppStrings.storeUnavailable), findsOneWidget);
  });

  testWidgets('owned Remove Ads shows as purchased', (tester) async {
    await _pump(
      tester,
      home: const SettingsScreen(),
      prefs: {'ads_removed': true},
    );
    expect(find.text(AppStrings.adsRemoved), findsOneWidget);
  });

  testWidgets('out of undos offers a rewarded ad for one more', (tester) async {
    final (c, _) = await _pump(tester, home: const HomeScreen());
    await tester.tap(find.text(AppStrings.play));
    await tester.pumpAndSettle();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.addUndos(-c.read(gameControllerProvider).undosLeft); // use them up
    ctrl.place(0, 0, 0);
    await tester.pumpAndSettle();
    final before = c.read(gameControllerProvider).moveCount;

    await tester.tap(find.byTooltip(AppStrings.undo));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.outOfUndos), findsOneWidget);
    await tester.tap(find.text(AppStrings.watchAd));
    await tester.pumpAndSettle();

    final s = c.read(gameControllerProvider);
    expect(s.moveCount, before - 1);
    expect(s.undosLeft, 0);
  });

  testWidgets('settings opens About', (tester) async {
    await _pump(tester, home: const SettingsScreen());
    await tester.tap(find.text(AppStrings.about));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text(AppStrings.builtBy), findsOneWidget);
    expect(find.text(AppStrings.companyName), findsOneWidget);
    expect(find.text(AppConfig.contactEmail), findsOneWidget);
  });

  test('theme catalog is complete', () {
    expect(GameTheme.all.length, greaterThanOrEqualTo(5));
    expect(
      GameTheme.all.map((t) => t.id).toSet(),
      hasLength(GameTheme.all.length),
    );
    for (final t in GameTheme.all) {
      expect(t.blockColors, hasLength(8), reason: t.id);
    }
    expect(
      GameTheme.all.where((t) => t.brightness == Brightness.light),
      isNotEmpty,
    );
    expect(GameTheme.all.where((t) => t.unlockScore > 0), isNotEmpty);
    expect(GameTheme.byId('nope'), GameTheme.classicDark);
  });
}
