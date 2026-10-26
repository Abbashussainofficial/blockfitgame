import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Short game sound effects.
///
/// The WAV files in `assets/sounds/` are synthesised placeholders made by
/// `tools/generate_sounds.py`. Replace them with your own sounds by keeping
/// the same file names (or editing [_file] below).
enum Sfx { place, clear, combo, gameOver, tap }

/// Plays [Sfx] with one pre-loaded player per sound, so playback starts
/// instantly. All failures are logged and ignored: missing audio must never
/// break the game.
class AudioService {
  AudioService();

  final Map<Sfx, AudioPlayer> _players = {};
  bool _ready = false;

  /// Whether sounds should play (mirrors the Sound setting).
  bool enabled = true;

  static String _file(Sfx sfx) => switch (sfx) {
    Sfx.place => 'sounds/place.wav',
    Sfx.clear => 'sounds/clear.wav',
    Sfx.combo => 'sounds/combo.wav',
    Sfx.gameOver => 'sounds/game_over.wav',
    Sfx.tap => 'sounds/tap.wav',
  };

  /// Loads every sound. Safe to call more than once.
  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    // Mix with other apps' audio (e.g. the player's music) instead of
    // pausing it, and never take audio focus.
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
    } catch (e) {
      debugPrint('Audio context not set: $e');
    }
    for (final sfx in Sfx.values) {
      try {
        final player = AudioPlayer(playerId: 'sfx_${sfx.name}');
        await player.setReleaseMode(ReleaseMode.stop);
        // Android's low-latency mode (SoundPool) suits short effects.
        if (defaultTargetPlatform == TargetPlatform.android) {
          await player.setPlayerMode(PlayerMode.lowLatency);
        }
        await player.setSource(AssetSource(_file(sfx)));
        _players[sfx] = player;
      } catch (e) {
        debugPrint('Could not load ${sfx.name}: $e');
      }
    }
  }

  void play(Sfx sfx) {
    if (!enabled) return;
    final player = _players[sfx];
    if (player == null) return;
    unawaited(_restart(player, sfx));
  }

  Future<void> _restart(AudioPlayer player, Sfx sfx) async {
    try {
      await player.stop();
      await player.resume();
    } catch (e) {
      debugPrint('Could not play ${sfx.name}: $e');
    }
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
    _ready = false;
  }
}
