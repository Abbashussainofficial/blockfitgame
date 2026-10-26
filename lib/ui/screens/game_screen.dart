import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ad_config.dart';
import '../../core/constants.dart';
import '../../core/game_theme.dart';
import '../../core/strings.dart';
import '../../game/board_logic.dart';
import '../../game/game_controller.dart';
import '../../models/board.dart';
import '../../models/cell_pos.dart';
import '../../models/game_state.dart';
import '../../services/ad_service.dart';
import '../../services/feedback_service.dart';
import '../../services/storage_service.dart';
import '../providers/monetization_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/block_painter.dart';
import '../widgets/common.dart';
import '../widgets/drag_controller.dart';
import '../widgets/drag_layer.dart';
import '../widgets/effects.dart';
import '../widgets/game_board.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/pause_dialog.dart';
import '../widgets/reward_dialog.dart';
import '../widgets/piece_tray.dart';
import '../widgets/score_banner.dart';

/// Main gameplay screen: header, board, tray and the drag overlay.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const double _sidePadding = 16;

  late final DragController _drag = DragController(
    vsync: this,
    onDrop: _onDrop,
  );

  /// Root of the drag layer's coordinate space.
  final GlobalKey _layerKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();
  final List<GlobalKey> _slotKeys = List.generate(
    GameConfig.traySize,
    (_) => GlobalKey(),
  );

  ClearEffect? _clearEffect;
  int _clearId = 0;
  double _trayCell = 0;

  BannerMessage? _banner;
  int _bannerId = 0;

  PlaceEffect? _placeEffect;
  PointsPopup? _points;
  int _effectId = 0;

  /// "NEW BEST!" is announced once per game.
  bool _newBestShown = false;

  /// Game Over appears after a short pause so the final board is visible.
  bool _gameOverVisible = false;
  Timer? _gameOverTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = ref.read(gameControllerProvider);
    _gameOverVisible = state.isGameOver;
    _newBestShown = state.isNewBest;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameOverTimer?.cancel();
    _drag.dispose();
    super.dispose();
  }

  /// Auto-save whenever the app leaves the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) {
      unawaited(ref.read(gameControllerProvider.notifier).persist());
    }
  }

  void _onGameOverChanged(bool? wasOver, bool isOver) {
    _gameOverTimer?.cancel();
    if (isOver) {
      _gameOverTimer = Timer(UiConfig.gameOverDelay, () {
        if (!mounted) return;
        ref.read(feedbackProvider).gameOver();
        setState(() => _gameOverVisible = true);
      });
    } else if (_gameOverVisible) {
      setState(() => _gameOverVisible = false);
    }
  }

  void _playAgain() {
    _newBestShown = false;
    ref.read(gameControllerProvider.notifier).newGame();
  }

  Future<void> _openPause() async {
    // Once the game has ended (including the short pause before Game Over
    // appears) there is nothing to pause; the Game Over screen takes over.
    if (ref.read(gameControllerProvider).isGameOver) return;
    final controller = ref.read(gameControllerProvider.notifier);
    unawaited(controller.persist());
    final action = await showPauseDialog(context, ref.read(gameThemeProvider));
    if (!mounted) return;
    switch (action) {
      case PauseAction.resume:
        break;
      case PauseAction.restart:
        _playAgain();
      case PauseAction.home:
        Navigator.of(context).pop();
    }
  }

  // ---- Ads -----------------------------------------------------------------

  bool _leavingGameOver = false;

  /// Leaves Game Over (Play Again / Home), first showing an interstitial
  /// if one is due. Never called mid-game.
  Future<void> _leaveGameOver(void Function() then) async {
    if (_leavingGameOver) return;
    _leavingGameOver = true;
    try {
      await ref
          .read(adServiceProvider)
          .maybeShowInterstitial(
            ref.read(storageServiceProvider).gameOverCount,
          );
    } finally {
      _leavingGameOver = false;
    }
    if (mounted) then();
  }

  Future<void> _reviveWithAd() async {
    final ctrl = ref.read(gameControllerProvider.notifier);
    if (!ctrl.canRevive) return;
    final outcome = await ref.read(adServiceProvider).showRewarded();
    if (!mounted) return;
    switch (outcome) {
      case RewardOutcome.earned:
        ctrl.revive();
      case RewardOutcome.unavailable:
        showToast(context, AppStrings.adNotReady);
      case RewardOutcome.skipped:
        break;
    }
  }

  /// Free undos first; after that, offer a rewarded ad for one more.
  Future<void> _undo() async {
    final ctrl = ref.read(gameControllerProvider.notifier);
    if (ctrl.canUndo) {
      ctrl.undo();
      return;
    }
    if (!ctrl.hasHistory) return;
    final watch = await confirmWatchAd(
      context,
      ref.read(gameThemeProvider),
      title: AppStrings.outOfUndos,
      message: AppStrings.watchAdForUndo,
    );
    if (!watch || !mounted) return;
    final outcome = await ref.read(adServiceProvider).showRewarded();
    if (!mounted) return;
    switch (outcome) {
      case RewardOutcome.earned:
        ctrl.addUndos(AdConfig.undosPerReward);
        ctrl.undo();
      case RewardOutcome.unavailable:
        showToast(context, AppStrings.adNotReady);
      case RewardOutcome.skipped:
        break;
    }
  }

  /// Wraps a button action with the tap sound / haptic.
  VoidCallback _withTap(void Function() action) => () {
    ref.read(feedbackProvider).tap();
    action();
  };

  void _showBanner(List<String> lines, Color color) => setState(
    () => _banner = BannerMessage(id: ++_bannerId, lines: lines, color: color),
  );

  // ---- Drag plumbing -------------------------------------------------------

  RenderBox? _box(GlobalKey key) {
    final obj = key.currentContext?.findRenderObject();
    return obj is RenderBox && obj.hasSize ? obj : null;
  }

  /// [key]'s bounds in drag-layer coordinates.
  Rect? _rectInLayer(GlobalKey key) {
    final layer = _box(_layerKey);
    final box = _box(key);
    if (layer == null || box == null) return null;
    final topLeft = layer.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft & box.size;
  }

  Offset _toLayer(Offset global) =>
      _box(_layerKey)?.globalToLocal(global) ?? global;

  void _onPointerDown(int index, PointerDownEvent e) {
    final state = ref.read(gameControllerProvider);
    final piece = state.tray[index];
    if (piece == null || state.isGameOver) return;
    final boardRect = _rectInLayer(_boardKey);
    final slotRect = _rectInLayer(_slotKeys[index]);
    if (boardRect == null || slotRect == null) return;
    _drag.start(
      pointer: e.pointer,
      trayIndex: index,
      piece: piece,
      board: state.board,
      boardGeometry: BoardGeometry(boardRect),
      homeCenter: slotRect.center,
      trayCell: _trayCell,
      position: _toLayer(e.position),
    );
  }

  bool _onDrop(int trayIndex, CellPos anchor) {
    final result = ref
        .read(gameControllerProvider.notifier)
        .place(trayIndex, anchor.row, anchor.col);
    if (result == null) return false;
    ref.read(feedbackProvider).placed(result);

    // Pop the placed blocks, float "+N" from the piece, flash clears.
    final cells = result.placedCells;
    final row = cells.map((c) => c.row).reduce((a, b) => a + b) / cells.length;
    final col = cells.map((c) => c.col).reduce((a, b) => a + b) / cells.length;
    setState(() {
      _placeEffect = PlaceEffect(++_effectId, cells.toSet());
      _points = PointsPopup(
        id: _effectId,
        points: result.totalPoints,
        alignment: Alignment(
          (col + 0.5) / Board.size * 2 - 1,
          (row + 0.5) / Board.size * 2 - 1,
        ),
      );
      if (result.clearedCells.isNotEmpty) {
        _clearEffect = ClearEffect(++_clearId, result.clearedCells);
      }
    });

    final state = ref.read(gameControllerProvider);
    final theme = ref.read(gameThemeProvider);
    final lines = <String>[
      if (result.isCombo)
        AppStrings.combo(result.comboStreak)
      else if (result.linesCleared >= 2)
        AppStrings.linesCleared(result.linesCleared),
    ];
    // Only celebrate beating a real record, not the very first game.
    if (!_newBestShown && state.isNewBest && state.startingBest > 0) {
      _newBestShown = true;
      lines.add(AppStrings.newBest);
    }
    if (lines.isNotEmpty) _showBanner(lines, theme.accent);
    return true;
  }

  late final TrayCallbacks _trayCallbacks = TrayCallbacks(
    onDown: _onPointerDown,
    onMove: (e) => _drag.move(e.pointer, _toLayer(e.position)),
    onUp: (e) => _drag.end(e.pointer),
    onCancel: (e) => _drag.cancel(e.pointer),
  );

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final theme = ref.watch(gameThemeProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    ref.listen(
      gameControllerProvider.select((s) => s.isGameOver),
      _onGameOverChanged,
    );

    return PopScope(
      canPop: false,
      // Android back: pause during play, go Home from Game Over.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_gameOverVisible) {
          _leaveGameOver(() => Navigator.of(context).pop());
        } else if (!state.isGameOver) {
          _openPause();
        }
      },
      child: _scaffold(state, theme, controller),
    );
  }

  Widget _scaffold(
    GameState state,
    GameTheme theme,
    GameController controller,
  ) {
    return Scaffold(
      backgroundColor: theme.backgroundGradient.last,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.backgroundGradient,
          ),
        ),
        child: Stack(
          key: _layerKey,
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, c) => _layout(context, c, state, theme),
              ),
            ),
            Positioned.fill(
              child: DragLayer(drag: _drag, theme: theme),
            ),
            if (state.isGameOver && _gameOverVisible)
              Positioned.fill(
                child: GameOverOverlay(
                  theme: theme,
                  score: state.score,
                  bestScore: state.bestScore,
                  isNewBest: state.isNewBest,
                  onPlayAgain: _withTap(() => _leaveGameOver(_playAgain)),
                  onRevive: controller.canRevive
                      ? _withTap(_reviveWithAd)
                      : null,
                  onHome: Navigator.canPop(context)
                      ? _withTap(
                          () => _leaveGameOver(() => Navigator.pop(context)),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _layout(
    BuildContext context,
    BoxConstraints c,
    GameState state,
    GameTheme theme,
  ) {
    // Board takes the full width on phones, capped by height on short or
    // wide screens; the tray scales from the board's cell size.
    final side = min(c.maxWidth - 2 * _sidePadding, c.maxHeight * 0.6);
    final boardCell = BoardGeometry(Offset.zero & Size.square(side)).cell;
    final trayHeight = boardCell * UiConfig.trayHeightCells;
    _trayCell =
        min(trayHeight, c.maxWidth / GameConfig.traySize) /
        UiConfig.trayPieceMaxCells;

    final placeable = [
      for (final p in state.tray)
        p != null && BoardLogic.canPlaceAnywhere(state.board, p.shape),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
      child: Column(
        children: [
          _Header(
            state: state,
            theme: theme,
            canUndo:
                ref.read(gameControllerProvider.notifier).hasHistory &&
                !state.isGameOver,
            onUndo: _withTap(_undo),
            onPause: state.isGameOver ? null : _withTap(_openPause),
          ),
          Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: side,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: GameBoard(
                        key: _boardKey,
                        board: state.board,
                        theme: theme,
                        drag: _drag,
                        clearEffect: _clearEffect,
                        placeEffect: _placeEffect,
                      ),
                    ),
                    if (_points != null)
                      Positioned.fill(
                        child: FloatingPoints(
                          key: ValueKey(_points!.id),
                          popup: _points!,
                          color: theme.textPrimary,
                        ),
                      ),
                    ScoreBanner(message: _banner),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: trayHeight,
            child: PieceTray(
              tray: state.tray,
              placeable: placeable,
              theme: theme,
              trayCell: _trayCell,
              slotKeys: _slotKeys,
              drag: _drag,
              callbacks: _trayCallbacks,
            ),
          ),
          const SizedBox(height: _sidePadding),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.theme,
    required this.canUndo,
    required this.onUndo,
    required this.onPause,
  });

  final GameState state;
  final GameTheme theme;
  final bool canUndo;
  final VoidCallback onUndo;

  /// `null` disables the button (game over).
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: AppStrings.pause,
            onPressed: onPause,
            color: theme.textPrimary,
            disabledColor: theme.textSecondary.withValues(alpha: 0.4),
            iconSize: 32,
            icon: const Icon(Icons.pause_circle_filled_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  AppStrings.score,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                AnimatedScore(
                  value: state.score,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: theme.accent,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${AppStrings.best} ${state.bestScore}',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Badge(
            // Undos left, or a video icon once only ad undos remain.
            label: state.undosLeft > 0
                ? Text('${state.undosLeft}')
                : Icon(
                    Icons.ondemand_video_rounded,
                    size: 10,
                    color: theme.boardColor,
                  ),
            isLabelVisible: canUndo,
            backgroundColor: theme.accent,
            textColor: theme.boardColor,
            child: IconButton(
              tooltip: AppStrings.undo,
              onPressed: canUndo ? onUndo : null,
              color: theme.textPrimary,
              disabledColor: theme.textSecondary.withValues(alpha: 0.4),
              iconSize: 32,
              icon: const Icon(Icons.undo_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
