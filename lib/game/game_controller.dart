import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../models/place_result.dart';
import '../services/storage_service.dart';
import 'game_engine.dart';

/// Riverpod bridge to [GameEngine]. UI reads [GameState] and calls these
/// methods; all rules stay in the engine.
///
/// Every change is auto-saved, so a game survives the app being killed. The
/// UI additionally calls [persist] when the app goes to the background.
class GameController extends Notifier<GameState> {
  late GameEngine _engine;
  late StorageService _storage;

  @override
  GameState build() {
    _storage = ref.read(storageServiceProvider);
    final best = _storage.bestScore;
    _engine = GameEngine(bestScore: best);
    final saved = _storage.loadGame();
    if (saved != null) {
      _engine.loadState(saved.copyWith(bestScore: max(saved.bestScore, best)));
    }
    return _engine.state;
  }

  bool get hasHistory => _engine.hasHistory;
  bool get canUndo => _engine.canUndo;
  bool get canRevive => _engine.canRevive;

  bool canPlace(int trayIndex, int row, int col) =>
      _engine.canPlace(trayIndex, row, col);

  /// Returns the placement outcome, or `null` if the move was rejected.
  PlaceResult? place(int trayIndex, int row, int col) {
    final result = _engine.place(trayIndex, row, col);
    if (result != null) _commit();
    return result;
  }

  bool undo() => _commitIf(_engine.undo());

  bool revive() => _commitIf(_engine.revive());

  void addUndos(int count) {
    _engine.addUndos(count);
    _commit();
  }

  void newGame() {
    _engine.newGame(
      bestScore: max(_engine.state.bestScore, _storage.bestScore),
    );
    _commit();
  }

  void loadState(GameState saved) {
    _engine.loadState(saved);
    _commit();
  }

  /// Writes the current game to disk now (e.g. on app pause).
  Future<void> persist() => _storage.saveGame(state);

  bool _commitIf(bool changed) {
    if (changed) _commit();
    return changed;
  }

  void _commit() {
    final next = _engine.state;
    final endedNow = next.isGameOver && !state.isGameOver;
    state = next;
    unawaited(_storage.saveGame(next));
    unawaited(_storage.submitScore(next.bestScore));
    if (endedNow) unawaited(_storage.incrementGameOverCount());
  }
}

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);
