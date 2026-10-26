/// Game-wide tunable constants. Keep magic numbers here, not in logic or UI.
abstract final class GameConfig {
  /// Width and height of the square board. The bitboard solver relies on
  /// `gridSize * gridSize <= 64`, so this must stay at 8 or below.
  static const int gridSize = 8;

  /// Number of pieces offered in the tray at once.
  static const int traySize = 3;

  /// Points awarded for every block cell placed on the board.
  static const int pointsPerCell = 1;

  /// Base points for every cleared row or column, before multipliers.
  static const int pointsPerLine = 10;

  /// Free undos available at the start of each game.
  static const int freeUndos = 2;

  /// How many previous states are remembered for undo.
  static const int undoHistoryDepth = 10;

  /// Score at which piece difficulty reaches its maximum.
  static const int difficultyMaxScore = 4000;

  /// Random sets tried before falling back to "pieces that individually fit".
  static const int generatorAttempts = 24;

  /// Side length of the square area emptied in the board centre on revive.
  static const int reviveClearSize = 4;
}

/// Layout and feel of the game UI.
abstract final class UiConfig {
  /// Gap around the board grid, as a fraction of the board side.
  static const double boardPaddingRatio = 0.025;

  /// Gap between cells, as a fraction of one cell.
  static const double cellGapRatio = 0.08;

  /// Corner radius of a block, as a fraction of its side.
  static const double blockRadiusRatio = 0.2;

  /// How far (in board cells) the dragged piece floats above the finger.
  static const double dragLiftCells = 1.6;

  /// Lifted piece is drawn slightly smaller and translucent so the ghost's
  /// green / red outline stays visible around it.
  static const double dragScale = 0.9;
  static const double dragOpacity = 0.9;

  /// Max distance (in cells) the ghost may snap to reach a valid spot.
  static const double snapRadiusCells = 0.9;

  /// Tray slot height, in board cells.
  static const double trayHeightCells = 2.9;

  /// A tray slot must fit a 5-long line, plus this much breathing room.
  static const double trayPieceMaxCells = 5.6;

  /// Opacity of tray pieces that cannot be placed anywhere.
  static const double unplaceableOpacity = 0.35;

  static const Duration liftDuration = Duration(milliseconds: 110);
  static const Duration returnDuration = Duration(milliseconds: 220);
  static const Duration clearDuration = Duration(milliseconds: 420);
  static const Duration placeDuration = Duration(milliseconds: 260);
  static const Duration scoreCountDuration = Duration(milliseconds: 450);
  static const Duration pointsPopupDuration = Duration(milliseconds: 800);
  static const Duration trayPopDuration = Duration(milliseconds: 320);

  /// Delay between each tray piece popping in on a new deal.
  static const Duration trayPopStagger = Duration(milliseconds: 70);

  /// Pause after the final move before the Game Over screen appears.
  static const Duration gameOverDelay = Duration(milliseconds: 750);
  static const Duration gameOverFade = Duration(milliseconds: 350);

  /// How long "COMBO xN!" / "NEW BEST!" stays on screen.
  static const Duration bannerDuration = Duration(milliseconds: 1200);
}
