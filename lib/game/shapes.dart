import '../models/piece_shape.dart';

/// Number of distinct block colours a theme must provide.
const int kBlockColorCount = 8;

/// Every piece shape in the game. `X` = block, `.` = gap.
///
/// Tiers: 0 = easy (small), 1 = medium, 2 = hard (big / awkward).
/// Colour indices are per family so a shape always looks the same.
final List<PieceShape> kAllShapes = List.unmodifiable(<PieceShape>[
  // Single dot.
  _s('dot', 'dot', ['X'], 0, 0),

  // Straight lines, 2 to 5 long, both orientations.
  _s('line2_h', 'line2', ['XX'], 0, 1),
  _s('line2_v', 'line2', ['X', 'X'], 0, 1),
  _s('line3_h', 'line3', ['XXX'], 1, 2),
  _s('line3_v', 'line3', ['X', 'X', 'X'], 1, 2),
  _s('line4_h', 'line4', ['XXXX'], 2, 3),
  _s('line4_v', 'line4', ['X', 'X', 'X', 'X'], 2, 3),
  _s('line5_h', 'line5', ['XXXXX'], 2, 4),
  _s('line5_v', 'line5', ['X', 'X', 'X', 'X', 'X'], 2, 4),

  // Squares.
  _s('square2', 'square2', ['XX', 'XX'], 1, 5),
  _s('square3', 'square3', ['XXX', 'XXX', 'XXX'], 2, 6),

  // Small corners (3 cells).
  _s('corner2_a', 'corner2', ['X.', 'XX'], 0, 7),
  _s('corner2_b', 'corner2', ['.X', 'XX'], 0, 7),
  _s('corner2_c', 'corner2', ['XX', 'X.'], 0, 7),
  _s('corner2_d', 'corner2', ['XX', '.X'], 0, 7),

  // Big corners (5 cells).
  _s('corner3_a', 'corner3', ['X..', 'X..', 'XXX'], 2, 2),
  _s('corner3_b', 'corner3', ['..X', '..X', 'XXX'], 2, 2),
  _s('corner3_c', 'corner3', ['XXX', 'X..', 'X..'], 2, 2),
  _s('corner3_d', 'corner3', ['XXX', '..X', '..X'], 2, 2),

  // L tetromino, four rotations.
  _s('l_0', 'l', ['X.', 'X.', 'XX'], 1, 3),
  _s('l_90', 'l', ['XXX', 'X..'], 1, 3),
  _s('l_180', 'l', ['XX', '.X', '.X'], 1, 3),
  _s('l_270', 'l', ['..X', 'XXX'], 1, 3),

  // J tetromino, four rotations.
  _s('j_0', 'j', ['.X', '.X', 'XX'], 1, 4),
  _s('j_90', 'j', ['X..', 'XXX'], 1, 4),
  _s('j_180', 'j', ['XX', 'X.', 'X.'], 1, 4),
  _s('j_270', 'j', ['XXX', '..X'], 1, 4),

  // T tetromino, four rotations.
  _s('t_0', 't', ['XXX', '.X.'], 1, 5),
  _s('t_90', 't', ['.X', 'XX', '.X'], 1, 5),
  _s('t_180', 't', ['.X.', 'XXX'], 1, 5),
  _s('t_270', 't', ['X.', 'XX', 'X.'], 1, 5),

  // S and Z tetrominoes.
  _s('s_h', 's', ['.XX', 'XX.'], 1, 6),
  _s('s_v', 's', ['X.', 'XX', '.X'], 1, 6),
  _s('z_h', 'z', ['XX.', '.XX'], 1, 7),
  _s('z_v', 'z', ['.X', 'XX', 'X.'], 1, 7),

  // 2x3 rectangles.
  _s('rect_h', 'rect', ['XXX', 'XXX'], 2, 1),
  _s('rect_v', 'rect', ['XX', 'XX', 'XX'], 2, 1),
]);

final Map<String, PieceShape> _byId = {for (final s in kAllShapes) s.id: s};

/// Looks up a shape by id, or returns `null` if it no longer exists
/// (e.g. an old save file referencing a removed shape).
PieceShape? shapeById(String id) => _byId[id];

PieceShape _s(
  String id,
  String family,
  List<String> pattern,
  int tier,
  int colorIndex,
) => PieceShape.fromPattern(
  id: id,
  family: family,
  pattern: pattern,
  tier: tier,
  colorIndex: colorIndex,
);
