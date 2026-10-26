import 'dart:convert';
import 'dart:math';

import 'package:block_fit/core/constants.dart';
import 'package:block_fit/game/game_engine.dart';
import 'package:block_fit/game/piece_generator.dart';
import 'package:block_fit/game/shapes.dart';
import 'package:block_fit/models/board.dart';
import 'package:block_fit/models/game_state.dart';
import 'package:block_fit/models/piece.dart';
import 'package:flutter_test/flutter_test.dart';

Piece _p(String shapeId, [int id = 100]) =>
    Piece(id: id, shape: shapeById(shapeId)!);

GameEngine _engineWith(Board board, List<Piece?> tray, {int score = 0}) {
  final engine = GameEngine(generator: PieceGenerator(random: Random(42)));
  engine.loadState(
    GameState(board: board, tray: tray, score: score, bestScore: score),
  );
  return engine;
}

void main() {
  test('new game has an empty board, full tray and zero score', () {
    final engine = GameEngine(bestScore: 250);
    final s = engine.state;
    expect(s.board.isEmpty, isTrue);
    expect(s.remainingPieces, hasLength(GameConfig.traySize));
    expect(s.score, 0);
    expect(s.bestScore, 250);
    expect(s.undosLeft, GameConfig.freeUndos);
    expect(s.isGameOver, isFalse);
  });

  test('valid placement scores cells and empties the tray slot', () {
    final engine = _engineWith(Board.empty(), [
      _p('square2', 1),
      _p('dot', 2),
      _p('dot', 3),
    ]);
    final result = engine.place(0, 3, 3);
    expect(result, isNotNull);
    expect(result!.placementPoints, 4);
    expect(result.linesCleared, 0);
    expect(engine.state.score, 4);
    expect(engine.state.tray[0], isNull);
    expect(engine.state.board.filledCount, 4);
  });

  test('invalid placement changes nothing', () {
    final engine = _engineWith(Board.empty(), [
      _p('square3', 1),
      _p('dot', 2),
      _p('dot', 3),
    ]);
    final before = engine.state;
    expect(engine.place(0, 7, 7), isNull);
    expect(engine.place(5, 0, 0), isNull); // bad tray index
    expect(engine.state, same(before));
  });

  test('placing the last piece deals a new tray', () {
    final engine = _engineWith(Board.empty(), [null, null, _p('dot', 9)]);
    final result = engine.place(2, 0, 0)!;
    expect(result.newTrayDealt, isTrue);
    expect(engine.state.remainingPieces, hasLength(3));
    expect(engine.state.remainingPieces.every((p) => p.id > 9), isTrue);
  });

  test('clearing a row and a column at once scores x2', () {
    final board = Board.fromRows([
      '.0000000',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
    ]);
    final engine = _engineWith(board, [_p('dot'), _p('dot', 2), null]);
    final r = engine.place(0, 0, 0)!;
    expect(r.clearedRows, [0]);
    expect(r.clearedCols, [0]);
    expect(r.clearedCells, hasLength(15));
    expect(r.clearPoints, 40); // 2 lines * 10 * x2, streak 1
    expect(r.totalPoints, 41);
    expect(engine.state.board.isEmpty, isTrue);
  });

  test('combo streak grows on consecutive clears and resets', () {
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
    final engine = _engineWith(board, [
      _p('dot', 1),
      _p('dot', 2),
      _p('dot', 3),
    ]);

    final first = engine.place(0, 0, 0)!;
    expect(first.comboStreak, 1);
    expect(first.isCombo, isFalse);
    expect(first.clearPoints, 10);

    final second = engine.place(1, 1, 0)!;
    expect(second.comboStreak, 2);
    expect(second.isCombo, isTrue);
    expect(second.clearPoints, 20);

    final third = engine.place(2, 5, 5)!;
    expect(third.comboStreak, 0);
    expect(engine.state.comboStreak, 0);
  });

  test('game over when no remaining piece fits', () {
    final full = Board.fromRows([
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
    ]);
    final engine = _engineWith(full, [_p('square2'), _p('line2_h', 2), null]);
    expect(engine.state.isGameOver, isTrue);
    expect(engine.canPlace(0, 0, 1), isFalse);
  });

  test('not game over while at least one piece fits', () {
    final engine = _engineWith(Board.empty(), [_p('square3'), null, null]);
    expect(engine.state.isGameOver, isFalse);
  });

  test('best score updates live and isNewBest flags a record', () {
    final engine = GameEngine(
      generator: PieceGenerator(random: Random(1)),
      bestScore: 3,
    );
    engine.loadState(
      GameState(
        board: Board.empty(),
        tray: [_p('square2'), null, _p('dot', 2)],
        bestScore: 3,
        startingBest: 3,
      ),
    );
    engine.place(0, 0, 0);
    expect(engine.state.score, 4);
    expect(engine.state.bestScore, 4);
    expect(engine.state.isNewBest, isTrue);
  });

  group('undo', () {
    test('restores the previous board, tray and score', () {
      final engine = _engineWith(Board.empty(), [
        _p('square2', 1),
        _p('dot', 2),
        _p('dot', 3),
      ]);
      final before = engine.state;
      engine.place(0, 0, 0);
      expect(engine.undo(), isTrue);
      expect(engine.state.board, before.board);
      expect(engine.state.tray, before.tray);
      expect(engine.state.score, 0);
      expect(engine.state.undosLeft, GameConfig.freeUndos - 1);
    });

    test('is limited and can be topped up', () {
      final engine = _engineWith(Board.empty(), [
        _p('dot', 1),
        _p('dot', 2),
        _p('dot', 3),
      ]);
      expect(engine.canUndo, isFalse); // nothing to undo yet
      for (var i = 0; i < GameConfig.freeUndos; i++) {
        engine.place(0, 0, 0);
        expect(engine.undo(), isTrue);
      }
      engine.place(0, 0, 0);
      expect(engine.canUndo, isFalse);
      expect(engine.undo(), isFalse);
      engine.addUndos(1);
      expect(engine.undo(), isTrue);
    });
  });

  group('revive', () {
    final dead = Board.fromRows([
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
    ]);

    test('works once after game over and continues the game', () {
      final engine = _engineWith(dead, [_p('square3'), null, null], score: 50);
      expect(engine.canRevive, isTrue);
      expect(engine.revive(), isTrue);
      expect(engine.state.isGameOver, isFalse);
      expect(engine.state.reviveUsed, isTrue);
      expect(engine.state.score, 50);
      expect(engine.state.remainingPieces, hasLength(3));
      expect(engine.canRevive, isFalse);
    });

    test('is not available during play', () {
      final engine = _engineWith(Board.empty(), [_p('dot'), null, null]);
      expect(engine.revive(), isFalse);
    });
  });

  test('state survives a JSON round trip', () {
    final engine = GameEngine(generator: PieceGenerator(random: Random(3)));
    engine.place(0, 0, 0);
    final json = jsonEncode(engine.state.toJson());
    final restored = GameState.fromJson(
      jsonDecode(json) as Map<String, Object?>,
    );
    expect(restored.board, engine.state.board);
    expect(restored.tray, engine.state.tray);
    expect(restored.score, engine.state.score);
    expect(restored.undosLeft, engine.state.undosLeft);
  });

  test('corrupt saves throw FormatException', () {
    expect(
      () => GameState.fromJson({'v': 999}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => GameState.fromJson({
        'v': GameState.schemaVersion,
        'board': List.filled(64, -1),
        'tray': [
          {'id': 1, 'shape': 'no_such_shape'},
          null,
          null,
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
