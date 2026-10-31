import 'package:block_fit/core/constants.dart';
import 'package:block_fit/core/strings.dart';
import 'package:block_fit/game/board_logic.dart';
import 'package:block_fit/game/game_controller.dart';
import 'package:block_fit/services/storage_service.dart';
import 'package:block_fit/ui/screens/game_screen.dart';
import 'package:block_fit/ui/screens/home_screen.dart';
import 'package:block_fit/ui/screens/settings_screen.dart';
import 'package:block_fit/ui/screens/tutorial_screen.dart';
import 'package:block_fit/ui/widgets/block_painter.dart';
import 'package:block_fit/ui/widgets/game_board.dart';
import 'package:block_fit/ui/widgets/piece_tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, StorageService)> _pump(
  WidgetTester tester,
  Widget home, {
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final storage = StorageService(await SharedPreferences.getInstance());
  final c = ProviderContainer(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: home),
    ),
  );
  return (c, storage);
}

/// Drags the tutorial piece so its top-left block lands on [row], [col].
Future<void> _dragTo(
  WidgetTester tester,
  TutorialStep step,
  int row,
  int col,
) async {
  final tray = tester.getRect(find.byType(PieceTray));
  final geo = BoardGeometry(tester.getRect(find.byType(GameBoard)));
  final slotW = tray.width / GameConfig.traySize;
  final from = Offset(tray.left + slotW * 1.5, tray.center.dy);
  final shape = step.shape;
  final to =
      geo.cellRect(row, col).topLeft +
      Offset(
        shape.width * geo.cell / 2,
        shape.height * geo.cell + UiConfig.dragLiftCells * geo.cell,
      );
  final g = await tester.startGesture(from);
  await tester.pump();
  for (var i = 1; i <= 10; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await _frames(tester);
}

/// Runs ~0.6 s of frames: lets route transitions and piece animations finish
/// (the tutorial's hint animation repeats forever, so pumpAndSettle can't).
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
}

void main() {
  test('every lesson move is legal and clears a line', () {
    for (final step in kTutorialSteps) {
      final board = step.board;
      final t = step.target;
      expect(
        BoardLogic.canPlace(board, step.shape, t.row, t.col),
        isTrue,
        reason: step.title,
      );
      final placed = BoardLogic.place(board, step.shape, t.row, t.col);
      expect(
        BoardLogic.findFullLines(placed).count,
        greaterThan(0),
        reason: step.title,
      );
    }
  });

  testWidgets('first Play opens the tutorial, which then starts a game', (
    tester,
  ) async {
    final (c, storage) = await _pump(tester, const HomeScreen());
    await tester.tap(find.text(AppStrings.play));
    await _frames(tester);
    expect(find.byType(TutorialScreen), findsOneWidget);
    expect(find.text(AppStrings.tutorialRowTitle), findsOneWidget);

    for (final (i, step) in kTutorialSteps.indexed) {
      expect(
        find.text(AppStrings.tutorialStep(i + 1, kTutorialSteps.length)),
        findsOneWidget,
      );

      // A wrong spot is refused and the piece goes back.
      final wrong = BoardLogic.validAnchors(
        step.board,
        step.shape,
      ).firstWhere((a) => a != step.target);
      await _dragTo(tester, step, wrong.row, wrong.col);
      expect(find.text(AppStrings.tutorialWrongSpot), findsOneWidget);
      expect(find.text(AppStrings.next), findsNothing);

      await _dragTo(tester, step, step.target.row, step.target.col);
      expect(find.text(step.done), findsOneWidget);
      await tester.tap(find.text(AppStrings.next));
      await _frames(tester);
    }

    expect(find.text(AppStrings.tutorialReadyTitle), findsOneWidget);
    expect(storage.tutorialSeen, isFalse);
    await tester.tap(find.text(AppStrings.letsPlay));
    await _frames(tester);

    expect(storage.tutorialSeen, isTrue);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(c.read(gameControllerProvider).score, 0);
    expect(c.read(gameControllerProvider).board.isEmpty, isTrue);
  });

  testWidgets('Skip goes straight to the game and is remembered', (
    tester,
  ) async {
    final (_, storage) = await _pump(tester, const HomeScreen());
    await tester.tap(find.text(AppStrings.play));
    await _frames(tester);
    await tester.tap(find.text(AppStrings.skip));
    await _frames(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(storage.tutorialSeen, isTrue);
  });

  testWidgets('after the tutorial, Play goes straight to the game', (
    tester,
  ) async {
    await _pump(tester, const HomeScreen(), prefs: {'tutorial_seen': true});
    await tester.tap(find.text(AppStrings.play));
    await _frames(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(TutorialScreen), findsNothing);
  });

  testWidgets('How to Play from Home returns to Home without a game', (
    tester,
  ) async {
    final (c, _) = await _pump(
      tester,
      const HomeScreen(),
      prefs: {'tutorial_seen': true},
    );
    await tester.tap(find.text(AppStrings.howToPlay));
    await _frames(tester);
    expect(find.byType(TutorialScreen), findsOneWidget);
    await tester.tap(find.text(AppStrings.skip));
    await _frames(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    expect(c.read(gameControllerProvider).moveCount, 0);
  });

  testWidgets('Settings has How to Play', (tester) async {
    await _pump(tester, const SettingsScreen());
    await tester.tap(find.text(AppStrings.howToPlay));
    await _frames(tester);
    expect(find.byType(TutorialScreen), findsOneWidget);
  });
}
