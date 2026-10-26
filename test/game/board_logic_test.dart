import 'package:block_fit/game/board_logic.dart';
import 'package:block_fit/game/shapes.dart';
import 'package:block_fit/models/board.dart';
import 'package:block_fit/models/cell_pos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dot = shapeById('dot')!;
  final line3 = shapeById('line3_h')!;
  final square3 = shapeById('square3')!;
  final cornerA = shapeById('corner2_a')!; // X. / XX

  group('placement', () {
    test('fits on an empty board inside the bounds', () {
      final b = Board.empty();
      expect(BoardLogic.canPlace(b, square3, 0, 0), isTrue);
      expect(BoardLogic.canPlace(b, square3, 5, 5), isTrue);
    });

    test('rejects placements that go off the board', () {
      final b = Board.empty();
      expect(BoardLogic.canPlace(b, square3, 6, 0), isFalse);
      expect(BoardLogic.canPlace(b, line3, 0, 6), isFalse);
      expect(BoardLogic.canPlace(b, dot, -1, 0), isFalse);
    });

    test('rejects overlap but allows filling gaps in a shape', () {
      final b = Board.fromRows([
        '.0......',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      // corner2_a leaves (0,1) empty, so it fits around the filled cell.
      expect(BoardLogic.canPlace(b, cornerA, 0, 0), isTrue);
      expect(BoardLogic.canPlace(b, line3, 0, 0), isFalse);
    });

    test('place writes the shape colour and does not mutate input', () {
      final b = Board.empty();
      final next = BoardLogic.place(b, line3, 2, 3);
      expect(b.isEmpty, isTrue);
      expect(next.filledCount, 3);
      for (var c = 3; c < 6; c++) {
        expect(next.colorAt(2, c), line3.colorIndex);
      }
    });

    test('place throws on invalid moves', () {
      expect(
        () => BoardLogic.place(Board.empty(), square3, 7, 7),
        throwsStateError,
      );
    });

    test('validAnchors counts every legal position', () {
      expect(BoardLogic.validAnchors(Board.empty(), dot), hasLength(64));
      expect(BoardLogic.validAnchors(Board.empty(), square3), hasLength(36));
    });
  });

  group('line clears', () {
    test('detects a full row and a full column', () {
      final b = Board.fromRows([
        '00000000',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
      ]);
      final lines = BoardLogic.findFullLines(b);
      expect(lines.rows, [0]);
      expect(lines.cols, [0]);
      expect(lines.count, 2);
    });

    test('crossing row and column cells are counted once', () {
      final b = Board.fromRows([
        '00000000',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
        '0.......',
      ]);
      final cells = BoardLogic.cellsInLines(b, BoardLogic.findFullLines(b));
      expect(cells, hasLength(15));
      expect(cells.containsKey(const CellPos(0, 0)), isTrue);
    });

    test('clears multiple lines together and keeps other blocks', () {
      final b = Board.fromRows([
        '11111111',
        '22222222',
        '3.......',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final lines = BoardLogic.findFullLines(b);
      expect(lines.rows, [0, 1]);
      final cleared = BoardLogic.clearLines(b, lines);
      expect(cleared.filledCount, 1);
      expect(cleared.colorAt(2, 0), 3);
    });

    test('no full lines on a partially filled board', () {
      final b = Board.fromRows([
        '0000000.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '.......0',
      ]);
      expect(BoardLogic.findFullLines(b).isEmpty, isTrue);
    });
  });

  test('clearCenter empties the middle square only', () {
    final full = Board.fromCells(List.filled(Board.cellCount, 0));
    final b = BoardLogic.clearCenter(full, 4);
    expect(b.filledCount, 64 - 16);
    expect(b.isFilled(2, 2), isFalse);
    expect(b.isFilled(5, 5), isFalse);
    expect(b.isFilled(1, 1), isTrue);
    expect(b.isFilled(6, 6), isTrue);
  });

  test('board JSON round trip', () {
    final b = BoardLogic.place(Board.empty(), square3, 1, 1);
    expect(Board.fromJson(b.toJson()), b);
    expect(() => Board.fromJson([1, 2]), throwsArgumentError);
  });
}
