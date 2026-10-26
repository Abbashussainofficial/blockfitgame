import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/game_theme.dart';
import '../../core/strings.dart';

/// Game Over screen shown over the final board: score, best, and the
/// Revive / Play Again / Home actions. Fades in.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.theme,
    required this.score,
    required this.bestScore,
    required this.isNewBest,
    required this.onPlayAgain,
    this.onRevive,
    this.onHome,
  });

  final GameTheme theme;
  final int score;
  final int bestScore;
  final bool isNewBest;
  final VoidCallback onPlayAgain;

  /// `null` hides Revive (already used this game).
  final VoidCallback? onRevive;

  /// `null` hides Home (no screen to go back to).
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: UiConfig.gameOverFade,
    curve: Curves.easeOut,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
    ),
    child: ColoredBox(
      color: Colors.black.withValues(alpha: 0.62),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _card(),
          ),
        ),
      ),
    ),
  );

  Widget _card() => Container(
    constraints: const BoxConstraints(maxWidth: 360),
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
    decoration: BoxDecoration(
      color: theme.boardColor,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: theme.emptyCellColor, width: 2),
      boxShadow: const [BoxShadow(blurRadius: 30, color: Colors.black45)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.gameOver,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.noMovesLeft,
          style: TextStyle(color: theme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 24),
        if (isNewBest) ...[_newBestBadge(), const SizedBox(height: 12)],
        Text(
          AppStrings.score,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          '$score',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 56,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded, color: theme.accent, size: 20),
            const SizedBox(width: 6),
            Text(
              '${AppStrings.best}  $bestScore',
              style: TextStyle(
                color: theme.accent,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (onRevive != null) ...[
          _button(
            label: AppStrings.revive,
            icon: Icons.ondemand_video_rounded,
            onPressed: onRevive!,
            filled: true,
            color: theme.ghostValid,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 14),
            child: Text(
              AppStrings.reviveHint,
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ),
        ],
        _button(
          label: AppStrings.playAgain,
          icon: Icons.replay_rounded,
          onPressed: onPlayAgain,
          filled: true,
          color: theme.accent,
        ),
        if (onHome != null) ...[
          const SizedBox(height: 10),
          _button(
            label: AppStrings.home,
            icon: Icons.home_rounded,
            onPressed: onHome!,
            filled: false,
            color: theme.textPrimary,
          ),
        ],
      ],
    ),
  );

  Widget _newBestBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: theme.accent.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      AppStrings.newBest,
      style: TextStyle(
        color: theme.accent,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _button({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool filled,
    required Color color,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    const size = Size.fromHeight(52);
    const text = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
    return filled
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: theme.boardColor,
              minimumSize: size,
              shape: shape,
              textStyle: text,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: theme.emptyCellColor, width: 2),
              minimumSize: size,
              shape: shape,
              textStyle: text,
            ),
          );
  }
}
