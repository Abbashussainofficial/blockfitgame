import 'cell_pos.dart';

/// A fixed block arrangement (one orientation). Rotations are separate shapes.
class PieceShape {
  PieceShape._({
    required this.id,
    required this.family,
    required this.cells,
    required this.tier,
    required this.colorIndex,
    required this.width,
    required this.height,
  });

  /// Builds a shape from rows of text where `X` marks a block, e.g.
  /// `['X.', 'XX']`. Cells are normalised so the top-left block row/col is 0.
  factory PieceShape.fromPattern({
    required String id,
    required String family,
    required List<String> pattern,
    required int tier,
    required int colorIndex,
  }) {
    final cells = <CellPos>[];
    for (var r = 0; r < pattern.length; r++) {
      for (var c = 0; c < pattern[r].length; c++) {
        if (pattern[r][c] == 'X') cells.add(CellPos(r, c));
      }
    }
    if (cells.isEmpty) {
      throw ArgumentError.value(pattern, 'pattern', 'Shape "$id" is empty');
    }
    final minR = cells.map((p) => p.row).reduce((a, b) => a < b ? a : b);
    final minC = cells.map((p) => p.col).reduce((a, b) => a < b ? a : b);
    final normalised = [
      for (final p in cells) CellPos(p.row - minR, p.col - minC),
    ];
    final maxR = normalised.map((p) => p.row).reduce((a, b) => a > b ? a : b);
    final maxC = normalised.map((p) => p.col).reduce((a, b) => a > b ? a : b);
    return PieceShape._(
      id: id,
      family: family,
      cells: List.unmodifiable(normalised),
      tier: tier,
      colorIndex: colorIndex,
      width: maxC + 1,
      height: maxR + 1,
    );
  }

  /// Stable identifier used for saving and restoring games.
  final String id;

  /// Shapes that are rotations of each other share a family. Generation
  /// weights are split across a family so big families are not over-dealt.
  final String family;

  /// Block offsets relative to the shape's top-left corner.
  final List<CellPos> cells;

  /// 0 = easy, 1 = medium, 2 = hard. Drives difficulty-based weighting.
  final int tier;

  /// Index into the active theme's block palette.
  final int colorIndex;

  final int width;
  final int height;

  int get cellCount => cells.length;

  @override
  String toString() => 'PieceShape($id)';
}
