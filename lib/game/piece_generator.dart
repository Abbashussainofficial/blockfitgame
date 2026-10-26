import 'dart:math';

import '../core/constants.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/piece_shape.dart';
import 'bitboard.dart';
import 'shapes.dart';

/// Deals tray pieces with weighted randomness and a fairness guarantee.
///
/// 1. Draw random sets (weighted by difficulty) and keep the first set that
///    can be placed completely, in some order, on the current board.
/// 2. If none is found, draw only from shapes that fit right now, so the
///    player is never dealt a dead hand while a playable one exists.
/// 3. Only when no shape fits at all is an unplayable set returned
///    (the engine then ends the game).
class PieceGenerator {
  PieceGenerator({
    Random? random,
    List<PieceShape>? shapes,
    this.attempts = GameConfig.generatorAttempts,
    int firstId = 1,
  }) : _random = random ?? Random(),
       _shapes = shapes ?? kAllShapes,
       _nextId = firstId {
    for (final s in _shapes) {
      _familySize[s.family] = (_familySize[s.family] ?? 0) + 1;
    }
  }

  final Random _random;
  final List<PieceShape> _shapes;
  final int attempts;
  final Map<String, int> _familySize = {};
  int _nextId;

  /// Next piece id to hand out. Restored from saves so ids stay unique.
  int get nextId => _nextId;
  set nextId(int value) => _nextId = max(_nextId, value);

  /// 0.0 at the start, rising linearly to 1.0 at
  /// [GameConfig.difficultyMaxScore].
  static double difficultyFor(int score) =>
      (score / GameConfig.difficultyMaxScore).clamp(0.0, 1.0);

  /// Relative chance of dealing [shape] at [difficulty]. Easy shapes become
  /// rarer and hard shapes more common as the score rises. Weights are split
  /// across a family so, e.g., 4 L rotations together count as one "L".
  double weightFor(PieceShape shape, double difficulty) {
    final tierWeight = switch (shape.tier) {
      0 => _lerp(1.0, 0.45, difficulty),
      1 => 1.0,
      _ => _lerp(0.3, 1.1, difficulty),
    };
    return tierWeight / (_familySize[shape.family] ?? 1);
  }

  /// Deals a full tray for [board] at the given [score].
  List<Piece> generate(Board board, {int score = 0}) {
    final difficulty = difficultyFor(score);
    final mask = board.mask;

    // Step 1: any shape, but the whole set must be placeable.
    for (var i = 0; i < attempts; i++) {
      final set = _drawSet(_shapes, difficulty);
      if (Bitboard.canPlaceAll(mask, set)) return _toPieces(set);
    }

    // Step 2: restrict to shapes that individually fit right now.
    final fitting = [
      for (final s in _shapes)
        if (Bitboard.fitsAnywhere(mask, s)) s,
    ];
    if (fitting.isEmpty) return _toPieces(_drawSet(_shapes, difficulty));

    var set = _drawSet(fitting, difficulty);
    for (var i = 0; i < attempts; i++) {
      if (Bitboard.canPlaceAll(mask, set)) break;
      set = _drawSet(fitting, difficulty);
    }
    return _toPieces(set);
  }

  /// Makes a single piece (used when restoring or for boosters).
  Piece makePiece(PieceShape shape) => Piece(id: _nextId++, shape: shape);

  List<PieceShape> _drawSet(List<PieceShape> pool, double difficulty) => [
    for (var i = 0; i < GameConfig.traySize; i++) _pick(pool, difficulty),
  ];

  PieceShape _pick(List<PieceShape> pool, double difficulty) {
    var total = 0.0;
    for (final s in pool) {
      total += weightFor(s, difficulty);
    }
    var roll = _random.nextDouble() * total;
    for (final s in pool) {
      roll -= weightFor(s, difficulty);
      if (roll <= 0) return s;
    }
    return pool.last;
  }

  List<Piece> _toPieces(List<PieceShape> shapes) => [
    for (final s in shapes) makePiece(s),
  ];

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
