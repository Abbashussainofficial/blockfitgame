import '../core/constants.dart';

/// Immutable grid of cells. Each cell holds a colour index, or [emptyCell].
///
/// Game rules live in `lib/game/board_logic.dart`; this class is only data.
class Board {
  Board._(List<int> cells) : _cells = List.unmodifiable(cells);

  factory Board.empty() => Board._(List.filled(cellCount, emptyCell));

  /// Creates a board from a flat, row-major list of colour indices.
  factory Board.fromCells(List<int> cells) {
    if (cells.length != cellCount) {
      throw ArgumentError.value(
        cells.length,
        'cells.length',
        'Expected $cellCount cells',
      );
    }
    return Board._(cells);
  }

  /// Parses rows of text for tests and debugging: `.` is empty, a digit is a
  /// colour index and any other character is colour 0.
  factory Board.fromRows(List<String> rows) {
    if (rows.length != size || rows.any((r) => r.length != size)) {
      throw ArgumentError('Board.fromRows needs $size rows of $size chars');
    }
    final cells = <int>[];
    for (final row in rows) {
      for (final ch in row.split('')) {
        cells.add(ch == '.' ? emptyCell : (int.tryParse(ch) ?? 0));
      }
    }
    return Board._(cells);
  }

  factory Board.fromJson(Object? json) {
    if (json is! List) throw const FormatException('Board JSON must be a list');
    return Board.fromCells([for (final v in json) (v as num).toInt()]);
  }

  static const int size = GameConfig.gridSize;
  static const int cellCount = size * size;
  static const int emptyCell = -1;

  final List<int> _cells;

  /// Row-major cell list (read-only).
  List<int> get cells => _cells;

  static int indexOf(int row, int col) => row * size + col;

  static bool inBounds(int row, int col) =>
      row >= 0 && row < size && col >= 0 && col < size;

  int colorAt(int row, int col) => _cells[indexOf(row, col)];

  bool isFilled(int row, int col) => _cells[indexOf(row, col)] != emptyCell;

  int get filledCount => _cells.where((c) => c != emptyCell).length;

  bool get isEmpty => filledCount == 0;

  /// Occupancy as a 64-bit mask (bit `row * size + col`). Used by the solver.
  late final int mask = () {
    var m = 0;
    for (var i = 0; i < cellCount; i++) {
      if (_cells[i] != emptyCell) m |= 1 << i;
    }
    return m;
  }();

  /// Returns a new board with the given `index -> colour` changes applied.
  Board withChanges(Map<int, int> changes) {
    final next = List<int>.of(_cells);
    changes.forEach((i, color) => next[i] = color);
    return Board._(next);
  }

  List<int> toJson() => List.of(_cells);

  @override
  bool operator ==(Object other) {
    if (other is! Board) return false;
    for (var i = 0; i < cellCount; i++) {
      if (_cells[i] != other._cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_cells);

  @override
  String toString() {
    final sb = StringBuffer();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = colorAt(r, c);
        sb.write(v == emptyCell ? '.' : '$v');
      }
      if (r < size - 1) sb.writeln();
    }
    return sb.toString();
  }
}
