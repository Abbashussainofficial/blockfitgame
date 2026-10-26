import 'package:block_fit/game/game_controller.dart';
import 'package:block_fit/game/shapes.dart';
import 'package:block_fit/models/board.dart';
import 'package:block_fit/models/game_state.dart';
import 'package:block_fit/models/piece.dart';
import 'package:block_fit/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Piece _p(String id, int n) => Piece(id: n, shape: shapeById(id)!);

final _checkerboard = Board.fromRows([
  '0.0.0.0.',
  '.0.0.0.0',
  '0.0.0.0.',
  '.0.0.0.0',
  '0.0.0.0.',
  '.0.0.0.0',
  '0.0.0.0.',
  '.0.0.0.0',
]);

Future<(ProviderContainer, StorageService)> _setUp([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = StorageService(await SharedPreferences.getInstance());
  final c = ProviderContainer(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(c.dispose);
  return (c, storage);
}

/// Lets fire-and-forget storage writes complete.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts with the stored best score', () async {
    final (c, _) = await _setUp({'best_score': 500});
    final s = c.read(gameControllerProvider);
    expect(s.bestScore, 500);
    expect(s.startingBest, 500);
  });

  test('every move is auto-saved and restored on next launch', () async {
    final (c, storage) = await _setUp();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.loadState(
      GameState(
        board: Board.empty(),
        tray: [_p('square2', 1), _p('dot', 2), _p('dot', 3)],
      ),
    );
    ctrl.place(0, 2, 2);
    await _flush();

    // A fresh container simulates relaunching the app.
    final relaunched = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(relaunched.dispose);
    final restored = relaunched.read(gameControllerProvider);
    expect(restored.score, 4);
    expect(restored.board.isFilled(2, 2), isTrue);
    expect(restored.tray[0], isNull);
  });

  test('best score is persisted as soon as it is beaten', () async {
    final (c, storage) = await _setUp({'best_score': 2});
    c
        .read(gameControllerProvider.notifier)
        .loadState(
          GameState(
            board: Board.empty(),
            tray: [_p('square2', 1), null, _p('dot', 3)],
            bestScore: 2,
            startingBest: 2,
          ),
        );
    c.read(gameControllerProvider.notifier).place(0, 0, 0);
    await _flush();
    expect(storage.bestScore, 4);
  });

  test('game over is counted once and New Game keeps the best', () async {
    final (c, storage) = await _setUp();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.loadState(
      GameState(
        board: _checkerboard,
        tray: [_p('dot', 1), _p('square2', 2), null],
        score: 90,
        bestScore: 90,
      ),
    );
    ctrl.place(0, 0, 1);
    await _flush();
    expect(c.read(gameControllerProvider).isGameOver, isTrue);
    expect(storage.gameOverCount, 1);

    ctrl.newGame();
    await _flush();
    final s = c.read(gameControllerProvider);
    expect(s.isGameOver, isFalse);
    expect(s.score, 0);
    expect(s.bestScore, 91);
    expect(storage.gameOverCount, 1);
  });

  test('corrupt save falls back to a new game', () async {
    final (c, _) = await _setUp({'saved_game': '{broken'});
    final s = c.read(gameControllerProvider);
    expect(s.board.isEmpty, isTrue);
    expect(s.remainingPieces, hasLength(3));
  });
}
