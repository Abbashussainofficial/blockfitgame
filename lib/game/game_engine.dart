import 'dart:math';

import '../core/constants.dart';
import '../models/board.dart';
import '../models/game_state.dart';
import '../models/piece.dart';
import '../models/place_result.dart';
import 'board_logic.dart';
import 'piece_generator.dart';
import 'scoring.dart';

/// Owns the rules of a single game. Pure Dart: no Flutter imports, so it can
/// be unit tested and driven by any state-management layer.
class GameEngine {
  GameEngine({PieceGenerator? generator, int bestScore = 0})
    : _generator = generator ?? PieceGenerator() {
    _state = _freshState(bestScore);
  }

  final PieceGenerator _generator;
  late GameState _state;
  final List<GameState> _history = [];

  GameState get state => _state;

  /// Starts a new game, keeping the given best score.
  void newGame({int? bestScore}) {
    _history.clear();
    _state = _freshState(bestScore ?? _state.bestScore);
  }

  /// Replaces the current game with a restored one (e.g. from auto-save).
  /// Undo history is not saved, so it starts empty.
  void loadState(GameState state) {
    _history.clear();
    var maxId = 0;
    for (final p in state.remainingPieces) {
      maxId = max(maxId, p.id);
    }
    _generator.nextId = maxId + 1;
    _state = state.copyWith(isGameOver: _isGameOver(state.board, state.tray));
  }

  /// Whether tray slot [trayIndex] fits with its top-left at ([row], [col]).
  bool canPlace(int trayIndex, int row, int col) {
    final piece = _pieceAt(trayIndex);
    return piece != null &&
        !_state.isGameOver &&
        BoardLogic.canPlace(_state.board, piece.shape, row, col);
  }

  /// Places tray piece [trayIndex] at ([row], [col]). Returns `null` (and
  /// changes nothing) if the move is invalid.
  PlaceResult? place(int trayIndex, int row, int col) {
    if (!canPlace(trayIndex, row, col)) return null;
    final piece = _pieceAt(trayIndex)!;
    final before = _state;

    final placedBoard = BoardLogic.place(before.board, piece.shape, row, col);
    final lines = BoardLogic.findFullLines(placedBoard);
    final clearedCells = BoardLogic.cellsInLines(placedBoard, lines);
    var board = BoardLogic.clearLines(placedBoard, lines);

    final streak = Scoring.nextComboStreak(before.comboStreak, lines.count);
    final placePts = Scoring.placementPoints(piece.shape.cellCount);
    final clearPts = Scoring.clearPoints(lines.count, streak);
    final score = before.score + placePts + clearPts;

    var tray = List<Piece?>.of(before.tray)..[trayIndex] = null;
    final dealt = tray.every((p) => p == null);
    if (dealt) tray = _generator.generate(board, score: score);

    final gameOver = _isGameOver(board, tray);
    _pushHistory(before);
    _state = before.copyWith(
      board: board,
      tray: List.unmodifiable(tray),
      score: score,
      bestScore: max(before.bestScore, score),
      comboStreak: streak,
      isGameOver: gameOver,
      moveCount: before.moveCount + 1,
    );

    return PlaceResult(
      placedCells: BoardLogic.cellsFor(piece.shape, row, col),
      clearedRows: lines.rows,
      clearedCols: lines.cols,
      clearedCells: clearedCells,
      placementPoints: placePts,
      clearPoints: clearPts,
      comboStreak: streak,
      newTrayDealt: dealt,
      isGameOver: gameOver,
    );
  }

  /// Whether there is a move to take back (regardless of undos left).
  bool get hasHistory => _history.isNotEmpty;

  bool get canUndo => hasHistory && _state.undosLeft > 0;

  /// Reverts the last placement, spending one undo. The best score is kept
  /// so an undo never lowers a record already reached.
  bool undo() {
    if (!canUndo) return false;
    final previous = _history.removeLast();
    _state = previous.copyWith(
      undosLeft: _state.undosLeft - 1,
      bestScore: _state.bestScore,
      reviveUsed: _state.reviveUsed,
    );
    return true;
  }

  /// Grants extra undos (e.g. after a rewarded ad).
  void addUndos(int count) {
    _state = _state.copyWith(undosLeft: _state.undosLeft + count);
  }

  bool get canRevive => _state.isGameOver && !_state.reviveUsed;

  /// Second chance after game over (once per game): empties the board centre
  /// and deals a fresh, playable tray.
  bool revive() {
    if (!canRevive) return false;
    final board = BoardLogic.clearCenter(
      _state.board,
      GameConfig.reviveClearSize,
    );
    final tray = _generator.generate(board, score: _state.score);
    _history.clear();
    _state = _state.copyWith(
      board: board,
      tray: List.unmodifiable(tray),
      comboStreak: 0,
      reviveUsed: true,
      isGameOver: _isGameOver(board, tray),
    );
    return true;
  }

  Piece? _pieceAt(int index) =>
      index >= 0 && index < _state.tray.length ? _state.tray[index] : null;

  GameState _freshState(int bestScore) {
    final board = Board.empty();
    return GameState(
      board: board,
      tray: List.unmodifiable(_generator.generate(board)),
      bestScore: bestScore,
      startingBest: bestScore,
    );
  }

  void _pushHistory(GameState s) {
    _history.add(s);
    if (_history.length > GameConfig.undoHistoryDepth) _history.removeAt(0);
  }

  /// Game over when no remaining tray piece fits anywhere.
  static bool _isGameOver(Board board, List<Piece?> tray) {
    for (final p in tray) {
      if (p != null && BoardLogic.canPlaceAnywhere(board, p.shape)) {
        return false;
      }
    }
    return true;
  }
}
