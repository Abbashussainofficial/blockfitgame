import 'cell_pos.dart';

/// Everything the UI needs to animate and score a single successful placement.
class PlaceResult {
  const PlaceResult({
    required this.placedCells,
    required this.clearedRows,
    required this.clearedCols,
    required this.clearedCells,
    required this.placementPoints,
    required this.clearPoints,
    required this.comboStreak,
    required this.newTrayDealt,
    required this.isGameOver,
  });

  /// Board cells covered by the placed piece.
  final List<CellPos> placedCells;

  final List<int> clearedRows;
  final List<int> clearedCols;

  /// Cells removed by line clears, mapped to the colour they had.
  final Map<CellPos, int> clearedCells;

  final int placementPoints;
  final int clearPoints;

  /// Consecutive turns with at least one clear (0 if this turn cleared none).
  final int comboStreak;

  /// True when this placement emptied the tray and 3 new pieces were dealt.
  final bool newTrayDealt;

  final bool isGameOver;

  int get linesCleared => clearedRows.length + clearedCols.length;
  int get totalPoints => placementPoints + clearPoints;

  /// A streak of 2+ consecutive clearing turns is shown as "COMBO xN".
  bool get isCombo => comboStreak >= 2;
}
