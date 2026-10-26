/// An immutable (row, column) coordinate on the board or inside a piece.
class CellPos {
  const CellPos(this.row, this.col);

  final int row;
  final int col;

  CellPos operator +(CellPos other) =>
      CellPos(row + other.row, col + other.col);

  @override
  bool operator ==(Object other) =>
      other is CellPos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row, $col)';
}
