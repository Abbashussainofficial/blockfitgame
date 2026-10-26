import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_theme.dart';
import '../../core/strings.dart';
import '../../game/game_controller.dart';
import '../providers/theme_provider.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/common.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'themes_screen.dart';

/// Main menu: Play / Continue, Themes, Settings and the high score.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(gameThemeProvider);
    final game = ref.watch(gameControllerProvider);
    // A game is resumable if it was started and has not ended.
    final canContinue = !game.isGameOver && game.moveCount > 0;

    void openGame({required bool fresh}) {
      if (fresh) ref.read(gameControllerProvider.notifier).newGame();
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const GameScreen()));
    }

    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));

    return ThemedScaffold(
      theme: theme,
      // The only banner ad in the app lives here (never during gameplay).
      body: Column(
        children: [
          Expanded(
            child: _menu(
              context,
              theme,
              game.bestScore,
              canContinue,
              openGame,
              open,
            ),
          ),
          const HomeBannerAd(),
        ],
      ),
    );
  }

  Widget _menu(
    BuildContext context,
    GameTheme theme,
    int bestScore,
    bool canContinue,
    void Function({required bool fresh}) openGame,
    void Function(Widget) open,
  ) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _title(theme),
                _HighScoreCard(theme: theme, best: bestScore),
                Column(
                  children: [
                    if (canContinue) ...[
                      MenuButton(
                        theme: theme,
                        label: AppStrings.continueGame,
                        icon: Icons.play_arrow_rounded,
                        primary: true,
                        onPressed: () => openGame(fresh: false),
                      ),
                      const SizedBox(height: 12),
                    ],
                    MenuButton(
                      theme: theme,
                      label: canContinue ? AppStrings.newGame : AppStrings.play,
                      icon: canContinue
                          ? Icons.refresh_rounded
                          : Icons.play_arrow_rounded,
                      primary: !canContinue,
                      onPressed: () => openGame(fresh: true),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: MenuButton(
                            theme: theme,
                            label: AppStrings.themes,
                            icon: Icons.palette_rounded,
                            onPressed: () => open(const ThemesScreen()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MenuButton(
                            theme: theme,
                            label: AppStrings.settings,
                            icon: Icons.settings_rounded,
                            onPressed: () => open(const SettingsScreen()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(GameTheme theme) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 24),
    child: Column(
      children: [
        BlockFitLogo(theme: theme, size: 104),
        const SizedBox(height: 18),
        Text(
          AppStrings.appName,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 46,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        Text(
          AppStrings.tagline,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textSecondary, fontSize: 15),
        ),
      ],
    ),
  );
}

class _HighScoreCard extends StatelessWidget {
  const _HighScoreCard({required this.theme, required this.best});

  final GameTheme theme;
  final int best;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 28),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    decoration: BoxDecoration(
      color: theme.boardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: theme.emptyCellColor, width: 2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.emoji_events_rounded, color: theme.accent, size: 32),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.highScore,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$best',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
