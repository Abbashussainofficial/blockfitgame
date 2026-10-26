import 'dart:ui';

import '../../core/constants.dart';
import '../../models/board.dart';
import '../../models/cell_pos.dart';

/// Maps board cells to pixels inside a square board rect.
class BoardGeometry {
  BoardGeometry(this.rect)
    : padding = rect.width * UiConfig.boardPaddingRatio,
      cell =
          (rect.width - 2 * rect.width * UiConfig.boardPaddingRatio) /
          Board.size;

  /// Board bounds (local or global, depending on who built it).
  final Rect rect;
  final double padding;

  /// Side of one cell, including its gap.
  final double cell;

  /// Top-left of cell (0, 0).
  Offset get gridOrigin => rect.topLeft + Offset(padding, padding);

  Rect cellRect(int row, int col) => Rect.fromLTWH(
    gridOrigin.dx + col * cell,
    gridOrigin.dy + row * cell,
    cell,
    cell,
  );

  Rect cellRectAt(CellPos p) => cellRect(p.row, p.col);
}

/// Draws rounded, softly shaded blocks. One instance per painter so [Paint]
/// objects are reused across frames instead of reallocated.
class BlockPainter {
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static const Color _white = Color(0xFFFFFFFF);
  static const Color _black = Color(0xFF000000);

  /// Shrinks a cell's rect by the standard gap.
  static Rect inset(Rect cellRect) =>
      cellRect.deflate(cellRect.width * UiConfig.cellGapRatio / 2);

  static RRect _rrect(Rect r) => RRect.fromRectAndRadius(
    r,
    Radius.circular(r.width * UiConfig.blockRadiusRatio),
  );

  /// A filled 3D-looking block: darker base edge, main face, top highlight.
  void block(Canvas canvas, Rect rect, Color color, {double opacity = 1}) {
    final edge = rect.height * 0.1;
    _fill.color = Color.lerp(color, _black, 0.3)!.withValues(alpha: opacity);
    canvas.drawRRect(_rrect(rect), _fill);

    final face = Rect.fromLTRB(
      rect.left,
      rect.top,
      rect.right,
      rect.bottom - edge,
    );
    _fill.color = color.withValues(alpha: opacity);
    canvas.drawRRect(_rrect(face), _fill);

    final shine = Rect.fromLTWH(
      face.left + face.width * 0.16,
      face.top + face.height * 0.1,
      face.width * 0.68,
      face.height * 0.22,
    );
    _fill.color = _white.withValues(alpha: 0.28 * opacity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shine, Radius.circular(shine.height / 2)),
      _fill,
    );
  }

  /// A flat empty slot.
  void empty(Canvas canvas, Rect rect, Color color) {
    _fill.color = color;
    canvas.drawRRect(_rrect(rect), _fill);
  }

  /// A translucent ghost block with a coloured outline.
  void ghost(Canvas canvas, Rect rect, Color fill, Color outline) {
    _fill.color = fill.withValues(alpha: 0.45);
    canvas.drawRRect(_rrect(rect), _fill);
    _stroke
      ..color = outline
      ..strokeWidth = rect.width * 0.07;
    canvas.drawRRect(_rrect(rect.deflate(_stroke.strokeWidth / 2)), _stroke);
  }

  /// A plain rounded rect, e.g. for flashes.
  void flat(Canvas canvas, Rect rect, Color color) {
    _fill.color = color;
    canvas.drawRRect(_rrect(rect), _fill);
  }
}
