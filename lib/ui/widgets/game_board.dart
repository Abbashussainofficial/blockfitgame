import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/game_theme.dart';
import '../../models/board.dart';
import '../../models/cell_pos.dart';
import 'block_painter.dart';
import 'drag_controller.dart';

/// Cells removed by a line clear, kept briefly so they can animate out.
/// [id] changes on every clear so the board knows to restart the animation.
class ClearEffect {
  const ClearEffect(this.id, this.cells);

  final int id;
  final Map<CellPos, int> cells;
}

/// Cells of the piece just placed, so they can "pop" into place.
class PlaceEffect {
  const PlaceEffect(this.id, this.cells);

  final int id;
  final Set<CellPos> cells;
}

/// The 8x8 grid: placed blocks, the drag ghost, would-clear preview, the
/// place pop and the line-clear flash/shrink. Fills its (square) parent.
class GameBoard extends StatefulWidget {
  const GameBoard({
    super.key,
    required this.board,
    required this.theme,
    required this.drag,
    this.clearEffect,
    this.placeEffect,
  });

  final Board board;
  final GameTheme theme;
  final DragController drag;
  final ClearEffect? clearEffect;
  final PlaceEffect? placeEffect;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  late final AnimationController _clear = AnimationController(
    vsync: this,
    duration: UiConfig.clearDuration,
    value: 1,
  );
  late final AnimationController _place = AnimationController(
    vsync: this,
    duration: UiConfig.placeDuration,
    value: 1,
  );

  @override
  void didUpdateWidget(GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final effect = widget.clearEffect;
    if (effect != null && effect.id != oldWidget.clearEffect?.id) {
      _clear.forward(from: 0);
    }
    final place = widget.placeEffect;
    if (place != null && place.id != oldWidget.placeEffect?.id) {
      _place.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _place.dispose();
    _clear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _BoardPainter(
        board: widget.board,
        theme: widget.theme,
        drag: widget.drag,
        clearEffect: widget.clearEffect,
        clearProgress: _clear,
        placeEffect: widget.placeEffect,
        placeProgress: _place,
      ),
    ),
  );
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.board,
    required this.theme,
    required this.drag,
    required this.clearEffect,
    required this.clearProgress,
    required this.placeEffect,
    required this.placeProgress,
  }) : super(repaint: Listenable.merge([drag, clearProgress, placeProgress]));

  final Board board;
  final GameTheme theme;
  final DragController drag;
  final ClearEffect? clearEffect;
  final Animation<double> clearProgress;
  final PlaceEffect? placeEffect;
  final Animation<double> placeProgress;
  final BlockPainter _blocks = BlockPainter();

  static const double _flashPortion = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = BoardGeometry(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(geo.rect, Radius.circular(geo.cell * 0.35)),
      Paint()..color = theme.boardColor,
    );

    final piece = drag.piece;
    final ghost = drag.ghostAnchor;
    final rows = drag.previewRows;
    final cols = drag.previewCols;
    final previewColor = piece == null
        ? null
        : theme.blockColor(piece.shape.colorIndex);
    // Just-placed blocks overshoot slightly, then settle ("pop").
    final popT = placeProgress.value;
    final popping = popT < 1 ? placeEffect?.cells : null;
    final popScale = 0.72 + 0.28 * Curves.easeOutBack.transform(popT);

    // Placed blocks and empty slots. Blocks in a would-clear line take the
    // dragged piece's colour as a hint.
    for (var r = 0; r < Board.size; r++) {
      for (var c = 0; c < Board.size; c++) {
        var rect = BlockPainter.inset(geo.cellRect(r, c));
        if (!board.isFilled(r, c)) {
          _blocks.empty(canvas, rect, theme.emptyCellColor);
          continue;
        }
        if (popping != null && popping.contains(CellPos(r, c))) {
          _blocks.empty(canvas, rect, theme.emptyCellColor);
          rect = Rect.fromCenter(
            center: rect.center,
            width: rect.width * popScale,
            height: rect.height * popScale,
          );
        }
        final inPreview = rows.contains(r) || cols.contains(c);
        _blocks.block(
          canvas,
          rect,
          inPreview && previewColor != null
              ? previewColor
              : theme.blockColor(board.colorAt(r, c)),
        );
      }
    }

    if (piece != null && ghost != null) {
      for (final cell in piece.shape.cells) {
        final rect = BlockPainter.inset(
          geo.cellRect(ghost.row + cell.row, ghost.col + cell.col),
        );
        if (drag.ghostValid) {
          _blocks.ghost(canvas, rect, previewColor!, theme.ghostValid);
        } else {
          _blocks.ghost(canvas, rect, theme.ghostInvalid, theme.ghostInvalid);
        }
      }
    }

    _paintClear(canvas, geo);
  }

  /// Cleared cells flash white, then shrink and fade out.
  void _paintClear(Canvas canvas, BoardGeometry geo) {
    final effect = clearEffect;
    final t = clearProgress.value;
    if (effect == null || t >= 1) return;

    for (final entry in effect.cells.entries) {
      final rect = BlockPainter.inset(geo.cellRectAt(entry.key));
      final color = theme.blockColor(entry.value);
      if (t < _flashPortion) {
        final flash = sin(t / _flashPortion * pi);
        _blocks.block(canvas, rect, color);
        _blocks.flat(
          canvas,
          rect,
          Colors.white.withValues(alpha: 0.75 * flash),
        );
      } else {
        final k = Curves.easeIn.transform(
          (t - _flashPortion) / (1 - _flashPortion),
        );
        final scale = 1 - k;
        if (scale <= 0.02) continue;
        final shrunk = Rect.fromCenter(
          center: rect.center,
          width: rect.width * scale,
          height: rect.height * scale,
        );
        _blocks.block(canvas, shrunk, color, opacity: scale);
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.clearEffect != clearEffect ||
      old.placeEffect != placeEffect ||
      old.drag != drag;
}
