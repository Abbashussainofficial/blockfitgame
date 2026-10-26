import '../core/constants.dart';

/// Scoring rules.
///
/// * Placement: [GameConfig.pointsPerCell] per block.
/// * Clears: [GameConfig.pointsPerLine] per line, times the number of lines
///   cleared together (2 lines = x2, 3 lines = x3, ...).
/// * Combo: consecutive clearing turns build a streak; the clear points are
///   multiplied by the streak (first clear x1, next turn x2, ...).
abstract final class Scoring {
  static int placementPoints(int cellCount) =>
      cellCount * GameConfig.pointsPerCell;

  static int clearPoints(int lines, int comboStreak) {
    if (lines <= 0) return 0;
    final multiLine = lines * GameConfig.pointsPerLine * lines;
    return multiLine * (comboStreak < 1 ? 1 : comboStreak);
  }

  /// Streak after a turn that cleared [lines] lines.
  static int nextComboStreak(int current, int lines) =>
      lines > 0 ? current + 1 : 0;
}
