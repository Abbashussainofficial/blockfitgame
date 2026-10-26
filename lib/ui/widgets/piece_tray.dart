import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/game_theme.dart';
import '../../models/piece.dart';
import '../../models/piece_shape.dart';
import 'block_painter.dart';
import 'drag_controller.dart';
import 'effects.dart';

/// Paints a piece shape with square cells of side [cell], filling its size.
class PiecePainter extends CustomPainter {
  PiecePainter({
    required this.shape,
    required this.color,
    required this.cell,
    this.opacity = 1,
  });

  final PieceShape shape;
  final Color color;
  final double cell;
  final double opacity;
  final BlockPainter _blocks = BlockPainter();

  /// Draws [shape] with its top-left at [origin]. Shared with the drag layer.
  static void paintShape(
    Canvas canvas,
    BlockPainter blocks,
    PieceShape shape,
    Offset origin,
    double cell,
    Color color, {
    double opacity = 1,
  }) {
    for (final c in shape.cells) {
      final rect = Rect.fromLTWH(
        origin.dx + c.col * cell,
        origin.dy + c.row * cell,
        cell,
        cell,
      );
      blocks.block(canvas, BlockPainter.inset(rect), color, opacity: opacity);
    }
  }

  @override
  void paint(Canvas canvas, Size size) => paintShape(
    canvas,
    _blocks,
    shape,
    Offset.zero,
    cell,
    color,
    opacity: opacity,
  );

  @override
  bool shouldRepaint(PiecePainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.cell != cell ||
      old.opacity != opacity;
}

/// Pointer callbacks for a tray slot. Raw pointer events (not gestures) are
/// used so a piece lifts the instant it is touched, with no drag slop delay.
class TrayCallbacks {
  const TrayCallbacks({
    required this.onDown,
    required this.onMove,
    required this.onUp,
    required this.onCancel,
  });

  final void Function(int index, PointerDownEvent event) onDown;
  final void Function(PointerMoveEvent event) onMove;
  final void Function(PointerUpEvent event) onUp;
  final void Function(PointerCancelEvent event) onCancel;
}

/// The row of up to three pieces waiting to be placed.
class PieceTray extends StatelessWidget {
  const PieceTray({
    super.key,
    required this.tray,
    required this.placeable,
    required this.theme,
    required this.trayCell,
    required this.slotKeys,
    required this.drag,
    required this.callbacks,
  });

  final List<Piece?> tray;

  /// Per slot: whether that piece fits anywhere on the board right now.
  final List<bool> placeable;
  final GameTheme theme;
  final double trayCell;

  /// Keys used to find each slot's centre for the return animation.
  final List<GlobalKey> slotKeys;
  final DragController drag;
  final TrayCallbacks callbacks;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int?>(
    valueListenable: drag.hiddenSlot,
    builder: (context, hidden, _) => Row(
      children: [
        for (var i = 0; i < tray.length; i++)
          Expanded(child: _slot(i, hidden == i)),
      ],
    ),
  );

  Widget _slot(int index, bool hidden) {
    final piece = tray[index];
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => callbacks.onDown(index, e),
      onPointerMove: callbacks.onMove,
      onPointerUp: callbacks.onUp,
      onPointerCancel: callbacks.onCancel,
      child: SizedBox.expand(
        key: slotKeys[index],
        child: Center(
          child: piece == null
              ? null
              // Lifted pieces stay in the tree (just invisible) so they do
              // not replay the pop-in when they return to the tray.
              : Opacity(
                  opacity: hidden ? 0 : 1,
                  child: PopIn(
                    key: ValueKey(piece.id),
                    delay: UiConfig.trayPopStagger * index,
                    child: CustomPaint(
                      size: Size(
                        piece.shape.width * trayCell,
                        piece.shape.height * trayCell,
                      ),
                      painter: PiecePainter(
                        shape: piece.shape,
                        color: theme.blockColor(piece.shape.colorIndex),
                        cell: trayCell,
                        opacity: placeable[index]
                            ? 1
                            : UiConfig.unplaceableOpacity,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
