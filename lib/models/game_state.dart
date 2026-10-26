import '../core/constants.dart';
import '../game/shapes.dart';
import 'board.dart';
import 'piece.dart';

/// Immutable snapshot of a game in progress. Serialisable for auto-save.
class GameState {
  const GameState({
    required this.board,
    required this.tray,
    this.score = 0,
    this.bestScore = 0,
    this.startingBest = 0,
    this.comboStreak = 0,
    this.undosLeft = GameConfig.freeUndos,
    this.reviveUsed = false,
    this.isGameOver = false,
    this.moveCount = 0,
  });

  /// Bump when the JSON layout changes incompatibly.
  static const int schemaVersion = 1;

  final Board board;

  /// Always [GameConfig.traySize] slots; `null` means that slot was used.
  final List<Piece?> tray;

  final int score;

  /// Best score ever, kept up to date live as [score] grows.
  final int bestScore;

  /// Best score when this game began; beating it shows "New Best!".
  final int startingBest;

  final int comboStreak;
  final int undosLeft;
  final bool reviveUsed;
  final bool isGameOver;
  final int moveCount;

  bool get isNewBest => score > 0 && score > startingBest;

  List<Piece> get remainingPieces => [for (final p in tray) ?p];

  GameState copyWith({
    Board? board,
    List<Piece?>? tray,
    int? score,
    int? bestScore,
    int? startingBest,
    int? comboStreak,
    int? undosLeft,
    bool? reviveUsed,
    bool? isGameOver,
    int? moveCount,
  }) => GameState(
    board: board ?? this.board,
    tray: tray ?? this.tray,
    score: score ?? this.score,
    bestScore: bestScore ?? this.bestScore,
    startingBest: startingBest ?? this.startingBest,
    comboStreak: comboStreak ?? this.comboStreak,
    undosLeft: undosLeft ?? this.undosLeft,
    reviveUsed: reviveUsed ?? this.reviveUsed,
    isGameOver: isGameOver ?? this.isGameOver,
    moveCount: moveCount ?? this.moveCount,
  );

  Map<String, Object?> toJson() => {
    'v': schemaVersion,
    'board': board.toJson(),
    'tray': [for (final p in tray) p?.toJson()],
    'score': score,
    'bestScore': bestScore,
    'startingBest': startingBest,
    'comboStreak': comboStreak,
    'undosLeft': undosLeft,
    'reviveUsed': reviveUsed,
    'isGameOver': isGameOver,
    'moveCount': moveCount,
  };

  /// Restores a saved game. Throws [FormatException] on corrupt or
  /// incompatible data so callers can discard the save safely.
  factory GameState.fromJson(Map<String, Object?> json) {
    if (json['v'] != schemaVersion) {
      throw FormatException('Unsupported save version: ${json['v']}');
    }
    final rawTray = json['tray'];
    if (rawTray is! List || rawTray.length != GameConfig.traySize) {
      throw const FormatException('Invalid tray');
    }
    final tray = <Piece?>[
      for (final entry in rawTray)
        if (entry == null) null else _pieceFromJson(entry),
    ];
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return GameState(
      board: Board.fromJson(json['board']),
      tray: List.unmodifiable(tray),
      score: readInt('score'),
      bestScore: readInt('bestScore'),
      startingBest: readInt('startingBest'),
      comboStreak: readInt('comboStreak'),
      undosLeft: readInt('undosLeft'),
      reviveUsed: json['reviveUsed'] == true,
      isGameOver: json['isGameOver'] == true,
      moveCount: readInt('moveCount'),
    );
  }

  static Piece _pieceFromJson(Object entry) {
    if (entry is! Map) throw const FormatException('Invalid piece');
    final shape = shapeById('${entry['shape']}');
    final id = entry['id'];
    if (shape == null || id is! num) {
      throw const FormatException('Unknown piece shape');
    }
    return Piece(id: id.toInt(), shape: shape);
  }
}
