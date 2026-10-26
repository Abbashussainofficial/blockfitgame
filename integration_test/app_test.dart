// End-to-end test of Block Fit on a real device or simulator.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart -d <device>
//
// A bot plays complete games through real drag gestures: it reads the live
// game state, picks a move and drags the piece onto the board, then checks
// that the app reacted correctly. Screenshots are saved to build/screenshots.

import 'package:block_fit/core/constants.dart';
import 'package:block_fit/core/game_theme.dart';
import 'package:block_fit/core/strings.dart';
import 'package:block_fit/game/board_logic.dart';
import 'package:block_fit/game/game_controller.dart';
import 'package:block_fit/main.dart' as app;
import 'package:block_fit/models/board.dart';
import 'package:block_fit/models/cell_pos.dart';
import 'package:block_fit/models/game_state.dart';
import 'package:block_fit/ui/providers/settings_provider.dart';
import 'package:block_fit/ui/providers/theme_provider.dart';
import 'package:block_fit/ui/screens/about_screen.dart';
import 'package:block_fit/ui/screens/game_screen.dart';
import 'package:block_fit/ui/screens/home_screen.dart';
import 'package:block_fit/ui/widgets/block_painter.dart';
import 'package:block_fit/ui/widgets/game_board.dart';
import 'package:block_fit/ui/widgets/piece_tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Statistics printed at the end so the run is easy to judge.
class _Stats {
  int moves = 0;
  int linesCleared = 0;
  int maxCombo = 0;
  int traysDealt = 0;
  int gamesOver = 0;
  int bestScore = 0;
}

final _stats = _Stats();

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

GameState _state(WidgetTester tester) =>
    _container(tester).read(gameControllerProvider);

/// Pumps frames for [d] of real time (the splash has an endless spinner, so
/// pumpAndSettle can't be used everywhere).
Future<void> _wait(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _waitFor(WidgetTester tester, Finder f, {int seconds = 10}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (f.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for $f');
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A candidate move: tray slot + anchor, and how many lines it clears.
typedef _Move = ({int slot, CellPos anchor, int lines, int filledAfter});

List<_Move> _moves(GameState s) {
  final out = <_Move>[];
  for (var i = 0; i < s.tray.length; i++) {
    final p = s.tray[i];
    if (p == null) continue;
    for (final a in BoardLogic.validAnchors(s.board, p.shape)) {
      final placed = BoardLogic.place(s.board, p.shape, a.row, a.col);
      final lines = BoardLogic.findFullLines(placed);
      out.add((
        slot: i,
        anchor: a,
        lines: lines.count,
        filledAfter: BoardLogic.clearLines(placed, lines).filledCount,
      ));
    }
  }
  return out;
}

/// Good play: clear as many lines as possible, keep the board empty.
_Move? _bestMove(GameState s) {
  final m = _moves(s);
  if (m.isEmpty) return null;
  m.sort((a, b) {
    final byLines = b.lines.compareTo(a.lines);
    return byLines != 0 ? byLines : a.filledAfter.compareTo(b.filledAfter);
  });
  return m.first;
}

/// Bad play (to reach Game Over): never clear, scatter pieces.
_Move? _worstMove(GameState s) {
  final m = _moves(s);
  if (m.isEmpty) return null;
  final noClear = m.where((x) => x.lines == 0).toList();
  final pool = noClear.isEmpty ? m : noClear;
  // Spread pieces out: pick the anchor in the middle of the list.
  return pool[pool.length ~/ 2];
}

/// Drags tray [slot] so its top-left block lands on [anchor], using real
/// pointer events (exactly what a finger does).
Future<void> _dragPiece(
  WidgetTester tester,
  int slot,
  CellPos anchor, {
  String? screenshotMidDrag,
}) async {
  final s = _state(tester);
  final shape = s.tray[slot]!.shape;
  final tray = tester.getRect(find.byType(PieceTray));
  final geo = BoardGeometry(tester.getRect(find.byType(GameBoard)));
  final slotW = tray.width / GameConfig.traySize;
  final from = Offset(tray.left + slotW * (slot + 0.5), tray.center.dy);
  final topLeft = geo.cellRect(anchor.row, anchor.col).topLeft;
  final to =
      topLeft +
      Offset(
        shape.width * geo.cell / 2,
        shape.height * geo.cell + UiConfig.dragLiftCells * geo.cell,
      );

  final g = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 16));
  for (var i = 1; i <= 12; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 12)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (screenshotMidDrag != null) {
    await _shot(tester, screenshotMidDrag);
  }
  await g.up();
  await tester.pump(const Duration(milliseconds: 16));
}

late IntegrationTestWidgetsFlutterBinding _binding;

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump();
  await _binding.takeScreenshot(name);
}

/// Plays one move through the UI and verifies the app accepted it.
Future<void> _playMove(
  WidgetTester tester,
  _Move move, {
  String? screenshotMidDrag,
}) async {
  final before = _state(tester);
  final hadTwoLeft = before.remainingPieces.length == 1;
  await _dragPiece(
    tester,
    move.slot,
    move.anchor,
    screenshotMidDrag: screenshotMidDrag,
  );
  await _wait(tester, const Duration(milliseconds: 450));
  final after = _state(tester);

  expect(
    after.moveCount,
    before.moveCount + 1,
    reason: 'drag to ${move.anchor} with slot ${move.slot} was not accepted',
  );
  expect(after.score, greaterThan(before.score));
  _stats.moves++;
  _stats.linesCleared += move.lines;
  if (after.comboStreak > _stats.maxCombo) _stats.maxCombo = after.comboStreak;
  if (hadTwoLeft) {
    _stats.traysDealt++;
    expect(after.remainingPieces, hasLength(GameConfig.traySize));
  }
}

/// Plays until Game Over, using good moves first and bad ones afterwards.
Future<void> _playUntilGameOver(
  WidgetTester tester, {
  int goodMoves = 0,
  void Function(GameState s, int moveIndex)? onMove,
}) async {
  var i = 0;
  while (!_state(tester).isGameOver) {
    final s = _state(tester);
    final move = i < goodMoves ? _bestMove(s) : _worstMove(s);
    expect(move, isNotNull, reason: 'not game over but no legal move');
    await _playMove(tester, move!);
    onMove?.call(_state(tester), i);
    i++;
    expect(i, lessThan(400), reason: 'game never ended');
  }
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Block Fit end-to-end', (tester) async {
    // Start from a clean install.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // ---- Splash -> Home ---------------------------------------------------
    await app.main();
    await tester.pump();
    expect(find.text(AppStrings.loading), findsOneWidget);
    await _shot(tester, '01_splash');
    await _waitFor(tester, find.byType(HomeScreen));
    await _wait(tester, const Duration(milliseconds: 500));
    expect(find.text(AppStrings.play), findsOneWidget);
    expect(find.text(AppStrings.continueGame), findsNothing);
    await _shot(tester, '02_home');

    // ---- Play a game with good moves ------------------------------------
    await tester.tap(find.text(AppStrings.play));
    await _wait(tester, const Duration(milliseconds: 800));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(_state(tester).board.isEmpty, isTrue);
    expect(_state(tester).remainingPieces, hasLength(3));
    await _shot(tester, '03_game_start');

    // An invalid drop (onto the tray area) must return the piece.
    final before = _state(tester);
    final tray = tester.getRect(find.byType(PieceTray));
    final g = await tester.startGesture(
      Offset(tray.left + tray.width / 6, tray.center.dy),
    );
    await g.moveBy(const Offset(0, -8));
    await tester.pump();
    await g.up();
    await _wait(tester, const Duration(milliseconds: 400));
    expect(_state(tester).moveCount, before.moveCount);
    expect(_state(tester).tray, before.tray);

    var shotDrag = false;
    var shotCombo = false;
    for (var i = 0; i < 45; i++) {
      final s = _state(tester);
      if (s.isGameOver) {
        // Even good play can run out of room; start a fresh game and go on.
        _stats.gamesOver++;
        await _wait(tester, const Duration(milliseconds: 1300));
        expect(find.text(AppStrings.gameOver), findsOneWidget);
        await tester.tap(find.text(AppStrings.playAgain));
        await _wait(tester, const Duration(milliseconds: 800));
        expect(_state(tester).score, 0);
        continue;
      }
      final move = _bestMove(s)!;
      // Capture a drag with the ghost once the board has some blocks.
      final dragShot = !shotDrag && s.board.filledCount >= 12;
      await _playMove(
        tester,
        move,
        screenshotMidDrag: dragShot ? '04_dragging_ghost' : null,
      );
      shotDrag |= dragShot;
      if (!shotCombo && _state(tester).comboStreak >= 2) {
        await tester.pump(const Duration(milliseconds: 120));
        await _shot(tester, '05_combo');
        shotCombo = true;
      }
    }
    expect(_stats.linesCleared, greaterThan(0), reason: 'bot never cleared');
    expect(find.text('${_state(tester).score}'), findsWidgets);
    await _shot(tester, '06_mid_game');

    // ---- Pause -> Home -> Continue ---------------------------------------
    // Continue only appears for a started game, so make sure moves exist.
    while (_state(tester).moveCount < 2) {
      await _playMove(tester, _bestMove(_state(tester))!);
    }
    final mid = _state(tester);
    await tester.tap(find.byTooltip(AppStrings.pause));
    await _wait(tester, const Duration(milliseconds: 500));
    expect(find.text(AppStrings.paused), findsOneWidget);
    await _shot(tester, '07_pause');
    await tester.tap(find.text(AppStrings.home));
    await _wait(tester, const Duration(milliseconds: 600));
    expect(find.text(AppStrings.continueGame), findsOneWidget);
    expect(prefs.getString('saved_game'), isNotNull, reason: 'not auto-saved');
    await tester.tap(find.text(AppStrings.continueGame));
    await _wait(tester, const Duration(milliseconds: 600));
    expect(
      (_state(tester).moveCount, _state(tester).score),
      (mid.moveCount, mid.score),
      reason: 'game changed between Pause and Continue',
    );

    // ---- Undo -------------------------------------------------------------
    final preUndo = _state(tester);
    await _playMove(tester, _worstMove(preUndo)!);
    await tester.tap(find.byTooltip(AppStrings.undo));
    await _wait(tester, const Duration(milliseconds: 600));
    expect(_state(tester).score, preUndo.score, reason: 'undo failed');
    expect(_state(tester).board, preUndo.board);

    // ---- Play badly to Game Over, then Revive ----------------------------
    await _playUntilGameOver(tester);
    _stats.gamesOver++;
    await _wait(tester, const Duration(milliseconds: 1300));
    expect(find.text(AppStrings.gameOver), findsOneWidget);
    expect(find.text(AppStrings.revive), findsOneWidget);
    await _shot(tester, '08_game_over');

    await tester.tap(find.text(AppStrings.revive));
    await _wait(tester, const Duration(milliseconds: 800));
    expect(_state(tester).isGameOver, isFalse, reason: 'revive failed');
    expect(_state(tester).reviveUsed, isTrue);
    await _shot(tester, '09_revived');

    // Second Game Over: Revive is no longer offered.
    await _playUntilGameOver(tester);
    _stats.gamesOver++;
    await _wait(tester, const Duration(milliseconds: 1300));
    expect(find.text(AppStrings.gameOver), findsOneWidget);
    expect(find.text(AppStrings.revive), findsNothing);
    final finalScore = _state(tester).score;
    _stats.bestScore = _state(tester).bestScore;
    expect(_stats.bestScore, greaterThanOrEqualTo(finalScore));
    expect(prefs.getInt('best_score'), _stats.bestScore);

    // ---- Play Again --------------------------------------------------------
    await tester.tap(find.text(AppStrings.playAgain));
    await _wait(tester, const Duration(milliseconds: 800));
    expect(_state(tester).score, 0);
    expect(_state(tester).board.isEmpty, isTrue);
    expect(_state(tester).bestScore, _stats.bestScore);

    // ---- Home: themes, settings, about -----------------------------------
    await tester.tap(find.byTooltip(AppStrings.pause));
    await _wait(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text(AppStrings.home));
    await _wait(tester, const Duration(milliseconds: 600));
    expect(find.text('${_stats.bestScore}'), findsOneWidget);
    await _shot(tester, '10_home_highscore');

    await tester.tap(find.text(AppStrings.themes));
    await _wait(tester, const Duration(milliseconds: 600));
    await _shot(tester, '11_themes');
    final c = _container(tester);
    for (final theme in GameTheme.all) {
      final unlocked = theme.isUnlocked(_stats.bestScore);
      await tester.tap(find.text(theme.name));
      await _wait(tester, const Duration(milliseconds: 300));
      expect(
        c.read(gameThemeProvider).id == theme.id,
        unlocked,
        reason: '${theme.name} unlocked=$unlocked',
      );
    }
    // Go back to Classic Dark.
    await tester.tap(find.text(GameTheme.classicDark.name));
    await _wait(tester, const Duration(milliseconds: 300));
    await tester.pageBack();
    await _wait(tester, const Duration(milliseconds: 600));

    await tester.tap(find.text(AppStrings.settings));
    await _wait(tester, const Duration(milliseconds: 600));
    await _shot(tester, '12_settings');
    await tester.tap(find.text(AppStrings.sound));
    await _wait(tester, const Duration(milliseconds: 300));
    expect(c.read(settingsProvider).soundOn, isFalse);
    expect(prefs.getBool('sound_on'), isFalse);
    await tester.tap(find.text(AppStrings.sound));
    await _wait(tester, const Duration(milliseconds: 300));
    expect(c.read(settingsProvider).soundOn, isTrue);
    await tester.tap(find.text(AppStrings.about));
    await _wait(tester, const Duration(milliseconds: 600));
    expect(find.text(AppStrings.companyName), findsOneWidget);
    await _shot(tester, '13_about');

    // ---- A light theme in play ------------------------------------------
    if (GameTheme.sunset.isUnlocked(_stats.bestScore)) {
      c.read(settingsProvider.notifier).selectTheme(GameTheme.sunset);
      Navigator.of(tester.element(find.byType(AboutScreen)))
          .popUntil((route) => route.isFirst);
      await _wait(tester, const Duration(milliseconds: 700));
      final start = [
        AppStrings.continueGame,
        AppStrings.play,
      ].map(find.text).firstWhere((f) => f.evaluate().isNotEmpty);
      await tester.tap(start);
      await _wait(tester, const Duration(milliseconds: 700));
      for (var i = 0; i < 6 && !_state(tester).isGameOver; i++) {
        await _playMove(tester, _bestMove(_state(tester))!);
      }
      await _shot(tester, '14_sunset_theme');
      c.read(settingsProvider.notifier).selectTheme(GameTheme.classicDark);
    }

    // ignore: avoid_print
    print(
      'BOT STATS: moves=${_stats.moves} lines=${_stats.linesCleared} '
      'maxCombo=${_stats.maxCombo} traysDealt=${_stats.traysDealt} '
      'gameOvers=${_stats.gamesOver} best=${_stats.bestScore} '
      'boardEmptyAtEnd=${_state(tester).board == Board.empty()}',
    );
  });
}
