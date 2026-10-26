import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../core/strings.dart';
import '../../services/link_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/common.dart';

/// Credits and contact details.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(gameThemeProvider);
    final secondary = TextStyle(color: theme.textSecondary, fontSize: 15);

    return ThemedScaffold(
      theme: theme,
      title: AppStrings.about,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              BlockFitLogo(theme: theme, size: 96),
              const SizedBox(height: 16),
              Text(
                AppStrings.appName,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(AppStrings.version(AppConfig.version), style: secondary),
              const SizedBox(height: 36),
              Text(AppStrings.builtBy, style: secondary),
              const SizedBox(height: 4),
              Text(
                AppStrings.companyName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 36),
              Text(AppStrings.contactUs, style: secondary),
              TextButton.icon(
                onPressed: () async {
                  if (!await LinkService.emailSupport() && context.mounted) {
                    showToast(context, AppStrings.linkFailed);
                  }
                },
                icon: Icon(Icons.mail_rounded, color: theme.accent),
                label: Text(
                  AppConfig.contactEmail,
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
