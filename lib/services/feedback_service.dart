import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place_result.dart';
import '../ui/providers/settings_provider.dart';
import 'audio_service.dart';

/// Sound + haptics for game events, honouring the Sound and Vibration
/// settings. Widgets call the high-level methods ([placed], [tap], ...)
/// rather than picking sounds themselves.
class FeedbackService {
  FeedbackService(this._audio);

  final AudioService _audio;

  bool get soundOn => _audio.enabled;
  set soundOn(bool on) => _audio.enabled = on;
  bool vibrationOn = true;

  /// A piece was placed: tock + light tap; clears and combos add more.
  void placed(PlaceResult result) {
    if (result.isCombo) {
      _audio.play(Sfx.combo);
      _haptic(HapticFeedback.heavyImpact);
    } else if (result.linesCleared > 0) {
      _audio.play(Sfx.clear);
      _haptic(HapticFeedback.mediumImpact);
    } else {
      _audio.play(Sfx.place);
      _haptic(HapticFeedback.lightImpact);
    }
  }

  void gameOver() {
    _audio.play(Sfx.gameOver);
    _haptic(HapticFeedback.heavyImpact);
  }

  /// Button press.
  void tap() {
    _audio.play(Sfx.tap);
    _haptic(HapticFeedback.selectionClick);
  }

  void _haptic(Future<void> Function() effect) {
    if (!vibrationOn) return;
    unawaited(effect().catchError((Object _) {}));
  }
}

/// Overridden in `main()` with an initialised [AudioService].
final audioServiceProvider = Provider<AudioService>((ref) => AudioService());

final feedbackProvider = Provider<FeedbackService>((ref) {
  final service = FeedbackService(ref.watch(audioServiceProvider));
  // Keep in sync with Settings without rebuilding the service.
  void apply() {
    final s = ref.read(settingsProvider);
    service
      ..soundOn = s.soundOn
      ..vibrationOn = s.vibrationOn;
  }

  apply();
  ref.listen(settingsProvider, (_, _) => apply());
  return service;
});
