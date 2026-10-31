// Captures the Google Play phone screenshots.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/store_screenshots_test.dart -d <device>
//
// Run on an Android emulator set to 1080x1920 (`adb shell wm size 1080x1920`)
// so the images come out at exactly 9:16. Boards are hand-made so every shot
// shows a lively mid-game; "Remove Ads" is pre-set so no ads appear.
// Images are saved to build/screenshots/store_*.png.

import 'package:block_fit/core/constants.dart';
import 'package:block_fit/core/game_theme.dart';
import 'package:block_fit/core/strings.dart';
import 'package:block_fit/game/board_logic.dart';
import 'package:block_fit/game/game_controller.dart';
import 'package:block_fit/game/shapes.dart';
import 'package:block_fit/main.dart' as app;
import 'package:block_fit/models/board.dart';
import 'package:block_fit/models/game_state.dart';
import 'package:block_fit/models/piece.dart';
import 'package:block_fit/ui/providers/settings_provider.dart';
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

late IntegrationTestWidgetsFlutterBinding _binding;

const int _best = 2860;

Piece _p(String id, int n) => Piece(id: n, shape: shapeById(id)!);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Future<void> _wait(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _waitFor(WidgetTester tester, Finder f) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (f.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for $f');
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump();
  await _binding.takeScreenshot('store_$name');
}

void _load(WidgetTester tester, GameState s) =>
    _container(tester).read(gameControllerProvider.notifier).loadState(s);

/// Finger position that puts tray [slot]'s piece with its top-left block on
/// ([row], [col]).
(Offset, Offset) _dragPath(WidgetTester tester, int slot, int row, int col) {
  final shape = _container(tester)
      .read(gameControllerProvider)
      .tray[slot]!
      .shape;
  final tray = tester.getRect(find.byType(PieceTray));
  final geo = BoardGeometry(tester.getRect(find.byType(GameBoard)));
  final slotW = tray.width / GameConfig.traySize;
  final from = Offset(tray.left + slotW * (slot + 0.5), tray.center.dy);
  final to =
      geo.cellRect(row, col).topLeft +
      Offset(
        shape.width * geo.cell / 2,
        shape.height * geo.cell + UiConfig.dragLiftCells * geo.cell,
      );
  return (from, to);
}

Future<TestGesture> _hover(
  WidgetTester tester,
  int slot,
  int row,
  int col,
) async {
  final (from, to) = _dragPath(tester, slot, row, col);
  final g = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 16));
  for (var i = 1; i <= 12; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 12)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await _wait(tester, const Duration(milliseconds: 200));
  return g;
}

// Boards: '.' = empty, digit = colour index.

final _dragBoard = Board.fromRows(const [
  '........',
  '........',
  '...1....',
  '..111.6.',
  '0...3366',
  '00.4333.',
  '0244.555',
  '5577...2',
]);

final _comboBoard = Board.fromRows(const [
  '........',
  '.....2..',
  '....22..',
  '.1...2..',
  '.11..3..',
  '0.1.333.',
  '004455..',
  '077455..',
]);

final _themeBoard = Board.fromRows(const [
  '........',
  '.......4',
  '..22...4',
  '.1225..4',
  '.11.55..',
  '0..3.567',
  '00333.77',
  '0661.477',
]);

final _gameOverBoard = Board.fromRows(const [
  '0112.335',
  '0.12233.',
  '44.17.66',
  '4.577006',
  '55.7.400',
  '6551.4.2',
  '6.11223.',
  '66.0.233',
]);

GameState _game(
  Board board,
  List<Piece?> tray, {
  required int score,
  int combo = 0,
  bool over = false,
}) => GameState(
  board: board,
  tray: tray,
  score: score,
  bestScore: score > _best ? score : _best,
  startingBest: _best,
  comboStreak: combo,
  isGameOver: over,
  moveCount: 40,
);

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Play Store screenshots', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setInt('best_score', _best);
    await prefs.setBool('ads_removed', true);
    await prefs.setBool('tutorial_seen', true);

    await app.main();
    await _waitFor(tester, find.byType(HomeScreen));
    await _binding.convertFlutterSurfaceToImage();
    await _wait(tester, const Duration(milliseconds: 1200));
    await _shot(tester, '03_home');

    await tester.tap(find.text(AppStrings.themes));
    await _wait(tester, const Duration(milliseconds: 900));
    await _shot(tester, '04_themes');
    await tester.pageBack();
    await _wait(tester, const Duration(milliseconds: 700));

    await tester.tap(find.text(AppStrings.settings));
    await _wait(tester, const Duration(milliseconds: 900));
    await _shot(tester, '08_settings');
    await tester.pageBack();
    await _wait(tester, const Duration(milliseconds: 700));

    // 1. Dragging a piece with the ghost preview completing the bottom row.
    await tester.tap(find.text(AppStrings.play));
    await _waitFor(tester, find.byType(GameScreen));
    _load(
      tester,
      _game(_dragBoard, [
        _p('line3_h', 1),
        _p('t_0', 2),
        _p('corner2_a', 3),
      ], score: 1240),
    );
    await _wait(tester, const Duration(milliseconds: 900));
    final drag = await _hover(tester, 0, 7, 4);
    await _shot(tester, '01_drag');
    await drag.up();
    await _wait(tester, const Duration(milliseconds: 900));

    // 2. A double clear on a combo streak.
    _load(
      tester,
      _game(
        _comboBoard,
        [_p('line2_h', 4), _p('square2', 5), _p('l_0', 6)],
        score: 1580,
        combo: 1,
      ),
    );
    await _wait(tester, const Duration(milliseconds: 900));
    final combo = await _hover(tester, 1, 6, 6);
    await combo.up();
    await tester.pump(const Duration(milliseconds: 16));
    for (final ms in [120, 200, 300]) {
      await _wait(tester, Duration(milliseconds: ms ~/ 3));
      await _shot(tester, '02_combo_$ms');
    }
    await _wait(tester, const Duration(milliseconds: 1200));

    // 5-6. Light and neon themes mid-game.
    final settings = _container(tester).read(settingsProvider.notifier);
    for (final (name, theme, score) in [
      ('05_sunset', GameTheme.sunset, 1960),
      ('06_neon', GameTheme.neon, 2410),
    ]) {
      settings.selectTheme(theme);
      _load(
        tester,
        _game(_themeBoard, [
          _p('square2', 7),
          _p('line4_h', 8),
          _p('s_h', 9),
        ], score: score),
      );
      await _wait(tester, const Duration(milliseconds: 1000));
      await _shot(tester, name);
    }
    settings.selectTheme(GameTheme.classicDark);

    // 7. Game Over with a new best score.
    final overTray = [
      _p('square3', 10),
      _p('line5_h', 11),
      _p('corner3_a', 12),
    ];
    for (final p in overTray) {
      expect(
        BoardLogic.validAnchors(_gameOverBoard, p.shape),
        isEmpty,
        reason: '${p.shape.id} still fits',
      );
    }
    _load(tester, _game(_gameOverBoard, overTray, score: 3125, over: true));
    await _wait(tester, const Duration(milliseconds: 2500));
    expect(find.text(AppStrings.gameOver), findsOneWidget);
    await _shot(tester, '07_game_over');
  });
}
