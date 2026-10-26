import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_theme.dart';
import '../../core/strings.dart';
import '../../services/feedback_service.dart';
import '../../services/storage_service.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/block_painter.dart';
import '../widgets/common.dart';

/// Grid of themes. Locked themes show the best score needed to unlock them.
class ThemesScreen extends ConsumerWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(gameThemeProvider);
    final best = ref.read(storageServiceProvider).bestScore;

    return ThemedScaffold(
      theme: active,
      title: AppStrings.themes,
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        itemCount: GameTheme.all.length,
        itemBuilder: (context, i) {
          final theme = GameTheme.all[i];
          final unlocked = theme.isUnlocked(best);
          return _ThemeCard(
            theme: theme,
            frame: active,
            unlocked: unlocked,
            selected: theme.id == active.id,
            onTap: () {
              ref.read(feedbackProvider).tap();
              if (!ref.read(settingsProvider.notifier).selectTheme(theme)) {
                showToast(context, AppStrings.themeLocked);
              }
            },
          );
        },
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.frame,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  /// Theme being previewed.
  final GameTheme theme;

  /// Active theme, used for the card's outline and labels.
  final GameTheme frame;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: theme.name,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.backgroundGradient,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? frame.accent : frame.emptyCellColor,
            width: selected ? 3 : 2,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: unlocked ? 1 : 0.35,
                    child: CustomPaint(painter: _PreviewPainter(theme)),
                  ),
                  if (!unlocked)
                    Icon(
                      Icons.lock_rounded,
                      size: 40,
                      color: theme.textPrimary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              theme.name,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              selected
                  ? AppStrings.selected
                  : unlocked
                  ? ''
                  : AppStrings.unlockAt(theme.unlockScore),
              style: TextStyle(
                color: selected ? theme.accent : theme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A tiny 4x4 board showing the theme's board, empty cells and blocks.
class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.theme);

  final GameTheme theme;
  final BlockPainter _blocks = BlockPainter();

  static const List<List<int>> _cells = [
    [0, 0, -1, 1],
    [2, -1, -1, 1],
    [2, 3, 3, -1],
    [4, 5, 6, 7],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        origin & Size.square(side),
        Radius.circular(side * 0.1),
      ),
      Paint()..color = theme.boardColor,
    );
    final pad = side * 0.06;
    final cell = (side - 2 * pad) / 4;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final rect = BlockPainter.inset(
          Rect.fromLTWH(
            origin.dx + pad + c * cell,
            origin.dy + pad + r * cell,
            cell,
            cell,
          ),
        );
        final v = _cells[r][c];
        if (v < 0) {
          _blocks.empty(canvas, rect, theme.emptyCellColor);
        } else {
          _blocks.block(canvas, rect, theme.blockColor(v));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.theme != theme;
}
