import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/game_theme.dart';
import 'block_painter.dart';
import 'drag_controller.dart';
import 'piece_tray.dart';

/// Full-screen, non-interactive layer that draws the piece under the finger
/// (and while it flies back to the tray). Repaints only on drag changes.
class DragLayer extends StatelessWidget {
  const DragLayer({super.key, required this.drag, required this.theme});

  final DragController drag;
  final GameTheme theme;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FloatingPainter(drag, theme),
      ),
    ),
  );
}

class _FloatingPainter extends CustomPainter {
  _FloatingPainter(this.drag, this.theme) : super(repaint: drag);

  final DragController drag;
  final GameTheme theme;
  final BlockPainter _blocks = BlockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final f = drag.floating;
    if (f == null) return;
    final shape = f.piece.shape;
    final origin =
        f.center - Offset(shape.width * f.cell / 2, shape.height * f.cell / 2);
    PiecePainter.paintShape(
      canvas,
      _blocks,
      shape,
      origin,
      f.cell,
      theme.blockColor(shape.colorIndex),
      opacity: UiConfig.dragOpacity,
    );
  }

  @override
  bool shouldRepaint(_FloatingPainter old) =>
      old.drag != drag || old.theme != theme;
}
