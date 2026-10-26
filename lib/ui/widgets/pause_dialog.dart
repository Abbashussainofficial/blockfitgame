import 'package:flutter/material.dart';

import '../../core/game_theme.dart';
import '../../core/strings.dart';
import 'common.dart';

enum PauseAction { resume, restart, home }

/// Shows the pause menu. Tapping outside or pressing back resumes.
Future<PauseAction> showPauseDialog(
  BuildContext context,
  GameTheme theme,
) async {
  final action = await showDialog<PauseAction>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (context) => Dialog(
      backgroundColor: theme.boardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: theme.emptyCellColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.paused,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            for (final (action, label, icon) in [
              (PauseAction.resume, AppStrings.resume, Icons.play_arrow_rounded),
              (PauseAction.restart, AppStrings.restart, Icons.replay_rounded),
              (PauseAction.home, AppStrings.home, Icons.home_rounded),
            ]) ...[
              MenuButton(
                theme: theme,
                label: label,
                icon: icon,
                primary: action == PauseAction.resume,
                onPressed: () => Navigator.of(context).pop(action),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    ),
  );
  return action ?? PauseAction.resume;
}
