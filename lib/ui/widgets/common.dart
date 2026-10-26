import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_theme.dart';
import '../../services/feedback_service.dart';
import 'block_painter.dart';

/// Full-screen scaffold with the theme's background gradient.
class ThemedScaffold extends StatelessWidget {
  const ThemedScaffold({
    super.key,
    required this.theme,
    required this.body,
    this.title,
  });

  final GameTheme theme;
  final Widget body;

  /// Shows an app bar with a back button when set.
  final String? title;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: theme.backgroundGradient.last,
    extendBodyBehindAppBar: true,
    appBar: title == null
        ? null
        : AppBar(
            title: Text(
              title!,
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            foregroundColor: theme.textPrimary,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
    body: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.backgroundGradient,
        ),
      ),
      child: SafeArea(child: body),
    ),
  );
}

/// The Block Fit mark: a 3x3 cluster of blocks in the theme's colours.
class BlockFitLogo extends StatelessWidget {
  const BlockFitLogo({super.key, required this.theme, this.size = 96});

  final GameTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LogoPainter(theme));
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.theme);

  final GameTheme theme;
  final BlockPainter _blocks = BlockPainter();

  /// Colour index per cell; -1 = gap. Reads as an L-piece meeting a square.
  static const List<List<int>> _pattern = [
    [0, -1, 5],
    [0, 3, 3],
    [0, 0, 3],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final color = _pattern[r][c];
        final rect = BlockPainter.inset(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
        );
        if (color < 0) {
          _blocks.empty(canvas, rect, theme.emptyCellColor);
        } else {
          _blocks.block(canvas, rect, theme.blockColor(color));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.theme != theme;
}

/// Large rounded menu button used on Home and in dialogs. Plays the tap
/// sound / haptic before running [onPressed].
class MenuButton extends ConsumerWidget {
  const MenuButton({
    super.key,
    required this.theme,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final GameTheme theme;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Primary buttons are filled with the accent colour.
  final bool primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void pressed() {
      ref.read(feedbackProvider).tap();
      onPressed();
    }

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );
    const minSize = Size.fromHeight(58);
    const text = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
    if (primary) {
      return FilledButton.icon(
        onPressed: pressed,
        icon: Icon(icon, size: 26),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: theme.accent,
          foregroundColor: theme.boardColor,
          minimumSize: minSize,
          shape: shape,
          textStyle: text,
        ),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: pressed,
      icon: Icon(icon, size: 24),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
      style: FilledButton.styleFrom(
        backgroundColor: theme.boardColor,
        foregroundColor: theme.textPrimary,
        minimumSize: minSize,
        shape: shape,
        textStyle: text,
        side: BorderSide(color: theme.emptyCellColor, width: 2),
      ),
    );
  }
}

/// Shows a short message at the bottom of the screen.
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
