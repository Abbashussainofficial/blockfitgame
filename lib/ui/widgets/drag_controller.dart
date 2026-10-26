import 'dart:math';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../game/board_logic.dart';
import '../../models/board.dart';
import '../../models/cell_pos.dart';
import '../../models/piece.dart';
import 'block_painter.dart';

/// Where and how big to draw the floating piece, in drag-layer coordinates.
typedef FloatingPiece = ({Piece piece, Offset center, double cell});

/// Tracks one drag of a tray piece: finger position, ghost snap target,
/// preview of lines that would clear, and the lift / return animations.
///
/// All offsets are in the drag layer's local coordinate space. Pointer moves
/// only notify listeners (painters), so dragging never rebuilds widgets.
class DragController extends ChangeNotifier {
  DragController({required TickerProvider vsync, required this.onDrop}) {
    _lift = AnimationController(vsync: vsync, duration: UiConfig.liftDuration)
      ..addListener(notifyListeners);
    _return =
        AnimationController(vsync: vsync, duration: UiConfig.returnDuration)
          ..addListener(notifyListeners)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _reset();
          });
  }

  /// Called on release over a valid spot. Return `false` to reject the drop,
  /// which sends the piece back to the tray.
  final bool Function(int trayIndex, CellPos anchor) onDrop;

  late final AnimationController _lift;
  late final AnimationController _return;

  /// Tray slot currently lifted out (hidden in the tray), if any.
  final ValueNotifier<int?> hiddenSlot = ValueNotifier(null);

  int? _pointer;
  int? _trayIndex;
  Piece? _piece;
  Board? _board;
  BoardGeometry? _geometry;
  Offset _finger = Offset.zero;
  Offset _homeCenter = Offset.zero;
  Offset _releaseCenter = Offset.zero;
  double _trayCell = 0;

  CellPos? _ghost;
  bool _ghostValid = false;
  Set<int> _previewRows = const {};
  Set<int> _previewCols = const {};

  /// Piece being dragged or returning, if any.
  Piece? get piece => _piece;

  bool get _returning => _return.isAnimating;

  /// Snap target for the ghost preview, or `null` when off the board.
  CellPos? get ghostAnchor => _returning ? null : _ghost;
  bool get ghostValid => _ghostValid;

  /// Rows / columns that would clear if the piece were dropped now.
  Set<int> get previewRows => _returning ? const {} : _previewRows;
  Set<int> get previewCols => _returning ? const {} : _previewCols;

  FloatingPiece? get floating {
    final piece = _piece;
    final geometry = _geometry;
    if (piece == null || geometry == null) return null;
    if (_returning) {
      final t = Curves.easeOutCubic.transform(_return.value);
      return (
        piece: piece,
        center: Offset.lerp(_releaseCenter, _homeCenter, t)!,
        cell: _lerp(geometry.cell * UiConfig.dragScale, _trayCell, t),
      );
    }
    final t = Curves.easeOut.transform(_lift.value);
    return (
      piece: piece,
      center: _dragCenter,
      cell: _lerp(_trayCell, geometry.cell * UiConfig.dragScale, t),
    );
  }

  /// Begins dragging [piece]. Ignored while another drag or return is active.
  void start({
    required int pointer,
    required int trayIndex,
    required Piece piece,
    required Board board,
    required BoardGeometry boardGeometry,
    required Offset homeCenter,
    required double trayCell,
    required Offset position,
  }) {
    if (_piece != null) return;
    _pointer = pointer;
    _trayIndex = trayIndex;
    _piece = piece;
    _board = board;
    _geometry = boardGeometry;
    _homeCenter = homeCenter;
    _trayCell = trayCell;
    _finger = position;
    hiddenSlot.value = trayIndex;
    _updateGhost();
    _lift.forward(from: 0);
    notifyListeners();
  }

  void move(int pointer, Offset position) {
    if (pointer != _pointer) return;
    _finger = position;
    _updateGhost();
    notifyListeners();
  }

  /// Finger lifted: drop if the ghost is valid, otherwise animate back.
  void end(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    final anchor = _ghost;
    if (anchor != null && _ghostValid && onDrop(_trayIndex!, anchor)) {
      _reset();
      return;
    }
    _sendHome();
  }

  /// Pointer cancelled by the system: never drop, just return the piece.
  void cancel(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    _sendHome();
  }

  void _sendHome() {
    _releaseCenter = _dragCenter;
    _return.forward(from: 0);
  }

  void _reset() {
    _pointer = null;
    _trayIndex = null;
    _piece = null;
    _board = null;
    _ghost = null;
    _ghostValid = false;
    _previewRows = const {};
    _previewCols = const {};
    _lift.value = 0;
    _return.value = 0;
    hiddenSlot.value = null;
    notifyListeners();
  }

  /// The piece floats above the finger so it is never hidden under it.
  Offset get _dragCenter {
    final shape = _piece!.shape;
    final cell = _geometry!.cell;
    return _finger -
        Offset(0, shape.height * cell / 2 + UiConfig.dragLiftCells * cell);
  }

  void _updateGhost() {
    final shape = _piece!.shape;
    final g = _geometry!;
    final board = _board!;
    final topLeft =
        _dragCenter -
        Offset(shape.width * g.cell / 2, shape.height * g.cell / 2);
    final fr = (topLeft.dy - g.gridOrigin.dy) / g.cell;
    final fc = (topLeft.dx - g.gridOrigin.dx) / g.cell;
    final r0 = fr.round();
    final c0 = fc.round();

    // Snap to the closest valid anchor within the snap radius.
    CellPos? best;
    var bestDist = double.infinity;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final r = r0 + dr;
        final c = c0 + dc;
        if (!BoardLogic.canPlace(board, shape, r, c)) continue;
        final d = sqrt(pow(r - fr, 2) + pow(c - fc, 2));
        if (d <= UiConfig.snapRadiusCells && d < bestDist) {
          bestDist = d;
          best = CellPos(r, c);
        }
      }
    }

    CellPos? anchor = best;
    final valid = best != null;
    // No valid spot nearby: show a red ghost if the piece is over the board.
    if (anchor == null &&
        r0 >= 0 &&
        c0 >= 0 &&
        r0 + shape.height <= Board.size &&
        c0 + shape.width <= Board.size) {
      anchor = CellPos(r0, c0);
    }

    if (anchor == _ghost && valid == _ghostValid) return;
    _ghost = anchor;
    _ghostValid = valid;
    if (valid) {
      final placed = BoardLogic.place(board, shape, anchor!.row, anchor.col);
      final lines = BoardLogic.findFullLines(placed);
      _previewRows = lines.rows.toSet();
      _previewCols = lines.cols.toSet();
    } else {
      _previewRows = const {};
      _previewCols = const {};
    }
  }

  @override
  void dispose() {
    _lift.dispose();
    _return.dispose();
    hiddenSlot.dispose();
    super.dispose();
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
