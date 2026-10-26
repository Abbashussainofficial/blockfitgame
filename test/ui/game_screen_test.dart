import 'package:block_fit/core/constants.dart';
import 'package:block_fit/core/strings.dart';
import 'package:block_fit/game/game_controller.dart';
import 'package:block_fit/game/shapes.dart';
import 'package:block_fit/models/board.dart';
import 'package:block_fit/models/game_state.dart';
import 'package:block_fit/models/piece.dart';
import 'package:block_fit/services/storage_service.dart';
import 'package:block_fit/ui/screens/game_screen.dart';
import 'package:block_fit/ui/widgets/block_painter.dart';
import 'package:block_fit/ui/widgets/game_board.dart';
import 'package:block_fit/ui/widgets/piece_tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Piece _p(String id, int n) => Piece(id: n, shape: shapeById(id)!);

/// Pumps the game screen on a 360x780 phone with a known board and tray.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  Board board,
  List<Piece?> tray,
) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final storage = StorageService(await SharedPreferences.getInstance());
  final container = ProviderContainer(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  container
      .read(gameControllerProvider.notifier)
      .loadState(GameState(board: board, tray: tray));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GameScreen()),
    ),
  );
  return container;
}

/// Finger position that puts [piece]'s top-left block on board cell
/// ([row], [col]), accounting for the piece floating above the finger.
Offset _fingerFor(WidgetTester tester, Piece piece, int row, int col) {
  final geo = BoardGeometry(tester.getRect(find.byType(GameBoard)));
  final s = piece.shape;
  final topLeft = geo.cellRect(row, col).topLeft;
  return topLeft +
      Offset(
        s.width * geo.cell / 2,
        s.height * geo.cell + UiConfig.dragLiftCells * geo.cell,
      );
}

Offset _slotCenter(WidgetTester tester, int index) {
  final tray = tester.getRect(find.byType(PieceTray));
  final slot = tray.width / GameConfig.traySize;
  return Offset(tray.left + slot * (index + 0.5), tray.center.dy);
}

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from);
  await tester.pump();
  for (var i = 1; i <= 10; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dragging a piece onto the board places it', (tester) async {
    final square = _p('square2', 1);
    final c = await _pump(tester, Board.empty(), [
      square,
      _p('dot', 2),
      _p('dot', 3),
    ]);

    await _drag(
      tester,
      _slotCenter(tester, 0),
      _fingerFor(tester, square, 0, 0),
    );

    final s = c.read(gameControllerProvider);
    expect(s.tray[0], isNull);
    expect(s.score, 4);
    for (final (r, col) in [(0, 0), (0, 1), (1, 0), (1, 1)]) {
      expect(s.board.isFilled(r, col), isTrue);
    }
  });

  testWidgets('snaps to the nearest cell when slightly off', (tester) async {
    final square = _p('square2', 1);
    final c = await _pump(tester, Board.empty(), [square, null, _p('dot', 3)]);
    final geo = BoardGeometry(tester.getRect(find.byType(GameBoard)));
    final target =
        _fingerFor(tester, square, 3, 3) +
        Offset(geo.cell * 0.3, -geo.cell * 0.3);

    await _drag(tester, _slotCenter(tester, 0), target);

    expect(c.read(gameControllerProvider).board.isFilled(3, 3), isTrue);
  });

  testWidgets('invalid drop returns the piece to the tray', (tester) async {
    final square = _p('square3', 1);
    final c = await _pump(tester, Board.empty(), [
      square,
      _p('dot', 2),
      _p('dot', 3),
    ]);
    final before = c.read(gameControllerProvider);
    final start = _slotCenter(tester, 0);

    // Release just above the tray, below the board: no valid ghost.
    await _drag(tester, start, start + const Offset(0, -10));

    final after = c.read(gameControllerProvider);
    expect(after, same(before));
    expect(after.tray[0], square);
  });

  testWidgets('placing shows +points and the score counts up', (tester) async {
    final square = _p('square2', 1);
    await _pump(tester, Board.empty(), [square, _p('dot', 2), _p('dot', 3)]);
    final g = await tester.startGesture(_slotCenter(tester, 0));
    await tester.pump();
    await g.moveTo(_fingerFor(tester, square, 2, 2));
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('+4'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('+4'), findsNothing);
    expect(find.text('4'), findsOneWidget); // header settled on the new score
  });

  testWidgets('completing a row clears it and scores', (tester) async {
    final board = Board.fromRows([
      '.0000000',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final dot = _p('dot', 1);
    final c = await _pump(tester, board, [dot, _p('dot', 2), null]);

    await _drag(tester, _slotCenter(tester, 0), _fingerFor(tester, dot, 0, 0));

    final s = c.read(gameControllerProvider);
    expect(s.board.isEmpty, isTrue);
    expect(s.score, 1 + 10);
  });

  testWidgets('consecutive clears show the combo banner', (tester) async {
    final board = Board.fromRows([
      '.0000000',
      '.0000000',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final a = _p('dot', 1);
    final b = _p('dot', 2);
    await _pump(tester, board, [a, b, _p('dot', 3)]);

    await _drag(tester, _slotCenter(tester, 0), _fingerFor(tester, a, 0, 0));
    expect(find.text(AppStrings.combo(2)), findsNothing);

    final g = await tester.startGesture(_slotCenter(tester, 1));
    await tester.pump();
    await g.moveTo(_fingerFor(tester, b, 1, 0));
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.combo(2)), findsOneWidget);
    await tester.pumpAndSettle();
  });

  group('game over', () {
    final checkerboard = Board.fromRows([
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
    ]);

    testWidgets('appears after the last possible move, then revive', (
      tester,
    ) async {
      final dot = _p('dot', 1);
      final c = await _pump(tester, checkerboard, [
        dot,
        _p('square2', 2),
        null,
      ]);
      expect(find.text(AppStrings.gameOver), findsNothing);

      // Drag by hand (no pumpAndSettle) so the delay can be measured.
      final g = await tester.startGesture(_slotCenter(tester, 0));
      await tester.pump();
      await g.moveTo(_fingerFor(tester, dot, 0, 1));
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(c.read(gameControllerProvider).isGameOver, isTrue);

      // Short pause so the player sees the final board first.
      await tester.pump(UiConfig.gameOverDelay ~/ 2);
      expect(find.text(AppStrings.gameOver), findsNothing);
      await tester.pump(UiConfig.gameOverDelay);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.gameOver), findsOneWidget);

      await tester.tap(find.text(AppStrings.revive));
      await tester.pumpAndSettle();
      final s = c.read(gameControllerProvider);
      expect(s.isGameOver, isFalse);
      expect(s.reviveUsed, isTrue);
      expect(find.text(AppStrings.gameOver), findsNothing);
    });

    testWidgets('pause is disabled in the pause before Game Over', (
      tester,
    ) async {
      final dot = _p('dot', 1);
      await _pump(tester, checkerboard, [dot, _p('square2', 2), null]);
      final g = await tester.startGesture(_slotCenter(tester, 0));
      await tester.pump();
      await g.moveTo(_fingerFor(tester, dot, 0, 1));
      await tester.pump();
      await g.up();
      await tester.pump();

      // Game has ended but the Game Over screen is not up yet.
      await tester.tap(find.byTooltip(AppStrings.pause));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(AppStrings.paused), findsNothing);

      await tester.pump(UiConfig.gameOverDelay);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.gameOver), findsOneWidget);
      expect(find.text(AppStrings.paused), findsNothing);
    });

    testWidgets('restored finished game shows Game Over; Play Again resets', (
      tester,
    ) async {
      final c = await _pump(tester, checkerboard, [
        _p('square3', 1),
        null,
        null,
      ]);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.gameOver), findsOneWidget);

      await tester.tap(find.text(AppStrings.playAgain));
      await tester.pumpAndSettle();
      final s = c.read(gameControllerProvider);
      expect(s.board.isEmpty, isTrue);
      expect(s.score, 0);
      expect(find.text(AppStrings.gameOver), findsNothing);
    });
  });
}
