import '../models/board.dart';
import '../models/piece_shape.dart';

/// Fast 64-bit occupancy maths for the piece generator's look-ahead solver.
///
/// Bit `row * 8 + col` is set when that cell is filled. Dart `int` is 64-bit
/// on Android (the VM), so a whole 8x8 board fits in one integer.
abstract final class Bitboard {
  static const int _n = Board.size;

  /// Masks for the 8 rows followed by the 8 columns.
  static final List<int> lineMasks = () {
    final masks = <int>[];
    for (var r = 0; r < _n; r++) {
      var m = 0;
      for (var c = 0; c < _n; c++) {
        m |= 1 << (r * _n + c);
      }
      masks.add(m);
    }
    for (var c = 0; c < _n; c++) {
      var m = 0;
      for (var r = 0; r < _n; r++) {
        m |= 1 << (r * _n + c);
      }
      masks.add(m);
    }
    return List<int>.unmodifiable(masks);
  }();

  static final Map<String, List<int>> _placementCache = {};

  /// Mask of [shape] for every in-bounds anchor (ignores occupancy).
  static List<int> placements(PieceShape shape) =>
      _placementCache.putIfAbsent(shape.id, () {
        final result = <int>[];
        for (var r = 0; r <= _n - shape.height; r++) {
          for (var c = 0; c <= _n - shape.width; c++) {
            var m = 0;
            for (final cell in shape.cells) {
              m |= 1 << ((r + cell.row) * _n + (c + cell.col));
            }
            result.add(m);
          }
        }
        return List<int>.unmodifiable(result);
      });

  /// Removes all full rows and columns at once.
  static int clearFull(int board) {
    var cleared = 0;
    for (final m in lineMasks) {
      if (board & m == m) cleared |= m;
    }
    return board & ~cleared;
  }

  static bool fitsAnywhere(int board, PieceShape shape) {
    for (final m in placements(shape)) {
      if (board & m == 0) return true;
    }
    return false;
  }

  /// True if every shape in [shapes] can be placed one after another in some
  /// order, applying line clears between placements.
  static bool canPlaceAll(int board, List<PieceShape> shapes) {
    final visited = <(int, int)>{};
    bool solve(int b, int remaining) {
      if (remaining == 0) return true;
      // Different orders often reach the same position; skip repeats.
      if (!visited.add((b, remaining))) return false;
      for (var i = 0; i < shapes.length; i++) {
        final bit = 1 << i;
        if (remaining & bit == 0) continue;
        for (final m in placements(shapes[i])) {
          if (b & m != 0) continue;
          if (solve(clearFull(b | m), remaining & ~bit)) return true;
        }
      }
      return false;
    }

    return solve(board, (1 << shapes.length) - 1);
  }
}
