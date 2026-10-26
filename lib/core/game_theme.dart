import 'package:flutter/material.dart';

import '../game/shapes.dart';

/// Visual palette for the board, pieces and screen background.
///
/// More themes (and unlock rules) are added in a later phase; every theme must
/// supply exactly [kBlockColorCount] block colours (checked by unit tests).
class GameTheme {
  const GameTheme({
    required this.id,
    required this.name,
    required this.brightness,
    required this.backgroundGradient,
    required this.boardColor,
    required this.emptyCellColor,
    required this.blockColors,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.ghostValid,
    required this.ghostInvalid,
    this.unlockScore = 0,
  });

  final String id;
  final String name;
  final Brightness brightness;
  final List<Color> backgroundGradient;
  final Color boardColor;
  final Color emptyCellColor;
  final List<Color> blockColors;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color ghostValid;
  final Color ghostInvalid;

  /// Best score needed to unlock this theme (0 = always available).
  final int unlockScore;

  Color blockColor(int index) => blockColors[index % blockColors.length];

  static const GameTheme classicDark = GameTheme(
    id: 'classic_dark',
    name: 'Classic Dark',
    brightness: Brightness.dark,
    backgroundGradient: [Color(0xFF1B2138), Color(0xFF0E1222)],
    boardColor: Color(0xFF151A2E),
    emptyCellColor: Color(0xFF232A45),
    blockColors: [
      Color(0xFFFFC93C), // amber
      Color(0xFF4FC3F7), // sky
      Color(0xFFFF7A59), // coral
      Color(0xFF7C4DFF), // violet
      Color(0xFF26D0A8), // mint
      Color(0xFFFF5C8A), // pink
      Color(0xFF5C7CFA), // indigo
      Color(0xFF9CDB43), // lime
    ],
    textPrimary: Color(0xFFF4F6FF),
    textSecondary: Color(0xFF9AA3C7),
    accent: Color(0xFFFFC93C),
    ghostValid: Color(0xFF3DDC84),
    ghostInvalid: Color(0xFFFF4D4F),
  );

  static const GameTheme ocean = GameTheme(
    id: 'ocean',
    name: 'Ocean',
    brightness: Brightness.dark,
    backgroundGradient: [Color(0xFF0B3C5D), Color(0xFF041C2E)],
    boardColor: Color(0xFF06283F),
    emptyCellColor: Color(0xFF0E3A57),
    blockColors: [
      Color(0xFF4DD0E1),
      Color(0xFF29B6F6),
      Color(0xFF26A69A),
      Color(0xFF7986CB),
      Color(0xFF80DEEA),
      Color(0xFFFFB74D),
      Color(0xFF5C6BC0),
      Color(0xFFA5D6A7),
    ],
    textPrimary: Color(0xFFE6F7FF),
    textSecondary: Color(0xFF8FB8CF),
    accent: Color(0xFF4DD0E1),
    ghostValid: Color(0xFF69F0AE),
    ghostInvalid: Color(0xFFFF5252),
  );

  /// Light, warm theme.
  static const GameTheme sunset = GameTheme(
    id: 'sunset',
    name: 'Sunset',
    brightness: Brightness.light,
    backgroundGradient: [Color(0xFFFFE3C2), Color(0xFFFFB8A1)],
    boardColor: Color(0xFFFFF4EA),
    emptyCellColor: Color(0xFFF6DCCB),
    blockColors: [
      Color(0xFFFF8A3D),
      Color(0xFFE94F64),
      Color(0xFFFFC542),
      Color(0xFF9B5DE5),
      Color(0xFFF15BB5),
      Color(0xFF00BBF9),
      Color(0xFFFF6F59),
      Color(0xFF43AA8B),
    ],
    textPrimary: Color(0xFF4A2C2A),
    textSecondary: Color(0xFF8C5E55),
    accent: Color(0xFFE94F64),
    ghostValid: Color(0xFF2EAD6B),
    ghostInvalid: Color(0xFFD7263D),
    unlockScore: 300,
  );

  /// Light, natural theme.
  static const GameTheme forest = GameTheme(
    id: 'forest',
    name: 'Forest',
    brightness: Brightness.light,
    backgroundGradient: [Color(0xFFE3F1D9), Color(0xFFB9D8A8)],
    boardColor: Color(0xFFF4FAEF),
    emptyCellColor: Color(0xFFD7E8CC),
    blockColors: [
      Color(0xFF4C9A2A),
      Color(0xFF8BC34A),
      Color(0xFFD4A017),
      Color(0xFF8D6E63),
      Color(0xFF2E7D6B),
      Color(0xFFE07A5F),
      Color(0xFF5B8E7D),
      Color(0xFFB5A642),
    ],
    textPrimary: Color(0xFF233A1E),
    textSecondary: Color(0xFF5E7A55),
    accent: Color(0xFF4C9A2A),
    ghostValid: Color(0xFF2E9E4F),
    ghostInvalid: Color(0xFFC62828),
    unlockScore: 1000,
  );

  static const GameTheme neon = GameTheme(
    id: 'neon',
    name: 'Neon',
    brightness: Brightness.dark,
    backgroundGradient: [Color(0xFF14002B), Color(0xFF000000)],
    boardColor: Color(0xFF0A0014),
    emptyCellColor: Color(0xFF1C0B33),
    blockColors: [
      Color(0xFFFF00E5),
      Color(0xFF00F0FF),
      Color(0xFF39FF14),
      Color(0xFFFFF01F),
      Color(0xFFFF3131),
      Color(0xFF9D00FF),
      Color(0xFF00FF9F),
      Color(0xFFFF8C00),
    ],
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB39DDB),
    accent: Color(0xFF00F0FF),
    ghostValid: Color(0xFF39FF14),
    ghostInvalid: Color(0xFFFF3131),
    unlockScore: 2500,
  );

  /// Bundled app font (Nunito, a Google Font, shipped in assets/fonts so the
  /// app works fully offline).
  static const String fontFamily = 'Nunito';

  /// Every theme, in display order.
  static const List<GameTheme> all = [classicDark, ocean, sunset, forest, neon];

  static GameTheme byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => classicDark);

  bool isUnlocked(int bestScore) => bestScore >= unlockScore;

  /// Material theme for dialogs, switches and buttons on non-game screens.
  ThemeData toMaterial() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: boardColor,
      primary: accent,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundGradient.last,
      dialogTheme: DialogThemeData(backgroundColor: boardColor),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(bodyColor: textPrimary, displayColor: textPrimary),
    );
  }
}
