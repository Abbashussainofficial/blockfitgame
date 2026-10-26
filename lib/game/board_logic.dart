import '../models/board.dart';
import '../models/cell_pos.dart';
import '../models/piece_shape.dart';

/// Rows and columns that are completely filled.
class FullLines {
  const FullLines(this.rows, this.cols);

  final List<int> rows;
  final List<int> cols;

  bool get isEmpty => rows.isEmpty && cols.isEmpty;
  int get count => rows.length + cols.length;
}

/// Pure placement and line-clear rules on a [Board].
abstract final class BoardLogic {
  /// Whether [shape] fits with its top-left corner at ([row], [col]):
  /// every block must be on the board and on an empty cell.
  static bool canPlace(Board board, PieceShape shape, int row, int col) {
    for (final cell in shape.cells) {
      final r = row + cell.row;
      final c = col + cell.col;
      if (!Board.inBounds(r, c) || board.isFilled(r, c)) return false;
    }
    return true;
  }

  /// Board cells [shape] would cover at ([row], [col]). Does not validate.
  static List<CellPos> cellsFor(PieceShape shape, int row, int col) => [
    for (final cell in shape.cells) CellPos(row + cell.row, col + cell.col),
  ];

  /// Places [shape] and returns the new board. Throws [StateError] if the
  /// placement is invalid; call [canPlace] first.
  static Board place(Board board, PieceShape shape, int row, int col) {
    if (!canPlace(board, shape, row, col)) {
      throw StateError('Cannot place ${shape.id} at ($row, $col)');
    }
    return board.withChanges({
      for (final p in cellsFor(shape, row, col))
        Board.indexOf(p.row, p.col): shape.colorIndex,
    });
  }

  static FullLines findFullLines(Board board) {
    final rows = <int>[];
    final cols = <int>[];
    for (var i = 0; i < Board.size; i++) {
      var rowFull = true;
      var colFull = true;
      for (var j = 0; j < Board.size; j++) {
        if (!board.isFilled(i, j)) rowFull = false;
        if (!board.isFilled(j, i)) colFull = false;
      }
      if (rowFull) rows.add(i);
      if (colFull) cols.add(i);
    }
    return FullLines(rows, cols);
  }

  /// Cells covered by [lines], each listed once even where a row and column
  /// cross, mapped to their current colour.
  static Map<CellPos, int> cellsInLines(Board board, FullLines lines) {
    final result = <CellPos, int>{};
    for (final r in lines.rows) {
      for (var c = 0; c < Board.size; c++) {
        result[CellPos(r, c)] = board.colorAt(r, c);
      }
    }
    for (final c in lines.cols) {
      for (var r = 0; r < Board.size; r++) {
        result[CellPos(r, c)] = board.colorAt(r, c);
      }
    }
    return result;
  }

  /// Empties every cell in [lines]. Rows and columns clear simultaneously.
  static Board clearLines(Board board, FullLines lines) {
    if (lines.isEmpty) return board;
    return board.withChanges({
      for (final p in cellsInLines(board, lines).keys)
        Board.indexOf(p.row, p.col): Board.emptyCell,
    });
  }

  /// All top-left anchors where [shape] fits.
  static List<CellPos> validAnchors(Board board, PieceShape shape) => [
    for (var r = 0; r <= Board.size - shape.height; r++)
      for (var c = 0; c <= Board.size - shape.width; c++)
        if (canPlace(board, shape, r, c)) CellPos(r, c),
  ];

  static bool canPlaceAnywhere(Board board, PieceShape shape) {
    for (var r = 0; r <= Board.size - shape.height; r++) {
      for (var c = 0; c <= Board.size - shape.width; c++) {
        if (canPlace(board, shape, r, c)) return true;
      }
    }
    return false;
  }

  /// Empties a centred square of side [size]. Used by the revive booster.
  static Board clearCenter(Board board, int size) {
    final start = (Board.size - size) ~/ 2;
    return board.withChanges({
      for (var r = start; r < start + size; r++)
        for (var c = start; c < start + size; c++)
          Board.indexOf(r, c): Board.emptyCell,
    });
  }
}
