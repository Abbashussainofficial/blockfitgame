import 'dart:math';

import 'package:block_fit/game/bitboard.dart';
import 'package:block_fit/game/board_logic.dart';
import 'package:block_fit/game/piece_generator.dart';
import 'package:block_fit/game/shapes.dart';
import 'package:block_fit/models/board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every other cell filled with no line close to complete: only dots fit.
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

void main() {
  group('shape catalog', () {
    test('has 20+ shapes with unique ids', () {
      expect(kAllShapes.length, greaterThanOrEqualTo(20));
      expect(kAllShapes.map((s) => s.id).toSet(), hasLength(kAllShapes.length));
    });

    test('shapes are normalised and use valid colours', () {
      for (final s in kAllShapes) {
        expect(s.cells.any((c) => c.row == 0), isTrue, reason: s.id);
        expect(s.cells.any((c) => c.col == 0), isTrue, reason: s.id);
        expect(s.colorIndex, inInclusiveRange(0, kBlockColorCount - 1));
        expect(s.width, lessThanOrEqualTo(Board.size));
        expect(s.height, lessThanOrEqualTo(Board.size));
      }
    });

    test('includes the required families', () {
      final families = kAllShapes.map((s) => s.family).toSet();
      for (final f in [
        'dot', 'line2', 'line3', 'line4', 'line5', 'square2', 'square3', //
        'l', 'j', 't', 's', 'z', 'corner2', 'corner3',
      ]) {
        expect(families, contains(f));
      }
    });
  });

  group('bitboard', () {
    test('placement counts match the slow path', () {
      for (final s in kAllShapes) {
        expect(
          Bitboard.placements(s).length,
          BoardLogic.validAnchors(Board.empty(), s).length,
          reason: s.id,
        );
      }
    });

    test('clearFull removes completed rows and columns', () {
      final b = Board.fromRows([
        '00000000',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
        '0......0',
      ]);
      final expected = Board.fromRows([
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '.......0',
      ]);
      expect(Bitboard.clearFull(b.mask), expected.mask);
    });

    test('canPlaceAll uses clears between placements', () {
      // Row 0 needs exactly a line4 to clear; then square3 fits top-right.
      final b = Board.fromRows([
        '....0000',
        '00000...',
        '00000...',
        '00000000',
        '00000000',
        '00000000',
        '00000000',
        '00000000',
      ]);
      final line4 = shapeById('line4_h')!;
      final square3 = shapeById('square3')!;
      expect(Bitboard.fitsAnywhere(b.mask, square3), isFalse);
      expect(Bitboard.canPlaceAll(b.mask, [square3, line4]), isTrue);
    });

    test('canPlaceAll is false when the board cannot take the set', () {
      final square3 = shapeById('square3')!;
      expect(
        Bitboard.canPlaceAll(_checkerboard.mask, [square3, square3, square3]),
        isFalse,
      );
    });
  });

  group('generator', () {
    test('deals three playable pieces on an empty board', () {
      final gen = PieceGenerator(random: Random(1));
      for (var i = 0; i < 50; i++) {
        final set = gen.generate(Board.empty());
        expect(set, hasLength(3));
        expect(Bitboard.canPlaceAll(0, [for (final p in set) p.shape]), isTrue);
      }
    });

    test('piece ids are unique', () {
      final gen = PieceGenerator(random: Random(2));
      final ids = <int>{};
      for (var i = 0; i < 20; i++) {
        for (final p in gen.generate(Board.empty())) {
          expect(ids.add(p.id), isTrue);
        }
      }
    });

    test('never deals a dead hand when a playable one exists', () {
      // Only single dots fit on the checkerboard.
      for (var seed = 0; seed < 20; seed++) {
        final gen = PieceGenerator(random: Random(seed));
        final set = gen.generate(_checkerboard, score: 3000);
        for (final p in set) {
          expect(p.shape.id, 'dot', reason: 'seed $seed');
        }
      }
    });

    test('difficulty rises with score and makes hard shapes likelier', () {
      expect(PieceGenerator.difficultyFor(0), 0);
      expect(PieceGenerator.difficultyFor(100000), 1);
      expect(
        PieceGenerator.difficultyFor(1000),
        lessThan(PieceGenerator.difficultyFor(2000)),
      );

      final gen = PieceGenerator();
      final hard = shapeById('square3')!;
      final easy = shapeById('dot')!;
      expect(gen.weightFor(hard, 1), greaterThan(gen.weightFor(hard, 0)));
      expect(gen.weightFor(easy, 1), lessThan(gen.weightFor(easy, 0)));
    });

    test('hard shapes are dealt more often at high scores', () {
      int hardCount(int score) {
        final gen = PieceGenerator(random: Random(7));
        var n = 0;
        for (var i = 0; i < 300; i++) {
          n += gen
              .generate(Board.empty(), score: score)
              .where((p) => p.shape.tier == 2)
              .length;
        }
        return n;
      }

      expect(hardCount(10000), greaterThan(hardCount(0)));
    });
  });
}
