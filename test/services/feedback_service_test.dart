import 'package:block_fit/models/cell_pos.dart';
import 'package:block_fit/models/place_result.dart';
import 'package:block_fit/services/audio_service.dart';
import 'package:block_fit/services/feedback_service.dart';
import 'package:block_fit/services/storage_service.dart';
import 'package:block_fit/ui/providers/settings_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudio extends AudioService {
  final List<Sfx> played = [];

  @override
  void play(Sfx sfx) {
    if (enabled) played.add(sfx);
  }
}

PlaceResult _result({int lines = 0, int streak = 0}) => PlaceResult(
  placedCells: const [CellPos(0, 0)],
  clearedRows: List.generate(lines, (i) => i),
  clearedCols: const [],
  clearedCells: const {},
  placementPoints: 1,
  clearPoints: 0,
  comboStreak: streak,
  newTrayDealt: false,
  isGameOver: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAudio audio;
  late List<String> haptics;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    audio = _FakeAudio();
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
    c = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        audioServiceProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(c.dispose);
  });

  test('each event plays its own sound and haptic', () async {
    final f = c.read(feedbackProvider);
    f.placed(_result());
    f.placed(_result(lines: 1, streak: 1));
    f.placed(_result(lines: 1, streak: 2));
    f.gameOver();
    f.tap();
    await Future<void>.delayed(Duration.zero);

    expect(audio.played, [
      Sfx.place,
      Sfx.clear,
      Sfx.combo,
      Sfx.gameOver,
      Sfx.tap,
    ]);
    expect(haptics, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.selectionClick',
    ]);
  });

  test('Sound and Vibration settings silence feedback', () async {
    final f = c.read(feedbackProvider);
    c.read(settingsProvider.notifier)
      ..setSound(false)
      ..setVibration(false);
    f.placed(_result(lines: 2, streak: 3));
    f.tap();
    await Future<void>.delayed(Duration.zero);
    expect(audio.played, isEmpty);
    expect(haptics, isEmpty);

    c.read(settingsProvider.notifier).setSound(true);
    f.tap();
    expect(audio.played, [Sfx.tap]);
    expect(haptics, isEmpty);
  });

  test('audio without init is a silent no-op', () {
    expect(() => AudioService().play(Sfx.place), returnsNormally);
  });
}
