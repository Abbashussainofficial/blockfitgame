import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_theme.dart';
import '../../services/storage_service.dart';
import 'settings_provider.dart';

/// Active visual theme. Falls back to Classic Dark if the saved choice is
/// unknown or (e.g. after a data reset) no longer unlocked.
final gameThemeProvider = Provider<GameTheme>((ref) {
  final theme = GameTheme.byId(ref.watch(settingsProvider).themeId);
  final best = ref.read(storageServiceProvider).bestScore;
  return theme.isUnlocked(best) ? theme : GameTheme.classicDark;
});
