import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';

/// Local persistence (fully offline) on top of shared_preferences.
///
/// Every read is defensive: corrupt or missing data falls back to defaults
/// instead of crashing, and every write swallows platform errors after
/// logging them, so storage problems never interrupt play.
class StorageService {
  StorageService(this._prefs);

  static Future<StorageService> create() async =>
      StorageService(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const String _kBestScore = 'best_score';
  static const String _kSavedGame = 'saved_game';
  static const String _kGameOverCount = 'game_over_count';
  static const String _kSoundOn = 'sound_on';
  static const String _kVibrationOn = 'vibration_on';
  static const String _kThemeId = 'theme_id';
  static const String _kAdsRemoved = 'ads_removed';

  // ---- Best score ----------------------------------------------------------

  int get bestScore => _safe(() => _prefs.getInt(_kBestScore), 0) ?? 0;

  /// Stores [score] only if it beats the saved best.
  Future<void> submitScore(int score) async {
    if (score > bestScore) {
      await _write(() => _prefs.setInt(_kBestScore, score));
    }
  }

  // ---- Saved game ----------------------------------------------------------

  bool get hasSavedGame => _prefs.containsKey(_kSavedGame);

  /// The saved game, or `null` if there is none or it cannot be read
  /// (unreadable saves are deleted so they do not fail again).
  GameState? loadGame() {
    final raw = _safe(() => _prefs.getString(_kSavedGame), null);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) throw const FormatException();
      return GameState.fromJson(json);
    } catch (e) {
      debugPrint('Discarding unreadable saved game: $e');
      clearGame();
      return null;
    }
  }

  Future<void> saveGame(GameState state) =>
      _write(() => _prefs.setString(_kSavedGame, jsonEncode(state.toJson())));

  Future<void> clearGame() => _write(() => _prefs.remove(_kSavedGame));

  // ---- Counters ------------------------------------------------------------

  /// Number of games that have ended. Drives interstitial ad frequency.
  int get gameOverCount => _safe(() => _prefs.getInt(_kGameOverCount), 0) ?? 0;

  Future<void> incrementGameOverCount() =>
      _write(() => _prefs.setInt(_kGameOverCount, gameOverCount + 1));

  // ---- Settings ----------------------------------------------------------

  bool get soundOn => _safe(() => _prefs.getBool(_kSoundOn), true) ?? true;
  Future<void> setSoundOn(bool v) => _write(() => _prefs.setBool(_kSoundOn, v));

  bool get vibrationOn =>
      _safe(() => _prefs.getBool(_kVibrationOn), true) ?? true;
  Future<void> setVibrationOn(bool v) =>
      _write(() => _prefs.setBool(_kVibrationOn, v));

  String? get themeId => _safe(() => _prefs.getString(_kThemeId), null);
  Future<void> setThemeId(String id) =>
      _write(() => _prefs.setString(_kThemeId, id));

  // ---- Purchases ---------------------------------------------------------

  /// Cached "Remove Ads" ownership (re-synced from Google Play on launch).
  bool get adsRemoved =>
      _safe(() => _prefs.getBool(_kAdsRemoved), false) ?? false;
  Future<void> setAdsRemoved(bool v) =>
      _write(() => _prefs.setBool(_kAdsRemoved, v));

  // ---- Helpers -------------------------------------------------------------

  T _safe<T>(T Function() read, T fallback) {
    try {
      return read();
    } catch (e) {
      debugPrint('Storage read failed: $e');
      return fallback;
    }
  }

  Future<void> _write(Future<bool> Function() write) async {
    try {
      await write();
    } catch (e) {
      debugPrint('Storage write failed: $e');
    }
  }
}

/// Overridden in `main()` with an initialised instance.
final storageServiceProvider = Provider<StorageService>(
  (ref) => throw UnimplementedError('storageServiceProvider not overridden'),
);
