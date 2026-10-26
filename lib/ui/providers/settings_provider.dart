import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_theme.dart';
import '../../models/app_settings.dart';
import '../../services/storage_service.dart';

/// Loads and persists [AppSettings].
class SettingsController extends Notifier<AppSettings> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  AppSettings build() => AppSettings(
    soundOn: _storage.soundOn,
    vibrationOn: _storage.vibrationOn,
    themeId: _storage.themeId ?? GameTheme.classicDark.id,
  );

  void setSound(bool on) {
    state = state.copyWith(soundOn: on);
    unawaited(_storage.setSoundOn(on));
  }

  void setVibration(bool on) {
    state = state.copyWith(vibrationOn: on);
    unawaited(_storage.setVibrationOn(on));
  }

  /// Selects [theme] if the player's best score has unlocked it.
  bool selectTheme(GameTheme theme) {
    if (!theme.isUnlocked(_storage.bestScore)) return false;
    state = state.copyWith(themeId: theme.id);
    unawaited(_storage.setThemeId(theme.id));
    return true;
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
