import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../core/strings.dart';
import '../providers/theme_provider.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

/// Logo, title and a loading bar, then fades into the Home screen.
/// Storage is already loaded in `main()`, so this only enforces a minimum
/// display time.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(AppConfig.splashMinDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(gameThemeProvider);
    return ThemedScaffold(
      theme: theme,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, t, child) =>
              Transform.scale(scale: t, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BlockFitLogo(theme: theme, size: 120),
              const SizedBox(height: 24),
              Text(
                AppStrings.appName,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    color: theme.accent,
                    backgroundColor: theme.emptyCellColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.loading,
                style: TextStyle(color: theme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
