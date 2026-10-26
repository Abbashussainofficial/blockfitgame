import 'package:block_fit/game/game_engine.dart';
import 'package:block_fit/models/game_state.dart';
import 'package:block_fit/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StorageService> _storage([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return StorageService(await SharedPreferences.getInstance());
}

void main() {
  test('best score defaults to 0 and only ever increases', () async {
    final s = await _storage();
    expect(s.bestScore, 0);
    await s.submitScore(120);
    expect(s.bestScore, 120);
    await s.submitScore(80);
    expect(s.bestScore, 120);
  });

  test('saved game round trips and can be cleared', () async {
    final s = await _storage();
    expect(s.loadGame(), isNull);
    final engine = GameEngine()..place(0, 0, 0);
    await s.saveGame(engine.state);
    expect(s.hasSavedGame, isTrue);

    final loaded = s.loadGame()!;
    expect(loaded.board, engine.state.board);
    expect(loaded.score, engine.state.score);

    await s.clearGame();
    expect(s.hasSavedGame, isFalse);
  });

  test('corrupt saves are discarded instead of crashing', () async {
    for (final bad in ['not json', '[1,2,3]', '{"v": 999}']) {
      final s = await _storage({'saved_game': bad});
      expect(s.loadGame(), isNull, reason: bad);
      expect(s.hasSavedGame, isFalse, reason: bad);
    }
  });

  test('wrong value types fall back to defaults', () async {
    final s = await _storage({'best_score': 'oops', 'game_over_count': 'x'});
    expect(s.bestScore, 0);
    expect(s.gameOverCount, 0);
  });

  test('game over counter increments', () async {
    final s = await _storage();
    await s.incrementGameOverCount();
    await s.incrementGameOverCount();
    expect(s.gameOverCount, 2);
  });

  test('schema version is stored with the game', () async {
    final s = await _storage();
    await s.saveGame(GameEngine().state);
    expect(s.loadGame(), isA<GameState>());
  });
}
