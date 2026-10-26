import 'package:flutter/material.dart';

import '../../core/game_theme.dart';
import '../../core/strings.dart';

/// Asks before showing a rewarded ad. Resolves to `true` if the player
/// agrees to watch.
Future<bool> confirmWatchAd(
  BuildContext context,
  GameTheme theme, {
  required String title,
  required String message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.boardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Icon(Icons.ondemand_video_rounded, color: theme.accent, size: 36),
      title: Text(
        title,
        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.textSecondary, fontSize: 16),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            AppStrings.cancel,
            style: TextStyle(color: theme.textSecondary),
          ),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text(AppStrings.watchAd),
          style: FilledButton.styleFrom(
            backgroundColor: theme.accent,
            foregroundColor: theme.boardColor,
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}
