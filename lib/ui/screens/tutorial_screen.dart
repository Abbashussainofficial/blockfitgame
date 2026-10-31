import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/game_theme.dart';
import '../../core/strings.dart';
import '../../game/board_logic.dart';
import '../../game/game_controller.dart';
import '../../game/shapes.dart';
import '../../models/board.dart';
import '../../models/cell_pos.dart';
import '../../models/piece.dart';
import '../../models/piece_shape.dart';
import '../../models/place_result.dart';
import '../../services/feedback_service.dart';
import '../../services/storage_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/block_painter.dart';
import '../widgets/common.dart';
import '../widgets/drag_controller.dart';
import '../widgets/drag_layer.dart';
import '../widgets/game_board.dart';
import '../widgets/piece_tray.dart';
import 'game_screen.dart';

/// One hands-on lesson: a prepared board and a single piece that must be
/// dropped on [target].
class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.hint,
    required this.done,
    required this.rows,
    required this.shapeId,
    required this.target,
  });

  final String title;
  final String hint;

  /// Shown once the player has made the move.
  final String done;

  /// Board in [Board.fromRows] format.
  final List<String> rows;
  final String shapeId;

  /// Top-left cell the piece has to land on.
  final CellPos target;

  Board get board => Board.fromRows(rows);
  PieceShape get shape => shapeById(shapeId)!;
}

/// The lessons, in order. Each move clears at least one line.
const List<TutorialStep> kTutorialSteps = [
  TutorialStep(
    title: AppStrings.tutorialRowTitle,
    hint: AppStrings.tutorialRowHint,
    done: AppStrings.tutorialRowDone,
    rows: [
      '........',
      '........',
      '........',
      '........',
      '........',
      '..1.....',
      '.11..3..',
      '5577...2',
    ],
    shapeId: 'line3_h',
    target: CellPos(7, 4),
  ),
  TutorialStep(
    title: AppStrings.tutorialColTitle,
    hint: AppStrings.tutorialColHint,
    done: AppStrings.tutorialColDone,
    rows: [
      '........',
      '........',
      '......4.',
      '..3...4.',
      '..33..4.',
      '......4.',
      '.1....4.',
      '11....4.',
    ],
    shapeId: 'line2_v',
    target: CellPos(0, 6),
  ),
  TutorialStep(
    title: AppStrings.tutorialMultiTitle,
    hint: AppStrings.tutorialMultiHint,
    done: AppStrings.tutorialMultiDone,
    rows: [
      '........',
      '........',
      '........',
      '...2....',
      '..22....',
      '...2....',
      '004455..',
      '077455..',
    ],
    shapeId: 'square2',
    target: CellPos(6, 6),
  ),
];

/// "How to Play": a few guided moves on a real board, then the key rules.
///
/// Shown before the very first game ([startGameWhenDone]) and from Home /
/// Settings. It uses its own board, so scores and saved games are untouched.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key, this.startGameWhenDone = false});

  /// Replace this screen with a fresh game when finished or skipped.
  final bool startGameWhenDone;

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen>
    with TickerProviderStateMixin {
  static const double _sidePadding = 16;

  /// The piece always waits in the middle slot.
  static const int _slot = 1;

  late final DragController _drag = DragController(
    vsync: this,
    onDrop: _onDrop,
  );

  /// Drives the demo hand and the pulsing target.
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  final GlobalKey _layerKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();
  final List<GlobalKey> _slotKeys = List.generate(
    GameConfig.traySize,
    (_) => GlobalKey(),
  );

  int _step = 0;
  late Board _board;
  late List<Piece?> _tray;
  bool _done = false;
  bool _wrongSpot = false;
  double _trayCell = 0;

  ClearEffect? _clearEffect;
  PlaceEffect? _placeEffect;
  int _effectId = 0;

  bool get _onTips => _step >= kTutorialSteps.length;
  TutorialStep get _current => kTutorialSteps[_step];

  @override
  void initState() {
    super.initState();
    _loadStep(0);
  }

  @override
  void dispose() {
    _hint.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _loadStep(int index) {
    _step = index;
    _done = false;
    _wrongSpot = false;
    if (_onTips) return;
    _board = _current.board;
    _tray = List.generate(
      GameConfig.traySize,
      (i) => i == _slot ? Piece(id: index + 1, shape: _current.shape) : null,
    );
  }

  void _next() => setState(() => _loadStep(_step + 1));

  Future<void> _finish() async {
    await ref.read(storageServiceProvider).setTutorialSeen();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (widget.startGameWhenDone) {
      ref.read(gameControllerProvider.notifier).newGame();
      nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const GameScreen()),
      );
    } else {
      nav.pop();
    }
  }

  // ---- Drag plumbing (same coordinate handling as the game screen) ---------

  RenderBox? _box(GlobalKey key) {
    final obj = key.currentContext?.findRenderObject();
    return obj is RenderBox && obj.hasSize ? obj : null;
  }

  Rect? _rectInLayer(GlobalKey key) {
    final layer = _box(_layerKey);
    final box = _box(key);
    if (layer == null || box == null) return null;
    final topLeft = layer.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft & box.size;
  }

  Offset _toLayer(Offset global) =>
      _box(_layerKey)?.globalToLocal(global) ?? global;

  void _onPointerDown(int index, PointerDownEvent e) {
    final piece = _tray[index];
    if (piece == null || _done) return;
    final boardRect = _rectInLayer(_boardKey);
    final slotRect = _rectInLayer(_slotKeys[index]);
    if (boardRect == null || slotRect == null) return;
    _drag.start(
      pointer: e.pointer,
      trayIndex: index,
      piece: piece,
      board: _board,
      boardGeometry: BoardGeometry(boardRect),
      homeCenter: slotRect.center,
      trayCell: _trayCell,
      position: _toLayer(e.position),
    );
  }

  /// Only the lesson's target spot is accepted; anything else bounces back.
  bool _onDrop(int trayIndex, CellPos anchor) {
    if (_done) return false;
    final shape = _current.shape;
    if (anchor != _current.target) {
      setState(() => _wrongSpot = true);
      return false;
    }
    final placed = BoardLogic.place(_board, shape, anchor.row, anchor.col);
    final lines = BoardLogic.findFullLines(placed);
    final cleared = BoardLogic.cellsInLines(placed, lines);
    final cells = BoardLogic.cellsFor(shape, anchor.row, anchor.col);
    ref
        .read(feedbackProvider)
        .placed(
          PlaceResult(
            placedCells: cells,
            clearedRows: lines.rows,
            clearedCols: lines.cols,
            clearedCells: cleared,
            placementPoints: 0,
            clearPoints: 0,
            comboStreak: 1,
            newTrayDealt: false,
            isGameOver: false,
          ),
        );
    setState(() {
      _board = BoardLogic.clearLines(placed, lines);
      _tray = List.filled(GameConfig.traySize, null);
      _done = true;
      _wrongSpot = false;
      _placeEffect = PlaceEffect(++_effectId, cells.toSet());
      _clearEffect = ClearEffect(_effectId, cleared);
    });
    return true;
  }

  late final TrayCallbacks _trayCallbacks = TrayCallbacks(
    onDown: _onPointerDown,
    onMove: (e) => _drag.move(e.pointer, _toLayer(e.position)),
    onUp: (e) => _drag.end(e.pointer),
    onCancel: (e) => _drag.cancel(e.pointer),
  );

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(gameThemeProvider);
    return Scaffold(
      backgroundColor: theme.backgroundGradient.last,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.backgroundGradient,
          ),
        ),
        child: _onTips
            ? SafeArea(child: _tips(theme))
            : Stack(
                key: _layerKey,
                children: [
                  SafeArea(
                    child: LayoutBuilder(
                      builder: (context, c) => _lesson(c, theme),
                    ),
                  ),
                  if (!_done)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _HintPainter(
                            animation: _hint,
                            drag: _drag,
                            theme: theme,
                            shape: _current.shape,
                            target: _current.target,
                            trayCell: () => _trayCell,
                            boardRect: () => _rectInLayer(_boardKey),
                            slotRect: () => _rectInLayer(_slotKeys[_slot]),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: DragLayer(drag: _drag, theme: theme),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _topBar(GameTheme theme, String label) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
      TextButton(
        onPressed: _finish,
        style: TextButton.styleFrom(foregroundColor: theme.textSecondary),
        child: Text(
          AppStrings.skip,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  Widget _lesson(BoxConstraints c, GameTheme theme) {
    final side = min(c.maxWidth - 2 * _sidePadding, c.maxHeight * 0.5);
    final boardCell = BoardGeometry(Offset.zero & Size.square(side)).cell;
    final trayHeight = boardCell * UiConfig.trayHeightCells;
    _trayCell =
        min(trayHeight, c.maxWidth / GameConfig.traySize) /
        UiConfig.trayPieceMaxCells;

    final message = _done
        ? _current.done
        : _wrongSpot
        ? AppStrings.tutorialWrongSpot
        : _current.hint;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
      child: Column(
        children: [
          _topBar(
            theme,
            AppStrings.tutorialStep(_step + 1, kTutorialSteps.length),
          ),
          const SizedBox(height: 4),
          Text(
            _current.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                message,
                key: ValueKey(message),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _done ? theme.accent : theme.textSecondary,
                  fontSize: 16,
                  fontWeight: _done ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: side,
                child: GameBoard(
                  key: _boardKey,
                  board: _board,
                  theme: theme,
                  drag: _drag,
                  clearEffect: _clearEffect,
                  placeEffect: _placeEffect,
                ),
              ),
            ),
          ),
          SizedBox(
            height: trayHeight,
            child: PieceTray(
              tray: _tray,
              placeable: [for (final p in _tray) p != null],
              theme: theme,
              trayCell: _trayCell,
              slotKeys: _slotKeys,
              drag: _drag,
              callbacks: _trayCallbacks,
            ),
          ),
          SizedBox(
            height: 74,
            child: _done
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: MenuButton(
                      theme: theme,
                      label: AppStrings.next,
                      icon: Icons.arrow_forward_rounded,
                      primary: true,
                      onPressed: _next,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _tips(GameTheme theme) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                BlockFitLogo(theme: theme, size: 80),
                const SizedBox(height: 18),
                Text(
                  AppStrings.tutorialReadyTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 24),
                for (final (i, tip) in AppStrings.tutorialTips.indexed)
                  _Tip(theme: theme, icon: _tipIcons[i], text: tip),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24, top: 12),
          child: MenuButton(
            theme: theme,
            label: widget.startGameWhenDone
                ? AppStrings.letsPlay
                : AppStrings.gotIt,
            icon: widget.startGameWhenDone
                ? Icons.play_arrow_rounded
                : Icons.check_rounded,
            primary: true,
            onPressed: _finish,
          ),
        ),
      ],
    ),
  );

  static const List<IconData> _tipIcons = [
    Icons.view_module_rounded,
    Icons.block_rounded,
    Icons.flag_rounded,
    Icons.undo_rounded,
  ];
}

class _Tip extends StatelessWidget {
  const _Tip({required this.theme, required this.icon, required this.text});

  final GameTheme theme;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: theme.boardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.emptyCellColor, width: 2),
    ),
    child: Row(
      children: [
        Icon(icon, color: theme.accent, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Pulses the target cells and, while no piece is held, shows a hand
/// dragging a see-through copy of the piece from the tray to the target.
class _HintPainter extends CustomPainter {
  _HintPainter({
    required this.animation,
    required this.drag,
    required this.theme,
    required this.shape,
    required this.target,
    required this.trayCell,
    required this.boardRect,
    required this.slotRect,
  }) : super(repaint: Listenable.merge([animation, drag]));

  final Animation<double> animation;
  final DragController drag;
  final GameTheme theme;
  final PieceShape shape;
  final CellPos target;

  /// Read at paint time, after layout, in this painter's coordinates.
  final double Function() trayCell;
  final Rect? Function() boardRect;
  final Rect? Function() slotRect;

  final BlockPainter _blocks = BlockPainter();

  static const IconData _hand = Icons.touch_app_rounded;

  @override
  void paint(Canvas canvas, Size size) {
    final board = boardRect();
    final slot = slotRect();
    if (board == null || slot == null) return;
    final geo = BoardGeometry(board);
    final t = animation.value;

    // Pulsing outline on the cells the piece should cover.
    final pulse = 0.5 + 0.5 * sin(t * 4 * pi);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = geo.cell * 0.08
      ..color = theme.accent.withValues(alpha: 0.45 + 0.5 * pulse);
    for (final c in BoardLogic.cellsFor(shape, target.row, target.col)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          geo.cellRectAt(c).deflate(geo.cell * 0.06),
          Radius.circular(geo.cell * UiConfig.blockRadiusRatio),
        ),
        outline,
      );
    }

    if (drag.piece != null) return;

    // Timeline: appear on the tray, glide to the target, hold, fade out.
    final opacity = t < 0.12
        ? t / 0.12
        : t > 0.85
        ? (1 - t) / 0.15
        : 1.0;
    final move = Curves.easeInOut.transform(((t - 0.15) / 0.55).clamp(0, 1));
    final lift = Curves.easeOut.transform(((t - 0.12) / 0.12).clamp(0, 1));

    final cell = _lerp(trayCell(), geo.cell * UiConfig.dragScale, move);
    final targetCenter =
        geo.cellRect(target.row, target.col).topLeft +
        Offset(shape.width * geo.cell / 2, shape.height * geo.cell / 2);
    final liftBy =
        shape.height * geo.cell / 2 + UiConfig.dragLiftCells * geo.cell;
    final finger = Offset.lerp(
      slot.center,
      targetCenter + Offset(0, liftBy),
      move,
    )!;
    final pieceCenter = finger - Offset(0, liftBy * lift);

    PiecePainter.paintShape(
      canvas,
      _blocks,
      shape,
      pieceCenter - Offset(shape.width * cell / 2, shape.height * cell / 2),
      cell,
      theme.blockColor(shape.colorIndex),
      opacity: 0.6 * opacity,
    );

    // The hand, with its fingertip on the touch point.
    final handSize = geo.cell * 1.5;
    final hand = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(_hand.codePoint),
        style: TextStyle(
          fontFamily: _hand.fontFamily,
          package: _hand.fontPackage,
          fontSize: handSize,
          color: Colors.white.withValues(alpha: opacity),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.45 * opacity),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hand.paint(canvas, finger - Offset(handSize * 0.42, handSize * 0.1));
    hand.dispose();
  }

  @override
  bool shouldRepaint(_HintPainter old) =>
      old.shape != shape || old.target != target || old.theme != theme;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
